import pytest

from app.features.ai.retrieval_intent import resolve_retrieval_intent


CATALOG_LOCATIONS = [
    "Island Garden City of Samal", "Mati City", "Davao City", "Davao del Norte",
    "Samal Island Beach Area", "Dahican Beach", "beach", "island",
]


@pytest.mark.parametrize("word", ["beach", "beaches", "BEACHES"])
def test_original_request_resolves_province_and_beach(word):
    intent = resolve_retrieval_intent(
        f"I wanna travel the {word} in Davao del Norte, solo, budget 15,000 for 2 days",
        locations=CATALOG_LOCATIONS,
    )
    assert intent.target_locations == ("davao del norte",)
    assert intent.interest == "beach"
    assert intent.origin is None
    assert not intent.needs_clarification


def test_origin_and_target_are_distinct():
    intent = resolve_retrieval_intent(
        "Travel from Davao City to Samal for beaches", locations=CATALOG_LOCATIONS,
    )
    assert intent.origin == "davao city"
    assert intent.target_locations == ("samal",)
    assert intent.interest == "beach"
    assert not intent.needs_clarification


def test_origin_only_update_inherits_target_and_interest():
    intent = resolve_retrieval_intent(
        "I'm starting in Davao City",
        history=["Beaches in Samal for two days"],
        locations=CATALOG_LOCATIONS,
    )
    assert intent.origin == "davao city"
    assert intent.target_locations == ("samal",)
    assert intent.interest == "beach"


def test_latest_explicit_target_and_interest_replace_history_and_context():
    intent = resolve_retrieval_intent(
        "Actually Mati for food",
        history=["Beaches in Samal", "Starting in Davao City"],
        context={"target_location": "Samal", "interest": "mountain"},
        locations=CATALOG_LOCATIONS,
    )
    assert intent.target_locations == ("mati",)
    assert intent.interest == "food"
    assert intent.origin == "davao city"


def test_region_wide_request_clears_previous_specific_target():
    intent = resolve_retrieval_intent(
        "Show beaches across the whole Davao Region", history=["Visit Mati"],
        locations=CATALOG_LOCATIONS,
    )
    assert intent.region_wide
    assert intent.target_locations == ()
    assert intent.interest == "beach"


def test_unknown_explicit_place_cannot_broaden_to_everywhere():
    intent = resolve_retrieval_intent(
        "Beaches in Atlantis within my budget", history=["Visit Samal"],
        locations=CATALOG_LOCATIONS,
    )
    assert intent.target_locations == ("atlantis",)
    assert intent.needs_clarification
    assert not intent.region_wide


def test_conflicting_targets_require_clarification():
    intent = resolve_retrieval_intent(
        "Beaches in Samal or Mati", locations=CATALOG_LOCATIONS,
    )
    assert set(intent.target_locations) == {"samal", "mati"}
    assert intent.needs_clarification


def test_city_and_its_province_are_compatible():
    intent = resolve_retrieval_intent(
        "Visit Samal in Davao del Norte for beaches", locations=CATALOG_LOCATIONS,
    )
    assert intent.target_locations == ("samal",)
    assert not intent.needs_clarification


def test_catalog_city_alias_is_recognized_without_generic_place_aliases():
    intent = resolve_retrieval_intent(
        "Travel to Baybay for beaches", locations=["Baybay City", "beach", "island"],
    )
    assert intent.target_locations == ("baybay",)
    assert not intent.needs_clarification
    generic = resolve_retrieval_intent("I want a beach", locations=CATALOG_LOCATIONS)
    assert generic.target_locations == ()
    assert generic.interest == "beach"


def test_only_recognized_context_keys_influence_constraints():
    intent = resolve_retrieval_intent(
        "Show recommendations",
        context={
            "target_location": "Samal", "origin": "Davao City", "interest": "beaches",
            "unrelated": "Mati mountains", "notes": {"city": "Tagum"},
        },
        locations=CATALOG_LOCATIONS,
    )
    assert intent.target_locations == ("samal",)
    assert intent.origin == "davao city"
    assert intent.interest == "beach"
    assert not intent.needs_clarification


def test_last_history_with_each_explicit_field_is_used():
    intent = resolve_retrieval_intent(
        "My budget is 15000",
        history=["Beaches in Samal", "Actually Mati", "Starting in Davao City"],
        locations=CATALOG_LOCATIONS,
    )
    assert intent.target_locations == ("mati",)
    assert intent.origin == "davao city"
    assert intent.interest == "beach"


def test_unknown_origin_does_not_become_a_target():
    intent = resolve_retrieval_intent(
        "From Cagayan de Oro to Samal for beaches", locations=CATALOG_LOCATIONS,
    )
    assert intent.origin == "cagayan de oro"
    assert intent.target_locations == ("samal",)


def test_time_and_budget_are_not_locations_or_verified_costs():
    intent = resolve_retrieval_intent(
        "I want to travel to beaches in 2 days with a budget of 15000",
        locations=CATALOG_LOCATIONS,
    )
    assert intent.target_locations == ()
    assert intent.interest == "beach"
    assert set(intent.to_dict()) == {
        "target_locations", "origin", "interest", "region_wide", "needs_clarification",
    }


def test_catalog_davao_city_does_not_make_bare_davao_a_city_alias():
    intent = resolve_retrieval_intent("Beaches in Davao", locations=CATALOG_LOCATIONS)
    assert intent.target_locations == ("davao",)
    assert intent.needs_clarification


def test_named_samal_destination_and_its_province_are_compatible():
    intent = resolve_retrieval_intent(
        "Visit Samal Coral Beach in Davao del Norte",
        locations=["Samal Coral Beach", "Davao del Norte"],
    )
    assert intent.target_locations == ("samal coral beach",)
    assert not intent.needs_clarification


def test_latest_history_beats_stale_context_when_current_omits_target():
    intent = resolve_retrieval_intent(
        "My budget is 15000",
        history=["Beaches in Samal", "Actually Mati"],
        context={"target_location": "Samal"},
        locations=CATALOG_LOCATIONS,
    )
    assert intent.target_locations == ("mati",)


def test_multiple_interests_do_not_reject_valid_target_or_inherit_single_interest():
    intent = resolve_retrieval_intent(
        "Beaches and food in Samal",
        history=["Mountains in Davao del Sur"],
        locations=CATALOG_LOCATIONS,
    )
    assert intent.target_locations == ("samal",)
    assert intent.interest is None
    assert not intent.needs_clarification


@pytest.mark.parametrize("message", ["I want to relax", "What should I bring to the beach?"])
def test_general_help_is_not_an_unknown_target(message):
    intent = resolve_retrieval_intent(message, locations=CATALOG_LOCATIONS)
    assert intent.target_locations == ()
    assert not intent.needs_clarification


@pytest.mark.parametrize(
    "message",
    ["Show me nature spots in Davao City", "any good outdoors places", "eco-tourism trips"],
)
def test_nature_is_a_recognized_interest(message):
    intent = resolve_retrieval_intent(message, locations=CATALOG_LOCATIONS)
    assert intent.interest == "nature"


def test_naming_a_place_with_nature_in_its_name_is_not_a_nature_request():
    locations = [*CATALOG_LOCATIONS, "Eden Nature Park"]
    intent = resolve_retrieval_intent(
        "Add Eden Nature Park to my plan", locations=locations,
    )
    assert intent.interest is None
    assert intent.target_locations == ("eden nature park",)


def test_a_generic_nature_request_still_works_when_such_a_place_exists():
    locations = [*CATALOG_LOCATIONS, "Eden Nature Park"]
    intent = resolve_retrieval_intent("Any nature spots in Davao City?", locations=locations)
    assert intent.interest == "nature"


def test_nature_with_another_interest_does_not_pick_one_for_the_traveler():
    intent = resolve_retrieval_intent(
        "nature and waterfalls in Davao City", locations=CATALOG_LOCATIONS,
    )
    assert intent.interest is None

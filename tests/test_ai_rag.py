import asyncio
from decimal import Decimal
from types import SimpleNamespace

import pytest

from app.features.ai.rag import (
    VectorRAGRetriever,
    _accommodation_document,
    _destination_document,
    _transportation_document,
)
from app.features.ai import rag as rag_module


def destination(destination_id: int, name: str, district: str, **overrides):
    values = {
        "destination_id": destination_id,
        "name": name,
        "district": district,
        "location": name,
        "description": "A destination in the local travel catalog.",
        "category": "beach",
        "vibes": "relaxation",
        "activities": "swimming",
        "estimated_cost": Decimal("500.00"),
        "entrance_fee": "Ask the operator for current fees",
        "overnight_fee": None,
        "operating_hours": None,
        "best_time_to_visit": None,
        "how_to_get_there": None,
        "estimated_travel_time": None,
        "travel_notes": None,
        "what_to_bring": None,
        "budget_class": "budget",
        "crowd_level": None,
        "difficulty_level": "easy",
        "stay_duration_type": None,
        "transport_accessibility": None,
        "family_friendly": False,
        "group_friendly": False,
        "is_kid_friendly": False,
        "is_wheelchair_accessible": False,
        "is_pet_friendly": False,
        "is_elderly_friendly": False,
    }
    values.update(overrides)
    return SimpleNamespace(**values)


def room(place, *, name="Cabin", **overrides):
    values = {
        "accommodation_id": 1000 + place.destination_id,
        "destination_id": place.destination_id,
        "name": name,
        "room_type": "Standard",
        "price": Decimal("1200.00"),
        "capacity": 2,
        "description": "A place to sleep.",
    }
    values.update(overrides)
    return _accommodation_document(SimpleNamespace(**values), destination=place)


def transport(place, **overrides):
    values = {
        "transportation_id": 2000 + place.destination_id,
        "destination_id": place.destination_id,
        "vehicle_type": "Ferry",
        "transport_mode": "public_transport",
        "route_from": "Davao City Wharf",
        "route_to": place.location,
        "price": Decimal("150.00"),
        "duration_minutes": 30,
        "duration_text": "30 minutes",
        "notes": None,
    }
    values.update(overrides)
    return _transportation_document(SimpleNamespace(**values), destination=place)


def group(place):
    return [_destination_document(place), room(place), transport(place)]


def retriever_for(monkeypatch, documents):
    retriever = VectorRAGRetriever(None)

    async def load_documents():
        return documents

    monkeypatch.setattr(retriever, "_load_documents", load_documents)
    return retriever


def retrieve(retriever, query, **kwargs):
    return asyncio.run(retriever.retrieve(query, **kwargs))


def destination_ids(matches):
    return {
        match.payload["destination_id"]
        for match in matches
        if match.source == "destination"
    }


def assert_linked_groups(matches):
    selected = destination_ids(matches)
    assert all(match.payload["destination_id"] in selected for match in matches)
    assert len({(match.source, match.source_id) for match in matches}) == len(matches)


@pytest.fixture
def samal_catalog():
    first = destination(1, "Samal Coral Beach", "Davao del Norte", location="Samal")
    second = destination(2, "Samal Sand Beach", "Davao del Norte", location="Samal")
    wrong_province = destination(
        3,
        "Dahican Beach",
        "Davao Oriental",
        location="Mati",
        description=("A beach with room rates and transportation rates. Travelers "
                     "departing Davao del Norte or Samal can reach this beach."),
        how_to_get_there="Travel from Samal in Davao del Norte to Mati.",
    )
    island = destination(
        4,
        "Samal Island Wildlife Sanctuary",
        "Davao del Norte",
        location="Samal",
        category="wildlife",
        activities="bird watching",
        vibes="island, nature",
        description="An island wildlife sanctuary for bird watching.",
    )
    return group(first) + group(second) + group(wrong_province) + group(island)


def test_requested_samal_beaches_exclude_wrong_province_and_generic_island(
    monkeypatch, samal_catalog,
):
    retriever = retriever_for(monkeypatch, samal_catalog)
    matches = retrieve(
        retriever,
        "i wanna travel the beaches in davao del norte, can you recommend that "
        "good for solo traveler and that is within my budget of 15,000 and i "
        "wanna stay for 2 days.",
    )

    assert destination_ids(matches) == {1, 2}
    assert len(matches) == 6
    assert_linked_groups(matches)
    for destination_id in (1, 2):
        assert {
            match.source for match in matches
            if match.payload["destination_id"] == destination_id
        } == {"destination", "accommodation", "transportation"}


def test_beach_and_beaches_requests_select_the_same_places(monkeypatch, samal_catalog):
    retriever = retriever_for(monkeypatch, samal_catalog)
    singular = retrieve(retriever, "Suggest a beach in Samal, Davao del Norte.")
    plural = retrieve(retriever, "Suggest beaches in Samal, Davao del Norte.")

    assert destination_ids(singular) == destination_ids(plural) == {1, 2}


def test_latest_target_correction_overrides_previous_location(
    monkeypatch, samal_catalog,
):
    retriever = retriever_for(monkeypatch, samal_catalog)
    matches = retrieve(
        retriever,
        "Actually, suggest beaches in Mati, Davao Oriental instead.",
        history=["Suggest beaches in Samal, Davao del Norte with room rates."],
    )

    assert destination_ids(matches) == {3}
    assert_linked_groups(matches)


def test_departure_followup_keeps_previous_destination(monkeypatch, samal_catalog):
    retriever = retriever_for(monkeypatch, samal_catalog)
    matches = retrieve(
        retriever,
        "We will depart from Davao City. What about room and transport rates?",
        history=["Suggest beaches in Samal, Davao del Norte."],
    )

    assert destination_ids(matches) == {1, 2}
    assert_linked_groups(matches)


def test_origin_in_context_does_not_become_destination(monkeypatch, samal_catalog):
    retriever = retriever_for(monkeypatch, samal_catalog)
    matches = retrieve(
        retriever,
        "What are the available rooms and transport options?",
        context={
            "destination": "Samal, Davao del Norte", "origin": "Mati", "interest": "beach",
        },
    )

    assert destination_ids(matches) == {1, 2}
    assert_linked_groups(matches)


def test_from_and_to_separate_departure_from_target(monkeypatch, samal_catalog):
    city = destination(5, "Davao City Beach", "Davao City", location="Davao City")
    retriever = retriever_for(monkeypatch, samal_catalog + group(city))
    matches = retrieve(
        retriever,
        "I am traveling from Davao City to Samal for beaches and room rates.",
    )

    assert destination_ids(matches) == {1, 2}
    assert retriever.coverage["origin"] == "davao city"
    assert_linked_groups(matches)


def test_linked_rates_are_selected_despite_unrelated_keyword_rich_rates(monkeypatch):
    samal = destination(1, "Samal Coral Beach", "Davao del Norte", location="Samal")
    wrong = destination(2, "Dahican Beach", "Davao Oriental", location="Mati")
    documents = group(samal) + [
        _destination_document(wrong),
        room(wrong, name="Samal Davao del Norte beach room rates"),
        transport(wrong, notes="Samal Davao del Norte beach room transport rates"),
    ]
    retriever = retriever_for(monkeypatch, documents)
    matches = retrieve(retriever, "Samal beaches in Davao del Norte with room rates")

    assert destination_ids(matches) == {1}
    assert {match.source for match in matches} == {
        "destination", "accommodation", "transportation",
    }
    assert_linked_groups(matches)


def test_relevant_destination_keeps_linked_rates_with_zero_similarity(monkeypatch):
    samal = destination(1, "Samal Beach", "Davao del Norte", location="Samal")
    retriever = retriever_for(monkeypatch, group(samal))

    def score(*, query_vector, query_terms, document):
        return 0.9 if document.source == "destination" else 0.0

    monkeypatch.setattr(rag_module, "_score", score)
    matches = retrieve(retriever, "Samal beaches with room rates and transport")

    assert {match.source for match in matches} == {
        "destination", "accommodation", "transportation",
    }
    assert_linked_groups(matches)


def test_named_room_lookup_includes_only_its_parent_destination(monkeypatch):
    parent = destination(1, "Harbor View", "Davao del Norte", location="Samal")
    unrelated = destination(2, "Dahican Beach", "Davao Oriental", location="Mati")
    documents = [
        _destination_document(parent),
        room(parent, name="Cabin Resort"),
        transport(parent),
        _destination_document(unrelated),
        room(unrelated, name="Other Inn", description="Travel onward to Cabin Resort."),
        transport(unrelated, notes="Cabin Resort rates can be checked separately."),
    ]
    retriever = retriever_for(monkeypatch, documents)
    matches = retrieve(retriever, "What are the room rates at Cabin Resort?")

    assert destination_ids(matches) == {1}
    assert any(match.source == "accommodation" and match.title == "Cabin Resort"
               for match in matches)
    assert_linked_groups(matches)


@pytest.mark.parametrize("limit", [0, 1, 2, 6, 12])
def test_limits_keep_destinations_and_their_rates_together(monkeypatch, limit):
    documents = [
        document
        for destination_id in range(1, 5)
        for document in group(destination(
            destination_id,
            f"Samal Beach {destination_id}",
            "Davao del Norte",
            location="Samal",
        ))
    ]
    retriever = retriever_for(monkeypatch, documents)
    matches = retrieve(retriever, "Samal beaches with room rates and transport", limit=limit)

    assert len(matches) == limit
    assert_linked_groups(matches)
    if limit == 1:
        assert matches[0].source == "destination"
    if limit == 2:
        assert len(destination_ids(matches)) == 1
        assert len([match for match in matches if match.source != "destination"]) == 1
    if limit in (6, 12):
        assert len(destination_ids(matches)) == limit // 3


def test_duplicate_loaded_documents_do_not_duplicate_returned_sources(monkeypatch):
    documents = group(destination(1, "Samal Beach", "Davao del Norte", location="Samal"))
    retriever = retriever_for(monkeypatch, documents + documents)
    matches = retrieve(retriever, "Samal beaches with room rates and transportation", limit=12)

    assert len(matches) == 3
    assert_linked_groups(matches)


def test_no_matching_category_and_location_returns_no_unrelated_fallback(monkeypatch):
    falls = destination(
        1, "Tagbibinta Falls", "Davao de Oro", category="waterfall", activities="hiking",
    )
    beach = destination(2, "Samal Beach", "Davao del Norte", location="Samal")
    retriever = retriever_for(monkeypatch, group(falls) + group(beach))
    matches = retrieve(retriever, "Suggest beaches in Davao de Oro with room rates.")

    assert matches == []
    assert retriever.coverage["status"] == "no_matches"
    assert retriever.coverage["destinations"] == []


@pytest.mark.parametrize("limit, expected_room_status", [
    (1, "omitted_by_limit"),
    (6, "included"),
])
def test_coverage_distinguishes_missing_available_rates_from_omitted_rates(
    monkeypatch, limit, expected_room_status,
):
    samal = destination(1, "Samal Beach", "Davao del Norte", location="Samal")
    retriever = retriever_for(monkeypatch, [_destination_document(samal), room(samal)])
    matches = retrieve(
        retriever, "Samal beaches with rooms and transportation rates", limit=limit,
    )

    assert destination_ids(matches) == {1}
    assert retriever.coverage["status"] == "matched"
    assert retriever.coverage["destinations"] == [{
        "destination_id": 1,
        "accommodation_status": expected_room_status,
        "transportation_status": "no_available_records",
    }]
    assert retriever.coverage["truncated"] is (limit == 1)


def test_unstored_matching_target_reports_no_matches(monkeypatch):
    retriever = retriever_for(monkeypatch, [])
    assert retrieve(retriever, "Recommend beaches in Samal with rooms and ferry rates") == []
    assert retriever.coverage["status"] == "no_matches"


def test_region_wide_browsing_includes_destinations_from_distinct_districts(monkeypatch):
    places = [
        destination(1, "Davao City Garden", "Davao City", category="park"),
        destination(2, "Davao City Museum", "Davao City", category="museum"),
        destination(3, "Samal Coral Beach", "Davao del Norte"),
        destination(4, "Dahican Beach", "Davao Oriental", location="Mati"),
        destination(5, "Tagbibinta Falls", "Davao de Oro", category="waterfall"),
    ]
    retriever = retriever_for(monkeypatch, [doc for place in places for doc in group(place)])
    matches = retrieve(
        retriever, "Suggest destinations around the Davao Region with rooms and transport.",
        limit=12,
    )

    selected_districts = {
        match.payload["district"] for match in matches if match.source == "destination"
    }
    assert selected_districts == {
        "Davao City", "Davao del Norte", "Davao Oriental", "Davao de Oro",
    }
    assert_linked_groups(matches)

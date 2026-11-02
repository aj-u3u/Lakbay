# Phase 15D: Child-Aware Costing

The authenticated `POST /api/v1/planning/preview` accepts optional age details
and pricing rules in `state`. This is a stateless projection. No child prices,
traveler ages, or group expense shares are written to new tables.

## Request contract

- `traveler_count` remains the total party size.
- `adult_count` is the number of adults. When `child_ages` is supplied, it is
  required and `adult_count + len(child_ages)` must equal `traveler_count`.
- `child_ages` lists each child's age from 0 through 17. Duplicate ages represent
  different children. A child without a known age cannot receive a band price.
- `age_pricing_rules` are scoped to a selected `destination:<id>`, selected
  `activity:<destination_id>:<hash>`, or selected catalog
  `transportation:<id>` option. Each rule has nonoverlapping `child_bands` with
  `min_age`, `max_age`, and `rate` of `free`, `half`, or `full`.
- Destination and activity rules require `adult_unit_amount`. This is a traveler
  estimate because the current catalog lacks structured admission/activity
  prices. A transportation rule uses the selected catalog adult fare and is
  valid only for an explicitly priced per-person fare. Child bands are still
  traveler-supplied assumptions, not verified operator policies.

Example state fragment for one adult, a free four-year-old, and a half-rate
ten-year-old at destination 42:

```json
{
  "traveler_count": 3,
  "adult_count": 1,
  "child_ages": [4, 10],
  "age_pricing_rules": [
    {
      "category": "destination",
      "reference_id": "destination:42",
      "adult_unit_amount": "100.00",
      "child_bands": [
        {"min_age": 0, "max_age": 5, "rate": "free"},
        {"min_age": 6, "max_age": 12, "rate": "half"}
      ]
    }
  ]
}
```

The destination component is `1 × ₱100 + 1 × ₱0 + 1 × ₱50 = ₱150`.
Half rates round to cents per child before multiplying by the number of
children of that age and the explicit fare charge count.

## Budget behavior

The response keeps the existing `budget.lines`, category totals, completeness,
fit, and missing-cost contract. Adult catalog fare lines retain their existing
catalog provenance. Child lines use `source=traveler_age_pricing_rule` and show
the actual unit amount, quantity, and per-person basis. Destination and activity
adult lines use the same traveler-rule source. The assumption list discloses
that child bands are unverified.

A whole-trip allowance may cover all travelers instead of an age rule. A rule
cannot overlap an allowance for the same destination, activity, or all transport;
the response then reports a `pricing_assumption_invalid` selection problem.
An absent child rule for a selected per-person fare adds
`child_price_rule_missing`; an age outside the supplied bands adds
`child_price_band_missing`. Either makes `total_estimate=null` and budget
completeness `partial`. Known adult amounts remain in `priced_subtotal`, so a
proven minimum overage can still be reported. Per-vehicle, per-group, and room
prices keep their existing whole-unit calculations because no per-child fare
applies to those catalog charging units.

The rules are passed through the existing planning preview to AI generation;
the backend still validates selected IDs and budget limits. Both Flutter chat
review sheets collect the adult count and each child's age, verify they sum to
`traveler_count`, and send them in the planning state. For each selected
destination, the traveler chooses either a whole-trip allowance or an adult
per-person fee plus explicit free/half/full rates for every child age. The app
sends one destination allowance **or** one destination age rule, never both.
Activity and per-person transport age-band controls remain to be added; those
rules can already be sent through the API directly. Operators' current child
fees and eligibility rules still require direct verification.
If planning chat changes destination IDs, selected age rules are cleared along
with other destination-bound choices; party ages remain in the planning state.

Tests: `tests/test_phase15d_child_costs.py` and the planning cost, preview,
AI-save, and feedback regression suites.

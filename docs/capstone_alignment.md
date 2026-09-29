# Capstone Alignment Notes

This document maps panel comments to planned backend and documentation changes.
It is intended for manuscript, diagram, and defense preparation. It does not
change backend behavior by itself.

## Panel Comment Mapping

| Panel comment | Backend/docs status | Planned response |
| --- | --- | --- |
| Find the best routing algorithm and discuss it | Routing exists with OSRM and Haversine fallback | Document algorithm comparison in `docs/routing.md`, then improve routing in Phase 15A if needed |
| Add geo-analytics, not just mapping | Coordinates and route estimates exist | Add `docs/geo_analytics.md` and Phase 15B destination grouping |
| Group destination suggestions using ranking or scoring | Recommendation scoring exists | Extend docs with the exact scoring formula and planned group scoring |
| Consider children with free, half, or full costs | Deferred in expenses docs | Add Phase 15D child-aware costing plan |
| Put specific functions in use case diagram | Not stored in backend repo | Update capstone diagram manually using the use case notes below |
| Correct DFD and remove group member entity | Not stored in backend repo | Treat group member as a role/internal trip membership record, not an external actor |
| Rephrase objectives clearly | Not stored in backend repo | Use the objective wording below as a concise draft |
| Let AI generate itinerary based on geo-analytics | AI itinerary exists, but route context is separate | Add Phase 15E to pass geo-analytics context into AI |
| Show top 5 recommended destinations | Already supported by default limit 5 | Make this explicit in recommendation docs and examples |
| Account for land, plane, or boat travel | Transportation text fields exist, route modes are limited | Add travel category plan: land, air, sea, mixed |
| Add projection of costs based on activities | Destination and itinerary activity costs exist | Add Phase 15C activity-based budget projection |
| Provide feedback based on itinerary | Post-trip reviews exist | Add Phase 15F pre-trip itinerary feedback |

## Use Case Diagram Functions

Use these function names in the use case diagram instead of vague labels.

Traveler/user functions:

- Register account.
- Log in.
- Browse destinations.
- Submit travel preferences.
- View top 5 recommended destinations.
- View geo-analytics destination groups.
- Estimate trip budget.
- Generate AI itinerary.
- Preview or optimize route.
- Evaluate itinerary feedback.
- Save trip.
- Manage trip tasks.
- Record expenses.
- Upload trip memories.
- Generate trip report.
- Submit trip review.
- View notifications.

Admin functions:

- Manage destinations.
- Manage accommodation rates.
- Manage transportation rates.
- Review evaluation metrics.
- Review AI generation metrics.

System functions:

- Score destination recommendations.
- Group destinations using geo-analytics.
- Project activity and trip costs.
- Optimize routes.
- Validate AI itinerary output.
- Create notifications.
- Generate PDF reports.

## DFD Correction Notes

Recommended external entities:

- Traveler/User.
- Admin.
- External AI provider.
- External routing provider.
- External storage provider.

Do not use `Group Member` as a separate external entity. A group member is a
role or state of a user inside a trip. In the backend, this is represented by
the `trip_members` data store and membership roles such as owner, organizer, or
member.

Recommended data stores:

- Users.
- Destinations.
- Accommodations.
- Transportations.
- Preference signals.
- Recommendation interactions.
- AI generation runs.
- Trips.
- Trip members.
- Itinerary activities.
- Trip routes.
- Expenses.
- Memories.
- Reviews.
- Notifications.

## Concise Objective Draft

Use these as a cleaner starting point for the manuscript objectives:

1. Develop a FastAPI backend for a Davao Region travel planning application.
2. Provide preference-based destination recommendations using an explainable
   scoring model.
3. Support route-aware itinerary planning through geo-analytics and route
   optimization.
4. Generate AI-assisted itinerary options using validated destination, budget,
   transportation, and geo-analytics data.
5. Estimate trip costs using destination, activity, accommodation,
   transportation, meal, and traveler information.
6. Support saved trips, group collaboration, shared expenses, memories, reports,
   reviews, and notifications.
7. Collect evaluation data for recommendation quality, AI itinerary usefulness,
   route efficiency, budget adherence, and overall user experience.

## Writing Caution

When writing the capstone paper, separate implemented features from planned
enhancements.

Suggested wording:

```text
The current backend supports destination recommendations, budget estimation, AI
itinerary generation, route optimization, trip management, collaboration,
expenses, memories, reports, reviews, and notifications. Geo-analytics grouping,
child-aware costing, and AI itinerary generation using combined geo-analytics
context are planned as Phase 15 enhancements.
```


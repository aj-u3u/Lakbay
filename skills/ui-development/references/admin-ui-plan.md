# Lakbay Admin Web Interface Plan

Status: frontend enhancement implemented, 2026-10-03, after explicit user authorization. This document retains the original audit and proposed target; the implementation scope and current API limitations are recorded in the project README. Backend and mobile sources were inspected but not modified.

## Purpose and design direction

Create a coherent workspace for destination content, market rates, account administration, traveler feedback, and trip inspection. Use the same Lakbay identity as the mobile application while giving administrators efficient tables, reliable editing flows, and visible relationships between records.

The primary user is an administrator working in a desktop browser. Responsive layouts should remain usable on tablets and narrow browser windows. Light mode is the proposed initial workspace for long data-entry sessions; retain a fully specified dark mode and honor a saved appearance choice. This default is a recommendation, not an existing requirement.

## Source audit: what currently causes confusion

These findings come from source inspection, not a running-browser visual audit.

| Observed issue | Source evidence | Design response |
|---|---|---|
| The core palette and Outfit already match the mobile application; dashboard components introduce unrelated accents and gray text | Admin `lib/core/theme/app_theme.dart:6`; mobile `lib/core/theme/app_theme.dart:6`; admin `lib/screens/dashboard_screen.dart:98`, `:113`, `:181`, `:248` | Centralize semantic tokens and apply them across pages rather than recoloring only the theme |
| Navigation gives Transport, Accommodation, Activities, and Meals equal top-level weight, but contains no Reviews or Trips destinations | `lib/widgets/app_shell.dart:61`; `lib/main.dart:37` | Organize by the five requested admin jobs and group related rates |
| Activities and Meals tell the admin to edit the destination, but the destination editor only submits name, district, category, latitude, and longitude | `lib/screens/activities_screen.dart:85`; `lib/screens/meals_screen.dart:85`; `lib/screens/destinations_screen.dart:953` | Provide a real supported edit path, or explain the dependency; avoid instructions leading to missing fields |
| The active shell defines private navigation/top-bar widgets while separate Sidebar and Topbar implementations also exist | `lib/widgets/app_shell.dart:14`, `:50`; `lib/widgets/sidebar.dart:4`; `lib/widgets/topbar.dart:4` | Choose one shell during future implementation; do not assume the standalone widgets currently drive the screen |
| The active top bar derives an uppercase route title; pages repeat their own heading. Page gutters differ between dashboard and lists; the dashboard grid uses window width despite the sidebar consuming space | `lib/widgets/app_shell.dart:338`; `lib/screens/dashboard_screen.dart:74`, `:82`, `:308`; `lib/screens/destinations_screen.dart:42` | Global top bar plus one page title; common gutters; responsive decisions based on available content width |
| Static Recent Activity and Platform Status components exist in source but are not mounted by the current dashboard build | `lib/screens/dashboard_screen.dart:90`, `:595`, `:741` | Do not treat these as observed visible widgets or reuse their static data as live operational evidence |
| Settings contains booking confirmations, push notifications, and buttons with empty handlers | `lib/screens/settings_screen.dart:30`, `:55`, `:61` | Keep only requirements with actual behavior; move appearance/profile to utilities |

## Proposed navigation and ownership

| Main section | Admin job | Structure and principal action |
|---|---|---|
| Overview | See what needs attention and move to the relevant work | A few reliable totals, content/rate issues, recent verified feedback; links to filtered lists |
| Destinations | Maintain places and their traveler-facing information | Searchable list -> destination details -> full editor; **Add destination** |
| Market Rates | Maintain comparable costs used in travel planning | Accommodation and Transport tabs; destination/type filters; **Add rate** opens an explicit type/context choice |
| Users | Inspect accounts and perform supported account administration | Searchable list -> user details; account/role actions are proposed backend-dependent capabilities |
| Reviews & Feedback | Read traveler feedback and inspect related trips/places | Filtered list -> review details; moderation tools are proposed only where a workflow is agreed |
| Trips | View trip information and its related records | Searchable list -> read-only trip details; **View trip** |

The sidebar ends with account utilities rather than additional operational categories. Profile, appearance, supported settings, and Sign out remain easy to reach. Avoid an empty Settings section solely to complete the menu.

Accommodation and Transport remain first-class rate types under one workspace. Activities and meal inclusions belong to destination information. A future structured activity/meal rate catalog can be added under Market Rates after its model and API are agreed; the current final backend does not expose that catalog.

Relationship rules:

- A destination is the context for accommodation and transport rates. Its detail screen links to a destination-filtered rate list.
- A rate records its destination association and relevant type, route, or lodging information. Its destination link returns to the canonical place record.
- A review links to the original trip and any itinerary destination that the data explicitly identifies. Do not invent a direct destination foreign key where none exists.
- A trip links to its owner/members and itinerary places. Related account information appears only within an authorized admin access policy.
- Reuse the same identifiers and records across screens. Preserve navigation context and avoid separate copies of values that can drift.

## Common web page structure

| Region | Content and alignment |
|---|---|
| Sidebar | Lakbay+ Admin identity; operational navigation; selected-state indicator; account utilities |
| Global top bar | Breadcrumb/context when useful; appearance and current account; menu trigger at narrow widths |
| Page header | Title and one-sentence purpose on the left; one dominant task action on the right; one shared content gutter |
| Toolbar | Search, domain filters, active-filter summary and reset; count reflects the current result set |
| Workspace | Table/list, detail sections, or form; same left/right anchors as the header and toolbar |
| Footer/action area | Pagination for lists; Save/Cancel for editors; never detached from the record being acted on |

Use explicit page labels such as “Market Rates”, not raw route strings. Remove repeated title blocks. List rows, toolbar controls, section titles, and editor fields should have predictable vertical rhythm. Wrap actions and filters when the space shrinks rather than clipping them.

Proposed dimensions, expressed in Flutter logical pixels:

| Token | Proposal |
|---|---|
| Spacing scale | `4, 8, 12, 16, 24, 32, 48` |
| Desktop sidebar | `248` wide; compact labeled/icon rail approximately `80` when necessary |
| Global top bar | `64` high |
| Page gutters | `32` desktop; `24` tablet; `16` narrow |
| Section/panel gap | `24`; related controls `8-12` |
| Control height | `44` for inputs/main buttons; keep toolbar controls aligned |
| Table density | Header approximately `44`; default row approximately `56`; expand for wrapping, zoom, or accessibility |
| Radius | Inputs/buttons `12`; information panels `12-16`; preserve larger brand radius for occasional identity surfaces |
| Typography | Page title `28/36`; section title `18/26`; body/table `14/22`; helper `12/18`; principal values `24/32` |
| Weight | Regular body; medium table headers; semibold labels/actions; bold page title |

Use a fluid content area for operational tables. Constrain reading/form line length with an editor width near `960` when appropriate; do not constrain wide tables to a mobile-card width. Align money/numeric columns right, text left, and header/cell baselines consistently. Use tabular figures if the font supports them.

Suggested responsive behavior:

- At `1280+`: persistent expanded sidebar, complete toolbars, table and detail layouts with room for parallel sections.
- At `1024-1279`: compact sidebar if content needs space; filters can wrap; remove optional table columns only when their content is available in details.
- At `768-1023`: drawer navigation, stacked headers/actions where needed, single/two-column forms according to content fit.
- Below `768`: drawer, stacked filters/forms and compact summaries or a labeled horizontal table scroll. Keep essential fields and actions accessible.

Treat breakpoints as starting points. Verify at representative `1440`, `1280`, `1024`, `768`, and `390` widths, at text zoom, and with long names. Avoid page-wide horizontal overflow; intentional table scrolling stays inside the table region.

## Screen specifications

### Overview

Answer “What needs my attention?” Use four compact summaries only when supported: destination count, rate coverage/issues, account count, and recent feedback/trip information. An unavailable summary shows an explanation rather than zero.

The main workspace can prioritize destinations with missing information and rates awaiting verification **if supporting metadata is introduced**. Otherwise use real destination/rate records and links to their lists. Review queues and audit activity require backend support. Every displayed metric has a defined source, period, and drill-down. Avoid decorative charts, made-up percentage growth, permanent notification dots, and a simulated system-health checklist.

### Destinations

List columns: thumbnail/name, district or supported location label, category, existing active state, and actions. Proposed content-completeness/updated-at columns depend on reliable fields. Search by name and filter using supported category/location/active values. Public active-only listing is insufficient for a complete admin inventory; inactive records need an admin contract.

Detail sections: Overview, Location, Activities & inclusions, Related rates, and associated feedback when supported. The map helps confirm coordinates; textual coordinates and location remain accessible.

Use a dedicated editor grouped into Identity & description, Location, Activities & traveler suitability, Estimated fees, and Image. The final schema provides name, category, district/location, `lat`/`lng`, description, `image_url`, descriptive `activities`, estimated/entrance/overnight costs, and suitability/accessibility fields. Keep existing data types intact; descriptive activity text is not a per-activity price list. Image URL editing is different from an upload workflow, which needs separate support. The initial admin form supports fewer fields. Do not label a record “Published” or offer draft/publish scheduling when only `is_active` exists.

Primary flow: find destination -> inspect details -> edit supported fields -> validate -> save -> receive confirmed success -> return to the same list context. Deactivation/deletion wording must match actual backend semantics and explain relevant linked-data implications.

### Market Rates

Use Accommodation and Transport tabs within one consistently structured workspace. An aggregate view across destinations is a target UX, with an aggregation/admin-list dependency if the API only lists rates per destination.

Include available/unavailable filtering and a recovery path in the target admin inventory. Current public rate lists return available records only and do not expose an unavailable filter. Although a known rate ID can be updated back to available, an admin still needs an authorized way to rediscover unavailable rows. Treat complete inventory/recovery as a backend dependency, not a working filter today.

Accommodation columns: name/room type, destination, price with confirmed unit, capacity, availability when accessible, and actions. Transport columns: vehicle type, route from/to, associated destination, price, duration, and actions. Map labels to actual schema fields rather than legacy admin aliases. Use “Add accommodation rate” rather than “Add property” until a separate property entity is modeled.

Editors must choose the destination context. Format prices in Philippine pesos with explicit billing basis, for example “PHP 1,500 / room / night” or the confirmed route fare unit. Do not assume a transportation price is per person when the contract does not define that unit. Treat source/provider, verification date, validity period, and stale-rate badges as proposed metadata, not existing fields.

Do not infer meal/activity prices from overall destination estimated cost. Display such values as estimates or inclusions until a structured model supports rate editing.

### Users

Proposed list columns: name, email, role, and supported account state/date. Detail shows permitted profile information and related trip/review summaries where access exists.

The inspected backend provides self-profile operations; a global admin user list, role changes, suspension, account deletion, and related-data visibility need explicit backend contracts. These are design dependencies. Do not show password values or invent editable fields. Use focused confirmations for sensitive supported actions and explain their effect; do not substitute hard deletion for account suspension.

### Reviews & Feedback

Initial target: read and filter feedback by trip, date, and available ratings; inspect comments with original trip context. The backend review model has five 1-5 fields: `post_trip_rating` (Post-trip rating), `accuracy_rating` (Accuracy), `route_efficiency_rating` (Route efficiency), `budget_adherence_rating` (Budget adherence), and `overall_experience_rating` (Overall experience). Confirm survey wording before assigning narrower meanings such as recommendation accuracy. Display overall experience directly; label any separately calculated aggregate and agree its formula.

A detail view displays the original feedback, rating breakdown, submission date, permitted author information, related trip, and optional destination reference where supplied. Comments may be empty. Existing review states are `active` and `deleted`. “Pending”, “Flagged”, “Hidden”, reply tools, reason codes, and moderation actions are proposals requiring an admin review policy and backend support. Keep review inspection useful without pretending a moderation queue already exists. Preserve traveler-authored content; do not silently rewrite it through an admin editor.

### Trips

Read-only target list: trip title/identifier, owner, date information, status, traveler count, and **View trip**. Existing statuses are `planned`, `ongoing`, `completed`, and `archived`; use these meanings rather than inventing booking-confirmation states.

Detail sections: trip summary, participants permitted for admin inspection, itinerary/timeline and destination links, planned budget versus recorded expenses when available, and submitted feedback. Label planned and actual amounts separately. Keep task/memory information secondary when relevant and permitted.

Owner/member-scoped traveler routes do not provide global admin visibility. The final backend needs a deliberate admin read policy and endpoints before this workspace can show all trips. Do not add itinerary editing, reassignment, AI regeneration, bookings, or trip deletion to this viewing requirement.

## Palette and component semantics

Canonical brand values come from `UI_FOR_LAKBAY/lib/core/theme/app_theme.dart`; the admin already matches the core values.

| Role | Value | Use |
|---|---|---|
| Primary | `#20878E` | Brand/navigation accents and principal action family |
| Secondary | `#D66F29` | Restrained emphasis and secondary brand cues |
| Accent | `#178A90` | Supporting brand accent; not a separate status meaning |
| Light background / surface | `#F5F9F9` / `#FFFFFF` | Workspace / tables and panels |
| Light primary / secondary text | `#1A2E2E` / `#5C7878` | Body text / supporting text on appropriate surfaces |
| Dark background / surface | `#0D1F1F` / `#163030` | Dark workspace / panels |
| Dark primary / secondary text | `#F0F7F7` / `#8AADAD` | Dark-theme content |
| Light divider / input border | `#DDE8E8` / `#CFDFDF` | Structural divisions / existing input border token |
| Light input fill | `#F0F6F6` | Input surface |
| Existing admin dark surface / border | `#112525` / `#1C3D3D` | Optional admin-specific structural tokens; validate both themes |
| Existing admin status colors | Success `#10B981`; warning `#F59E0B`; error `#EF4444` | Semantic status only; pair with label/icon and tested text colors |

Teal and orange identify the brand; labels/icons identify meaning. Hover, selected, focused, disabled, and error states must be distinguishable. Use a restrained selected sidebar background plus an indicator and label weight. Keep action styles consistent: principal task, secondary outline/quiet action, and destructive action with explicit wording.

Calculated opaque-color contrast on source swatches: white on primary teal approximately `4.270:1`; white on orange approximately `3.406:1`; light muted text on page background approximately `4.487:1`, but on white approximately `4.759:1`. Rounded display ratios do not establish compliance. Copying the mobile swatches does not make every text pairing accessible.

Proposed semantic variants, subject to design review: `#19767D` for a filled action with white normal-size text (approximately `5.345:1`); `#A94F18` for orange-family text/action needs with white (approximately `5.499:1`); `#5A7474` for muted text on the light page (approximately `4.731:1`). Keep original brand swatches unchanged. Alternatively select a tested existing darker brand-family surface; document each role rather than changing colors ad hoc.

The design target follows [W3C text contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html): at least `4.5:1` for normal text and `3:1` for qualifying large text. Meaningful control/state graphics need `3:1` against adjacent colors under [non-text contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html). Pale dividers can remain decorative; if a border is necessary to identify a control, provide a sufficiently contrasting identifying treatment. Use at least `24` logical-pixel pointer targets or qualifying spacing under [target-size guidance](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html); the proposed `44` controls provide a practical workspace target. Full WCAG conformance requires a broader implementation review.

## States and truthful behavior

| Situation | Expected behavior |
|---|---|
| Loading | Stable skeleton/progress within the intended region; no invented data |
| Empty dataset | Explain that no records exist; offer creation only when supported |
| No search results | Preserve filters and offer clear/reset |
| API failure | Inline failure/retry; preserve previous data only when clearly marked stale |
| Backend capability missing | Explain availability in planning; omit/disable dependent controls in implementation |
| Forbidden/session expired | Clear access message or sign-in path; never represent it as an empty dataset |
| Validation/save failure | Retain entered values; show useful field/global errors; allow retry |
| Save succeeds | Confirm the saved record and refresh canonical data |
| Unsaved changes | Prompt before leaving/discarding; keep Save and Cancel predictable |
| Destructive operation | State record/context and actual consequence; distinguish deactivation from deletion |

Tables need readable headers, sorting indicators when supported, visible filter states, and pagination/count behavior that matches the API. Rich editors need persistent labels, required indicators, unit labels, inline help, and logical keyboard order. Dialogs must trap focus while open, offer escape/cancel where appropriate, and restore focus to the invoker.

## Final backend dependency map

Recheck `lakbay_backend_final` schemas and permissions before implementation. The current admin's older contract is not the intended integration target.

| Domain | Observed final-backend capability | Admin enhancement dependency |
|---|---|---|
| Authentication | `/api/v1/auth/login`, nested `user` and `tokens`; Bearer-protected writes | Align session parsing and authenticated requests during a separate authorized implementation |
| Destinations | Destination CRUD, `PATCH` updates, admin-protected writes; public active-only reads | Complete admin inventory/inactive inspection; richer editor must match schemas |
| Accommodation / Transport | Destination-scoped available-record list/create; `PATCH` and soft deletion by rate ID | Global admin list/aggregation, unavailable-record discovery/recovery, and any new billing/verification metadata |
| Activities / Meals | Destination activity text and fee estimates; request-level meal budget input | Structured rate catalogs and traveler display consumption, if requested |
| Users | Self-profile GET/PATCH | Global list/detail, administrative actions, permission/audit model |
| Reviews | Trip-scoped feedback, five rating dimensions, trip-access checks | Admin-wide search/list/detail and any moderation workflow |
| Trips | Owner/member-scoped trip workflows | Read-only admin-wide list/detail access policy and endpoints |
| Overview | Underlying traveler/catalog resources; no matching legacy `/analytics/*` or `/admin/users` routes registered | Defined admin metrics/queues; no placeholder growth/activity/health claims |

Useful source locations: final `app/main.py:29`, `app/core/config.py:11`, `app/api.py`; `app/features/auth/schemas.py`; `app/features/destinations/router.py`; `app/features/accommodations/router.py`; `app/features/transportations/router.py`; `app/features/users/router.py`; `app/features/reviews/router.py`; `app/features/trips/router.py`. Mobile configuration: `lib/core/config/api_config.dart:4`. Current admin contract: `lib/services/api_service.dart:6`.

Canonical field examples to preserve in future UI adapters:

| Record | Final schema fields relevant to the proposed workspace |
|---|---|
| Destination | `destination_id`, `name`, `description`, `district`, `location`, `category`, `lat`, `lng`, `activities`, `estimated_cost`, `entrance_fee`, `overnight_fee`, `image_url`, `is_active`, timestamps |
| Accommodation | `accommodation_id`, `destination_id`, `name`, `room_type`, `price`, `capacity`, `description`, `is_available`, timestamps |
| Transportation | `transportation_id`, `destination_id`, `vehicle_type`, `transport_mode`, `route_from`, `route_to`, `price`, `duration_minutes`, `duration_text`, `notes`, `is_available`, timestamps |
| User | `user_id`, `full_name`, `email`, `role`, `avatar_url`, `is_active`, timestamps; current self-update accepts name/avatar only |
| Review | `trip_review_id`, trip/user/member references, optional destination reference, five rating fields listed above, `comments`, `status`, timestamps |

These are field examples, not authorization to expose all records. Review the corresponding feature `schemas.py` and read-access rules before implementing list/detail forms. Available timestamps can support “Updated” labels; they do not constitute a verification history or an audit log.

A future end-to-end acceptance scenario is: an admin saves a supported destination/rate through the final backend; read back its canonical ID/value; refresh the traveler app; verify that a successful API request supplied that same value and that the screen displays it. Test destination, accommodation, and transportation records separately.

The inspected mobile app has a destination fallback at `UI_FOR_LAKBAY/lib/services/api_service.dart:433`, hardcoded accommodation presentation at `lib/models/destination.dart:427`, no accommodation/transport listing calls, and empty rate ID selections sent during itinerary generation at `lib/services/api_service.dart:803`. Delivering rate changes requires a separately scoped mobile integration slice as well as admin/backend alignment. The admin-only enhancement does not authorize changing the mobile app. A successful admin save does not prove traveler-screen delivery.

## Delivery sequence and review criteria

Planning can finalize the shell, component specifications, relationships, and complete list/detail/editor wireframes now. Keep dependent workflows visible in the planning document so their backend work can be scoped separately.

When implementation is later requested:

1. Consolidate shell, page headers, theme tokens, and common states.
2. Align one destination and accommodation/transport workflow with the final backend, including permissions and mobile consumption.
3. Implement Users, Reviews, and Trips only as their admin contracts become available; keep trip scope read-only.
4. Add Overview summaries sourced from supported real operations.

Review success with these tasks: find and update a destination; find its associated rate and understand the billing unit; inspect an account; open feedback and understand its trip context; view a trip without encountering editing controls. Check consistent gutters, hierarchy, active navigation, both themes, long content, keyboard access, narrow windows, and truthful unavailable/error states. Record any remaining contract dependency rather than implying the entire system is connected.

# Release review — budget and saved place data

Prepared on 10 November 2026 after the user approved separating the completed
fixes from unfinished work. This is a local release preparation record. Nothing
was pushed, merged into a remote branch, or deployed by this review.

**Backend deployment, later on 10 November:** the three backend commits below,
followed by the route-order and cleanup commits, reached `main` as `d8a0af4`
(fast-forward from `ae82ccc`). Render auto-deployed it, as confirmed by the
user from Render's events. The traveler and admin commits below are not merged,
and no phone check has been run against the deployed backend.

## Reviewed commits

| Project | Commit | Included change |
| --- | --- | --- |
| Backend | `40d76ee3faf44ee17305bcdf5e878533ccdc950b` | Three canonical per-person/whole-trip budget guard cases; no runtime change. |
| Backend | `b0015ef3a09f8092d2bca7334297e6ae3b3db067` | Saved destination facts and rate currencies/units in itinerary context, prompt versions/rules, API guide and end-to-end mocked regression. |
| Traveler | `1117ac86440e78cdcb98501ccc1a477cc2dd5030` | Canonical preview total in generation requests; preserve per-person scope and cents; regressions. |
| Traveler | `1329c144f90d9eeb6c162ab472a05fed519d180b` | Retain five saved travel-detail fields and feed the existing tips section; refresh/clearing regressions. |
| Admin | `2025a80db05b9bed96aa03f4582a74494394152f` | Exact save-payload regression for pins, fees, hours and travel notes; no runtime change. |

The backend's pin-based scope, phase notes and Claude handoff are a separate
documentation commit. They do not remove arrival fields or change database data.
No schema or migration change is included.

## Branches and inherited work

The isolated checkouts live under `tmp/release-review-20261110/` in the backend
workspace. The original three checkouts remain on their existing branches.

| Project | Local release branch | Starting commit |
| --- | --- | --- |
| Backend | `codex/release-budget-catalog-20261110` | `0378516a4abd5b25a32bb5bf817cdc5f4ac50952` |
| Traveler | `codex/release-budget-catalog-20261110` | `d89ba1dc533d12186f6c3a0fb27ab1c8905dd933` |
| Admin | `codex/release-catalog-save-check-20261110` | `525c78d` |

Remote refs were refreshed during review. The backend starts one existing
Top 5 documentation commit ahead of `origin/main` (`ae82ccc`). The traveler
starts **17 existing commits / 119 changed files** ahead of its `origin/main`
(`5b4afc9`): earlier conversational planning, Top 5, map/GPS and UI work. Those
commits are inherited foundations, not newly extracted fixes. A merge of the
traveler release branch into `main` would include them and must be described
with that full scope. The admin starting commit matches its remote
`codex/step0-admin-review` branch.

The extracted fixes exclude pending trip completion/app assessments, the View
Trip redesign and route changes, plus pending admin OSM, reporting, profile,
user-directory and shell changes. Only the reviewed hunks were taken from
shared files; whole dirty traveler/provider/API files were not copied into the
release. The admin regression passes on the committed editor without its
pending redesign. Flutter-generated platform registrations are excluded from
the commits.

## Verification of the isolated release branches

| Check | Result |
| --- | --- |
| Focused backend budget/catalog/AI/save/Top 5/unknown-cost tests | **58 passed** |
| Full traveler tests | **193 passed** |
| Full admin tests | **29 passed** |
| Traveler analysis | No issues |
| Admin analysis | No issues |
| Explicit selected file lists and staged whitespace checks | Passed |
| Credential-pattern scan of selected files | No findings |

The earlier 204 traveler / 38 admin counts describe the original checkouts with
their other pending features. The smaller release counts reflect their exclusion.
Tests use isolated SQLite, mock providers and local HTTP test servers; they do
not spend Groq credits or edit Neon. Test logs, patch files, starting file hashes
and commit metadata are retained under the ignored release-review directory.

Android test build: **passed** (`assembleDebug`, 339.2 seconds). The local artifact
is `outputs/releases/2026-11-10/lakbay-budget-catalog-1329c144-test.apk`
(170,940,587 bytes), built from traveler commit `1329c144f90d9eeb6c162ab472a05fed519d180b`.
SHA-256: `11c48cf9b129338d3ea654f7223a4f0d08bc49487691f7c9aa633696f078e5af`.
It uses `https://lakbay-backend-final.onrender.com/api/v1`. This is an installable
debug build for verification, not a store-signed release. The new backend prompt
context is not live until its corresponding backend revision is deployed.

Final file-hash verification confirmed that original branch HEADs and unrelated
source/test/asset/document bytes match the starting snapshot. The only original
file updates during extraction were the explicitly updated handoff/release
documents and removal of an excess EOF blank line in the new backend test.

## Remaining release work

The user subsequently deferred deployment and phone checks to work on itinerary
and route behavior. The approved saved-route correction is a later local change;
the six release commits and APK described here are preserved and do not include
it. Resume with a fresh review and rebuild rather than treating this APK as
proof of the later fix. See the [routing guide](routing.md).

1. Review the complete traveler branch scope against `main`, including its
   inherited 17 commits. Choose the deployment/merge target explicitly.
2. ~~Publish the reviewed branches and deploy the backend revision.~~ Done for
   the backend: `d8a0af4` is deployed (see the note at the top). The health
   endpoint still has no build identifier, so Render's events remain the proof
   of which revision is running. The traveler and admin branches are unpublished.
3. Install the traveler test build on the connected phone. The final device
   discovery detected a physical Android 15 phone; earlier checks showed only
   Windows and Edge. No phone journey was run during this review. After backend
   deployment, refresh an admin-edited place and confirm
   pin, notes, fees, hours and rate units; then exercise Top 5 and generation.
4. Confirm that PHP 3,000.05 per person for three travelers sends PHP 9,000.15
   exactly once while the editable planning state remains per person. Check an
   ordinary whole-trip budget and a rejected/expired session as well.

Arrival editing stays deferred and pin routes remain approximate. Missing live
catalog prices/units and source verification still need actual admin review.
The accommodation selector, saved-route order/return preservation, >50 Top 5
shortlist edge case and other open findings in the
[Claude handoff](claude_codex_objectives_audit_2026-11-10.md) are not fixed by
these release commits. The backend route-order rule and the >50 Top 5
shortlist fix were added in later commits that are now deployed; the traveler
route-preservation change is still uncommitted.

# Lakbay+ UI/UX and Feature Enhancement Detailed Plan (v2)

## Purpose
This document outlines the revised UI/UX, navigation flow, and functional enhancement plan for Lakbay+. Every section includes detailed developer instructions, screen-by-screen specifications, and data/logic requirements.

**Goals:**
- Improve user experience through clear feedback, intuitive navigation, and premium visual design
- Strengthen travel-planning logic with AI-integrated destination data
- Differentiate solo and group travel clearly at the planning level, not at signup
- Prepare backend-ready functional specifications
- Ensure all buttons have defined destinations and behaviors
- Ensure destination data flows consistently into AI generation and trip details

---

# GLOBAL SYSTEM REQUIREMENTS

## 1. Feedback Mechanisms (Required Across All Screens)

Users must always understand: what action happened, whether it succeeded or failed, and what to do next.

---

### 1.1 Toast / Snackbar Notifications

**Trigger on:**
- Adding a destination or trip → `"Trip added successfully."`
- Uploading a memory photo → `"Memory uploaded successfully."`
- Completing a task → `"Task marked as completed."`
- Saving a trip → `"Trip saved."`
- Updating budget → `"Budget updated."`

**Developer Instructions:**
- Display at bottom of screen, above navigation bar
- Auto-dismiss after 3 seconds
- Support swipe-to-dismiss gesture
- Use green color for success, red for errors, blue for info
- Queue toasts if multiple actions fire rapidly

---

### 1.2 Loading States

**Required for:**
- AI itinerary generation → show animated spinner with message: `"Generating your itinerary..."`
- Image uploads → show progress bar with percentage
- Trip saving → full-screen overlay with `"Saving your trip..."`
- Notification fetch → skeleton loader in notification list
- Planner budget calculation → inline spinner next to result field

**Developer Instructions:**
- Never show a blank white screen during async operations
- Skeleton loaders must match the shape and layout of actual content
- Loading overlays must be dismissible only after action completes or fails

---

### 1.3 Empty States

**Trigger when no content exists. Always include a call-to-action button.**

| Screen | Message | CTA Button |
|---|---|---|
| Trips Page | "No trips yet. Start planning your adventure." | "Plan a Trip" → navigates to Planner |
| Memories | "No memories yet. Capture your first moment." | "Upload Memory" → opens photo picker |
| Notifications | "You're all caught up!" | None |
| Group Tasks | "No tasks assigned yet." | "Add Task" → opens task creation sheet |

---

### 1.4 Error Handling

**Error messages must be actionable. Never show raw error codes to users.**

| Error Type | User-Facing Message | Action |
|---|---|---|
| No internet | "No connection. Check your network and try again." | "Retry" button |
| AI unavailable | "AI is temporarily unavailable. Try again shortly." | "Retry" button |
| Failed photo upload | "Upload failed. Please try a smaller image." | "Try Again" |
| Missing required input | Highlight field in red with inline label: `"This field is required."` | Focus on field |
| Session expired | "Your session has expired. Please log in again." | "Log In" → Auth screen |

---

### 1.5 Confirmation Dialogs

**Required before any destructive or irreversible action.**

| Action | Dialog Title | Dialog Message | Buttons |
|---|---|---|---|
| Delete trip | "Delete Trip?" | "This will permanently delete the trip and all its data." | "Cancel" / "Delete" (red) |
| Delete memory | "Delete Memory?" | "This photo will be removed from your memories." | "Cancel" / "Delete" (red) |
| Remove group member | "Remove Member?" | "This person will lose access to the group trip." | "Cancel" / "Remove" (red) |
| Cancel task | "Cancel Task?" | "This task will be marked as cancelled." | "Keep" / "Cancel Task" |
| Leave group trip | "Leave Trip?" | "You will lose access to this group trip." | "Stay" / "Leave" (red) |

---

# GET STARTED PAGE

## Current Issue
The carousel photo is not working.

## Required Fix — Carousel

**Package:** `carousel_slider`

**Implementation Requirements:**
- Autoplay interval: 4 seconds
- Support swipe left/right gesture
- Smooth fade or slide animation (slide recommended)
- Maintain 16:9 image aspect ratio; use `BoxFit.cover`
- Show dot indicators at bottom of carousel; active dot = white/filled, inactive = white/outlined
- Minimum 3 destination photos in carousel (Davao-region photos)
- Images must preload to avoid blank flash on autoplay

**Developer Instructions:**
```
CarouselSlider(
  options: CarouselOptions(
    autoPlay: true,
    autoPlayInterval: Duration(seconds: 4),
    viewportFraction: 1.0,
    enableInfiniteScroll: true,
  ),
  items: destinationImages.map((img) => Image.asset(img, fit: BoxFit.cover)).toList(),
)
```

---

## Visual Enhancement

**Required additions:**
- Gradient overlay (bottom 40% of carousel): dark to transparent, for text legibility
- Destination name text over gradient: large, bold, premium serif or sans-serif font
- Subtle animation on page load: fade-in of logo and CTA buttons (300ms ease-in)
- Bottom CTA buttons: "Get Started" (primary/filled) and "Log In" (secondary/outlined)

**Button Destinations:**
| Button | Action |
|---|---|
| "Get Started" | Navigate → Create Account Page |
| "Log In" | Navigate → Login Page |

---

# SNEAK PEEK / DISCOVER PAGE

## UI Revision — Bento-Style Layout

**Reason:** Bento grids feel premium, modern, and visually travel-inspired. They allow featured content alongside quick-scan cards.

**Bento Grid Layout Specification:**

```
[ LARGE CARD — Featured Destination (full width) ]
[ MEDIUM CARD — Adventure ] [ MEDIUM CARD — Beach ]
[ SMALL — Rating ] [ SMALL — Budget ] [ SMALL — AI Pick ]
[ MEDIUM CARD — Nature ] [ MEDIUM CARD — Culture ]
```

**Card Types:**

| Card Size | Content |
|---|---|
| Large (full width) | Featured destination photo, name, short tagline, "Explore" button |
| Medium | Category name (Adventure/Beach/Nature/Culture), photo, destination count |
| Small | Rating badge, "Budget Friendly" tag, or "AI Recommended" badge |

**Developer Instructions:**
- Use `GridView` or custom `Wrap` widget with defined proportions
- Large card: height 220px, rounded corners 16px
- Medium cards: height 140px, side by side with 8px gap
- Small cards: height 80px, three per row
- All cards are tappable → navigate to filtered Destination List for that category

---

## Text Revision

| Current | Replace With |
|---|---|
| "Create Free Account" | "Create Account" |

---

# CREATE ACCOUNT PAGE

## Required Changes

### 4.1 Add Confirm Password Field

**Fields (in order):**
1. Full Name
2. Email
3. Password (with show/hide toggle eye icon)
4. Confirm Password (with show/hide toggle eye icon)

**Validation Rules:**
- Full Name: required, min 2 characters
- Email: required, valid email format
- Password: required, min 8 characters, at least 1 uppercase, 1 number
- Confirm Password: must match Password field exactly
- Show inline red error text beneath field on validation fail
- "Sign Up" button disabled until all fields pass validation

**Show/Hide Toggle:**
- Eye icon on right side of password fields
- Tap to toggle visibility
- Both fields toggle independently

---

### 4.2 Remove Travel Preferences

**Reason:** Travel preferences belong to trip planning, not account creation. Keeping signup minimal reduces drop-off.

**Fields to Remove:** Any travel type, preferred destinations, or category checkboxes at signup.

**Minimal Signup Fields Only:** Full Name, Email, Password, Confirm Password.

---

### 4.3 Button Destinations

| Button | Action |
|---|---|
| "Sign Up" / "Create Account" | Validate → Create account → Navigate to Home Page |
| "Already have an account? Log In" | Navigate → Login Page |
| Back arrow | Navigate → Get Started Page |

---

# HOME PAGE

**Current UI is strong. Enhancements add richness without clutter.**

---

## 5.1 District Bento Explorer (New Section)

**Placement:** Below "Popular Destinations" section.

**Purpose:** Encourage exploration of all 6 districts within the Davao Region.

**Districts to Include (all 6):**

| District | Suggested Mood Tag |
|---|---|
| Davao City | Urban Culture & Heritage |
| Davao del Norte | Adventure Gateways |
| Davao Oriental | Coastal Escapes |
| Davao de Oro | Wilderness & Rivers |
| Davao del Sur | Mountain Retreats |
| Davao Occidental | Hidden Coastal Gems |

> ⚠️ **Note:** Davao Occidental was missing in the previous version. It is now included as the 6th district.

**Bento Card Contents:**
- Destination photo (representative of district)
- District name (bold)
- Mood tag (italic subtitle)
- Destination count (e.g., "8 destinations")

**Tap Action:** Navigate → filtered Destination List showing only destinations within that district.

---

## 5.2 Additional Home Suggestions — Detailed Functionality

### 5.2.1 Continue Planning Widget

**What it does:** Detects if the user has any unfinished/draft trip and surfaces a quick-resume card.

**Trigger:** Displayed only if an incomplete trip exists in local or remote storage.

**Card Contents:**
- Trip name (e.g., "Mt. Apo Trip")
- Progress indicator (e.g., "Step 2 of 4: Add budget")
- Destination thumbnail
- "Continue" button

**Button Action:** "Continue" → Navigate directly to the step in the Planner where the user left off.

**Hide When:** No draft trips exist, or all trips are fully created.

---

### 5.2.2 AI Mood Suggestions

**What it does:** Displays quick-tap mood tiles that pre-fill the AI Planner with a travel mood/category, allowing users to start planning instantly with a single tap.

**Mood Options:**
- 🏔️ Adventure
- 🌿 Relaxation
- 👨‍👩‍👧 Family
- 🌊 Beach
- 🌲 Nature
- 🏙️ Culture

**Tap Action:** Navigate → AI Planner Page (Scenario 2 / Open-ended) with the selected mood pre-filled into the prompt field.

**Example:** Tapping "Beach" pre-fills the AI prompt with: `"Suggest a beach trip in Davao Region."`

---

### 5.2.3 Notifications Bell

**What it does:** Displays a bell icon in the top app bar with an unread count badge.

**Badge Behavior:**
- Red circle badge appears when unread notifications > 0
- Badge shows count (max display: "9+" if over 9)
- Badge disappears when all notifications are marked as read

**Tap Action:** Bell icon → Navigate to Notifications Page.

---

## 5.3 Notification Page — Full Functionality

**Notification Types:**
| Notification Type | Example Message |
|---|---|
| AI itinerary ready | "Your AI itinerary for Mt. Apo is ready!" |
| Trip updated | "Your Samal Island trip has been updated." |
| Member joined | "Maria joined your Davao Oriental trip." |
| Task completed | "Juan completed: Book accommodation." |
| Memory uploaded | "A new memory was added to Samal Trip." |

**Each Notification Card Must Show:**
- Icon (unique per notification type)
- Title (bold)
- Description (1–2 lines)
- Timestamp (relative: "2 hours ago", "Yesterday")
- Unread indicator (colored left border or dot)
- Tap action → navigates to the relevant screen (trip, task, memory, or AI result)

**Mark as Read:**
- Tapping the notification marks it as read (removes unread indicator)
- "Mark All as Read" button in top-right of Notifications Page

---

# DESTINATION DETAILS PAGE

## 6.1 Activity Pricing (Required)

**Each activity listed must have a visible price indicator.**

**Format:**

```
[ Activity Name ]         [ Free ] or [ ₱XXX ]
Hiking Mt. Apo            ₱150 entrance fee
Sightseeing (People's Park) Free
Eden Nature Park Zipline   ₱400
```

**Developer Instructions:**
- Use a tag/pill component: green pill for "Free", blue pill for "₱XXX"
- Pricing data must be stored in the destination database and editable by admins

---

## 6.2 Full Destination Information Schema

**This data schema is the single source of truth. It must flow into:**
1. AI itinerary generation (pre-loads context for Scenario 1)
2. Trip Details Page (displays same data once trip is created)
3. PDF receipt export

---

### Core Details
| Field | Type | Example |
|---|---|---|
| Destination Name | String | "Mt. Hamiguitan Wildlife Sanctuary" |
| Location / District | String | "Davao Oriental" |
| Description | Long text | "A UNESCO World Heritage Site..." |
| Category | Enum | Adventure, Beach, Nature, Culture, Urban |
| Rating | Float (1–5) | 4.7 |
| Operating Hours | String | "Monday–Sunday, 6:00 AM – 5:00 PM" |

---

### Financial Information (Critical for AI + Trip Details)
| Field | Type | Example |
|---|---|---|
| Entrance Fee | Number (₱) | ₱150 |
| Activity Prices | Array of {name, price} | [{Hiking, ₱150}, {Zipline, ₱400}] |
| Accommodation Range | String | "₱800 – ₱3,500/night" |
| Transportation Estimate | String | "₱200–₱500 from Davao City" |
| Parking Fee | Number or null | ₱50 or null if not applicable |
| Meal Estimate | String | "₱150–₱400/meal" |

> ⚠️ **AI Integration Note:** When a user taps "Plan with AI" from a destination, ALL financial fields above must be passed as context to the AI prompt so the AI can compute Low/Balanced/Premium budget options accurately.

---

### Trip Planning Information
| Field | Type | Example |
|---|---|---|
| Best Time to Visit | String | "March–May (dry season)" |
| Crowd Level | Enum | Low / Moderate / High |
| Estimated Duration | String | "1–2 days" |
| Weather Reminder | String | "Bring rain gear; afternoon showers common" |
| Travel Tips | Array of strings | ["Book guides in advance", "Wear sturdy footwear"] |

---

### Convenience Information
| Field | Type | Example |
|---|---|---|
| Available Accommodations | Array of strings | ["Campsite", "Eco-lodge", "Nearby pension house"] |
| Meal Availability | String | "Food stalls inside; restaurant 2km away" |
| Transportation Options | Array of strings | ["Private car", "Habal-habal", "Van for hire"] |
| Nearby Attractions | Array of destination IDs | Links to related destinations |

---

# HOME TO AI FLOW

## Scenario 1 — Destination-Selected AI Planning

**Flow:**
```
Home → Destination Details → [Tap "Plan with AI"] → AI Planner (pre-loaded)
```

**What AI Receives Automatically (from Destination Data):**
- Destination name and location
- All activity names and prices
- Entrance fee
- Accommodation range
- Transportation estimate
- Meal estimate
- Operating hours
- Best time to visit
- Travel tips

**AI Then Asks User:**
1. Travel dates (date range picker)
2. Trip duration (auto-calculated from dates, editable)
3. Budget preference (slider or input: min–max in ₱)
4. Solo or Group? If group → number of travelers

**AI Output:**
Generate 3 itinerary options:

| Option | Description |
|---|---|
| Low Budget | Minimizes fees; uses cheapest transport and accommodation |
| Balanced | Mix of comfort and savings |
| Premium | Best available options regardless of cost |

Each option must show:
- Day-by-day schedule
- Itemized cost breakdown (using destination's financial data)
- Total estimated cost
- "Use This Plan" button → saves to Trips Page

---

## Scenario 2 — Open-Ended AI Suggestion

**Flow:**
```
Planner Page → User types prompt → AI responds
```

**Example Prompt:** `"Beach trip under ₱5,000 for 2 people"`

**AI Behavior:**
- Recommends 2–3 matching destinations from the Davao Region
- Displays each destination with photo, name, and estimated cost
- User selects one → AI generates itinerary using that destination's full data schema (same as Scenario 1)
- Same 3 budget option output format

---

# SOLO VS. GROUP TRAVEL

## Placement

**Solo/Group selection belongs in the Planner, not at signup.**

**Placement in Planner Flow:**
```
1. Enter destination (or use AI suggestion)
2. Select dates
3. ← [Solo or Group?] ←
4. Enter budget
5. Generate itinerary
```

**UI:**
```
Travel Type
○ Solo Travel
● Group Travel
```

If Group is selected → additional field appears: "Number of travelers" (stepper input, min 2).

---

## Solo vs. Group UI Differences

**Core layout stays the same. Extra modules appear contextually.**

### Solo Travel Modules
| Module | Description |
|---|---|
| Personal Itinerary | Private, non-shared schedule |
| Personal Notes | Free-text field, visible only to user |
| Solo Budget Tracker | Single-person expense tracker |
| Personal Memories | Private photo gallery |
| PDF Receipt Export | Single-person expense summary |

**UI Style:** Cleaner, minimal, no collaboration indicators.

---

### Group Travel Extra Modules
| Module | Description |
|---|---|
| Members Panel | Expandable list of members with avatars |
| Task Assignment | Assign tasks to individual members |
| Shared Expenses | Split-cost calculator; shows each person's share |
| Collaboration Notes | All members can add/edit notes |
| Group Memories | Shared photo gallery (privacy restricted to group members only) |
| Contribution Tracker | Shows who has paid what |

**UI Style:** Member avatars shown in header; group indicators on cards.

---

# TRIPS PAGE

## Trip Cards — Required Fix

**Current Issue:** Cards are not tappable.

**Required:** Each trip card must be a full tappable area → navigates to Trip Details Page for that trip.

---

## Trip Tags

Each trip card must show a visual pill tag:

| Tag | Color |
|---|---|
| Solo | Blue pill |
| Group | Green pill |

---

## Trip Status (Revised)

**Remove "Active" status. Only two statuses:**

| Status | Meaning | Display |
|---|---|---|
| Upcoming | Trip date is in the future | Yellow badge |
| Completed | Trip date has passed | Gray badge |

> ⚠️ "Active" status has been removed per product decision. Trips are either planned (Upcoming) or done (Completed).

---

## Add Button — Full Functionality (Required)

**Current Issue:** Add (+) button has no function.

**Required:** Tapping "+" opens a bottom sheet modal with three options:

| Option | Icon | Action |
|---|---|---|
| Manual Trip | 📝 | Navigate → Manual Trip Creator form |
| AI Trip | 🤖 | Navigate → AI Planner Page (Scenario 2) |
| Join via Link | 🔗 | Opens text input to paste a shared group trip link |

---

# TRIP DETAILS PAGE

**Must be editable wherever marked. Data must reflect destination schema.**

---

## Solo Trip Details Layout

| Section | Contents | Editable? |
|---|---|---|
| 1. Hero Card | Destination photo, name, district | No |
| 2. Trip Info | Destination, dates, duration | Yes |
| 3. Pricing | Entrance fee, activity prices, accommodation, transport, meals — all pulled from destination schema | Yes (user can adjust actuals) |
| 4. Notes | AI-generated suggestions + user personal notes | Yes |
| 5. Itinerary | Day-by-day schedule | Yes |
| 6. Route & Transport | Map view + transport options from destination schema | Yes |
| 7. Memories | Location-tagged personal photos | Add/Delete |
| 8. Budget Analysis | Estimated vs. actual spend chart | Auto-calculated |
| 9. PDF Receipt | Export button → generates downloadable PDF | Button |

**Button Destinations:**
| Button | Action |
|---|---|
| "Edit" (any section) | Opens inline edit mode for that section |
| "Add Memory" | Opens photo picker |
| "Export PDF" | Generates and downloads PDF receipt |
| "Delete Trip" | Confirmation dialog → delete |

---

## Group Trip Details Layout

| Section | Contents | Editable? |
|---|---|---|
| 1. Hero Section | Destination photo, trip name, district | No |
| 2. Members Panel | Expandable list: avatars, names, roles (organizer/member) | Organizer can remove members |
| 3. Task Assignment | List of tasks, each with assignee and due date | Yes (by organizer or assignee) |
| 4. Shared Notes | AI suggestions + all member inputs | Yes (all members) |
| 5. Itinerary | Day-by-day schedule | Yes (organizer) |
| 6. Transportation | Options from destination schema | Yes |
| 7. Collaboration Memories | Shared photo gallery | Add (any member) |
| 8. Budget Split | Per-person cost breakdown using destination financial data | Auto-calculated |
| 9. Contribution Tracker | Who paid what; balance per member | Yes |
| 10. PDF Receipt | Group expense summary | Button |

**Button Destinations:**
| Button | Action |
|---|---|
| "Add Member" | Opens share link generator or search |
| "Add Task" | Opens task creation sheet |
| "Upload Memory" | Opens photo picker |
| "Export PDF" | Generates group PDF receipt |
| "Leave Trip" | Confirmation dialog → removes user from group |

---

# PHOTO MEMORIES

## Memory Data Schema

Each memory must contain:

| Field | Type | Required |
|---|---|---|
| Photo | Image file | Yes |
| Location Tag | GPS coordinates + place name | Yes |
| Date Taken | DateTime | Yes (auto from photo metadata or manual) |
| Uploader | User ID + display name | Yes |
| Trip Association | Trip ID | Yes |
| Caption | String | Optional |

---

# MEMORIES PAGE

## Layout

**Tab Navigation:**
```
[ All ]  [ Solo ]  [ Group ]
```

- **All:** Every memory the user has access to (own + group memberships)
- **Solo:** Only memories from solo trips
- **Group:** Only memories from group trips the user belongs to

**Privacy Rule:** Users can only see memories from groups they are a member of. No browsing of unrelated group memories.

---

## Memory Card Contents

| Element | Details |
|---|---|
| Thumbnail | Square crop, 1:1 ratio |
| Location Tag | Pin icon + place name |
| Trip Name | Linked to the trip |
| Date | Formatted: "May 15, 2025" |
| Uploader Name | Shown for group memories |

**Tap Action:** Full-screen photo viewer with all metadata displayed.

---

## Button Destinations on Memories Page

| Button | Action |
|---|---|
| "+" / "Add Memory" | Opens photo picker → location tag prompt → save |
| Memory card (tap) | Full-screen photo viewer |
| Delete (long press or swipe) | Confirmation dialog → delete memory |

---

# PROFILE PAGE

## Required Changes

**Remove:**
- Settings icon (move settings to separate page accessible from hamburger or bottom navigation)
- Travel Preferences section (no longer part of profile)

---

## Edit Profile Fields

### Basic (Required)
| Field | Notes |
|---|---|
| Profile Photo | Tappable to change; shows camera overlay on tap |
| Full Name | Editable text field |
| Username | Editable; unique validation |
| Email | Editable; requires re-authentication to change |

### Optional
| Field | Notes |
|---|---|
| Phone Number | Optional; used for future trip notifications |
| Emergency Contact | Name + number; recommended for solo travelers |

### Travel Stats (Read-Only Display)
| Field | Source |
|---|---|
| Saved Trips Count | Count from Trips database |
| Memories Count | Count from Memories database |

### Security
| Option | Action |
|---|---|
| Change Password | Opens change password flow (current → new → confirm) |
| Log Out | Confirmation dialog → clears session → navigate to Get Started Page |

---

## Button Destinations on Profile Page

| Button | Action |
|---|---|
| "Edit Profile" | Opens editable form for basic fields |
| "Save" | Validates and saves changes → success toast |
| "Change Password" | Opens change password screen |
| "Log Out" | Confirmation dialog → Log Out → Get Started Page |

---

# AI DATA INTEGRATION SUMMARY

**Critical Rule:** All financial and logistical data from the Destination schema (Section 6.2) must be consistently used in:

| Feature | Data Used |
|---|---|
| AI Planner (Scenario 1) | Entrance fee, activity prices, accommodation range, transport estimate, meal estimate, operating hours, travel tips |
| AI Planner (Scenario 2) | Same fields, pulled after AI recommends destination |
| Solo Trip Details → Pricing section | Entrance fee, activity prices, accommodation, transport, meals |
| Group Trip Details → Budget Split | Same + divided by number of travelers |
| PDF Receipt | All financial fields, itemized |
| Budget Analysis Chart | Estimated (from destination schema) vs. Actual (user-entered) |

---

# FINAL UX PHILOSOPHY

Lakbay+ must feel:
- **Intelligent** — AI knows the destination before the user even types
- **Visually premium** — Bento grids, smooth transitions, rich photos
- **Organized** — Data flows consistently from destination → AI → trip → receipt
- **Traveler-friendly** — Financial info always visible; no hidden costs
- **Collaborative when needed** — Group features appear only for group trips
- **Simple when solo** — Clean, minimal, personal

The system does not use separate app flows for solo and group. Core experience stays consistent. Solo and group features appear contextually based on trip type selected during planning.

---

*Document Version: 2.0 | Last Updated: May 2026*

# LyfeWare Ecosystem: Cross-App Integration Roadmap

This document outlines features that leverage shared data between **Pantry**, **HomeBase**, and **Vinyl** via the unified LyfeWare Auth and Supabase backend.

## 1. Kitchen Concert (Pantry + Vinyl)
- **Concept:** Recipes set the musical vibe.
- **Data Flow:** `recipe_cuisine` (Pantry) -> `genre_seed` (Vinyl).
- **Feature:** When "Cooking Mode" starts in Pantry, Vinyl automatically triggers a playlist matching the cuisine (e.g., Italian Opera for Pasta, Lo-fi for Meal Prep).

## 2. Chore-Sync Anthems (HomeBase + Vinyl)
- **Concept:** High-energy music for high-effort chores.
- **Data Flow:** `task_difficulty` (HomeBase) -> `audio_features.bpm` (Vinyl).
- **Feature:** Marking a "Deep Clean" chore as "In Progress" in HomeBase triggers a high-BPM "Power Clean" playlist in Vinyl.

## 3. The Smart Grocery Split (Pantry + HomeBase)
- **Concept:** Automated household debt management.
- **Data Flow:** `receipt_total` (Pantry) -> `new_expense` (HomeBase).
- **Feature:** When scanning a receipt in Pantry , items tagged "Household" are automatically pushed to the HomeBase expense tracker and split among housemates.

## 4. The Potluck Planner (Triple Integration)
- **Concept:** Seamless event hosting.
- **Data Flow:** `household_members` (HomeBase) + `dietary_restrictions` (Pantry) + `top_genres` (Vinyl).
- **Feature:** Creating an event in HomeBase generates a grocery list in Pantry (filtered by guest allergies) and a "Household Blend" playlist in Vinyl based on all attendees' tastes.

## 5. Eco-Vibe Analytics (The LyfeWare Wrap)
- **Concept:** Unified household "Month in Review."
- **Data Flow:** Aggregated stats from all three apps.
- **Feature:** A monthly report showing: "You saved $50 by not wasting food (Pantry), completed 45 chores (HomeBase), and your top house genre was Jazz (Vinyl)."

## 6. Mood-Food Matching (Vinyl + Pantry)
- **Concept:** Listen-history informs dinner suggestions.
- **Data Flow:** `recent_mood_analysis` (Vinyl) -> `recipe_tags` (Pantry).
- **Feature:** If Vinyl detects "Stressed" or "Melancholic" listening patterns, Pantry suggests "Comfort Food" or "Easy 15-minute" recipes. High-energy music suggests "Meal Prep" or "Experimental" recipes.

## 7. "Who's Home?" Shopping Alerts (HomeBase + Pantry)
- **Concept:** Geofencing and presence-aware shopping.
- **Data Flow:** `user_location_status` (HomeBase) -> `shopping_list_notification` (Pantry).
- **Feature:** When a roommate is detected at a grocery store via HomeBase, Pantry sends a push notification to other roommates: "User is at Whole Foods. Any last-minute additions to the Shared List?"

## 8. The Victory Fanfare (HomeBase + Vinyl)
- **Concept:** Gamifying household tasks with sound.
- **Data Flow:** `chore_completion_status` (HomeBase) -> `playback_trigger` (Vinyl).
- **Feature:** When the "Last Dish" is checked off in HomeBase, Vinyl plays a user-defined "Victory Song" on all connected household speakers.

## 9. Concert Fund Tracker (Vinyl + HomeBase)
- **Concept:** Collective saving for experiences.
- **Data Flow:** `artist_wishlist` (Vinyl) -> `shared_savings_goal` (HomeBase).
- **Feature:** If multiple roommates "Star" the same artist in Vinyl, HomeBase suggests a "Concert Fund" savings goal and tracks contributions toward tickets.

## 10. Late-Night Snack Mode (Vinyl + Pantry)
- **Concept:** Contextual UI for late-night vibes.
- **Data Flow:** `active_playback_time` (Vinyl) -> `pantry_visibility` (Pantry).
- **Feature:** If Vinyl is playing past 11 PM, Pantry's "Suggested Recipes" switches to "Quick Snacks" and "Hangover Prevention" tips, using a "Dark Mode" high-contrast UI to match the late-night listening vibe.

## 11. The "Grocery Gig" Status (Pantry + HomeBase)
- **Concept:** Real-time activity presence.
- **Data Flow:** `shopping_session_active` (Pantry) -> `user_status_label` (HomeBase).
- **Description:** When a user activates "Personal Shopper" mode in Pantry, their status in the HomeBase household list automatically updates to "🛒 At the Store." This prevents unnecessary "Who's home?" messages and signals housemates to check the shared shopping list immediately.

## 12. Soundtrack of My Life: Chef Edition (Pantry + Vinyl)
- **Concept:** Historical musical/culinary pairings.
- **Data Flow:** `playback_history` (Vinyl) -> `chef_history_metadata` (Pantry).
- **Description:** When a user completes a meal in Pantry, the app queries Vinyl for the top tracks played during that time window. In the Pantry "Chef History" tab, each cooked meal is saved alongside its "Official Soundtrack," creating a sensory diary of the user's culinary journey.

## 13. Rent-Day Rewards (HomeBase + Vinyl)
- **Concept:** Boosting morale after financial tasks.
- **Data Flow:** `all_bills_paid_status` (HomeBase) -> `playback_trigger` (Vinyl).
- **Description:** Once the monthly rent and utilities are marked as fully paid by all members in HomeBase, Vinyl unlocks a "Financial Freedom" achievement and automatically queues a curated celebration playlist for the household's shared speakers.

## 14. Nutritional BPM (Triple Integration)
- **Concept:** Correlating physical activity and nutrition.
- **Data Flow:** `protein_goal_shortfall` (Pantry) + `chore_energy_requirement` (HomeBase) -> `workout_vibe_curation` (Vinyl).
- **Description:** If Pantry tracks that the user hasn't hit their nutritional goals, HomeBase moves high-energy "Active Chores" (like yard work or vacuuming) to the top of the queue. Simultaneously, Vinyl suggests a "Power Move" workout playlist to motivate the user to finish their chores and hit their fitness targets.

---

## SQL Architecture Prompt for Claude

**Copy and paste the following prompt to Claude to generate your unified Supabase schema:**

> "I am building the LyfeWare Ecosystem, which consists of three apps (Pantry, HomeBase, and Vinyl) that share a single Supabase backend and a 'Sign in with LyfeWare' identity system.
> 
> Please act as a world-class Database Architect and generate a single, robust SQL migration file that sets up the following:
> 
> 1. **Core Identity:** A `profiles` table that extends Supabase Auth with fields for `display_name`, `avatar_url`, `dietary_restrictions`, `favorite_genres`, and an `active_household_id`.
> 2. **Household Logic:** A `households` table and a `household_members` join table to allow users to belong to shared spaces.
> 3. **Pantry Schema:** Tables for `pantry_items`, `recipes`, `shopping_list` (with `is_household` flag), and `chef_history`.
> 4. **HomeBase Schema:** Tables for `chores` (with difficulty ratings), `expenses`, and `household_events`.
> 5. **Vinyl Schema:** Tables for `listening_sessions`, `artist_wishlist`, and `shared_playlists`.
> 6. **Cross-App Sync:** 
>    - Create a trigger that updates a user's status in `profiles` when a `shopping_session` starts in Pantry.
>    - Ensure all tables use Row Level Security (RLS) so users can only see their personal data or data belonging to their `active_household_id`.
>    - Implement Foreign Key constraints that link app-specific data to the central `household_id`.
> 
> Use `DROP TABLE IF EXISTS` logic for all tables to ensure a clean slate, and provide clear comments for each section. Ensure all timestamps use `timezone('utc'::text, now())`."

---

## Technical Implementation Notes
- **Shared Profile Table:** Must store `dietary_restrictions`, `favorite_genres`, and `active_household_id`.
- **Household ID:** The primary key linking data across all three apps.
- **Real-time Subscriptions:** Use Supabase Realtime/Broadcast to trigger Vinyl playback changes when HomeBase or Pantry state changes occur.
# AppWare Ecosystem: Cross-App Integration Roadmap

This document outlines features that leverage shared data between **Hungry**, **Roomies**, and **Jukebox** via the unified AppWare Auth and Supabase backend.

## 1. Kitchen Concert (Hungry + Jukebox)
- **Concept:** Recipes set the musical vibe.
- **Data Flow:** `recipe_cuisine` (Hungry) -> `genre_seed` (Jukebox).
- **Feature:** When "Cooking Mode" starts in Hungry, Jukebox automatically triggers a playlist matching the cuisine (e.g., Italian Opera for Pasta, Lo-fi for Meal Prep).

## 2. Chore-Sync Anthems (Roomies + Jukebox)
- **Concept:** High-energy music for high-effort chores.
- **Data Flow:** `task_difficulty` (Roomies) -> `audio_features.bpm` (Jukebox).
- **Feature:** Marking a "Deep Clean" chore as "In Progress" in Roomies triggers a high-BPM "Power Clean" playlist in Jukebox.

## 3. The Smart Grocery Split (Hungry + Roomies)
- **Concept:** Automated household debt management.
- **Data Flow:** `receipt_total` (Hungry) -> `new_expense` (Roomies).
- **Feature:** When scanning a receipt in Hungry , items tagged "Household" are automatically pushed to the Roomies expense tracker and split among housemates.

## 4. The Potluck Planner (Triple Integration)
- **Concept:** Seamless event hosting.
- **Data Flow:** `household_members` (Roomies) + `dietary_restrictions` (Hungry) + `top_genres` (Jukebox).
- **Feature:** Creating an event in Roomies generates a grocery list in Hungry (filtered by guest allergies) and a "Household Blend" playlist in Jukebox based on all attendees' tastes.

## 5. Eco-Vibe Analytics (The AppWare Wrap)
- **Concept:** Unified household "Month in Review."
- **Data Flow:** Aggregated stats from all three apps.
- **Feature:** A monthly report showing: "You saved $50 by not wasting food (Hungry), completed 45 chores (Roomies), and your top house genre was Jazz (Jukebox)."

## 6. Mood-Food Matching (Jukebox + Hungry)
- **Concept:** Listen-history informs dinner suggestions.
- **Data Flow:** `recent_mood_analysis` (Jukebox) -> `recipe_tags` (Hungry).
- **Feature:** If Jukebox detects "Stressed" or "Melancholic" listening patterns, Hungry suggests "Comfort Food" or "Easy 15-minute" recipes. High-energy music suggests "Meal Prep" or "Experimental" recipes.

## 7. "Who's Home?" Shopping Alerts (Roomies + Hungry)
- **Concept:** Geofencing and presence-aware shopping.
- **Data Flow:** `user_location_status` (Roomies) -> `shopping_list_notification` (Hungry).
- **Feature:** When a roommate is detected at a grocery store via Roomies, Hungry sends a push notification to other roommates: "User is at Whole Foods. Any last-minute additions to the Shared List?"

## 8. The Victory Fanfare (Roomies + Jukebox)
- **Concept:** Gamifying household tasks with sound.
- **Data Flow:** `chore_completion_status` (Roomies) -> `playback_trigger` (Jukebox).
- **Feature:** When the "Last Dish" is checked off in Roomies, Jukebox plays a user-defined "Victory Song" on all connected household speakers.

## 9. Concert Fund Tracker (Jukebox + Roomies)
- **Concept:** Collective saving for experiences.
- **Data Flow:** `artist_wishlist` (Jukebox) -> `shared_savings_goal` (Roomies).
- **Feature:** If multiple roommates "Star" the same artist in Jukebox, Roomies suggests a "Concert Fund" savings goal and tracks contributions toward tickets.

## 10. Late-Night Snack Mode (Jukebox + Hungry)
- **Concept:** Contextual UI for late-night vibes.
- **Data Flow:** `active_playback_time` (Jukebox) -> `pantry_visibility` (Hungry).
- **Feature:** If Jukebox is playing past 11 PM, Hungry's "Suggested Recipes" switches to "Quick Snacks" and "Hangover Prevention" tips, using a "Dark Mode" high-contrast UI to match the late-night listening vibe.

## 11. The "Grocery Gig" Status (Hungry + Roomies)
- **Concept:** Real-time activity presence.
- **Data Flow:** `shopping_session_active` (Hungry) -> `user_status_label` (Roomies).
- **Description:** When a user activates "Personal Shopper" mode in Hungry, their status in the Roomies household list automatically updates to "🛒 At the Store." This prevents unnecessary "Who's home?" messages and signals housemates to check the shared shopping list immediately.

## 12. Soundtrack of My Life: Chef Edition (Hungry + Jukebox)
- **Concept:** Historical musical/culinary pairings.
- **Data Flow:** `playback_history` (Jukebox) -> `chef_history_metadata` (Hungry).
- **Description:** When a user completes a meal in Hungry, the app queries Jukebox for the top tracks played during that time window. In the Hungry "Chef History" tab, each cooked meal is saved alongside its "Official Soundtrack," creating a sensory diary of the user's culinary journey.

## 13. Rent-Day Rewards (Roomies + Jukebox)
- **Concept:** Boosting morale after financial tasks.
- **Data Flow:** `all_bills_paid_status` (Roomies) -> `playback_trigger` (Jukebox).
- **Description:** Once the monthly rent and utilities are marked as fully paid by all members in Roomies, Jukebox unlocks a "Financial Freedom" achievement and automatically queues a curated celebration playlist for the household's shared speakers.

## 14. Nutritional BPM (Triple Integration)
- **Concept:** Correlating physical activity and nutrition.
- **Data Flow:** `protein_goal_shortfall` (Hungry) + `chore_energy_requirement` (Roomies) -> `workout_vibe_curation` (Jukebox).
- **Description:** If Hungry tracks that the user hasn't hit their nutritional goals, Roomies moves high-energy "Active Chores" (like yard work or vacuuming) to the top of the queue. Simultaneously, Jukebox suggests a "Power Move" workout playlist to motivate the user to finish their chores and hit their fitness targets.

---

## SQL Architecture Prompt for Claude

**Copy and paste the following prompt to Claude to generate your unified Supabase schema:**

> "I am building the AppWare Ecosystem, which consists of three apps (Hungry, Roomies, and Jukebox) that share a single Supabase backend and a 'Sign in with AppWare' identity system.
> 
> Please act as a world-class Database Architect and generate a single, robust SQL migration file that sets up the following:
> 
> 1. **Core Identity:** A `profiles` table that extends Supabase Auth with fields for `display_name`, `avatar_url`, `dietary_restrictions`, `favorite_genres`, and an `active_household_id`.
> 2. **Household Logic:** A `households` table and a `household_members` join table to allow users to belong to shared spaces.
> 3. **Hungry Schema:** Tables for `pantry_items`, `recipes`, `shopping_list` (with `is_household` flag), and `chef_history`.
> 4. **Roomies Schema:** Tables for `chores` (with difficulty ratings), `expenses`, and `household_events`.
> 5. **Jukebox Schema:** Tables for `listening_sessions`, `artist_wishlist`, and `shared_playlists`.
> 6. **Cross-App Sync:** 
>    - Create a trigger that updates a user's status in `profiles` when a `shopping_session` starts in Hungry.
>    - Ensure all tables use Row Level Security (RLS) so users can only see their personal data or data belonging to their `active_household_id`.
>    - Implement Foreign Key constraints that link app-specific data to the central `household_id`.
> 
> Use `DROP TABLE IF EXISTS` logic for all tables to ensure a clean slate, and provide clear comments for each section. Ensure all timestamps use `timezone('utc'::text, now())`."

---

## Technical Implementation Notes
- **Shared Profile Table:** Must store `dietary_restrictions`, `favorite_genres`, and `active_household_id`.
- **Household ID:** The primary key linking data across all three apps.
- **Real-time Subscriptions:** Use Supabase Realtime/Broadcast to trigger Jukebox playback changes when Roomies or Hungry state changes occur.
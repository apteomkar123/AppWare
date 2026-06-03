== PANTRY ==
The schema is mostly backward-compatible with Pantry's current code because
table names are preserved (fridge_inventory, shopping_list, saved_recipes, etc.).

Changes needed in Pantry app code:
  1. friendships table: The old schema used (user_id, friend_id) as the primary
     key. The new unified schema uses (requester_id, addressee_id) + status.
     Update all Pantry queries that read/write friendships:
       - OLD: .from('friendships').select().eq('user_id', uid)
       - NEW: .from('friendships').select().or('requester_id.eq.'+uid+',addressee_id.eq.'+uid)
               .eq('status', 'accepted')

  2. friend_requests table: This table is GONE. Friend requests are now rows in
     friendships with status='pending'. Update Pantry's send/accept/decline flow:
       - Send request:  INSERT INTO friendships (requester_id, addressee_id)
       - Accept:        UPDATE friendships SET status='accepted' WHERE id=...
       - Decline/block: UPDATE friendships SET status='blocked' WHERE id=...

  3. household_members: Pantry previously stored household_id directly on profiles.
     The active household is still on profiles.active_household_id (preserved),
     but membership is now tracked in household_members junction table.
     When a user creates/joins a household, also INSERT into household_members.

  4. profiles.display_name vs profiles.username: Both exist. Pantry's greeting
     ("Good Afternoon, Chef") should use display_name, with username as fallback.

  5. hungry_settings JSONB: Store personal_name, dietary_restrictions, nutrition
     goals, age, weight, height, personal_monthly_budget inside this column:
       UPDATE profiles SET hungry_settings = hungry_settings || '{"personal_name":"..."}' WHERE id=...


== HOMEBASE ==
The main breaking change is the households table column name.

Changes needed in HomeBase app code:
  1. households.title → households.name
     The old HomeBase schema used `title` for the household name.
     The unified schema uses `name` (matching Pantry's convention).
     Search and replace in HomeBase: .select('title') → .select('name')
     and any inserts/updates that set `title` → set `name` instead.

  2. household_members: HomeBase already has this table and it's preserved
     with the same structure. No changes needed here.

  3. profiles: The HomeBase profile had username, avatar_url, karma, away, updated_at.
     All these fields exist in the unified profiles table. Queries should work
     as-is, but note: profiles.updated_at is now managed by a trigger automatically.

  4. handle_new_user trigger: The unified trigger auto-creates the profile with
     a unique username. No changes needed in app code.


== VINYL ==
Vinyl is the most compatible — its schema was the most complete and was used
as the reference model for friendships, now_playing, privacy_settings, etc.

Changes needed in Vinyl app code:
  1. profiles: Vinyl's profiles had `monthly_active_users` column — this has
     been removed from the unified schema (it was an analytics metric, not a
     profile field). Remove any code reading/writing monthly_active_users.

  2. friendships: Vinyl's model is preserved exactly (requester_id/addressee_id
     + status). No code changes needed.

  3. profiles.hungry_settings: New JSONB column — Vinyl should ignore it.
     No impact on existing Vinyl queries.

  4. profiles.karma / profiles.away: New columns from HomeBase — Vinyl should
     ignore them. No impact on existing Vinyl queries.


== LYFEWARE AUTH PORTAL ==
The auth portal at authlyfeware.netlify.app needs no database changes.
It uses Supabase Auth directly (auth.users table) which is unchanged.

The handle_new_user() trigger will auto-create a profiles row whenever
a new user signs up through any app or through the auth portal.

Recommended next steps for LyfeWare Auth portal:
  1. After sign-in, redirect users back to the app they came from using
     the ?redirect_to= query parameter pattern already in LyfeWareAuthIntegration.md
  2. The portal's .env already points to the correct Supabase project
  3. Enable Apple OAuth in Supabase Dashboard → Authentication → Providers
     (Google is already configured per the notes)
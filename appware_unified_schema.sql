-- ============================================================
-- APPWARE ECOSYSTEM — UNIFIED SUPABASE SCHEMA
-- Generated: 2026-05-29
-- Supabase Project: wshadsznycwugowiexmy.supabase.co
--
-- Covers: Hungry (food/kitchen), Roomies (household mgmt),
--         Jukebox (music social), AppWare Auth (SSO portal)
--
-- ⚠  THIS SCRIPT IS DESTRUCTIVE — it drops all existing
--    AppWare tables before recreating them.
--    Back up any data you want to keep first.
--
-- HOW TO RUN:
--   1. Supabase Dashboard → SQL Editor
--   2. Paste this entire file and press Run (▶)
--   3. If it errors partway, fix the issue and run again —
--      most statements are idempotent or safely re-runnable.
-- ============================================================


-- ============================================================
-- PHASE 0 — WIPE (drop everything in dependency order)
-- ============================================================

-- Triggers
DROP TRIGGER IF EXISTS on_auth_user_created       ON auth.users;
DROP TRIGGER IF EXISTS on_profile_created_privacy ON public.profiles;
DROP TRIGGER IF EXISTS profiles_updated_at        ON public.profiles;

-- Functions / views
DROP FUNCTION IF EXISTS public.handle_new_user()             CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_profile_privacy()  CASCADE;
DROP FUNCTION IF EXISTS public.touch_updated_at()            CASCADE;
DROP FUNCTION IF EXISTS public.is_household_member(uuid)     CASCADE;
DROP VIEW     IF EXISTS public.friends_view                  CASCADE;

-- Leaf tables first, then parents
DROP TABLE IF EXISTS public.green_room_messages    CASCADE;
DROP TABLE IF EXISTS public.green_rooms            CASCADE;
DROP TABLE IF EXISTS public.messages               CASCADE;
DROP TABLE IF EXISTS public.chat_participants      CASCADE;
DROP TABLE IF EXISTS public.chat_rooms             CASCADE;
DROP TABLE IF EXISTS public.giveaway_entries       CASCADE;
DROP TABLE IF EXISTS public.giveaways              CASCADE;
DROP TABLE IF EXISTS public.drop_reminders         CASCADE;
DROP TABLE IF EXISTS public.drops                  CASCADE;
DROP TABLE IF EXISTS public.time_capsules          CASCADE;
DROP TABLE IF EXISTS public.mixtape_swaps          CASCADE;
DROP TABLE IF EXISTS public.concert_wishlist       CASCADE;
DROP TABLE IF EXISTS public.concert_going          CASCADE;
DROP TABLE IF EXISTS public.privacy_settings       CASCADE;
DROP TABLE IF EXISTS public.circle_members         CASCADE;
DROP TABLE IF EXISTS public.circles                CASCADE;
DROP TABLE IF EXISTS public.ticket_stubs           CASCADE;
DROP TABLE IF EXISTS public.setlist_votes          CASCADE;
DROP TABLE IF EXISTS public.now_playing            CASCADE;
DROP TABLE IF EXISTS public.album_ratings          CASCADE;
DROP TABLE IF EXISTS public.day_one_registry       CASCADE;
DROP TABLE IF EXISTS public.linked_accounts        CASCADE;
DROP TABLE IF EXISTS public.friend_requests        CASCADE;
DROP TABLE IF EXISTS public.friendships            CASCADE;
DROP TABLE IF EXISTS public.potluck_claims         CASCADE;
DROP TABLE IF EXISTS public.potluck_items          CASCADE;
DROP TABLE IF EXISTS public.potluck_events         CASCADE;
DROP TABLE IF EXISTS public.chef_history_photos    CASCADE;
DROP TABLE IF EXISTS public.chef_history           CASCADE;
DROP TABLE IF EXISTS public.meal_plan_recipes      CASCADE;
DROP TABLE IF EXISTS public.meal_plans             CASCADE;
DROP TABLE IF EXISTS public.saved_recipes          CASCADE;
DROP TABLE IF EXISTS public.shopping_list          CASCADE;
DROP TABLE IF EXISTS public.fridge_inventory       CASCADE;
DROP TABLE IF EXISTS public.agreement_signatures   CASCADE;
DROP TABLE IF EXISTS public.coliving_agreements    CASCADE;
DROP TABLE IF EXISTS public.lockbox                CASCADE;
DROP TABLE IF EXISTS public.pet_logs               CASCADE;
DROP TABLE IF EXISTS public.maintenance_tickets    CASCADE;
DROP TABLE IF EXISTS public.guest_logs             CASCADE;
DROP TABLE IF EXISTS public.bookings               CASCADE;
DROP TABLE IF EXISTS public.read_acks              CASCADE;
DROP TABLE IF EXISTS public.notices                CASCADE;
DROP TABLE IF EXISTS public.shopping_items         CASCADE;
DROP TABLE IF EXISTS public.subscription_members   CASCADE;
DROP TABLE IF EXISTS public.subscriptions          CASCADE;
DROP TABLE IF EXISTS public.transaction_splits     CASCADE;
DROP TABLE IF EXISTS public.transactions           CASCADE;
DROP TABLE IF EXISTS public.karma_marketplace      CASCADE;
DROP TABLE IF EXISTS public.chore_assignments      CASCADE;
DROP TABLE IF EXISTS public.chores                 CASCADE;
DROP TABLE IF EXISTS public.user_presence          CASCADE;
DROP TABLE IF EXISTS public.cross_app_activity     CASCADE;
DROP TABLE IF EXISTS public.household_members      CASCADE;
DROP TABLE IF EXISTS public.profiles               CASCADE;
DROP TABLE IF EXISTS public.households             CASCADE;

-- Enum types
DROP TYPE IF EXISTS public.member_role        CASCADE;
DROP TYPE IF EXISTS public.presence_status    CASCADE;
DROP TYPE IF EXISTS public.chore_recurrence   CASCADE;
DROP TYPE IF EXISTS public.chore_status       CASCADE;
DROP TYPE IF EXISTS public.expense_category   CASCADE;
DROP TYPE IF EXISTS public.notice_type        CASCADE;
DROP TYPE IF EXISTS public.maintenance_status CASCADE;
DROP TYPE IF EXISTS public.pet_action         CASCADE; -- kept for safe drop on existing DBs


-- ============================================================
-- PHASE 1 — EXTENSIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ============================================================
-- PHASE 2 — ENUM TYPES  (Roomies-specific domain values)
-- ============================================================

CREATE TYPE public.member_role AS ENUM (
  'Administrator', 'Tenant', 'Landlord'
);
CREATE TYPE public.presence_status AS ENUM (
  'Available', 'Sleeping', 'Quiet Hours / Studying',
  'Work From Home', 'Away'
);
CREATE TYPE public.chore_recurrence AS ENUM (
  'Twice Weekly', 'Weekly', 'Bi-Weekly', 'Monthly', 'Quarterly'
);
CREATE TYPE public.chore_status AS ENUM (
  'Pending', 'Completed', 'Swapped', 'Auctioned'
);
CREATE TYPE public.expense_category AS ENUM (
  'Rent', 'Groceries', 'Utilities',
  'Shared Subscriptions', 'Miscellaneous Ad-Hoc'
);
CREATE TYPE public.notice_type AS ENUM (
  'Instant Buzz Notification', 'Permanent Memo', 'Formal Landlord Notice'
);
CREATE TYPE public.maintenance_status AS ENUM (
  'Open', 'Vendor Dispatched', 'Resolved'
);
-- pet_action enum removed — pet_logs.action is now text to support custom chore names


-- ============================================================
-- PHASE 3 — CORE GLOBAL TABLES
-- households and profiles have a circular FK dependency;
-- we resolve it by creating both without the circular column,
-- then adding the missing columns/constraints via ALTER.
-- ============================================================

-- ── Households ───────────────────────────────────────────────
-- Shared by Hungry (pantry/shopping context) AND Roomies
-- (chores/expenses/notices).  One household entry serves both apps.
CREATE TABLE IF NOT EXISTS public.households (
  id              uuid          PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            text          NOT NULL,
  invite_code     text          NOT NULL UNIQUE
                                DEFAULT upper(substring(md5(random()::text), 1, 8)),
  -- Hungry: monthly grocery / household budget
  budget_limit    numeric(10,2) NOT NULL DEFAULT 0,
  -- Roomies: total household income (used for split calculations)
  monthly_income  numeric(10,2) NOT NULL DEFAULT 0,
  created_at      timestamptz   NOT NULL DEFAULT now()
  -- NOTE: created_by (→ profiles) is added via ALTER below
);

-- ── Profiles ─────────────────────────────────────────────────
-- One row per AppWare account, merged from all three apps.
-- hungry_settings stores app-specific profile fields as JSONB
-- to avoid table sprawl.
CREATE TABLE IF NOT EXISTS public.profiles (
  id                  uuid     PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Identity
  username            text     UNIQUE,
  display_name        text,
  -- Global AppWare avatar (syncs across all apps by default)
  avatar_url          text,
  -- Per-app avatar overrides — NULL means fall back to global avatar_url
  hungry_avatar_url   text,
  roomies_avatar_url  text,
  jukebox_avatar_url  text,
  bio                 text,
  friend_code         text     UNIQUE
                               DEFAULT upper(substring(md5(random()::text), 1, 8)),
  -- Jukebox: music platform role + now-playing share
  role                text     NOT NULL DEFAULT 'listener'
                               CHECK (role IN ('listener', 'artist')),
  share_now_playing   boolean  NOT NULL DEFAULT false,
  theme_config        jsonb    NOT NULL
                               DEFAULT '{"era":"2020s","accent":"#E76F51","layout_order":[]}'::jsonb,
  -- Roomies: reputation karma score + away flag
  karma               integer  NOT NULL DEFAULT 100 CHECK (karma >= 0),
  away                boolean  NOT NULL DEFAULT false,
  -- Hungry: which household is currently "active" in the pantry context
  active_household_id uuid,    -- FK added after households exists (see ALTER below)
  -- Hungry: app-specific household override (NULL = share active_household_id with Roomies)
  hungry_household_id uuid,    -- FK added after households exists (see ALTER below)
  -- Hungry: personal settings stored as JSONB
  -- Schema: { personal_name, dietary_restrictions[], nutrition_goals{},
  --           age, weight_lbs, height_in, personal_monthly_budget }
  hungry_settings           jsonb    NOT NULL DEFAULT '{}'::jsonb,
  -- Tutorial / onboarding completion flags (NULL = not yet shown)
  hungry_tutorial_done          boolean,
  has_completed_roomies_tutorial boolean,
  jukebox_onboarding_done       boolean NOT NULL DEFAULT false,
  jukebox_tutorial_done         boolean NOT NULL DEFAULT false,
  -- Jukebox: user vibe profile (focus, favorite genres, preferred era)
  vibe_tags                 jsonb,
  -- Ecosystem: favorite genres for cross-app playlist seeding
  favorite_genres           text[]   NOT NULL DEFAULT '{}',
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

-- ── Resolve circular FKs ─────────────────────────────────────
ALTER TABLE public.households
  ADD COLUMN IF NOT EXISTS created_by uuid
    REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_active_household_fk
  FOREIGN KEY (active_household_id)
  REFERENCES public.households(id) ON DELETE SET NULL
  DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_hungry_household_fk
  FOREIGN KEY (hungry_household_id)
  REFERENCES public.households(id) ON DELETE SET NULL
  DEFERRABLE INITIALLY DEFERRED;

-- ── Household Members ─────────────────────────────────────────
-- Single junction used by both Hungry and Roomies.
CREATE TABLE IF NOT EXISTS public.household_members (
  id            uuid              PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id  uuid              NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  profile_id    uuid              NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  role          public.member_role NOT NULL DEFAULT 'Tenant',
  joined_at     timestamptz       NOT NULL DEFAULT now(),
  UNIQUE (household_id, profile_id)
);

-- ── is_household_member helper (defined early; SECURITY DEFINER
--    bypasses RLS so policies can call it without recursion) ──
CREATE OR REPLACE FUNCTION public.is_household_member(hid uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.household_members
    WHERE household_id = hid AND profile_id = auth.uid()
  );
$$;

-- ── Friendships ───────────────────────────────────────────────
-- Unified across all apps using Jukebox model (status column).
-- status = 'pending'  → friend request sent
-- status = 'accepted' → mutual friends
-- status = 'blocked'  → blocked
CREATE TABLE IF NOT EXISTS public.friendships (
  id                uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  requester_id      uuid    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  addressee_id      uuid    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status            text    NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'accepted', 'blocked')),
  from_social_sync  boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (requester_id, addressee_id),
  CHECK  (requester_id <> addressee_id)
);

-- ── Circles (private friend groups) ──────────────────────────
-- From Jukebox; usable cross-app via app_context.
CREATE TABLE IF NOT EXISTS public.circles (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name         text NOT NULL,
  app_context  text NOT NULL DEFAULT 'global'
               CHECK (app_context IN ('global', 'hungry', 'jukebox', 'roomies')),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.circle_members (
  circle_id  uuid NOT NULL REFERENCES public.circles(id)  ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (circle_id, user_id)
);

-- ── Cross-App Activity Feed ───────────────────────────────────
-- Records user actions across apps so friends can see them.
-- e.g. app='hungry', activity_type='cooked', payload={recipe_name, ...}
CREATE TABLE IF NOT EXISTS public.cross_app_activity (
  id             uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        uuid    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  app            text    NOT NULL CHECK (app IN ('hungry', 'jukebox', 'roomies')),
  activity_type  text    NOT NULL,
  payload        jsonb   NOT NULL DEFAULT '{}'::jsonb,
  is_public      boolean NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now()
);


-- ============================================================
-- PHASE 4 — HUNGRY: Food & Kitchen Management
-- ============================================================

-- ── Fridge / Pantry Inventory ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.fridge_inventory (
  id            uuid          PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       uuid          NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  household_id  uuid          REFERENCES public.households(id) ON DELETE SET NULL,
  item_name     text          NOT NULL,
  raw_name      text,
  category      text,
  quantity      numeric       NOT NULL DEFAULT 1,
  unit          text,
  expiry_date   date,
  price         numeric(10,2),
  barcode       text,
  nutrition     jsonb,
  is_household  boolean       NOT NULL DEFAULT false,
  created_at    timestamptz   NOT NULL DEFAULT now()
);

-- ── Shopping List (Hungry grocery/ingredient list) ────────────
CREATE TABLE IF NOT EXISTS public.shopping_list (
  id            uuid          PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       uuid          NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  household_id  uuid          REFERENCES public.households(id) ON DELETE CASCADE,
  item_name     text          NOT NULL,
  is_completed  boolean       NOT NULL DEFAULT false,
  price         numeric(10,2),
  aisle         text,
  is_urgent     boolean       NOT NULL DEFAULT false,
  created_at    timestamptz   NOT NULL DEFAULT now()
);

-- ── Saved / Starred Recipes ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.saved_recipes (
  id            uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       uuid    NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  household_id  uuid    REFERENCES public.households(id) ON DELETE CASCADE,
  recipe_id     text    NOT NULL,
  recipe_name   text    NOT NULL,
  meal_type     text,
  cuisine       text,
  ingredients   jsonb,
  steps         jsonb,
  nutrition     jsonb,
  is_public     boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, recipe_id, household_id)
);

-- ── Meal Plans (Smart Meal Prep) ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.meal_plans (
  id            uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       uuid    NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  household_id  uuid    REFERENCES public.households(id) ON DELETE CASCADE,
  title         text    NOT NULL,
  summary       text,
  week_start    date,
  is_public     boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.meal_plan_recipes (
  id           uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  plan_id      uuid    NOT NULL REFERENCES public.meal_plans(id) ON DELETE CASCADE,
  recipe_id    text    NOT NULL,
  recipe_name  text    NOT NULL,
  meal_type    text,
  day_of_week  integer CHECK (day_of_week BETWEEN 0 AND 6),
  ingredients  jsonb,
  steps        jsonb,
  nutrition    jsonb,
  sort_order   integer NOT NULL DEFAULT 0
);

-- ── Chef History (Cook Log) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.chef_history (
  id           uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      uuid    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recipe_id    text,
  recipe_name  text    NOT NULL,
  description  text,
  ingredients  jsonb,
  notes        text,
  is_public    boolean NOT NULL DEFAULT false,
  -- Feature #12: Soundtrack of My Life — track playing when meal was cooked
  -- Schema: { track_title, artist, album, artwork_url, platform }
  soundtrack   jsonb,
  cooked_at    timestamptz NOT NULL DEFAULT now(),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.chef_history_photos (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  history_id  uuid NOT NULL REFERENCES public.chef_history(id) ON DELETE CASCADE,
  url         text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ── Events / Potluck ──────────────────────────────────────────
-- potluck_events: named events with invite codes (host-created)
CREATE TABLE IF NOT EXISTS public.potluck_events (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  host_id     uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name        text        NOT NULL,
  event_code  text        NOT NULL UNIQUE,
  event_date  date,
  event_time  time,
  venue       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- potluck_items: items belonging to an event (claim/unclaim per user)
CREATE TABLE IF NOT EXISTS public.potluck_items (
  id              uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id        uuid        NOT NULL REFERENCES public.potluck_events(id) ON DELETE CASCADE,
  name            text        NOT NULL,
  claimed_by_id   uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  claimed_by_name text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Legacy potluck_claims table kept for schema compatibility (no longer used by app)
CREATE TABLE IF NOT EXISTS public.potluck_claims (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_id     uuid NOT NULL REFERENCES public.potluck_items(id) ON DELETE CASCADE,
  claimed_by  uuid NOT NULL REFERENCES public.profiles(id)      ON DELETE CASCADE,
  claimed_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (item_id)
);


-- ============================================================
-- PHASE 5 — ROOMIES: Household Management
-- ============================================================

-- ── User Presence Status ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_presence (
  profile_id   uuid                   PRIMARY KEY
               REFERENCES public.profiles(id) ON DELETE CASCADE,
  status       public.presence_status NOT NULL DEFAULT 'Available',
  custom_text  text,
  updated_at   timestamptz            NOT NULL DEFAULT now()
);

-- ── Chores ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.chores (
  id               uuid                    PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id     uuid                    NOT NULL
                   REFERENCES public.households(id) ON DELETE CASCADE,
  title            text                    NOT NULL,
  description      text,
  recurrence       public.chore_recurrence NOT NULL DEFAULT 'Weekly',
  rotation_offset  integer                 NOT NULL DEFAULT 0,
  -- Feature #2: difficulty 1-5 drives BPM seed for Chore-Sync Anthems in Jukebox
  difficulty       integer                 NOT NULL DEFAULT 2 CHECK (difficulty BETWEEN 1 AND 5),
  created_at       timestamptz             NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.chore_assignments (
  id           uuid               PRIMARY KEY DEFAULT uuid_generate_v4(),
  chore_id     uuid               NOT NULL REFERENCES public.chores(id)   ON DELETE CASCADE,
  assigned_to  uuid               NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  due_date     date               NOT NULL,
  status       public.chore_status NOT NULL DEFAULT 'Pending',
  completed_at timestamptz
);

-- ── Karma Marketplace (chore auction/swap) ────────────────────
CREATE TABLE IF NOT EXISTS public.karma_marketplace (
  id             uuid          PRIMARY KEY DEFAULT uuid_generate_v4(),
  assignment_id  uuid          NOT NULL REFERENCES public.chore_assignments(id) ON DELETE CASCADE,
  cash_bounty    numeric(10,2) NOT NULL DEFAULT 0,
  karma_bounty   integer       NOT NULL DEFAULT 0,
  is_open        boolean       NOT NULL DEFAULT true,
  created_at     timestamptz   NOT NULL DEFAULT now()
);

-- ── Transactions & Bill Splits ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.transactions (
  id            uuid                    PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id  uuid                    NOT NULL
                REFERENCES public.households(id) ON DELETE CASCADE,
  paid_by       uuid                    NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount        numeric(10,2)           NOT NULL,
  memo          text                    NOT NULL DEFAULT '',
  category      public.expense_category NOT NULL DEFAULT 'Miscellaneous Ad-Hoc',
  created_at    timestamptz             NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.transaction_splits (
  id              uuid          PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id  uuid          NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  debtor_id       uuid          NOT NULL REFERENCES public.profiles(id)    ON DELETE CASCADE,
  amount_owed     numeric(10,2) NOT NULL,
  settled         boolean       NOT NULL DEFAULT false
);

-- ── Shared Subscriptions ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id            uuid          PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id  uuid          NOT NULL REFERENCES public.households(id)  ON DELETE CASCADE,
  title         text          NOT NULL,
  monthly_cost  numeric(10,2) NOT NULL,
  owner_id      uuid          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  started_at    timestamptz   NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.subscription_members (
  id               uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  subscription_id  uuid NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
  profile_id       uuid NOT NULL REFERENCES public.profiles(id)      ON DELETE CASCADE,
  UNIQUE (subscription_id, profile_id)
);

-- ── Shopping Items (Roomies household-supplies list) ──────────
-- Separate from Hungry's shopping_list — this covers non-food
-- household supplies (toilet paper, cleaning products, etc.)
CREATE TABLE IF NOT EXISTS public.shopping_items (
  id            uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id  uuid        NOT NULL REFERENCES public.households(id)  ON DELETE CASCADE,
  added_by      uuid        NOT NULL REFERENCES public.profiles(id)    ON DELETE CASCADE,
  title         text        NOT NULL,
  quantity      text        NOT NULL DEFAULT '1',
  urgent        boolean     NOT NULL DEFAULT false,
  purchased     boolean     NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ── Notices & Broadcasts ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notices (
  id            uuid               PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id  uuid               NOT NULL REFERENCES public.households(id)  ON DELETE CASCADE,
  author_id     uuid               NOT NULL REFERENCES public.profiles(id)    ON DELETE CASCADE,
  title         text,
  body          text               NOT NULL,
  type          public.notice_type NOT NULL DEFAULT 'Permanent Memo',
  created_at    timestamptz        NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.read_acks (
  id         uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  notice_id  uuid NOT NULL REFERENCES public.notices(id)  ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  read_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (notice_id, user_id)
);

-- ── Space Bookings (laundry room, parking, etc.) ──────────────
CREATE TABLE IF NOT EXISTS public.bookings (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id   uuid        NOT NULL REFERENCES public.households(id)  ON DELETE CASCADE,
  booked_by      uuid        NOT NULL REFERENCES public.profiles(id)    ON DELETE CASCADE,
  resource_name  text        NOT NULL,
  start_time     timestamptz NOT NULL,
  end_time       timestamptz NOT NULL
);

-- ── Guest Logs ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.guest_logs (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id    uuid NOT NULL REFERENCES public.households(id)  ON DELETE CASCADE,
  host_id         uuid NOT NULL REFERENCES public.profiles(id)    ON DELETE CASCADE,
  guest_name      text NOT NULL,
  arrival_date    date NOT NULL,
  departure_date  date NOT NULL
);

-- ── Maintenance Tickets ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.maintenance_tickets (
  id            uuid                      PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id  uuid                      NOT NULL REFERENCES public.households(id)  ON DELETE CASCADE,
  reported_by   uuid                      NOT NULL REFERENCES public.profiles(id)    ON DELETE CASCADE,
  title         text                      NOT NULL,
  description   text                      NOT NULL DEFAULT '',
  image_url     text,
  status        public.maintenance_status NOT NULL DEFAULT 'Open',
  created_at    timestamptz               NOT NULL DEFAULT now()
);

-- ── Pet Logs ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.pet_logs (
  id            uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id  uuid        NOT NULL REFERENCES public.households(id)  ON DELETE CASCADE,
  pet_name      text        NOT NULL,
  action        text        NOT NULL,
  done_by       uuid        NOT NULL REFERENCES public.profiles(id)    ON DELETE CASCADE,
  action_at     timestamptz NOT NULL DEFAULT now()
);

-- ── Co-living Agreement & Signatures ─────────────────────────
CREATE TABLE IF NOT EXISTS public.coliving_agreements (
  household_id          uuid    PRIMARY KEY
                        REFERENCES public.households(id) ON DELETE CASCADE,
  quiet_start           text    NOT NULL DEFAULT '22:00',
  quiet_end             text    NOT NULL DEFAULT '08:00',
  hygiene_score         integer NOT NULL DEFAULT 3
                        CHECK (hygiene_score BETWEEN 1 AND 5),
  guest_overstay_rules  text    NOT NULL DEFAULT 'Max 3 consecutive nights',
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.agreement_signatures (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id  uuid NOT NULL REFERENCES public.households(id)  ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES public.profiles(id)    ON DELETE CASCADE,
  signed_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (household_id, user_id)
);

-- ── Lockbox (shared household secrets vault) ──────────────────
CREATE TABLE IF NOT EXISTS public.lockbox (
  id             uuid    PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id   uuid    NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  key_name       text    NOT NULL,
  value          text    NOT NULL,
  is_restricted  boolean NOT NULL DEFAULT false
);


-- ============================================================
-- PHASE 6 — JUKEBOX: Music Social Platform
-- ============================================================

-- ── Linked Streaming Accounts ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.linked_accounts (
  id             uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider       text NOT NULL
                 CHECK (provider IN ('spotify', 'apple_music', 'instagram')),
  external_id    text NOT NULL,
  access_token   text NOT NULL,
  refresh_token  text,
  expires_at     timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider)
);

-- ── Album Ratings (0–5 in 0.5 increments) ────────────────────
CREATE TABLE IF NOT EXISTS public.album_ratings (
  id          uuid         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     uuid         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  album_id    text         NOT NULL,
  platform    text         NOT NULL,
  score       numeric(3,1) NOT NULL CHECK (score >= 0 AND score <= 5),
  liner_note  text,
  created_at  timestamptz  NOT NULL DEFAULT now(),
  UNIQUE (user_id, album_id, platform)
);

-- ── Upcoming Release Drops ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drops (
  id             uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  artist_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title          text NOT NULL,
  release_date   date NOT NULL,
  platform_link  text,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.drop_reminders (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  drop_id     uuid NOT NULL REFERENCES public.drops(id)   ON DELETE CASCADE,
  push_token  text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, drop_id)
);

-- ── Giveaways ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.giveaways (
  id                  uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  artist_id           uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title               text NOT NULL,
  description         text,
  ends_at             timestamptz NOT NULL,
  requirement_type    text NOT NULL
                      CHECK (requirement_type IN ('review', 'hype_drop')),
  requirement_ref_id  uuid,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.giveaway_entries (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  giveaway_id  uuid NOT NULL REFERENCES public.giveaways(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES public.profiles(id)  ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (giveaway_id, user_id)
);

-- ── Time Capsules ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.time_capsules (
  id           uuid   PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      uuid   NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  track_ids    text[] NOT NULL CHECK (array_length(track_ids, 1) <= 5),
  note         text,
  unlock_date  date   NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- ── Blind Mixtape Swaps ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.mixtape_swaps (
  id            uuid   PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id     uuid   NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recipient_id  uuid   NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  track_ids     text[] NOT NULL CHECK (array_length(track_ids, 1) = 3),
  week_key      text   NOT NULL,
  revealed      boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ── Day One Fan Registry ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.day_one_registry (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  fan_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  artist_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (fan_id, artist_id)
);

-- ── Concert Ticket Stubs ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ticket_stubs (
  id          uuid  PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     uuid  NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_id    text  NOT NULL,
  venue       text  NOT NULL,
  event_date  date  NOT NULL,
  artist_id   uuid  REFERENCES public.profiles(id) ON DELETE SET NULL,
  metadata    jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ── Setlist Votes ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.setlist_votes (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id    text NOT NULL,
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  track_id    text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (event_id, user_id, track_id)
);

-- ── Green Rooms (ephemeral artist Q&A channels) ───────────────
CREATE TABLE IF NOT EXISTS public.green_rooms (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id    text NOT NULL UNIQUE,
  artist_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  opens_at    timestamptz NOT NULL,
  closes_at   timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.green_room_messages (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id     uuid NOT NULL REFERENCES public.green_rooms(id) ON DELETE CASCADE,
  sender_id   uuid NOT NULL REFERENCES public.profiles(id)    ON DELETE CASCADE,
  body        text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ── Direct Message Rooms ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.chat_rooms (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.chat_participants (
  room_id    uuid NOT NULL REFERENCES public.chat_rooms(id)  ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.profiles(id)    ON DELETE CASCADE,
  joined_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.messages (
  id                uuid  PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id           uuid  NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  sender_id         uuid  NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  body              text,
  music_attachment  jsonb,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- ── Now Playing Cache ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.now_playing (
  user_id      uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  track_title  text NOT NULL,
  artist       text NOT NULL,
  album        text,
  artwork_url  text,
  platform     text NOT NULL DEFAULT 'spotify',
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- ── Jukebox Privacy Settings ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.privacy_settings (
  user_id           uuid    PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  public_profile    boolean NOT NULL DEFAULT true,
  show_now_playing  boolean NOT NULL DEFAULT true,
  show_ratings      boolean NOT NULL DEFAULT true,
  show_stubs        boolean NOT NULL DEFAULT true,
  show_wishlist     boolean NOT NULL DEFAULT true,
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- ── Concert Wishlist (want to attend, no ticket yet) ──────────
CREATE TABLE IF NOT EXISTS public.concert_wishlist (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  artist_name  text NOT NULL,
  venue        text NOT NULL,
  city         text NOT NULL,
  event_date   text NOT NULL,
  event_id     text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, artist_name, venue, event_date)
);

-- ── Concert Going (marked attending) ─────────────────────────
CREATE TABLE IF NOT EXISTS public.concert_going (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  artist_name  text NOT NULL,
  venue        text NOT NULL,
  city         text NOT NULL,
  event_date   text NOT NULL,
  event_id     text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, artist_name, venue, event_date)
);


-- ============================================================
-- PHASE 7 — STORAGE BUCKETS
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('roomies-property-vault', 'roomies-property-vault', true)
ON CONFLICT DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('chef-history-photos', 'chef-history-photos', true)
ON CONFLICT DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('user-avatars', 'user-avatars', true)
ON CONFLICT DO NOTHING;


-- ============================================================
-- PHASE 8 — ENABLE ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.households            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.household_members     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circles               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circle_members        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cross_app_activity    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fridge_inventory      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shopping_list         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_recipes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_plans            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_plan_recipes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chef_history          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chef_history_photos   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.potluck_events        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.potluck_items         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.potluck_claims        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_presence         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chores                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chore_assignments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.karma_marketplace     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_splits    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_members  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shopping_items        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notices               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.read_acks             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_logs            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_tickets   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_logs              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coliving_agreements   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agreement_signatures  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lockbox               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linked_accounts       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.album_ratings         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drops                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.time_capsules         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_stubs          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.privacy_settings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.concert_wishlist      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.concert_going         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.now_playing           ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- PHASE 9 — ROW LEVEL SECURITY POLICIES
-- Drop-then-recreate pattern makes this script re-runnable.
-- ============================================================

-- ── Global: households ───────────────────────────────────────
DROP POLICY IF EXISTS "hh: members can view"      ON public.households;
DROP POLICY IF EXISTS "hh: auth can create"       ON public.households;
DROP POLICY IF EXISTS "hh: creator can update"    ON public.households;
DROP POLICY IF EXISTS "hh: creator can delete"    ON public.households;

-- Any authenticated user can SELECT households — required for invite-code lookup.
-- is_household_member() blocks non-members from finding a household by invite code.
CREATE POLICY "hh: members can view"
  ON public.households FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "hh: auth can create"
  ON public.households FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "hh: creator can update"
  ON public.households FOR UPDATE
  USING (created_by = auth.uid());
CREATE POLICY "hh: creator can delete"
  ON public.households FOR DELETE
  USING (created_by = auth.uid());

-- ── Global: profiles ─────────────────────────────────────────
DROP POLICY IF EXISTS "p: anyone can view"  ON public.profiles;
DROP POLICY IF EXISTS "p: owner can insert" ON public.profiles;
DROP POLICY IF EXISTS "p: owner can update" ON public.profiles;

CREATE POLICY "p: anyone can view"  ON public.profiles FOR SELECT USING (true);
CREATE POLICY "p: owner can insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "p: owner can update" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- ── Global: household_members ─────────────────────────────────
DROP POLICY IF EXISTS "hm: members can view" ON public.household_members;
DROP POLICY IF EXISTS "hm: auth can join"    ON public.household_members;
DROP POLICY IF EXISTS "hm: admin can remove" ON public.household_members;

CREATE POLICY "hm: members can view"
  ON public.household_members FOR SELECT
  USING (is_household_member(household_id));
CREATE POLICY "hm: auth can join"
  ON public.household_members FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "hm: admin can remove"
  ON public.household_members FOR DELETE
  USING (
    profile_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.household_members hm2
      WHERE hm2.household_id = household_members.household_id
        AND hm2.profile_id = auth.uid()
        AND hm2.role = 'Administrator'
    )
  );

-- ── Global: friendships ───────────────────────────────────────
DROP POLICY IF EXISTS "f: view own"           ON public.friendships;
DROP POLICY IF EXISTS "f: can request"        ON public.friendships;
DROP POLICY IF EXISTS "f: addressee responds" ON public.friendships;
DROP POLICY IF EXISTS "f: can delete own"     ON public.friendships;

CREATE POLICY "f: view own"
  ON public.friendships FOR SELECT
  USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
CREATE POLICY "f: can request"
  ON public.friendships FOR INSERT
  WITH CHECK (auth.uid() = requester_id);
CREATE POLICY "f: addressee responds"
  ON public.friendships FOR UPDATE
  USING (auth.uid() = addressee_id OR auth.uid() = requester_id);
CREATE POLICY "f: can delete own"
  ON public.friendships FOR DELETE
  USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- ── Global: circles ───────────────────────────────────────────
DROP POLICY IF EXISTS "c: member or owner can view" ON public.circles;
DROP POLICY IF EXISTS "c: owner can manage"         ON public.circles;

CREATE POLICY "c: member or owner can view"
  ON public.circles FOR SELECT
  USING (
    auth.uid() = owner_id OR
    EXISTS (SELECT 1 FROM public.circle_members WHERE circle_id = id AND user_id = auth.uid())
  );
CREATE POLICY "c: owner can manage"
  ON public.circles FOR ALL
  USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

-- ── Global: circle_members ────────────────────────────────────
DROP POLICY IF EXISTS "cm: members can view"     ON public.circle_members;
DROP POLICY IF EXISTS "cm: owner can add"        ON public.circle_members;
DROP POLICY IF EXISTS "cm: self or owner remove" ON public.circle_members;

CREATE POLICY "cm: members can view"
  ON public.circle_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.circles c
      WHERE c.id = circle_id AND (
        c.owner_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.circle_members cm2
                WHERE cm2.circle_id = circle_members.circle_id AND cm2.user_id = auth.uid())
      )
    )
  );
CREATE POLICY "cm: owner can add"
  ON public.circle_members FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.circles WHERE id = circle_id AND owner_id = auth.uid())
  );
CREATE POLICY "cm: self or owner remove"
  ON public.circle_members FOR DELETE
  USING (
    user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.circles WHERE id = circle_id AND owner_id = auth.uid())
  );

-- ── Global: cross_app_activity ────────────────────────────────
DROP POLICY IF EXISTS "caa: public or own" ON public.cross_app_activity;
DROP POLICY IF EXISTS "caa: owner writes"  ON public.cross_app_activity;

CREATE POLICY "caa: public or own"
  ON public.cross_app_activity FOR SELECT
  USING (is_public = true OR user_id = auth.uid());
CREATE POLICY "caa: owner writes"
  ON public.cross_app_activity FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ── Hungry: fridge_inventory ──────────────────────────────────
DROP POLICY IF EXISTS "fi: owner manages personal"     ON public.fridge_inventory;
DROP POLICY IF EXISTS "fi: household members view shared" ON public.fridge_inventory;

CREATE POLICY "fi: owner manages personal"
  ON public.fridge_inventory FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "fi: household members view shared"
  ON public.fridge_inventory FOR SELECT
  USING (
    is_household = true AND
    household_id IN (
      SELECT household_id FROM public.household_members WHERE profile_id = auth.uid()
    )
  );

-- ── Hungry: shopping_list ─────────────────────────────────────
DROP POLICY IF EXISTS "sl: owner manages personal"          ON public.shopping_list;
DROP POLICY IF EXISTS "sl: household members manage shared" ON public.shopping_list;

CREATE POLICY "sl: owner manages personal"
  ON public.shopping_list FOR ALL
  USING (user_id = auth.uid() AND household_id IS NULL)
  WITH CHECK (user_id = auth.uid());
CREATE POLICY "sl: household members manage shared"
  ON public.shopping_list FOR ALL
  USING (
    household_id IN (
      SELECT household_id FROM public.household_members WHERE profile_id = auth.uid()
    )
  )
  WITH CHECK (
    household_id IN (
      SELECT household_id FROM public.household_members WHERE profile_id = auth.uid()
    )
  );

-- ── Hungry: saved_recipes ─────────────────────────────────────
DROP POLICY IF EXISTS "sr: owner manages"       ON public.saved_recipes;
DROP POLICY IF EXISTS "sr: household can view"  ON public.saved_recipes;
DROP POLICY IF EXISTS "sr: public visible"      ON public.saved_recipes;

CREATE POLICY "sr: owner manages"
  ON public.saved_recipes FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "sr: household can view"
  ON public.saved_recipes FOR SELECT
  USING (
    household_id IN (
      SELECT household_id FROM public.household_members WHERE profile_id = auth.uid()
    )
  );
CREATE POLICY "sr: public visible"
  ON public.saved_recipes FOR SELECT
  USING (is_public = true);

-- ── Hungry: meal_plans ────────────────────────────────────────
DROP POLICY IF EXISTS "mp: owner manages"      ON public.meal_plans;
DROP POLICY IF EXISTS "mp: household can view" ON public.meal_plans;

CREATE POLICY "mp: owner manages"
  ON public.meal_plans FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "mp: household can view"
  ON public.meal_plans FOR SELECT
  USING (
    household_id IN (
      SELECT household_id FROM public.household_members WHERE profile_id = auth.uid()
    )
  );

-- ── Hungry: meal_plan_recipes ─────────────────────────────────
DROP POLICY IF EXISTS "mpr: via plan access" ON public.meal_plan_recipes;

CREATE POLICY "mpr: via plan access"
  ON public.meal_plan_recipes FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.meal_plans mp
      WHERE mp.id = plan_id AND (
        mp.user_id = auth.uid() OR
        mp.household_id IN (
          SELECT household_id FROM public.household_members WHERE profile_id = auth.uid()
        )
      )
    )
  );

-- ── Hungry: chef_history ──────────────────────────────────────
DROP POLICY IF EXISTS "ch: owner manages"   ON public.chef_history;
DROP POLICY IF EXISTS "ch: public visible"  ON public.chef_history;

CREATE POLICY "ch: owner manages"
  ON public.chef_history FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "ch: public visible"
  ON public.chef_history FOR SELECT
  USING (is_public = true);

-- ── Hungry: chef_history_photos ───────────────────────────────
DROP POLICY IF EXISTS "chp: via history owner" ON public.chef_history_photos;

CREATE POLICY "chp: via history owner"
  ON public.chef_history_photos FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.chef_history ch
      WHERE ch.id = history_id AND ch.user_id = auth.uid()
    )
  );

-- ── Hungry: potluck_events ────────────────────────────────────
DROP POLICY IF EXISTS "pe: authenticated can view"   ON public.potluck_events;
DROP POLICY IF EXISTS "pe: authenticated can create" ON public.potluck_events;
DROP POLICY IF EXISTS "pe: host can update"          ON public.potluck_events;
DROP POLICY IF EXISTS "pe: host can delete"          ON public.potluck_events;

CREATE POLICY "pe: authenticated can view"
  ON public.potluck_events FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "pe: authenticated can create"
  ON public.potluck_events FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND host_id = auth.uid());
CREATE POLICY "pe: host can update"
  ON public.potluck_events FOR UPDATE USING (host_id = auth.uid());
CREATE POLICY "pe: host can delete"
  ON public.potluck_events FOR DELETE USING (host_id = auth.uid());

-- ── Hungry: potluck_items ─────────────────────────────────────
DROP POLICY IF EXISTS "pi: household members manage" ON public.potluck_items;
DROP POLICY IF EXISTS "pi2: authenticated manages"   ON public.potluck_items;

CREATE POLICY "pi2: authenticated manages"
  ON public.potluck_items FOR ALL
  USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- ── Hungry: potluck_claims ────────────────────────────────────
DROP POLICY IF EXISTS "pc: claimer manages" ON public.potluck_claims;

CREATE POLICY "pc: claimer manages"
  ON public.potluck_claims FOR ALL
  USING (claimed_by = auth.uid()) WITH CHECK (claimed_by = auth.uid());

-- ── Roomies: user_presence ────────────────────────────────────
DROP POLICY IF EXISTS "up: anyone views"  ON public.user_presence;
DROP POLICY IF EXISTS "up: owner manages" ON public.user_presence;

CREATE POLICY "up: anyone views"  ON public.user_presence FOR SELECT USING (true);
CREATE POLICY "up: owner manages" ON public.user_presence FOR ALL   USING (auth.uid() = profile_id);

-- ── Roomies: chores ───────────────────────────────────────────
DROP POLICY IF EXISTS "ch2: members manage" ON public.chores;

CREATE POLICY "ch2: members manage"
  ON public.chores FOR ALL USING (is_household_member(household_id));

-- ── Roomies: chore_assignments / karma_marketplace ────────────
-- Permissive: any authenticated user (needed for swap/auction flows)
DROP POLICY IF EXISTS "ca: open"  ON public.chore_assignments;
DROP POLICY IF EXISTS "km: open"  ON public.karma_marketplace;

CREATE POLICY "ca: open" ON public.chore_assignments   FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "km: open" ON public.karma_marketplace   FOR ALL USING (auth.uid() IS NOT NULL);

-- ── Roomies: transactions / splits ───────────────────────────
DROP POLICY IF EXISTS "tx: members manage"     ON public.transactions;
DROP POLICY IF EXISTS "splits: open"           ON public.transaction_splits;

CREATE POLICY "tx: members manage"
  ON public.transactions FOR ALL USING (is_household_member(household_id));
CREATE POLICY "splits: open"
  ON public.transaction_splits FOR ALL USING (auth.uid() IS NOT NULL);

-- ── Roomies: subscriptions / members ─────────────────────────
DROP POLICY IF EXISTS "subs: members manage"    ON public.subscriptions;
DROP POLICY IF EXISTS "sub_m: open"             ON public.subscription_members;

CREATE POLICY "subs: members manage"
  ON public.subscriptions FOR ALL USING (is_household_member(household_id));
CREATE POLICY "sub_m: open"
  ON public.subscription_members FOR ALL USING (auth.uid() IS NOT NULL);

-- ── Roomies: shopping_items ───────────────────────────────────
DROP POLICY IF EXISTS "si: members manage" ON public.shopping_items;

CREATE POLICY "si: members manage"
  ON public.shopping_items FOR ALL USING (is_household_member(household_id));

-- ── Roomies: notices / read_acks ─────────────────────────────
DROP POLICY IF EXISTS "n: members manage"  ON public.notices;
DROP POLICY IF EXISTS "ack: open"          ON public.read_acks;

CREATE POLICY "n: members manage"
  ON public.notices FOR ALL USING (is_household_member(household_id));
CREATE POLICY "ack: open"
  ON public.read_acks FOR ALL USING (auth.uid() IS NOT NULL);

-- ── Roomies: bookings, guest_logs, maintenance, pets ──────────
DROP POLICY IF EXISTS "bk: members manage"   ON public.bookings;
DROP POLICY IF EXISTS "gl: members manage"   ON public.guest_logs;
DROP POLICY IF EXISTS "mt: members manage"   ON public.maintenance_tickets;
DROP POLICY IF EXISTS "pl: members manage"   ON public.pet_logs;

CREATE POLICY "bk: members manage" ON public.bookings             FOR ALL USING (is_household_member(household_id));
CREATE POLICY "gl: members manage" ON public.guest_logs           FOR ALL USING (is_household_member(household_id));
CREATE POLICY "mt: members manage" ON public.maintenance_tickets  FOR ALL USING (is_household_member(household_id));
CREATE POLICY "pl: members manage" ON public.pet_logs             FOR ALL USING (is_household_member(household_id));

-- ── Roomies: coliving_agreements / signatures ─────────────────
DROP POLICY IF EXISTS "ca2: members manage" ON public.coliving_agreements;
DROP POLICY IF EXISTS "sig: members manage" ON public.agreement_signatures;

CREATE POLICY "ca2: members manage" ON public.coliving_agreements  FOR ALL USING (is_household_member(household_id));
CREATE POLICY "sig: members manage" ON public.agreement_signatures FOR ALL USING (is_household_member(household_id));

-- ── Roomies: lockbox ─────────────────────────────────────────
DROP POLICY IF EXISTS "lb: members manage" ON public.lockbox;

CREATE POLICY "lb: members manage"
  ON public.lockbox FOR ALL USING (is_household_member(household_id));

-- ── Jukebox: linked_accounts ──────────────────────────────────
DROP POLICY IF EXISTS "la: owner manages" ON public.linked_accounts;

CREATE POLICY "la: owner manages"
  ON public.linked_accounts FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── Jukebox: album_ratings ────────────────────────────────────
DROP POLICY IF EXISTS "ar: public read"   ON public.album_ratings;
DROP POLICY IF EXISTS "ar: owner manages" ON public.album_ratings;

CREATE POLICY "ar: public read"   ON public.album_ratings FOR SELECT USING (true);
CREATE POLICY "ar: owner manages"
  ON public.album_ratings FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── Jukebox: drops ────────────────────────────────────────────
DROP POLICY IF EXISTS "dr: public read"    ON public.drops;
DROP POLICY IF EXISTS "dr: artist manages" ON public.drops;

CREATE POLICY "dr: public read"    ON public.drops FOR SELECT USING (true);
CREATE POLICY "dr: artist manages"
  ON public.drops FOR ALL
  USING (auth.uid() = artist_id) WITH CHECK (auth.uid() = artist_id);

-- ── Jukebox: time_capsules ────────────────────────────────────
DROP POLICY IF EXISTS "tc: owner and post-unlock" ON public.time_capsules;
DROP POLICY IF EXISTS "tc: owner inserts"         ON public.time_capsules;

CREATE POLICY "tc: owner and post-unlock"
  ON public.time_capsules FOR SELECT
  USING (auth.uid() = user_id OR unlock_date <= current_date);
CREATE POLICY "tc: owner inserts"
  ON public.time_capsules FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ── Jukebox: ticket_stubs ─────────────────────────────────────
DROP POLICY IF EXISTS "ts: public read"   ON public.ticket_stubs;
DROP POLICY IF EXISTS "ts: owner manages" ON public.ticket_stubs;

CREATE POLICY "ts: public read"   ON public.ticket_stubs FOR SELECT USING (true);
CREATE POLICY "ts: owner manages"
  ON public.ticket_stubs FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── Jukebox: privacy_settings ────────────────────────────────
DROP POLICY IF EXISTS "ps: owner manages" ON public.privacy_settings;
DROP POLICY IF EXISTS "ps: public read"   ON public.privacy_settings;

CREATE POLICY "ps: owner manages"
  ON public.privacy_settings FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ps: public read"
  ON public.privacy_settings FOR SELECT USING (true);

-- ── Jukebox: concert_wishlist ─────────────────────────────────
DROP POLICY IF EXISTS "cw: privacy-gated read" ON public.concert_wishlist;
DROP POLICY IF EXISTS "cw: owner manages"      ON public.concert_wishlist;

CREATE POLICY "cw: privacy-gated read"
  ON public.concert_wishlist FOR SELECT
  USING (
    auth.uid() = user_id OR
    COALESCE(
      (SELECT show_wishlist FROM public.privacy_settings
       WHERE user_id = concert_wishlist.user_id),
      true
    )
  );
CREATE POLICY "cw: owner manages"
  ON public.concert_wishlist FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── Jukebox: concert_going ────────────────────────────────────
DROP POLICY IF EXISTS "cg: public read"   ON public.concert_going;
DROP POLICY IF EXISTS "cg: owner manages" ON public.concert_going;

CREATE POLICY "cg: public read"   ON public.concert_going FOR SELECT USING (true);
CREATE POLICY "cg: owner manages"
  ON public.concert_going FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── Jukebox: messages ─────────────────────────────────────────
DROP POLICY IF EXISTS "msg: participants read" ON public.messages;
DROP POLICY IF EXISTS "msg: participants send" ON public.messages;

CREATE POLICY "msg: participants read"
  ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants
      WHERE room_id = messages.room_id AND user_id = auth.uid()
    )
  );
CREATE POLICY "msg: participants send"
  ON public.messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM public.chat_participants
      WHERE room_id = messages.room_id AND user_id = auth.uid()
    )
  );

-- ── Jukebox: now_playing ──────────────────────────────────────
DROP POLICY IF EXISTS "np: public read"   ON public.now_playing;
DROP POLICY IF EXISTS "np: owner manages" ON public.now_playing;

CREATE POLICY "np: public read"   ON public.now_playing FOR SELECT USING (true);
CREATE POLICY "np: owner manages"
  ON public.now_playing FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── Storage policies ──────────────────────────────────────────
DROP POLICY IF EXISTS "st: vault read"         ON storage.objects;
DROP POLICY IF EXISTS "st: vault insert"       ON storage.objects;
DROP POLICY IF EXISTS "st: vault delete"       ON storage.objects;
DROP POLICY IF EXISTS "st: avatars read"       ON storage.objects;
DROP POLICY IF EXISTS "st: avatars write"      ON storage.objects;
DROP POLICY IF EXISTS "st: chef photos read"   ON storage.objects;
DROP POLICY IF EXISTS "st: chef photos write"  ON storage.objects;

CREATE POLICY "st: vault read"
  ON storage.objects FOR SELECT USING (bucket_id = 'roomies-property-vault');
CREATE POLICY "st: vault insert"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'roomies-property-vault' AND auth.uid() IS NOT NULL);
CREATE POLICY "st: vault delete"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'roomies-property-vault' AND auth.uid() IS NOT NULL);
CREATE POLICY "st: avatars read"
  ON storage.objects FOR SELECT USING (bucket_id = 'user-avatars');
CREATE POLICY "st: avatars write"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'user-avatars' AND auth.uid() IS NOT NULL);
CREATE POLICY "st: chef photos read"
  ON storage.objects FOR SELECT USING (bucket_id = 'chef-history-photos');
CREATE POLICY "st: chef photos write"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'chef-history-photos' AND auth.uid() IS NOT NULL);


-- ============================================================
-- PHASE 10 — FUNCTIONS & TRIGGERS
-- ============================================================

-- Auto-create profile on every new sign-up
-- Works for email/password, Google OAuth, and AppWare SSO token flow.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  base_name  text;
  final_name text;
  n          int := 0;
BEGIN
  -- Wrapped in an inner exception block so any failure (duplicate username,
  -- missing column, constraint violation) is silently swallowed.  This ensures
  -- the auth.users INSERT never rolls back and never returns a 500 "Database
  -- error saving new user".  The profile row is created client-side on the
  -- first SIGNED_IN event if the trigger was silently skipped.
  BEGIN
    base_name := coalesce(
      new.raw_user_meta_data->>'username',
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(coalesce(new.email, new.id::text), '@', 1)
    );
    -- Strip characters that are not alphanumeric or underscore
    base_name  := regexp_replace(base_name, '[^a-zA-Z0-9_]', '', 'g');
    IF base_name = '' THEN base_name := substr(new.id::text, 1, 8); END IF;

    final_name := base_name;
    WHILE EXISTS (SELECT 1 FROM public.profiles WHERE username = final_name) LOOP
      n          := n + 1;
      final_name := base_name || n;
    END LOOP;

    INSERT INTO public.profiles (id, username, display_name, avatar_url)
    VALUES (
      new.id,
      final_name,
      coalesce(
        new.raw_user_meta_data->>'full_name',
        new.raw_user_meta_data->>'name',
        final_name
      ),
      new.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    NULL; -- profile will be created client-side on first SIGNED_IN event
  END;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Auto-create privacy_settings for every new Jukebox profile row
CREATE OR REPLACE FUNCTION public.handle_new_profile_privacy()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.privacy_settings (user_id)
  VALUES (new.id)
  ON CONFLICT DO NOTHING;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_profile_created_privacy ON public.profiles;
CREATE TRIGGER on_profile_created_privacy
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_profile_privacy();

-- Keep profiles.updated_at current
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


-- ============================================================
-- PHASE 11 — VIEWS
-- ============================================================

CREATE OR REPLACE VIEW public.friends_view AS
  SELECT
    CASE
      WHEN requester_id = auth.uid() THEN addressee_id
      ELSE requester_id
    END                AS friend_id,
    created_at
  FROM public.friendships
  WHERE status = 'accepted'
    AND (requester_id = auth.uid() OR addressee_id = auth.uid());


-- ============================================================
-- PHASE 12 — INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_hm_household         ON public.household_members  (household_id);
CREATE INDEX IF NOT EXISTS idx_hm_profile           ON public.household_members  (profile_id);
CREATE INDEX IF NOT EXISTS idx_f_requester          ON public.friendships         (requester_id);
CREATE INDEX IF NOT EXISTS idx_f_addressee          ON public.friendships         (addressee_id);
CREATE INDEX IF NOT EXISTS idx_f_accepted           ON public.friendships         (requester_id, addressee_id) WHERE status = 'accepted';
CREATE INDEX IF NOT EXISTS idx_fi_user              ON public.fridge_inventory    (user_id);
CREATE INDEX IF NOT EXISTS idx_fi_household         ON public.fridge_inventory    (household_id) WHERE household_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sl_user              ON public.shopping_list       (user_id);
CREATE INDEX IF NOT EXISTS idx_sl_household         ON public.shopping_list       (household_id) WHERE household_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sr_user              ON public.saved_recipes       (user_id);
CREATE INDEX IF NOT EXISTS idx_ch_user              ON public.chef_history        (user_id);
CREATE INDEX IF NOT EXISTS idx_ch_cooked            ON public.chef_history        (cooked_at DESC);
CREATE INDEX IF NOT EXISTS idx_la_user              ON public.linked_accounts     (user_id, provider);
CREATE INDEX IF NOT EXISTS idx_ar_album             ON public.album_ratings       (album_id, platform);
CREATE INDEX IF NOT EXISTS idx_ar_user              ON public.album_ratings       (user_id);
CREATE INDEX IF NOT EXISTS idx_msg_room             ON public.messages            (room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_np_updated           ON public.now_playing         (updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_tx_household         ON public.transactions        (household_id);
CREATE INDEX IF NOT EXISTS idx_chores_household     ON public.chores              (household_id);
CREATE INDEX IF NOT EXISTS idx_caa_user             ON public.cross_app_activity  (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_caa_public           ON public.cross_app_activity  (created_at DESC) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_p_username_trgm      ON public.profiles            USING gin (username     gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_p_displayname_trgm   ON public.profiles            USING gin (display_name gin_trgm_ops);


-- ============================================================
-- PHASE 13 — REALTIME SUBSCRIPTIONS
-- Wrapped in DO blocks to be idempotent.
-- ============================================================

DO $$ BEGIN
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.shopping_list;       EXCEPTION WHEN others THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.fridge_inventory;    EXCEPTION WHEN others THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.shopping_items;      EXCEPTION WHEN others THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;            EXCEPTION WHEN others THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.now_playing;         EXCEPTION WHEN others THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.user_presence;       EXCEPTION WHEN others THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.notices;             EXCEPTION WHEN others THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.chore_assignments;   EXCEPTION WHEN others THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.potluck_events;      EXCEPTION WHEN others THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.potluck_items;       EXCEPTION WHEN others THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.potluck_claims;      EXCEPTION WHEN others THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.cross_app_activity;  EXCEPTION WHEN others THEN NULL; END;
END $$;

-- ============================================================
-- DONE ✓
-- All tables, policies, functions, triggers, indexes, and
-- realtime subscriptions have been created.
-- ============================================================

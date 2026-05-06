create table if not exists public.billing_profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    free_words_limit integer not null default 2500 check (free_words_limit >= 0),
    free_words_used integer not null default 0 check (free_words_used >= 0),
    preferred_plan text,
    preferred_plan_updated_at timestamptz,
    active_plan text,
    beta_access_code text,
    beta_unlocked_at timestamptz,
    stripe_customer_id text unique,
    stripe_subscription_id text unique,
    subscription_status text not null default 'inactive',
    stripe_price_id text,
    current_period_end timestamptz,
    cancel_at_period_end boolean not null default false,
    trial_started_at timestamptz not null default timezone('utc', now()),
    trial_ends_at timestamptz not null default (timezone('utc', now()) + interval '7 days'),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.beta_transcription_usage (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    estimated_cost_usd numeric(10, 6) not null check (estimated_cost_usd >= 0),
    usage_month date not null,
    status text not null default 'reserved' check (status in ('reserved', 'succeeded', 'failed')),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

alter table public.billing_profiles
    alter column free_words_limit set default 2500;

alter table public.billing_profiles
    add column if not exists preferred_plan text;

alter table public.billing_profiles
    add column if not exists preferred_plan_updated_at timestamptz;

alter table public.billing_profiles
    add column if not exists active_plan text;

alter table public.billing_profiles
    add column if not exists beta_access_code text;

alter table public.billing_profiles
    add column if not exists beta_unlocked_at timestamptz;

-- Pentridge Labs subscription columns
alter table public.billing_profiles
    add column if not exists pentridge_subscription_active boolean not null default false;

alter table public.billing_profiles
    add column if not exists pentridge_tier text;

alter table public.billing_profiles
    add column if not exists pentridge_checked_at timestamptz;

alter table public.billing_profiles
    drop constraint if exists billing_profiles_pentridge_tier_check;

alter table public.billing_profiles
    add constraint billing_profiles_pentridge_tier_check
    check (pentridge_tier in ('standard', 'pro') or pentridge_tier is null);

alter table public.billing_profiles
    drop constraint if exists billing_profiles_preferred_plan_check;

alter table public.billing_profiles
    add constraint billing_profiles_preferred_plan_check
    check (preferred_plan in ('monthly', 'yearly') or preferred_plan is null);

alter table public.billing_profiles
    drop constraint if exists billing_profiles_active_plan_check;

alter table public.billing_profiles
    add constraint billing_profiles_active_plan_check
    check (active_plan in ('monthly', 'yearly') or active_plan is null);

alter table public.billing_profiles
    add column if not exists trial_started_at timestamptz;

alter table public.billing_profiles
    add column if not exists trial_ends_at timestamptz;

update public.billing_profiles
set free_words_limit = 2500
where free_words_limit <> 2500;

update public.billing_profiles
set trial_started_at = timezone('utc', now())
where trial_started_at is null;

update public.billing_profiles
set trial_ends_at = trial_started_at + interval '7 days'
where trial_ends_at is null;

update public.billing_profiles
set active_plan = preferred_plan
where active_plan is null
  and preferred_plan in ('monthly', 'yearly')
  and subscription_status in ('active', 'trialing', 'past_due');

update public.billing_profiles
set active_plan = null
where subscription_status not in ('active', 'trialing', 'past_due');

alter table public.billing_profiles
    alter column trial_started_at set default timezone('utc', now());

alter table public.billing_profiles
    alter column trial_ends_at set default (timezone('utc', now()) + interval '7 days');

alter table public.billing_profiles
    alter column trial_started_at set not null;

alter table public.billing_profiles
    alter column trial_ends_at set not null;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$;

drop trigger if exists billing_profiles_touch_updated_at on public.billing_profiles;

create trigger billing_profiles_touch_updated_at
before update on public.billing_profiles
for each row
execute function public.touch_updated_at();

drop trigger if exists beta_transcription_usage_touch_updated_at on public.beta_transcription_usage;

create trigger beta_transcription_usage_touch_updated_at
before update on public.beta_transcription_usage
for each row
execute function public.touch_updated_at();

alter table public.billing_profiles enable row level security;
alter table public.beta_transcription_usage enable row level security;

drop policy if exists billing_profiles_select_own on public.billing_profiles;
drop policy if exists billing_profiles_insert_own on public.billing_profiles;
drop policy if exists billing_profiles_update_own on public.billing_profiles;

create policy billing_profiles_select_own
on public.billing_profiles
for select
to authenticated
using (auth.uid() = user_id);

create policy billing_profiles_insert_own
on public.billing_profiles
for insert
to authenticated
with check (auth.uid() = user_id);

create policy billing_profiles_update_own
on public.billing_profiles
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists beta_transcription_usage_select_own on public.beta_transcription_usage;

create policy beta_transcription_usage_select_own
on public.beta_transcription_usage
for select
to authenticated
using (auth.uid() = user_id);

create or replace function public.subscription_is_active(p_status text)
returns boolean
language sql
immutable
as $$
    select coalesce(p_status, '') in ('active', 'trialing', 'past_due')
$$;

create or replace function public.current_beta_usage_month()
returns date
language sql
stable
as $$
    select date_trunc('month', timezone('America/New_York', now()))::date
$$;

create or replace function public.beta_monthly_spend_limit_usd()
returns numeric
language sql
immutable
as $$
    select 20.00::numeric
$$;

create or replace function public.beta_monthly_spend_used_usd()
returns numeric
language sql
stable
as $$
    select coalesce(sum(estimated_cost_usd), 0)::numeric
    from public.beta_transcription_usage
    where usage_month = public.current_beta_usage_month()
      and status in ('reserved', 'succeeded')
$$;

create or replace function public.pentridge_word_limit(p_tier text)
returns integer
language sql
immutable
as $$
    select case
        when p_tier = 'pro' then 2147483647  -- unlimited
        when p_tier = 'standard' then 10000
        else 0
    end
$$;

create or replace function public.billing_status_for_profile(
    p_profile public.billing_profiles
)
returns table (
    free_words_limit integer,
    free_words_used integer,
    free_words_remaining integer,
    has_active_subscription boolean,
    subscription_status text,
    stripe_customer_id text,
    current_period_end timestamptz,
    cancel_at_period_end boolean,
    trial_ends_at timestamptz,
    needs_subscription boolean,
    preferred_plan text,
    active_plan text,
    has_beta_access boolean,
    beta_monthly_spend_limit_usd numeric,
    beta_monthly_spend_used_usd numeric,
    beta_monthly_spend_remaining_usd numeric,
    beta_monthly_cap_reached boolean,
    pentridge_subscription_active boolean,
    pentridge_tier text,
    pentridge_word_limit integer
)
language plpgsql
stable
as $$
declare
    v_has_active boolean := public.subscription_is_active(p_profile.subscription_status);
    v_has_beta_access boolean := p_profile.beta_unlocked_at is not null;
    v_limit numeric := public.beta_monthly_spend_limit_usd();
    v_used numeric := public.beta_monthly_spend_used_usd();
    v_beta_cap_reached boolean := v_used >= v_limit;
    v_pentridge_active boolean := coalesce(p_profile.pentridge_subscription_active, false);
    v_pentridge_tier text := p_profile.pentridge_tier;
    v_pentridge_word_limit integer := public.pentridge_word_limit(v_pentridge_tier);
begin
    return query
    select
        p_profile.free_words_limit,
        p_profile.free_words_used,
        greatest(p_profile.free_words_limit - p_profile.free_words_used, 0),
        v_has_active,
        p_profile.subscription_status,
        p_profile.stripe_customer_id,
        p_profile.current_period_end,
        p_profile.cancel_at_period_end,
        p_profile.trial_ends_at,
        (
            not v_has_active
            and not v_pentridge_active
            and not (v_has_beta_access and not v_beta_cap_reached)
            and (
                p_profile.free_words_used >= p_profile.free_words_limit
                or timezone('utc', now()) >= p_profile.trial_ends_at
            )
        ),
        p_profile.preferred_plan,
        p_profile.active_plan,
        v_has_beta_access,
        v_limit,
        v_used,
        greatest(v_limit - v_used, 0),
        v_beta_cap_reached,
        v_pentridge_active,
        v_pentridge_tier,
        v_pentridge_word_limit;
end;
$$;

drop function if exists public.get_billing_status();

create function public.get_billing_status()
returns table (
    free_words_limit integer,
    free_words_used integer,
    free_words_remaining integer,
    has_active_subscription boolean,
    subscription_status text,
    stripe_customer_id text,
    current_period_end timestamptz,
    cancel_at_period_end boolean,
    trial_ends_at timestamptz,
    needs_subscription boolean,
    preferred_plan text,
    active_plan text,
    has_beta_access boolean,
    beta_monthly_spend_limit_usd numeric,
    beta_monthly_spend_used_usd numeric,
    beta_monthly_spend_remaining_usd numeric,
    beta_monthly_cap_reached boolean,
    pentridge_subscription_active boolean,
    pentridge_tier text,
    pentridge_word_limit integer
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_user_id uuid := auth.uid();
    v_profile public.billing_profiles%rowtype;
begin
    if v_user_id is null then
        raise exception 'Authentication required';
    end if;

    insert into public.billing_profiles (user_id)
    values (v_user_id)
    on conflict (user_id) do nothing;

    select *
    into v_profile
    from public.billing_profiles
    where user_id = v_user_id;

    if v_profile.trial_started_at is null or v_profile.trial_ends_at is null then
        update public.billing_profiles
        set trial_started_at = coalesce(trial_started_at, timezone('utc', now())),
            trial_ends_at = coalesce(trial_ends_at, coalesce(trial_started_at, timezone('utc', now())) + interval '7 days')
        where user_id = v_user_id
        returning *
        into v_profile;
    end if;

    return query
    select *
    from public.billing_status_for_profile(v_profile);
end;
$$;

revoke all on function public.get_billing_status() from public;
grant execute on function public.get_billing_status() to authenticated;

drop function if exists public.record_word_usage(integer);

create function public.record_word_usage(p_word_count integer)
returns table (
    free_words_limit integer,
    free_words_used integer,
    free_words_remaining integer,
    has_active_subscription boolean,
    subscription_status text,
    stripe_customer_id text,
    current_period_end timestamptz,
    cancel_at_period_end boolean,
    trial_ends_at timestamptz,
    needs_subscription boolean,
    preferred_plan text,
    active_plan text,
    has_beta_access boolean,
    beta_monthly_spend_limit_usd numeric,
    beta_monthly_spend_used_usd numeric,
    beta_monthly_spend_remaining_usd numeric,
    beta_monthly_cap_reached boolean,
    pentridge_subscription_active boolean,
    pentridge_tier text,
    pentridge_word_limit integer
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_user_id uuid := auth.uid();
    v_profile public.billing_profiles%rowtype;
    v_has_active boolean;
    v_has_beta_access boolean;
    v_word_count integer := greatest(coalesce(p_word_count, 0), 0);
begin
    if v_user_id is null then
        raise exception 'Authentication required';
    end if;

    insert into public.billing_profiles (user_id)
    values (v_user_id)
    on conflict (user_id) do nothing;

    select *
    into v_profile
    from public.billing_profiles
    where user_id = v_user_id;

    if v_profile.trial_started_at is null or v_profile.trial_ends_at is null then
        update public.billing_profiles
        set trial_started_at = coalesce(trial_started_at, timezone('utc', now())),
            trial_ends_at = coalesce(trial_ends_at, coalesce(trial_started_at, timezone('utc', now())) + interval '7 days')
        where user_id = v_user_id
        returning *
        into v_profile;
    end if;

    v_has_active := public.subscription_is_active(v_profile.subscription_status);
    v_has_beta_access := v_profile.beta_unlocked_at is not null;

    -- Skip word counting for active Stripe subscribers, beta users, and Pentridge Labs subscribers
    if not v_has_active and not v_has_beta_access and not coalesce(v_profile.pentridge_subscription_active, false) and v_word_count > 0 then
        update public.billing_profiles as billing_profile
        set free_words_used = least(
            billing_profile.free_words_used + v_word_count,
            billing_profile.free_words_limit
        )
        where billing_profile.user_id = v_user_id
        returning *
        into v_profile;

        v_has_active := public.subscription_is_active(v_profile.subscription_status);
    end if;

    return query
    select *
    from public.billing_status_for_profile(v_profile);
end;
$$;

revoke all on function public.record_word_usage(integer) from public;
grant execute on function public.record_word_usage(integer) to authenticated;

drop function if exists public.redeem_beta_access_code(text);

create function public.redeem_beta_access_code(p_code text)
returns table (
    free_words_limit integer,
    free_words_used integer,
    free_words_remaining integer,
    has_active_subscription boolean,
    subscription_status text,
    stripe_customer_id text,
    current_period_end timestamptz,
    cancel_at_period_end boolean,
    trial_ends_at timestamptz,
    needs_subscription boolean,
    preferred_plan text,
    active_plan text,
    has_beta_access boolean,
    beta_monthly_spend_limit_usd numeric,
    beta_monthly_spend_used_usd numeric,
    beta_monthly_spend_remaining_usd numeric,
    beta_monthly_cap_reached boolean,
    pentridge_subscription_active boolean,
    pentridge_tier text,
    pentridge_word_limit integer
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_user_id uuid := auth.uid();
    v_profile public.billing_profiles%rowtype;
    v_code text := upper(trim(coalesce(p_code, '')));
begin
    if v_user_id is null then
        raise exception 'Authentication required';
    end if;

    if v_code <> 'VOIYCE-PENTRIDGE' then
        raise exception 'Invalid beta code';
    end if;

    insert into public.billing_profiles (user_id, beta_access_code, beta_unlocked_at)
    values (v_user_id, v_code, timezone('utc', now()))
    on conflict (user_id) do update
    set beta_access_code = excluded.beta_access_code,
        beta_unlocked_at = coalesce(public.billing_profiles.beta_unlocked_at, excluded.beta_unlocked_at)
    returning *
    into v_profile;

    return query
    select *
    from public.billing_status_for_profile(v_profile);
end;
$$;

revoke all on function public.redeem_beta_access_code(text) from public;
grant execute on function public.redeem_beta_access_code(text) to authenticated;

drop function if exists public.reserve_beta_transcription_cost(uuid, numeric);

create function public.reserve_beta_transcription_cost(
    p_user_id uuid,
    p_estimated_cost_usd numeric
)
returns table (
    usage_id uuid,
    spend_used_usd numeric,
    spend_limit_usd numeric,
    spend_remaining_usd numeric
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_profile public.billing_profiles%rowtype;
    v_cost numeric := greatest(coalesce(p_estimated_cost_usd, 0), 0);
    v_limit numeric := public.beta_monthly_spend_limit_usd();
    v_used numeric := public.beta_monthly_spend_used_usd();
    v_usage_id uuid;
begin
    if p_user_id is null then
        raise exception 'User is required';
    end if;

    if auth.uid() is null or auth.uid() <> p_user_id then
        raise exception 'Authentication required';
    end if;

    select *
    into v_profile
    from public.billing_profiles
    where user_id = p_user_id;

    if v_profile.user_id is null or v_profile.beta_unlocked_at is null then
        raise exception 'Beta access is not active';
    end if;

    perform pg_advisory_xact_lock(hashtext('voiyce_beta_monthly_cap'));
    v_used := public.beta_monthly_spend_used_usd();

    if v_used + v_cost > v_limit then
        raise exception 'Beta monthly transcription cap reached';
    end if;

    insert into public.beta_transcription_usage (user_id, estimated_cost_usd, usage_month)
    values (p_user_id, v_cost, public.current_beta_usage_month())
    returning id
    into v_usage_id;

    return query
    select
        v_usage_id,
        v_used + v_cost,
        v_limit,
        greatest(v_limit - (v_used + v_cost), 0);
end;
$$;

revoke all on function public.reserve_beta_transcription_cost(uuid, numeric) from public;
grant execute on function public.reserve_beta_transcription_cost(uuid, numeric) to authenticated;

drop function if exists public.finalize_beta_transcription_cost(uuid, boolean);

create function public.finalize_beta_transcription_cost(
    p_usage_id uuid,
    p_succeeded boolean
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
    update public.beta_transcription_usage
    set status = case when coalesce(p_succeeded, false) then 'succeeded' else 'failed' end
    where id = p_usage_id
      and user_id = auth.uid()
      and status = 'reserved';
end;
$$;

revoke all on function public.finalize_beta_transcription_cost(uuid, boolean) from public;
grant execute on function public.finalize_beta_transcription_cost(uuid, boolean) to authenticated;

create or replace function public.apply_stripe_subscription_update(
    p_user_id uuid,
    p_customer_id text,
    p_subscription_id text,
    p_subscription_status text,
    p_price_id text,
    p_current_period_end timestamptz,
    p_cancel_at_period_end boolean default false,
    p_active_plan text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_profile public.billing_profiles%rowtype;
begin
    if p_user_id is not null then
        select *
        into v_profile
        from public.billing_profiles
        where user_id = p_user_id;
    end if;

    if v_profile.user_id is null and p_customer_id is not null then
        select *
        into v_profile
        from public.billing_profiles
        where stripe_customer_id = p_customer_id;
    end if;

    if v_profile.user_id is not null then
        update public.billing_profiles
        set stripe_customer_id = p_customer_id,
            stripe_subscription_id = p_subscription_id,
            subscription_status = coalesce(p_subscription_status, 'inactive'),
            stripe_price_id = p_price_id,
            current_period_end = p_current_period_end,
            cancel_at_period_end = coalesce(p_cancel_at_period_end, false),
            active_plan = case
                when public.subscription_is_active(coalesce(p_subscription_status, 'inactive')) then p_active_plan
                else null
            end
        where user_id = v_profile.user_id;

        return;
    end if;

    if p_user_id is null then
        raise exception 'Stripe event is missing an InsForge user mapping.';
    end if;

    insert into public.billing_profiles (
        user_id,
        free_words_limit,
        free_words_used,
        stripe_customer_id,
        stripe_subscription_id,
        subscription_status,
        stripe_price_id,
        current_period_end,
        cancel_at_period_end,
        active_plan,
        trial_started_at,
        trial_ends_at
    )
    values (
        p_user_id,
        2500,
        0,
        p_customer_id,
        p_subscription_id,
        coalesce(p_subscription_status, 'inactive'),
        p_price_id,
        p_current_period_end,
        coalesce(p_cancel_at_period_end, false),
        case
            when public.subscription_is_active(coalesce(p_subscription_status, 'inactive')) then p_active_plan
            else null
        end,
        timezone('utc', now()),
        timezone('utc', now()) + interval '7 days'
    )
    on conflict (user_id) do update
    set stripe_customer_id = excluded.stripe_customer_id,
        stripe_subscription_id = excluded.stripe_subscription_id,
        subscription_status = excluded.subscription_status,
        stripe_price_id = excluded.stripe_price_id,
        current_period_end = excluded.current_period_end,
        cancel_at_period_end = excluded.cancel_at_period_end,
        active_plan = excluded.active_plan;
end;
$$;

grant execute on function public.apply_stripe_subscription_update(
    uuid,
    text,
    text,
    text,
    text,
    timestamptz,
    boolean,
    text
) to authenticated;

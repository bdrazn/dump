-- Create function to get user settings
CREATE OR REPLACE FUNCTION get_user_settings(p_user_id uuid)
RETURNS TABLE (
  message_window_start time,
  message_window_end time,
  timezone text,
  phone_number_1 text,
  phone_number_2 text,
  phone_number_3 text,
  phone_number_4 text,
  phone_number_selection text,
  message_wheel_mode text,
  message_wheel_delay integer,
  openai_api_key text,
  deepseek_api_key text,
  active_ai text,
  smrtphone_api_key text,
  smrtphone_webhook_url text,
  stripe_customer_id text,
  subscription_status text,
  subscription_plan text,
  subscription_period_end timestamptz,
  cancel_at_period_end boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Try to get existing settings
  RETURN QUERY
  SELECT 
    us.message_window_start,
    us.message_window_end,
    us.timezone,
    us.phone_number_1,
    us.phone_number_2,
    us.phone_number_3,
    us.phone_number_4,
    us.phone_number_selection,
    us.message_wheel_mode,
    us.message_wheel_delay,
    us.openai_api_key,
    us.deepseek_api_key,
    us.active_ai,
    us.smrtphone_api_key,
    us.smrtphone_webhook_url,
    us.stripe_customer_id,
    us.subscription_status,
    us.subscription_plan,
    us.subscription_period_end,
    us.cancel_at_period_end
  FROM user_settings us
  WHERE us.user_id = p_user_id;

  -- If no settings exist, create default settings
  IF NOT FOUND THEN
    INSERT INTO user_settings (
      user_id,
      message_window_start,
      message_window_end,
      timezone,
      phone_number_selection,
      message_wheel_mode,
      message_wheel_delay,
      active_ai,
      subscription_status,
      subscription_plan
    ) VALUES (
      p_user_id,
      '08:00',
      '20:00',
      'UTC',
      'sequential',
      'sequential',
      60,
      'deepseek',
      'trialing',
      'basic'
    );

    RETURN QUERY
    SELECT 
      us.message_window_start,
      us.message_window_end,
      us.timezone,
      us.phone_number_1,
      us.phone_number_2,
      us.phone_number_3,
      us.phone_number_4,
      us.phone_number_selection,
      us.message_wheel_mode,
      us.message_wheel_delay,
      us.openai_api_key,
      us.deepseek_api_key,
      us.active_ai,
      us.smrtphone_api_key,
      us.smrtphone_webhook_url,
      us.stripe_customer_id,
      us.subscription_status,
      us.subscription_plan,
      us.subscription_period_end,
      us.cancel_at_period_end
    FROM user_settings us
    WHERE us.user_id = p_user_id;
  END IF;
END;
$$;
-- Drop and recreate user_settings table with proper defaults
DROP TABLE IF EXISTS user_settings CASCADE;

CREATE TABLE user_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  daily_message_limit integer DEFAULT 100,
  message_window_start time DEFAULT '08:00',
  message_window_end time DEFAULT '20:00',
  timezone text DEFAULT 'UTC',
  phone_number_1 text,
  phone_number_2 text,
  phone_number_3 text,
  phone_number_4 text,
  phone_number_selection text CHECK (phone_number_selection IN ('sequential', 'random')) DEFAULT 'sequential',
  message_wheel_mode text CHECK (message_wheel_mode IN ('sequential', 'random')) DEFAULT 'sequential',
  message_wheel_delay integer DEFAULT 60,
  openai_api_key text,
  deepseek_api_key text,
  active_ai text CHECK (active_ai IN ('openai', 'deepseek')) DEFAULT 'deepseek',
  smrtphone_api_key text,
  smrtphone_webhook_url text,
  stripe_customer_id text UNIQUE,
  subscription_status text CHECK (subscription_status IN ('trialing', 'active', 'canceled', 'incomplete', 'incomplete_expired', 'past_due', 'unpaid')) DEFAULT 'trialing',
  subscription_plan text CHECK (subscription_plan IN ('basic', 'pro', 'business')) DEFAULT 'basic',
  subscription_period_end timestamptz,
  cancel_at_period_end boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_user_settings_user ON user_settings(user_id);
CREATE INDEX idx_user_settings_customer ON user_settings(stripe_customer_id);
CREATE INDEX idx_user_settings_subscription ON user_settings(subscription_status, subscription_plan);

-- Create policies
CREATE POLICY "Users can view their own settings"
  ON user_settings FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can update their own settings"
  ON user_settings FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admin can view all settings"
  ON user_settings FOR SELECT
  USING (is_admin());

CREATE POLICY "Admin can manage all settings"
  ON user_settings FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Create trigger function to create user settings
CREATE OR REPLACE FUNCTION create_user_settings()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO user_settings (
    user_id,
    daily_message_limit,
    message_window_start,
    message_window_end,
    timezone,
    phone_number_selection,
    message_wheel_mode,
    message_wheel_delay,
    active_ai,
    subscription_status,
    subscription_plan
  )
  VALUES (
    NEW.id,
    100, -- default daily limit
    '08:00', -- default window start
    '20:00', -- default window end
    'UTC',
    'sequential',
    'sequential',
    60,
    'deepseek',
    'trialing',
    'basic'
  )
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Create trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created_settings ON auth.users;
CREATE TRIGGER on_auth_user_created_settings
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_settings();

-- Insert settings for existing users
INSERT INTO user_settings (
  user_id,
  daily_message_limit,
  message_window_start,
  message_window_end,
  timezone,
  phone_number_selection,
  message_wheel_mode,
  message_wheel_delay,
  active_ai,
  subscription_status,
  subscription_plan
)
SELECT 
  id,
  100,
  '08:00',
  '20:00',
  'UTC',
  'sequential',
  'sequential',
  60,
  'deepseek',
  'trialing',
  'basic'
FROM auth.users
WHERE NOT EXISTS (
  SELECT 1 FROM user_settings WHERE user_id = auth.users.id
);
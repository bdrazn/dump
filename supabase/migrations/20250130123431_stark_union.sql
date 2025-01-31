-- Create subscription plans enum
CREATE TYPE subscription_plan AS ENUM ('basic', 'pro', 'business');
CREATE TYPE subscription_status AS ENUM ('trialing', 'active', 'canceled', 'incomplete', 'incomplete_expired', 'past_due', 'unpaid');

-- Create subscription_plans table
CREATE TABLE subscription_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  stripe_price_id text UNIQUE,
  features jsonb NOT NULL DEFAULT '[]',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create subscription_features table
CREATE TABLE subscription_features (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid REFERENCES subscription_plans(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Add subscription-related columns to user_settings
ALTER TABLE user_settings
ADD COLUMN IF NOT EXISTS stripe_customer_id text UNIQUE,
ADD COLUMN IF NOT EXISTS subscription_status subscription_status,
ADD COLUMN IF NOT EXISTS subscription_plan subscription_plan DEFAULT 'basic',
ADD COLUMN IF NOT EXISTS subscription_period_end timestamptz,
ADD COLUMN IF NOT EXISTS cancel_at_period_end boolean DEFAULT false;

-- Create indexes
CREATE INDEX idx_subscription_plans_price ON subscription_plans(stripe_price_id);
CREATE INDEX idx_subscription_features_plan ON subscription_features(plan_id);
CREATE INDEX idx_user_settings_customer ON user_settings(stripe_customer_id);
CREATE INDEX idx_user_settings_subscription ON user_settings(subscription_status, subscription_plan);

-- Enable RLS
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_features ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Everyone can view subscription plans"
  ON subscription_plans FOR SELECT
  USING (true);

CREATE POLICY "Everyone can view subscription features"
  ON subscription_features FOR SELECT
  USING (true);

-- Create function to check if user has active subscription
CREATE OR REPLACE FUNCTION has_active_subscription(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_settings
    WHERE user_id = has_active_subscription.user_id
    AND subscription_status = 'active'
  );
END;
$$;

-- Create function to check subscription features
CREATE OR REPLACE FUNCTION can_access_feature(user_id uuid, feature_name text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_plan subscription_plan;
BEGIN
  -- Get user's current plan
  SELECT subscription_plan INTO user_plan
  FROM user_settings
  WHERE user_id = can_access_feature.user_id;

  -- Check if feature is available in user's plan
  RETURN EXISTS (
    SELECT 1
    FROM subscription_plans sp
    JOIN subscription_features sf ON sf.plan_id = sp.id
    WHERE sp.name = user_plan::text
    AND sf.name = feature_name
  );
END;
$$;

-- Insert default plans
INSERT INTO subscription_plans (name, stripe_price_id, features) VALUES
  ('basic', '', '["100_properties", "1000_messages", "basic_analytics"]'),
  ('pro', 'price_pro', '["unlimited_properties", "10000_messages", "advanced_analytics", "ai_features"]'),
  ('business', 'price_business', '["unlimited_everything", "api_access", "priority_support"]');

-- Insert default features
INSERT INTO subscription_features (plan_id, name, description)
SELECT id, unnest(ARRAY[
  'properties',
  'messages',
  'analytics',
  'support'
]), 'Basic feature'
FROM subscription_plans
WHERE name = 'basic';

INSERT INTO subscription_features (plan_id, name, description)
SELECT id, unnest(ARRAY[
  'unlimited_properties',
  'advanced_messages',
  'advanced_analytics',
  'priority_support',
  'ai_features'
]), 'Pro feature'
FROM subscription_plans
WHERE name = 'pro';

INSERT INTO subscription_features (plan_id, name, description)
SELECT id, unnest(ARRAY[
  'unlimited_everything',
  'api_access',
  'dedicated_support',
  'custom_features'
]), 'Business feature'
FROM subscription_plans
WHERE name = 'business';
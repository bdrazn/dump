-- Add subscription-related columns to user_settings
ALTER TABLE user_settings
ADD COLUMN IF NOT EXISTS max_properties integer DEFAULT 100,
ADD COLUMN IF NOT EXISTS max_messages_per_month integer DEFAULT 1000,
ADD COLUMN IF NOT EXISTS max_templates integer DEFAULT 5,
ADD COLUMN IF NOT EXISTS max_lists integer DEFAULT 5,
ADD COLUMN IF NOT EXISTS max_campaigns integer DEFAULT 2,
ADD COLUMN IF NOT EXISTS ai_features_enabled boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS api_access_enabled boolean DEFAULT false;

-- Create function to update user limits based on subscription
CREATE OR REPLACE FUNCTION update_user_limits()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update user settings based on plan
  UPDATE user_settings
  SET
    max_properties = CASE
      WHEN NEW.plan = 'pro' THEN -1  -- Unlimited
      WHEN NEW.plan = 'business' THEN -1  -- Unlimited
      ELSE 100  -- Basic plan
    END,
    max_messages_per_month = CASE
      WHEN NEW.plan = 'pro' THEN 10000
      WHEN NEW.plan = 'business' THEN -1  -- Unlimited
      ELSE 1000  -- Basic plan
    END,
    max_templates = CASE
      WHEN NEW.plan = 'pro' THEN 20
      WHEN NEW.plan = 'business' THEN -1  -- Unlimited
      ELSE 5  -- Basic plan
    END,
    max_lists = CASE
      WHEN NEW.plan = 'pro' THEN 20
      WHEN NEW.plan = 'business' THEN -1  -- Unlimited
      ELSE 5  -- Basic plan
    END,
    max_campaigns = CASE
      WHEN NEW.plan = 'pro' THEN 10
      WHEN NEW.plan = 'business' THEN -1  -- Unlimited
      ELSE 2  -- Basic plan
    END,
    ai_features_enabled = NEW.plan IN ('pro', 'business'),
    api_access_enabled = NEW.plan = 'business'
  WHERE user_id = NEW.user_id;

  RETURN NEW;
END;
$$;

-- Create trigger for subscription changes
CREATE TRIGGER on_subscription_change
  AFTER INSERT OR UPDATE ON subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION update_user_limits();

-- Create function to check subscription limits
CREATE OR REPLACE FUNCTION check_subscription_limit(
  p_user_id uuid,
  p_limit_type text,
  p_current_count integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  limit_value integer;
BEGIN
  -- Get the limit value based on type
  SELECT
    CASE p_limit_type
      WHEN 'properties' THEN max_properties
      WHEN 'messages' THEN max_messages_per_month
      WHEN 'templates' THEN max_templates
      WHEN 'lists' THEN max_lists
      WHEN 'campaigns' THEN max_campaigns
    END INTO limit_value
  FROM user_settings
  WHERE user_id = p_user_id;

  -- -1 means unlimited
  IF limit_value = -1 THEN
    RETURN true;
  END IF;

  -- Check if current count is within limit
  RETURN p_current_count < limit_value;
END;
$$;
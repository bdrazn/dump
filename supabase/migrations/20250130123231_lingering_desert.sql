-- Create subscription_usage table to track monthly usage
CREATE TABLE subscription_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  month date NOT NULL,
  messages_sent integer DEFAULT 0,
  properties_added integer DEFAULT 0,
  templates_created integer DEFAULT 0,
  lists_created integer DEFAULT 0,
  campaigns_created integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, month)
);

-- Enable RLS
ALTER TABLE subscription_usage ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_subscription_usage_user_month ON subscription_usage(user_id, month);

-- Create policies
CREATE POLICY "Users can view their own usage"
  ON subscription_usage FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Admin can view all usage"
  ON subscription_usage FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE id = auth.uid()
      AND email = 'beewax99@gmail.com'
    )
  );

-- Create function to increment usage
CREATE OR REPLACE FUNCTION increment_usage(
  p_user_id uuid,
  p_type text,
  p_amount integer DEFAULT 1
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_month date := date_trunc('month', current_date)::date;
BEGIN
  -- Insert or update usage record
  INSERT INTO subscription_usage (user_id, month)
  VALUES (p_user_id, current_month)
  ON CONFLICT (user_id, month)
  DO UPDATE SET
    messages_sent = CASE WHEN p_type = 'messages' 
      THEN subscription_usage.messages_sent + p_amount
      ELSE subscription_usage.messages_sent END,
    properties_added = CASE WHEN p_type = 'properties'
      THEN subscription_usage.properties_added + p_amount
      ELSE subscription_usage.properties_added END,
    templates_created = CASE WHEN p_type = 'templates'
      THEN subscription_usage.templates_created + p_amount
      ELSE subscription_usage.templates_created END,
    lists_created = CASE WHEN p_type = 'lists'
      THEN subscription_usage.lists_created + p_amount
      ELSE subscription_usage.lists_created END,
    campaigns_created = CASE WHEN p_type = 'campaigns'
      THEN subscription_usage.campaigns_created + p_amount
      ELSE subscription_usage.campaigns_created END,
    updated_at = now();
END;
$$;

-- Create trigger for updated_at
CREATE TRIGGER update_subscription_usage_updated_at
  BEFORE UPDATE ON subscription_usage
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
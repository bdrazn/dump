-- Create bulk message campaigns table
CREATE TABLE bulk_message_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  template_id uuid REFERENCES message_templates(id) ON DELETE SET NULL,
  status text CHECK (status IN ('draft', 'scheduled', 'running', 'paused', 'completed', 'failed')),
  scheduled_for timestamptz,
  target_list jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create bulk message stats table
CREATE TABLE bulk_message_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid REFERENCES bulk_message_campaigns(id) ON DELETE CASCADE,
  total_messages integer DEFAULT 0,
  sent_count integer DEFAULT 0,
  delivered_count integer DEFAULT 0,
  failed_count integer DEFAULT 0,
  response_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(campaign_id)
);

-- Enable RLS
ALTER TABLE bulk_message_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE bulk_message_stats ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_bulk_campaigns_workspace ON bulk_message_campaigns(workspace_id);
CREATE INDEX idx_bulk_campaigns_status ON bulk_message_campaigns(status);
CREATE INDEX idx_bulk_campaigns_scheduled ON bulk_message_campaigns(scheduled_for);
CREATE INDEX idx_bulk_stats_campaign ON bulk_message_stats(campaign_id);

-- Create policies
CREATE POLICY "Users can view bulk campaigns"
  ON bulk_message_campaigns FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage bulk campaigns"
  ON bulk_message_campaigns FOR ALL
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view bulk stats"
  ON bulk_message_stats FOR SELECT
  USING (
    campaign_id IN (
      SELECT id FROM bulk_message_campaigns
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can manage bulk stats"
  ON bulk_message_stats FOR ALL
  USING (
    campaign_id IN (
      SELECT id FROM bulk_message_campaigns
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    campaign_id IN (
      SELECT id FROM bulk_message_campaigns
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );

-- Create function to update campaign stats
CREATE OR REPLACE FUNCTION update_campaign_stats(
  p_campaign_id uuid,
  p_total_messages integer DEFAULT NULL,
  p_sent_count integer DEFAULT NULL,
  p_delivered_count integer DEFAULT NULL,
  p_failed_count integer DEFAULT NULL,
  p_response_count integer DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO bulk_message_stats (
    campaign_id,
    total_messages,
    sent_count,
    delivered_count,
    failed_count,
    response_count
  )
  VALUES (
    p_campaign_id,
    COALESCE(p_total_messages, 0),
    COALESCE(p_sent_count, 0),
    COALESCE(p_delivered_count, 0),
    COALESCE(p_failed_count, 0),
    COALESCE(p_response_count, 0)
  )
  ON CONFLICT (campaign_id)
  DO UPDATE SET
    total_messages = CASE 
      WHEN p_total_messages IS NOT NULL 
      THEN p_total_messages 
      ELSE bulk_message_stats.total_messages 
    END,
    sent_count = CASE 
      WHEN p_sent_count IS NOT NULL 
      THEN bulk_message_stats.sent_count + p_sent_count
      ELSE bulk_message_stats.sent_count 
    END,
    delivered_count = CASE 
      WHEN p_delivered_count IS NOT NULL 
      THEN bulk_message_stats.delivered_count + p_delivered_count
      ELSE bulk_message_stats.delivered_count 
    END,
    failed_count = CASE 
      WHEN p_failed_count IS NOT NULL 
      THEN bulk_message_stats.failed_count + p_failed_count
      ELSE bulk_message_stats.failed_count 
    END,
    response_count = CASE 
      WHEN p_response_count IS NOT NULL 
      THEN bulk_message_stats.response_count + p_response_count
      ELSE bulk_message_stats.response_count 
    END,
    updated_at = now();
END;
$$;

-- Create triggers for updated_at
CREATE TRIGGER update_bulk_campaigns_updated_at
  BEFORE UPDATE ON bulk_message_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_bulk_stats_updated_at
  BEFORE UPDATE ON bulk_message_stats
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
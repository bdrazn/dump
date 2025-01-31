-- Create message analysis logs table
CREATE TABLE message_analysis_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  message_id uuid REFERENCES messages(id) ON DELETE CASCADE,
  content text NOT NULL,
  status text CHECK (status IN ('interested', 'not_interested', 'dnc')),
  confidence numeric(4,3) CHECK (confidence >= 0 AND confidence <= 1),
  reasoning text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE message_analysis_logs ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_message_analysis_logs_workspace ON message_analysis_logs(workspace_id);
CREATE INDEX idx_message_analysis_logs_message ON message_analysis_logs(message_id);
CREATE INDEX idx_message_analysis_logs_status ON message_analysis_logs(status);
CREATE INDEX idx_message_analysis_logs_created ON message_analysis_logs(created_at);

-- Create policies
CREATE POLICY "Users can view message analysis logs"
  ON message_analysis_logs FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage message analysis logs"
  ON message_analysis_logs FOR ALL
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

-- Create trigger for updated_at
CREATE TRIGGER update_message_analysis_logs_updated_at
  BEFORE UPDATE ON message_analysis_logs
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Create function to log message analysis
CREATE OR REPLACE FUNCTION log_message_analysis(
  p_workspace_id uuid,
  p_message_id uuid,
  p_content text,
  p_status text,
  p_confidence numeric,
  p_reasoning text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  log_id uuid;
BEGIN
  INSERT INTO message_analysis_logs (
    workspace_id,
    message_id,
    content,
    status,
    confidence,
    reasoning
  )
  VALUES (
    p_workspace_id,
    p_message_id,
    p_content,
    p_status,
    p_confidence,
    p_reasoning
  )
  RETURNING id INTO log_id;

  RETURN log_id;
END;
$$;
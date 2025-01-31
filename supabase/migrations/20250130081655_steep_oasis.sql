-- Create smrtphone_messages table
CREATE TABLE smrtphone_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  thread_id uuid REFERENCES message_threads(id) ON DELETE CASCADE,
  external_id text UNIQUE,
  from_number text NOT NULL,
  to_number text NOT NULL,
  content text NOT NULL,
  status text CHECK (status IN ('sent', 'delivered', 'failed', 'spam')),
  direction text CHECK (direction IN ('inbound', 'outbound')),
  received_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE smrtphone_messages ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_smrtphone_messages_workspace ON smrtphone_messages(workspace_id);
CREATE INDEX idx_smrtphone_messages_thread ON smrtphone_messages(thread_id);
CREATE INDEX idx_smrtphone_messages_external ON smrtphone_messages(external_id);
CREATE INDEX idx_smrtphone_messages_status ON smrtphone_messages(status);
CREATE INDEX idx_smrtphone_messages_direction ON smrtphone_messages(direction);
CREATE INDEX idx_smrtphone_messages_created ON smrtphone_messages(created_at);

-- Create policies
CREATE POLICY "Users can view smrtphone messages"
  ON smrtphone_messages FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage smrtphone messages"
  ON smrtphone_messages FOR ALL
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
CREATE TRIGGER update_smrtphone_messages_updated_at
  BEFORE UPDATE ON smrtphone_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
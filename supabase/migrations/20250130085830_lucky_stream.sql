-- Remove created_by column reference from message_wheels
ALTER TABLE message_wheels
DROP COLUMN IF EXISTS created_by;

-- Add workspace_id foreign key if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'message_wheels' AND column_name = 'workspace_id'
  ) THEN
    ALTER TABLE message_wheels
    ADD COLUMN workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_message_wheels_workspace ON message_wheels(workspace_id);

-- Update RLS policies
DROP POLICY IF EXISTS "Users can view message wheels" ON message_wheels;
DROP POLICY IF EXISTS "Users can manage message wheels" ON message_wheels;

CREATE POLICY "Users can view message wheels"
  ON message_wheels FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage message wheels"
  ON message_wheels FOR ALL
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
-- Drop existing message thread policies
DROP POLICY IF EXISTS "Users can view message threads" ON message_threads;
DROP POLICY IF EXISTS "Users can manage message threads" ON message_threads;

-- Create new message thread policies
CREATE POLICY "message_thread_select_policy"
  ON message_threads FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "message_thread_insert_policy"
  ON message_threads FOR INSERT
  WITH CHECK (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "message_thread_update_policy"
  ON message_threads FOR UPDATE
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

CREATE POLICY "message_thread_delete_policy"
  ON message_threads FOR DELETE
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

-- Create function to get or create message thread
CREATE OR REPLACE FUNCTION get_or_create_message_thread(
  p_workspace_id uuid,
  p_contact_id uuid,
  p_direction text DEFAULT 'outbound'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  thread_id uuid;
BEGIN
  -- Try to find existing thread
  SELECT id INTO thread_id
  FROM message_threads
  WHERE workspace_id = p_workspace_id
    AND contact_id = p_contact_id;

  -- Create new thread if not found
  IF thread_id IS NULL THEN
    INSERT INTO message_threads (
      workspace_id,
      contact_id,
      direction
    )
    VALUES (
      p_workspace_id,
      p_contact_id,
      p_direction
    )
    RETURNING id INTO thread_id;
  END IF;

  RETURN thread_id;
END;
$$;
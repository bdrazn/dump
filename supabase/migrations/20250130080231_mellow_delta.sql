-- Drop existing policies
DROP POLICY IF EXISTS "Users can view messages" ON messages;
DROP POLICY IF EXISTS "Users can manage messages" ON messages;

-- Create new RLS policies for messages table
CREATE POLICY "Users can view messages"
  ON messages FOR SELECT
  USING (
    thread_id IN (
      SELECT id 
      FROM message_threads
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can insert messages"
  ON messages FOR INSERT
  WITH CHECK (
    thread_id IN (
      SELECT id 
      FROM message_threads
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can update messages"
  ON messages FOR UPDATE
  USING (
    thread_id IN (
      SELECT id 
      FROM message_threads
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    thread_id IN (
      SELECT id 
      FROM message_threads
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can delete messages"
  ON messages FOR DELETE
  USING (
    thread_id IN (
      SELECT id 
      FROM message_threads
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );
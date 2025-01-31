-- Add error_message column to messages table
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS error_message text;

-- Add direction column to message_threads if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'message_threads' AND column_name = 'direction'
  ) THEN
    ALTER TABLE message_threads
    ADD COLUMN direction text CHECK (direction IN ('inbound', 'outbound'));

    -- Create index for better performance
    CREATE INDEX idx_message_threads_direction ON message_threads(direction);
  END IF;
END $$;

-- Drop all existing message policies to avoid conflicts
DO $$
BEGIN
  -- Drop view policies
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname IN (
      'Users can view messages',
      'Users can view messages v2',
      'Users can view messages v3'
    )
  ) THEN
    DROP POLICY IF EXISTS "Users can view messages" ON messages;
    DROP POLICY IF EXISTS "Users can view messages v2" ON messages;
    DROP POLICY IF EXISTS "Users can view messages v3" ON messages;
  END IF;

  -- Drop insert policies
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname IN (
      'Users can insert messages',
      'Users can insert messages v2',
      'Users can insert messages v3'
    )
  ) THEN
    DROP POLICY IF EXISTS "Users can insert messages" ON messages;
    DROP POLICY IF EXISTS "Users can insert messages v2" ON messages;
    DROP POLICY IF EXISTS "Users can insert messages v3" ON messages;
  END IF;

  -- Drop update policies
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname IN (
      'Users can update messages',
      'Users can update messages v2',
      'Users can update messages v3'
    )
  ) THEN
    DROP POLICY IF EXISTS "Users can update messages" ON messages;
    DROP POLICY IF EXISTS "Users can update messages v2" ON messages;
    DROP POLICY IF EXISTS "Users can update messages v3" ON messages;
  END IF;

  -- Drop delete policies
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname IN (
      'Users can delete messages',
      'Users can delete messages v2',
      'Users can delete messages v3'
    )
  ) THEN
    DROP POLICY IF EXISTS "Users can delete messages" ON messages;
    DROP POLICY IF EXISTS "Users can delete messages v2" ON messages;
    DROP POLICY IF EXISTS "Users can delete messages v3" ON messages;
  END IF;
END $$;

-- Create fresh policies with new names
CREATE POLICY "message_select_policy"
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

CREATE POLICY "message_insert_policy"
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

CREATE POLICY "message_update_policy"
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

CREATE POLICY "message_delete_policy"
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

-- Update existing message threads to set direction based on first message
UPDATE message_threads mt
SET direction = COALESCE(
  (
    SELECT 
      CASE 
        WHEN sender_id = mt.contact_id THEN 'inbound'
        ELSE 'outbound'
      END
    FROM messages m
    WHERE m.thread_id = mt.id
    ORDER BY m.created_at ASC
    LIMIT 1
  ),
  'outbound'
)
WHERE direction IS NULL;
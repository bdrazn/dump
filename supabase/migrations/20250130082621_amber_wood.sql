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

-- Drop existing policies if they exist
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname = 'Users can view messages v2'
  ) THEN
    DROP POLICY "Users can view messages v2" ON messages;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname = 'Users can insert messages v2'
  ) THEN
    DROP POLICY "Users can insert messages v2" ON messages;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname = 'Users can update messages v2'
  ) THEN
    DROP POLICY "Users can update messages v2" ON messages;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname = 'Users can delete messages v2'
  ) THEN
    DROP POLICY "Users can delete messages v2" ON messages;
  END IF;
END $$;

-- Create new RLS policies for messages table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname = 'Users can view messages v3'
  ) THEN
    CREATE POLICY "Users can view messages v3"
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
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname = 'Users can insert messages v3'
  ) THEN
    CREATE POLICY "Users can insert messages v3"
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
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname = 'Users can update messages v3'
  ) THEN
    CREATE POLICY "Users can update messages v3"
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
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'messages' AND policyname = 'Users can delete messages v3'
  ) THEN
    CREATE POLICY "Users can delete messages v3"
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
  END IF;
END $$;

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
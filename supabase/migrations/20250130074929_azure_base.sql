-- Drop existing functions first
DROP FUNCTION IF EXISTS get_thread_details(uuid);
DROP FUNCTION IF EXISTS get_threads_by_folder(uuid, text);

-- Add deleted_at column to messages table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'messages' AND column_name = 'deleted_at'
  ) THEN
    ALTER TABLE messages ADD COLUMN deleted_at timestamptz;
    CREATE INDEX idx_messages_deleted_at ON messages(deleted_at);
  END IF;
END $$;

-- Add direction column to message_threads table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'message_threads' AND column_name = 'direction'
  ) THEN
    ALTER TABLE message_threads ADD COLUMN direction text CHECK (direction IN ('inbound', 'outbound'));
    CREATE INDEX idx_message_threads_direction ON message_threads(direction);
  END IF;
END $$;

-- Create thread details function
CREATE FUNCTION get_thread_details(p_thread_id uuid)
RETURNS TABLE (
  id uuid,
  status text,
  direction text,
  contact_id uuid,
  contact_first_name text,
  contact_last_name text,
  contact_business_name text,
  contact_email text,
  property_id uuid,
  property_address text,
  messages jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mt.id,
    mt.status,
    mt.direction,
    c.id as contact_id,
    c.first_name as contact_first_name,
    c.last_name as contact_last_name,
    c.business_name as contact_business_name,
    c.email as contact_email,
    p.id as property_id,
    p.address as property_address,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'content', m.content,
          'sender_id', m.sender_id,
          'created_at', m.created_at,
          'deleted_at', m.deleted_at,
          'status', sm.status,
          'direction', sm.direction,
          'from_number', sm.from_number,
          'to_number', sm.to_number
        ) ORDER BY m.created_at ASC
      ) FILTER (WHERE m.id IS NOT NULL),
      '[]'::jsonb
    ) as messages
  FROM message_threads mt
  JOIN contacts c ON c.id = mt.contact_id
  LEFT JOIN properties p ON p.id = mt.property_id
  LEFT JOIN messages m ON m.thread_id = mt.id
  LEFT JOIN sms_messages sm ON sm.thread_id = mt.id AND sm.external_id = m.id::text
  WHERE mt.id = p_thread_id
  GROUP BY mt.id, c.id, p.id;
END;
$$;

-- Create function to get threads by folder
CREATE FUNCTION get_threads_by_folder(
  p_workspace_id uuid,
  p_folder text
)
RETURNS TABLE (
  id uuid,
  status text,
  direction text,
  contact_id uuid,
  contact_first_name text,
  contact_last_name text,
  contact_business_name text,
  contact_email text,
  unread_count bigint,
  last_message jsonb,
  has_deleted_messages boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH thread_messages AS (
    SELECT 
      mt.id as thread_id,
      COUNT(m.id) FILTER (WHERE m.read_at IS NULL)::bigint as unread_count,
      bool_or(m.deleted_at IS NOT NULL) as has_deleted_messages,
      (
        SELECT jsonb_build_object(
          'content', m2.content,
          'created_at', m2.created_at,
          'sender_id', m2.sender_id,
          'deleted_at', m2.deleted_at
        )
        FROM messages m2
        WHERE m2.thread_id = mt.id
        ORDER BY m2.created_at DESC
        LIMIT 1
      ) as last_message
    FROM message_threads mt
    LEFT JOIN messages m ON m.thread_id = mt.id
    GROUP BY mt.id
  )
  SELECT 
    mt.id,
    mt.status,
    mt.direction,
    c.id as contact_id,
    c.first_name as contact_first_name,
    c.last_name as contact_last_name,
    c.business_name as contact_business_name,
    c.email as contact_email,
    tm.unread_count,
    tm.last_message,
    tm.has_deleted_messages
  FROM message_threads mt
  JOIN contacts c ON c.id = mt.contact_id
  JOIN thread_messages tm ON tm.thread_id = mt.id
  WHERE mt.workspace_id = p_workspace_id
  AND CASE 
    WHEN p_folder = 'inbox' THEN mt.direction = 'inbound' AND NOT tm.has_deleted_messages
    WHEN p_folder = 'sent' THEN mt.direction = 'outbound' AND NOT tm.has_deleted_messages
    WHEN p_folder = 'trash' THEN tm.has_deleted_messages
    ELSE true
  END
  ORDER BY (tm.last_message->>'created_at')::timestamptz DESC NULLS LAST;
END;
$$;

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
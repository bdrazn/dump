/*
  # Fix message threads and contacts relationships

  1. Changes
    - Update message thread queries to use contacts table
    - Add phone number relationships
    - Add helper functions for message threads

  2. Security
    - Add RLS policies for message threads
    - Add RLS policies for messages
*/

-- Create function to get thread details
CREATE OR REPLACE FUNCTION get_thread_details(p_thread_id uuid)
RETURNS TABLE (
  id uuid,
  status text,
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

-- Create function to get contact threads
CREATE OR REPLACE FUNCTION get_contact_threads(p_workspace_id uuid)
RETURNS TABLE (
  id uuid,
  contact_id uuid,
  first_name text,
  last_name text,
  business_name text,
  email text,
  status text,
  last_message jsonb,
  unread_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mt.id,
    c.id as contact_id,
    c.first_name,
    c.last_name,
    c.business_name,
    c.email,
    mt.status,
    (
      SELECT jsonb_build_object(
        'content', m.content,
        'created_at', m.created_at,
        'sender_id', m.sender_id
      )
      FROM messages m
      WHERE m.thread_id = mt.id
      ORDER BY m.created_at DESC
      LIMIT 1
    ) as last_message,
    COUNT(m.id) FILTER (WHERE m.sender_id != auth.uid() AND m.read_at IS NULL)::bigint as unread_count
  FROM message_threads mt
  JOIN contacts c ON c.id = mt.contact_id
  LEFT JOIN messages m ON m.thread_id = mt.id
  WHERE mt.workspace_id = p_workspace_id
  GROUP BY mt.id, c.id
  ORDER BY MAX(m.created_at) DESC NULLS LAST;
END;
$$;

-- Create function to get or create thread
CREATE OR REPLACE FUNCTION get_or_create_thread(
  p_workspace_id uuid,
  p_contact_id uuid,
  p_property_id uuid DEFAULT NULL
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
    AND contact_id = p_contact_id
    AND (
      (p_property_id IS NULL AND property_id IS NULL) OR
      property_id = p_property_id
    );

  -- Create new thread if not found
  IF thread_id IS NULL THEN
    INSERT INTO message_threads (
      workspace_id,
      contact_id,
      property_id
    )
    VALUES (
      p_workspace_id,
      p_contact_id,
      p_property_id
    )
    RETURNING id INTO thread_id;
  END IF;

  RETURN thread_id;
END;
$$;

-- Update message thread policies
DROP POLICY IF EXISTS "Users can view message threads" ON message_threads;
DROP POLICY IF EXISTS "Users can manage message threads" ON message_threads;

CREATE POLICY "Users can view message threads"
  ON message_threads FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage message threads"
  ON message_threads FOR ALL
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

-- Update message policies
DROP POLICY IF EXISTS "Users can view messages" ON messages;
DROP POLICY IF EXISTS "Users can manage messages" ON messages;

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

CREATE POLICY "Users can manage messages"
  ON messages FOR ALL
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
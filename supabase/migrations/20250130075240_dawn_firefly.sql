-- Drop existing functions first
DROP FUNCTION IF EXISTS get_thread_details(uuid);
DROP FUNCTION IF EXISTS get_threads_by_folder(uuid, text);

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
  last_message jsonb
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
    COUNT(m.id) FILTER (WHERE m.read_at IS NULL)::bigint as unread_count,
    (
      SELECT jsonb_build_object(
        'content', m2.content,
        'created_at', m2.created_at,
        'sender_id', m2.sender_id
      )
      FROM messages m2
      WHERE m2.thread_id = mt.id
      ORDER BY m2.created_at DESC
      LIMIT 1
    ) as last_message
  FROM message_threads mt
  JOIN contacts c ON c.id = mt.contact_id
  LEFT JOIN messages m ON m.thread_id = mt.id
  WHERE mt.workspace_id = p_workspace_id
  AND CASE 
    WHEN p_folder = 'inbox' THEN mt.direction = 'inbound' AND m.deleted_at IS NULL
    WHEN p_folder = 'sent' THEN mt.direction = 'outbound' AND m.deleted_at IS NULL
    WHEN p_folder = 'trash' THEN m.deleted_at IS NOT NULL
    ELSE true
  END
  GROUP BY mt.id, c.id
  ORDER BY MAX(m.created_at) DESC NULLS LAST;
END;
$$;
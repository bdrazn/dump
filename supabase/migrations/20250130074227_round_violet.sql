-- Add contact_id foreign key to message_threads table
ALTER TABLE message_threads
  ADD CONSTRAINT message_threads_contact_id_fkey
  FOREIGN KEY (contact_id) REFERENCES contacts(id)
  ON DELETE CASCADE;

-- Create index for better performance
CREATE INDEX idx_message_threads_contact ON message_threads(contact_id);

-- Update message_threads query function
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
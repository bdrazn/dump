/*
  # Fix SMS messages and relationships

  1. Changes
    - Create SMS messages table for tracking messages
    - Update message thread relationships
    - Add workspace relationship to messages
  
  2. Security
    - Enable RLS on new tables
    - Add appropriate policies
*/

-- Create SMS messages table
CREATE TABLE sms_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  external_id text UNIQUE,
  thread_id uuid REFERENCES message_threads(id) ON DELETE CASCADE,
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
ALTER TABLE sms_messages ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_sms_messages_workspace ON sms_messages(workspace_id);
CREATE INDEX idx_sms_messages_thread ON sms_messages(thread_id);
CREATE INDEX idx_sms_messages_external ON sms_messages(external_id);
CREATE INDEX idx_sms_messages_status ON sms_messages(status);
CREATE INDEX idx_sms_messages_direction ON sms_messages(direction);
CREATE INDEX idx_sms_messages_created ON sms_messages(created_at);

-- Create policies
CREATE POLICY "Users can view SMS messages"
  ON sms_messages FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage SMS messages"
  ON sms_messages FOR ALL
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

-- Update message threads to use contacts
ALTER TABLE message_threads
  DROP CONSTRAINT IF EXISTS message_threads_contact_id_fkey,
  ADD CONSTRAINT message_threads_contact_id_fkey 
    FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE;

-- Create function to get contact's phone numbers
CREATE OR REPLACE FUNCTION get_contact_phone_numbers(contact_id uuid)
RETURNS TABLE (number text, type text, is_primary boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    phone_numbers.number,
    phone_numbers.type,
    phone_numbers.is_primary
  FROM phone_numbers
  WHERE phone_numbers.owner_id = contact_id
  ORDER BY phone_numbers.is_primary DESC, phone_numbers.created_at ASC;
END;
$$;

-- Create function to get thread messages
CREATE OR REPLACE FUNCTION get_thread_messages(thread_id uuid)
RETURNS TABLE (
  id uuid,
  content text,
  sender_id uuid,
  created_at timestamptz,
  status text,
  direction text,
  from_number text,
  to_number text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.id,
    m.content,
    m.sender_id,
    m.created_at,
    sm.status,
    sm.direction,
    sm.from_number,
    sm.to_number
  FROM messages m
  LEFT JOIN sms_messages sm ON sm.thread_id = m.thread_id
  WHERE m.thread_id = get_thread_messages.thread_id
  ORDER BY m.created_at ASC;
END;
$$;

-- Create trigger for updated_at
CREATE TRIGGER update_sms_messages_updated_at
  BEFORE UPDATE ON sms_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
/*
  # Add Database Functions and Policies
  
  1. Functions
    - get_workspace_by_user
    - resolve_merge_fields
    - upsert_message_analytics
    - log_activity
    - get_or_create_contact
    - create_contact_property_relationship
  
  2. Additional Policies
    - Full CRUD policies for workspace members
*/

-- Create function to get workspace by user with explicit table alias
CREATE OR REPLACE FUNCTION get_workspace_by_user(p_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT workspace_users.workspace_id
    FROM workspace_users
    WHERE workspace_users.user_id = p_user_id
    LIMIT 1
  );
END;
$$;

-- Create function to resolve merge fields
CREATE OR REPLACE FUNCTION resolve_merge_fields(
  template_content text,
  contact_id uuid,
  property_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result text := template_content;
  contact_record RECORD;
  property_record RECORD;
BEGIN
  -- Get contact details
  SELECT * INTO contact_record
  FROM profiles
  WHERE id = contact_id;

  -- Get property details
  SELECT * INTO property_record
  FROM properties
  WHERE id = property_id;

  -- Replace contact fields
  IF contact_record IS NOT NULL THEN
    result := REPLACE(result, '{{contact_name}}',
      COALESCE(contact_record.business_name,
        contact_record.first_name || ' ' || contact_record.last_name));
    result := REPLACE(result, '{{contact_email}}', contact_record.email);
    result := REPLACE(result, '{{contact_phone}}', COALESCE(contact_record.phone1, ''));
  END IF;

  -- Replace property fields
  IF property_record IS NOT NULL THEN
    result := REPLACE(result, '{{property_address}}', property_record.address);
    result := REPLACE(result, '{{property_city}}', property_record.city);
    result := REPLACE(result, '{{property_state}}', property_record.state);
    result := REPLACE(result, '{{property_zip}}', property_record.zip);
  END IF;

  RETURN result;
END;
$$;

-- Create function to upsert message analytics
CREATE OR REPLACE FUNCTION upsert_message_analytics(
  p_workspace_id uuid,
  p_date date,
  p_updates jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO message_analytics (
    workspace_id,
    date,
    messages_sent,
    messages_delivered,
    responses_received,
    interested_count,
    not_interested_count,
    dnc_count
  )
  VALUES (
    p_workspace_id,
    p_date,
    COALESCE((p_updates->>'messages_sent')::integer, 0),
    COALESCE((p_updates->>'messages_delivered')::integer, 0),
    COALESCE((p_updates->>'responses_received')::integer, 0),
    COALESCE((p_updates->>'interested_count')::integer, 0),
    COALESCE((p_updates->>'not_interested_count')::integer, 0),
    COALESCE((p_updates->>'dnc_count')::integer, 0)
  )
  ON CONFLICT (workspace_id, date)
  DO UPDATE SET
    messages_sent = message_analytics.messages_sent + COALESCE((p_updates->>'messages_sent')::integer, 0),
    messages_delivered = message_analytics.messages_delivered + COALESCE((p_updates->>'messages_delivered')::integer, 0),
    responses_received = message_analytics.responses_received + COALESCE((p_updates->>'responses_received')::integer, 0),
    interested_count = message_analytics.interested_count + COALESCE((p_updates->>'interested_count')::integer, 0),
    not_interested_count = message_analytics.not_interested_count + COALESCE((p_updates->>'not_interested_count')::integer, 0),
    dnc_count = message_analytics.dnc_count + COALESCE((p_updates->>'dnc_count')::integer, 0),
    updated_at = now();
END;
$$;

-- Create function to log activity
CREATE OR REPLACE FUNCTION log_activity(
  p_workspace_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_action text,
  p_status text,
  p_message text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  log_id uuid;
BEGIN
  INSERT INTO activity_logs (
    workspace_id,
    user_id,
    entity_type,
    entity_id,
    action,
    status,
    message
  )
  VALUES (
    p_workspace_id,
    auth.uid(),
    p_entity_type,
    p_entity_id,
    p_action,
    p_status,
    p_message
  )
  RETURNING id INTO log_id;

  RETURN log_id;
END;
$$;

-- Create function to get or create contact
CREATE OR REPLACE FUNCTION get_or_create_contact(
  p_workspace_id uuid,
  p_first_name text,
  p_last_name text,
  p_business_name text,
  p_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  contact_id uuid;
BEGIN
  -- Try to find existing contact
  SELECT id INTO contact_id
  FROM profiles
  WHERE workspace_id = p_workspace_id
    AND first_name = p_first_name
    AND last_name = p_last_name
    AND (
      (p_business_name IS NULL AND business_name IS NULL) OR
      business_name = p_business_name
    );

  -- Create new contact if not found
  IF contact_id IS NULL THEN
    INSERT INTO profiles (
      workspace_id,
      first_name,
      last_name,
      business_name,
      email
    )
    VALUES (
      p_workspace_id,
      p_first_name,
      p_last_name,
      p_business_name,
      p_email
    )
    RETURNING id INTO contact_id;
  END IF;

  RETURN contact_id;
END;
$$;

-- Create function to create contact-property relationship
CREATE OR REPLACE FUNCTION create_contact_property_relationship(
  p_contact_id uuid,
  p_property_id uuid,
  p_relationship_type text,
  p_workspace_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify contact and property belong to the same workspace
  IF NOT EXISTS (
    SELECT 1
    FROM profiles c
    JOIN properties p ON c.workspace_id = p.workspace_id
    WHERE c.id = p_contact_id
      AND p.id = p_property_id
      AND c.workspace_id = p_workspace_id
  ) THEN
    RAISE EXCEPTION 'Contact and property must belong to the same workspace';
  END IF;

  -- Create or update relationship
  INSERT INTO property_contact_relations (
    contact_id,
    property_id,
    relationship_type
  )
  VALUES (
    p_contact_id,
    p_property_id,
    p_relationship_type
  )
  ON CONFLICT (contact_id, property_id)
  DO UPDATE SET
    relationship_type = EXCLUDED.relationship_type;
END;
$$;

-- Add CRUD policies for workspace members
CREATE POLICY "Workspace members can insert data"
  ON properties FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM workspace_users wu
    WHERE wu.workspace_id = properties.workspace_id
    AND wu.user_id = auth.uid()
  ));

CREATE POLICY "Workspace members can update data"
  ON properties FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM workspace_users wu
    WHERE wu.workspace_id = properties.workspace_id
    AND wu.user_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM workspace_users wu
    WHERE wu.workspace_id = properties.workspace_id
    AND wu.user_id = auth.uid()
  ));

CREATE POLICY "Workspace members can delete data"
  ON properties FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM workspace_users wu
    WHERE wu.workspace_id = properties.workspace_id
    AND wu.user_id = auth.uid()
  ));
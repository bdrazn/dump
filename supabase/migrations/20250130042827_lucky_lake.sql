/*
  # Rename profiles table to contacts
  
  1. Changes
    - Rename profiles table to contacts
    - Update all references to profiles table
    - Update foreign key constraints
    - Update RLS policies
  
  2. Security
    - Recreate RLS policies for contacts table
    - Maintain existing security model
*/

-- Rename the table
ALTER TABLE profiles RENAME TO contacts;

-- Update foreign key references
ALTER TABLE message_threads 
  DROP CONSTRAINT message_threads_contact_id_fkey,
  ADD CONSTRAINT message_threads_contact_id_fkey 
    FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE;

ALTER TABLE property_contact_relations
  DROP CONSTRAINT property_contact_relations_contact_id_fkey,
  ADD CONSTRAINT property_contact_relations_contact_id_fkey
    FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE;

-- Drop and recreate policies with new table name
DROP POLICY IF EXISTS "Users can view profiles" ON contacts;
DROP POLICY IF EXISTS "Users can view profiles in their workspace" ON contacts;

CREATE POLICY "Users can view contacts"
  ON contacts FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage contacts"
  ON contacts FOR ALL
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

-- Update functions that reference profiles table
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
  FROM contacts
  WHERE workspace_id = p_workspace_id
    AND first_name = p_first_name
    AND last_name = p_last_name
    AND (
      (p_business_name IS NULL AND business_name IS NULL) OR
      business_name = p_business_name
    );

  -- Create new contact if not found
  IF contact_id IS NULL THEN
    INSERT INTO contacts (
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
  FROM contacts
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

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  workspace_id uuid;
BEGIN
  -- Create default workspace
  INSERT INTO workspaces (name, created_by)
  VALUES (
    COALESCE(NEW.raw_user_meta_data->>'company_name', 'My Workspace'),
    NEW.id
  )
  RETURNING id INTO workspace_id;

  -- Add user to workspace
  INSERT INTO workspace_users (workspace_id, user_id, role)
  VALUES (workspace_id, NEW.id, 'owner');

  -- Create user contact
  INSERT INTO contacts (
    id,
    workspace_id,
    first_name,
    last_name,
    email
  )
  VALUES (
    NEW.id,
    workspace_id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    '',
    NEW.email
  );

  -- Create user settings
  INSERT INTO user_settings (user_id)
  VALUES (NEW.id);

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_auth_user_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.contacts (id, workspace_id, first_name, last_name, email)
  VALUES (
    NEW.id,
    (SELECT workspace_id FROM workspace_users WHERE user_id = NEW.id LIMIT 1),
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    '',
    NEW.email
  );
  RETURN NEW;
END;
$$;
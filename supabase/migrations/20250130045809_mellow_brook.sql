-- Create function to get contact properties
CREATE OR REPLACE FUNCTION get_contact_properties(p_contact_id uuid)
RETURNS TABLE (
  id uuid,
  address text,
  city text,
  state text,
  zip text,
  relationship_type text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.address,
    p.city,
    p.state,
    p.zip,
    pcr.relationship_type
  FROM properties p
  JOIN property_contact_relations pcr ON pcr.property_id = p.id
  WHERE pcr.contact_id = p_contact_id;
END;
$$;

-- Create function to get property contacts
CREATE OR REPLACE FUNCTION get_property_contacts(p_property_id uuid)
RETURNS TABLE (
  id uuid,
  first_name text,
  last_name text,
  business_name text,
  email text,
  relationship_type text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.first_name,
    c.last_name,
    c.business_name,
    c.email,
    pcr.relationship_type
  FROM contacts c
  JOIN property_contact_relations pcr ON pcr.contact_id = c.id
  WHERE pcr.property_id = p_property_id;
END;
$$;

-- Create function to get contact details with properties
CREATE OR REPLACE FUNCTION get_contact_details(p_contact_id uuid)
RETURNS TABLE (
  id uuid,
  first_name text,
  last_name text,
  business_name text,
  email text,
  phone_numbers jsonb,
  properties jsonb,
  notes text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.first_name,
    c.last_name,
    c.business_name,
    c.email,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'number', pn.number,
          'type', pn.type,
          'is_primary', pn.is_primary
        ) ORDER BY pn.is_primary DESC, pn.created_at ASC
      ) FILTER (WHERE pn.id IS NOT NULL),
      '[]'::jsonb
    ) as phone_numbers,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'address', p.address,
          'city', p.city,
          'state', p.state,
          'zip', p.zip,
          'relationship_type', pcr.relationship_type
        ) ORDER BY pcr.created_at ASC
      ) FILTER (WHERE p.id IS NOT NULL),
      '[]'::jsonb
    ) as properties,
    c.notes,
    c.created_at,
    c.updated_at
  FROM contacts c
  LEFT JOIN phone_numbers pn ON pn.owner_id = c.id
  LEFT JOIN property_contact_relations pcr ON pcr.contact_id = c.id
  LEFT JOIN properties p ON p.id = pcr.property_id
  WHERE c.id = p_contact_id
  GROUP BY c.id;
END;
$$;

-- Create function to get property details with contacts
CREATE OR REPLACE FUNCTION get_property_details(p_property_id uuid)
RETURNS TABLE (
  id uuid,
  address text,
  city text,
  state text,
  zip text,
  units integer,
  mailing_address text,
  estimated_value numeric,
  lead_status text,
  contacts jsonb,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.address,
    p.city,
    p.state,
    p.zip,
    p.units,
    p.mailing_address,
    p.estimated_value,
    p.lead_status,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'first_name', c.first_name,
          'last_name', c.last_name,
          'business_name', c.business_name,
          'email', c.email,
          'relationship_type', pcr.relationship_type
        ) ORDER BY pcr.created_at ASC
      ) FILTER (WHERE c.id IS NOT NULL),
      '[]'::jsonb
    ) as contacts,
    p.created_at,
    p.updated_at
  FROM properties p
  LEFT JOIN property_contact_relations pcr ON pcr.property_id = p.id
  LEFT JOIN contacts c ON c.id = pcr.contact_id
  WHERE p.id = p_property_id
  GROUP BY p.id;
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
    contact_id := gen_random_uuid(); -- Generate UUID first
    
    INSERT INTO contacts (
      id,
      workspace_id,
      first_name,
      last_name,
      business_name,
      email
    )
    VALUES (
      contact_id,
      p_workspace_id,
      p_first_name,
      p_last_name,
      p_business_name,
      p_email
    );
  END IF;

  RETURN contact_id;
END;
$$;

-- Update RLS policies
DROP POLICY IF EXISTS "Users can view property contact relations" ON property_contact_relations;
DROP POLICY IF EXISTS "Users can manage property contact relations" ON property_contact_relations;

CREATE POLICY "Users can view property contact relations"
  ON property_contact_relations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM workspace_users wu
      JOIN properties p ON p.workspace_id = wu.workspace_id
      WHERE wu.user_id = auth.uid()
      AND p.id = property_contact_relations.property_id
    )
  );

CREATE POLICY "Users can manage property contact relations"
  ON property_contact_relations FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM workspace_users wu
      JOIN properties p ON p.workspace_id = wu.workspace_id
      WHERE wu.user_id = auth.uid()
      AND p.id = property_contact_relations.property_id
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM workspace_users wu
      JOIN properties p ON p.workspace_id = wu.workspace_id
      WHERE wu.user_id = auth.uid()
      AND p.id = property_contact_relations.property_id
    )
  );
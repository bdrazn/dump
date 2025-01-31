-- Add NOT NULL constraint to hash columns
ALTER TABLE contacts
ALTER COLUMN hash SET NOT NULL;

ALTER TABLE properties 
ALTER COLUMN hash SET NOT NULL;

-- Create unique indexes for hash columns
DROP INDEX IF EXISTS idx_contacts_hash;
DROP INDEX IF EXISTS idx_properties_hash;

CREATE UNIQUE INDEX idx_contacts_workspace_hash ON contacts(workspace_id, hash);
CREATE UNIQUE INDEX idx_properties_workspace_hash ON properties(workspace_id, hash);

-- Create function to handle contact lookup/creation with hash
CREATE OR REPLACE FUNCTION get_or_create_contact_by_hash(
  p_workspace_id uuid,
  p_first_name text,
  p_last_name text,
  p_business_name text,
  p_email text,
  p_hash text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  contact_id uuid;
BEGIN
  -- Try to find existing contact by hash
  SELECT id INTO contact_id
  FROM contacts
  WHERE workspace_id = p_workspace_id
    AND hash = p_hash;

  -- Create new contact if not found
  IF contact_id IS NULL THEN
    INSERT INTO contacts (
      workspace_id,
      first_name,
      last_name,
      business_name,
      email,
      hash
    )
    VALUES (
      p_workspace_id,
      p_first_name,
      p_last_name,
      p_business_name,
      p_email,
      p_hash
    )
    RETURNING id INTO contact_id;
  END IF;

  RETURN contact_id;
END;
$$;

-- Create function to handle property lookup/creation with hash
CREATE OR REPLACE FUNCTION get_or_create_property_by_hash(
  p_workspace_id uuid,
  p_address text,
  p_city text,
  p_state text,
  p_zip text,
  p_mailing_address text,
  p_hash text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  property_id uuid;
BEGIN
  -- Try to find existing property by hash
  SELECT id INTO property_id
  FROM properties
  WHERE workspace_id = p_workspace_id
    AND hash = p_hash;

  -- Create new property if not found
  IF property_id IS NULL THEN
    INSERT INTO properties (
      workspace_id,
      address,
      city,
      state,
      zip,
      mailing_address,
      units,
      hash
    )
    VALUES (
      p_workspace_id,
      p_address,
      p_city,
      p_state,
      p_zip,
      p_mailing_address,
      1,
      p_hash
    )
    RETURNING id INTO property_id;
  END IF;

  RETURN property_id;
END;
$$;
/*
  # Update contact property relationship function
  
  1. Changes
    - Update function to use contacts table instead of profiles
    - Add better error handling and validation
  
  2. Security
    - Maintain workspace-based security checks
*/

-- Drop and recreate the function with updated table references
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
    FROM contacts c
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
    relationship_type = EXCLUDED.relationship_type,
    updated_at = now();
END;
$$;
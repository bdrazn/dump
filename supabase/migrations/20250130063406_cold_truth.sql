-- Drop the function first
DROP FUNCTION IF EXISTS get_property_details(uuid);

-- Recreate the function with updated schema
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
  tags jsonb,
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
          'id', t.id,
          'name', t.name,
          'description', t.description
        ) ORDER BY t.name ASC
      ) FILTER (WHERE t.id IS NOT NULL),
      '[]'::jsonb
    ) as tags,
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
  LEFT JOIN property_tags pt ON pt.property_id = p.id
  LEFT JOIN tags t ON t.id = pt.tag_id
  LEFT JOIN property_contact_relations pcr ON pcr.property_id = p.id
  LEFT JOIN contacts c ON c.id = pcr.contact_id
  WHERE p.id = p_property_id
  GROUP BY p.id;
END;
$$;
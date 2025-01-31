-- Create a function to search contacts by name, phone, or email
CREATE OR REPLACE FUNCTION search_contacts(
  p_workspace_id uuid,
  p_query text
)
RETURNS TABLE (
  id uuid,
  first_name text,
  last_name text,
  business_name text,
  email text,
  phone_numbers jsonb,
  properties jsonb,
  relevance float
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH contact_data AS (
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
            'state', p.state
          ) ORDER BY p.address ASC
        ) FILTER (WHERE p.id IS NOT NULL),
        '[]'::jsonb
      ) as properties,
      -- Calculate relevance score based on various matches
      GREATEST(
        -- Exact name match
        CASE WHEN c.first_name || ' ' || c.last_name ILIKE p_query THEN 1.0
        -- Partial name match
        WHEN c.first_name || ' ' || c.last_name ILIKE '%' || p_query || '%' THEN 0.8
        -- Business name match
        WHEN c.business_name ILIKE '%' || p_query || '%' THEN 0.7
        -- Email match
        WHEN c.email ILIKE '%' || p_query || '%' THEN 0.6
        ELSE 0.0 END,
        -- Phone number match (if query looks like a phone number)
        CASE WHEN p_query ~ '^\+?[\d\s-\(\)]+$' AND 
          EXISTS (
            SELECT 1 FROM phone_numbers pn 
            WHERE pn.owner_id = c.id 
            AND pn.number LIKE '%' || regexp_replace(p_query, '[^\d]', '', 'g') || '%'
          ) THEN 0.9
        ELSE 0.0 END
      ) as relevance
    FROM contacts c
    LEFT JOIN phone_numbers pn ON pn.owner_id = c.id
    LEFT JOIN property_contact_relations pcr ON pcr.contact_id = c.id
    LEFT JOIN properties p ON p.id = pcr.property_id
    WHERE c.workspace_id = p_workspace_id
    GROUP BY c.id
  )
  SELECT 
    cd.id,
    cd.first_name,
    cd.last_name,
    cd.business_name,
    cd.email,
    cd.phone_numbers,
    cd.properties,
    cd.relevance
  FROM contact_data cd
  WHERE cd.relevance > 0
  ORDER BY cd.relevance DESC, cd.last_name, cd.first_name;
END;
$$;

-- Create a function to search properties by address or contact info
CREATE OR REPLACE FUNCTION search_properties(
  p_workspace_id uuid,
  p_query text
)
RETURNS TABLE (
  id uuid,
  address text,
  city text,
  state text,
  zip text,
  units integer,
  lead_status text,
  contacts jsonb,
  relevance float
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH property_data AS (
    SELECT 
      p.id,
      p.address,
      p.city,
      p.state,
      p.zip,
      p.units,
      p.lead_status,
      COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', c.id,
            'first_name', c.first_name,
            'last_name', c.last_name,
            'business_name', c.business_name,
            'email', c.email,
            'phone_numbers', (
              SELECT jsonb_agg(
                jsonb_build_object(
                  'number', pn.number,
                  'type', pn.type,
                  'is_primary', pn.is_primary
                )
              )
              FROM phone_numbers pn
              WHERE pn.owner_id = c.id
            ),
            'relationship_type', pcr.relationship_type
          ) ORDER BY c.last_name, c.first_name
        ) FILTER (WHERE c.id IS NOT NULL),
        '[]'::jsonb
      ) as contacts,
      -- Calculate relevance score based on various matches
      GREATEST(
        -- Exact address match
        CASE WHEN p.address ILIKE p_query THEN 1.0
        -- Partial address match
        WHEN p.address ILIKE '%' || p_query || '%' THEN 0.8
        -- City/State match
        WHEN p.city ILIKE p_query OR p.state ILIKE p_query THEN 0.7
        -- ZIP match
        WHEN p.zip LIKE p_query || '%' THEN 0.6
        ELSE 0.0 END,
        -- Contact name match
        CASE WHEN EXISTS (
          SELECT 1 FROM contacts c
          JOIN property_contact_relations pcr ON pcr.contact_id = c.id
          WHERE pcr.property_id = p.id
          AND (
            c.first_name || ' ' || c.last_name ILIKE '%' || p_query || '%'
            OR c.business_name ILIKE '%' || p_query || '%'
          )
        ) THEN 0.5
        ELSE 0.0 END
      ) as relevance
    FROM properties p
    LEFT JOIN property_contact_relations pcr ON pcr.property_id = p.id
    LEFT JOIN contacts c ON c.id = pcr.contact_id
    LEFT JOIN phone_numbers pn ON pn.owner_id = c.id
    WHERE p.workspace_id = p_workspace_id
    GROUP BY p.id
  )
  SELECT 
    pd.id,
    pd.address,
    pd.city,
    pd.state,
    pd.zip,
    pd.units,
    pd.lead_status,
    pd.contacts,
    pd.relevance
  FROM property_data pd
  WHERE pd.relevance > 0
  ORDER BY pd.relevance DESC, pd.address;
END;
$$;
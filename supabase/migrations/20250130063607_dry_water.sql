-- Create function to search contacts by name, phone, or email
CREATE OR REPLACE FUNCTION search_contacts_by_query(
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
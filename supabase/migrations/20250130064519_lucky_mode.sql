-- Drop the existing function
DROP FUNCTION IF EXISTS search_contacts_by_query(uuid, text);

-- Recreate the function with correct numeric types
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
  relevance numeric
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
        CASE WHEN c.first_name || ' ' || c.last_name ILIKE p_query THEN 1.0::numeric
        -- Partial name match
        WHEN c.first_name || ' ' || c.last_name ILIKE '%' || p_query || '%' THEN 0.8::numeric
        -- Business name match
        WHEN c.business_name ILIKE '%' || p_query || '%' THEN 0.7::numeric
        -- Email match
        WHEN c.email ILIKE '%' || p_query || '%' THEN 0.6::numeric
        ELSE 0.0::numeric END,
        -- Phone number match (if query looks like a phone number)
        CASE WHEN p_query ~ '^[0-9\+\-\(\)\s]+$' AND 
          EXISTS (
            SELECT 1 FROM phone_numbers pn 
            WHERE pn.owner_id = c.id 
            AND regexp_replace(pn.number, '[^0-9]', '', 'g') LIKE '%' || regexp_replace(p_query, '[^0-9]', '', 'g') || '%'
          ) THEN 0.9::numeric
        ELSE 0.0::numeric END
      )::numeric as relevance
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
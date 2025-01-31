-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view property lists" ON property_lists;
DROP POLICY IF EXISTS "Users can manage property lists" ON property_lists;
DROP POLICY IF EXISTS "Users can view property list items" ON property_list_items;
DROP POLICY IF EXISTS "Users can manage property list items" ON property_list_items;

-- Create RLS policies for property_lists table
CREATE POLICY "Users can view property lists"
  ON property_lists FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage property lists"
  ON property_lists FOR ALL
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

-- Create RLS policies for property_list_items table
CREATE POLICY "Users can view property list items"
  ON property_list_items FOR SELECT
  USING (
    list_id IN (
      SELECT id FROM property_lists
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can manage property list items"
  ON property_list_items FOR ALL
  USING (
    list_id IN (
      SELECT id FROM property_lists
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    list_id IN (
      SELECT id FROM property_lists
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );

-- Create function to get list details with property count
CREATE OR REPLACE FUNCTION get_list_details(p_list_id uuid)
RETURNS TABLE (
  id uuid,
  name text,
  description text,
  property_count bigint,
  properties jsonb,
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
    pl.id,
    pl.name,
    pl.description,
    COUNT(pli.property_id)::bigint as property_count,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'address', p.address,
          'city', p.city,
          'state', p.state,
          'zip', p.zip,
          'lead_status', p.lead_status
        ) ORDER BY p.address ASC
      ) FILTER (WHERE p.id IS NOT NULL),
      '[]'::jsonb
    ) as properties,
    pl.created_at,
    pl.updated_at
  FROM property_lists pl
  LEFT JOIN property_list_items pli ON pli.list_id = pl.id
  LEFT JOIN properties p ON p.id = pli.property_id
  WHERE pl.id = p_list_id
  GROUP BY pl.id;
END;
$$;
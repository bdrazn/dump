-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view property tags" ON property_tags;
DROP POLICY IF EXISTS "Users can manage property tags" ON property_tags;

-- Create RLS policies for property_tags table
CREATE POLICY "Users can view property tags"
  ON property_tags FOR SELECT
  USING (
    property_id IN (
      SELECT id FROM properties
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can manage property tags"
  ON property_tags FOR ALL
  USING (
    property_id IN (
      SELECT id FROM properties
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    property_id IN (
      SELECT id FROM properties
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );

-- Create function to add tags to properties
CREATE OR REPLACE FUNCTION add_tags_to_properties(
  p_property_ids uuid[],
  p_tag_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify user has access to all properties
  IF NOT EXISTS (
    SELECT 1 FROM properties p
    WHERE p.id = ANY(p_property_ids)
    AND p.workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  ) THEN
    RAISE EXCEPTION 'Access denied to one or more properties';
  END IF;

  -- Add tags
  INSERT INTO property_tags (property_id, tag_id)
  SELECT unnest(p_property_ids), p_tag_id
  ON CONFLICT (property_id, tag_id) DO NOTHING;
END;
$$;
-- Drop existing policies
DROP POLICY IF EXISTS "Users can view property tags" ON property_tags;
DROP POLICY IF EXISTS "Users can manage property tags" ON property_tags;

-- Create RLS policies for property_tags table
CREATE POLICY "Users can view property tags"
  ON property_tags FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM properties p
      JOIN workspace_users wu ON wu.workspace_id = p.workspace_id
      WHERE wu.user_id = auth.uid()
      AND p.id = property_tags.property_id
    )
  );

CREATE POLICY "Users can manage property tags"
  ON property_tags FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM properties p
      JOIN workspace_users wu ON wu.workspace_id = p.workspace_id
      WHERE wu.user_id = auth.uid()
      AND p.id = property_tags.property_id
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM properties p
      JOIN workspace_users wu ON wu.workspace_id = p.workspace_id
      WHERE wu.user_id = auth.uid()
      AND p.id = property_tags.property_id
    )
  );

-- Create function to add tags to properties
CREATE OR REPLACE FUNCTION add_tag_to_properties(
  p_property_ids uuid[],
  p_tag_name text,
  p_workspace_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tag_id uuid;
BEGIN
  -- Get or create tag
  INSERT INTO tags (name, workspace_id)
  VALUES (p_tag_name, p_workspace_id)
  ON CONFLICT (workspace_id, name) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO v_tag_id;

  -- Add tag to properties
  INSERT INTO property_tags (property_id, tag_id)
  SELECT unnest(p_property_ids), v_tag_id
  ON CONFLICT (property_id, tag_id) DO NOTHING;
END;
$$;
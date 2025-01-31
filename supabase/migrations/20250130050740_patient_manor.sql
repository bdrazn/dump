-- Drop and recreate property_contact_relations table with correct foreign key
DROP TABLE IF EXISTS property_contact_relations CASCADE;

CREATE TABLE property_contact_relations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid REFERENCES contacts(id) ON DELETE CASCADE,
  property_id uuid REFERENCES properties(id) ON DELETE CASCADE,
  relationship_type text NOT NULL CHECK (relationship_type IN ('owner', 'tenant', 'agent', 'other')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(contact_id, property_id)
);

-- Enable RLS
ALTER TABLE property_contact_relations ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_property_contact_relations_contact ON property_contact_relations(contact_id);
CREATE INDEX idx_property_contact_relations_property ON property_contact_relations(property_id);

-- Create policies
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

-- Create trigger for updated_at
CREATE TRIGGER update_property_contact_relations_updated_at
  BEFORE UPDATE ON property_contact_relations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
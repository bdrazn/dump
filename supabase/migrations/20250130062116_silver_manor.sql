-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view tags" ON tags;
DROP POLICY IF EXISTS "Users can manage tags" ON tags;

-- Create RLS policies for tags table
CREATE POLICY "Users can view tags"
  ON tags FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage tags"
  ON tags FOR ALL
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

-- Add hash column to contacts and properties for deduplication
ALTER TABLE contacts
ADD COLUMN hash text;

ALTER TABLE properties
ADD COLUMN hash text;

-- Create indexes for hash columns
CREATE INDEX idx_contacts_hash ON contacts(hash);
CREATE INDEX idx_properties_hash ON properties(hash);
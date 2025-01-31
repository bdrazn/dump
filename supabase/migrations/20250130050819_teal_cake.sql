-- Drop and recreate phone_numbers table with correct foreign key
DROP TABLE IF EXISTS phone_numbers CASCADE;

CREATE TABLE phone_numbers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid REFERENCES contacts(id) ON DELETE CASCADE,
  number text NOT NULL,
  type text CHECK (type IN ('mobile', 'home', 'work', 'other')) DEFAULT 'mobile',
  is_primary boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE phone_numbers ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_phone_numbers_owner ON phone_numbers(owner_id);
CREATE INDEX idx_phone_numbers_number ON phone_numbers(number);

-- Create policies
CREATE POLICY "Users can view phone numbers"
  ON phone_numbers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM workspace_users wu
      JOIN contacts c ON c.workspace_id = wu.workspace_id
      WHERE wu.user_id = auth.uid()
      AND c.id = phone_numbers.owner_id
    )
  );

CREATE POLICY "Users can manage phone numbers"
  ON phone_numbers FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM workspace_users wu
      JOIN contacts c ON c.workspace_id = wu.workspace_id
      WHERE wu.user_id = auth.uid()
      AND c.id = phone_numbers.owner_id
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM workspace_users wu
      JOIN contacts c ON c.workspace_id = wu.workspace_id
      WHERE wu.user_id = auth.uid()
      AND c.id = phone_numbers.owner_id
    )
  );

-- Create trigger for updated_at
CREATE TRIGGER update_phone_numbers_updated_at
  BEFORE UPDATE ON phone_numbers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
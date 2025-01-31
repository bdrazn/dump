/*
  # Fix phone numbers and relationships

  1. Changes
    - Create phone_numbers table for better phone number management
    - Update contact-property relationships
    - Fix foreign key references
  
  2. Security
    - Enable RLS on new tables
    - Add appropriate policies
*/

-- Create phone_numbers table
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

-- Migrate existing phone numbers
DO $$
DECLARE
  contact_record RECORD;
  phone_number text;
BEGIN
  FOR contact_record IN SELECT * FROM contacts LOOP
    -- Phone 1
    IF contact_record.phone1 IS NOT NULL AND contact_record.phone1 != '' THEN
      INSERT INTO phone_numbers (owner_id, number, type, is_primary)
      VALUES (contact_record.id, contact_record.phone1, 'mobile', true);
    END IF;
    
    -- Phone 2
    IF contact_record.phone2 IS NOT NULL AND contact_record.phone2 != '' THEN
      INSERT INTO phone_numbers (owner_id, number, type)
      VALUES (contact_record.id, contact_record.phone2, 'mobile');
    END IF;
    
    -- Phone 3
    IF contact_record.phone3 IS NOT NULL AND contact_record.phone3 != '' THEN
      INSERT INTO phone_numbers (owner_id, number, type)
      VALUES (contact_record.id, contact_record.phone3, 'mobile');
    END IF;
    
    -- Phone 4
    IF contact_record.phone4 IS NOT NULL AND contact_record.phone4 != '' THEN
      INSERT INTO phone_numbers (owner_id, number, type)
      VALUES (contact_record.id, contact_record.phone4, 'mobile');
    END IF;
    
    -- Phone 5
    IF contact_record.phone5 IS NOT NULL AND contact_record.phone5 != '' THEN
      INSERT INTO phone_numbers (owner_id, number, type)
      VALUES (contact_record.id, contact_record.phone5, 'mobile');
    END IF;
  END LOOP;
END $$;

-- Drop old phone number columns
ALTER TABLE contacts
  DROP COLUMN phone1,
  DROP COLUMN phone2,
  DROP COLUMN phone3,
  DROP COLUMN phone4,
  DROP COLUMN phone5;

-- Update functions to use new phone numbers table
CREATE OR REPLACE FUNCTION resolve_merge_fields(
  template_content text,
  contact_id uuid,
  property_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result text := template_content;
  contact_record RECORD;
  property_record RECORD;
  primary_phone text;
BEGIN
  -- Get contact details
  SELECT * INTO contact_record
  FROM contacts
  WHERE id = contact_id;

  -- Get primary phone
  SELECT number INTO primary_phone
  FROM phone_numbers
  WHERE owner_id = contact_id
  AND is_primary = true
  LIMIT 1;

  -- Get property details
  SELECT * INTO property_record
  FROM properties
  WHERE id = property_id;

  -- Replace contact fields
  IF contact_record IS NOT NULL THEN
    result := REPLACE(result, '{{contact_name}}',
      COALESCE(contact_record.business_name,
        contact_record.first_name || ' ' || contact_record.last_name));
    result := REPLACE(result, '{{contact_email}}', contact_record.email);
    result := REPLACE(result, '{{contact_phone}}', COALESCE(primary_phone, ''));
  END IF;

  -- Replace property fields
  IF property_record IS NOT NULL THEN
    result := REPLACE(result, '{{property_address}}', property_record.address);
    result := REPLACE(result, '{{property_city}}', property_record.city);
    result := REPLACE(result, '{{property_state}}', property_record.state);
    result := REPLACE(result, '{{property_zip}}', property_record.zip);
  END IF;

  RETURN result;
END;
$$;

-- Create trigger for updated_at
CREATE TRIGGER update_phone_numbers_updated_at
  BEFORE UPDATE ON phone_numbers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
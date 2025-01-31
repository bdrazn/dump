/*
  # Fix contacts table structure
  
  1. Changes
    - Remove foreign key constraint to auth.users
    - Make contacts independent entities
    - Update triggers and functions to handle new structure
  
  2. Security
    - Maintain RLS policies for workspace-based access
    - Add policies for contact management
*/

-- Drop existing triggers that reference auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop and recreate contacts table without auth.users foreign key
DROP TABLE IF EXISTS contacts CASCADE;
CREATE TABLE contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  first_name text NOT NULL,
  last_name text NOT NULL,
  business_name text,
  email text NOT NULL,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_contacts_workspace ON contacts(workspace_id);
CREATE INDEX idx_contacts_email ON contacts(email);
CREATE INDEX idx_contacts_names ON contacts(first_name, last_name);

-- Create policies
CREATE POLICY "Users can view contacts"
  ON contacts FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage contacts"
  ON contacts FOR ALL
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

-- Update handle_new_user function to create a contact for the user
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  workspace_id uuid;
  contact_id uuid;
BEGIN
  -- Create default workspace
  INSERT INTO workspaces (name, created_by)
  VALUES (
    COALESCE(NEW.raw_user_meta_data->>'company_name', 'My Workspace'),
    NEW.id
  )
  RETURNING id INTO workspace_id;

  -- Add user to workspace
  INSERT INTO workspace_users (workspace_id, user_id, role)
  VALUES (workspace_id, NEW.id, 'owner');

  -- Create contact for user
  INSERT INTO contacts (
    workspace_id,
    first_name,
    last_name,
    email
  )
  VALUES (
    workspace_id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    '',
    NEW.email
  )
  RETURNING id INTO contact_id;

  -- Create user settings
  INSERT INTO user_settings (user_id)
  VALUES (NEW.id);

  RETURN NEW;
END;
$$;

-- Create trigger for updated_at
CREATE TRIGGER update_contacts_updated_at
  BEFORE UPDATE ON contacts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Recreate auth trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
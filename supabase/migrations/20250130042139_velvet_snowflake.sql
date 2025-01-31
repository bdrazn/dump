/*
  # Add Workspace Creation Trigger
  
  1. Functions
    - handle_new_user: Creates default workspace for new users
    - handle_auth_user_created: Trigger function for auth.users
  
  2. Triggers
    - on_auth_user_created: Trigger on auth.users table
*/

-- Create function to handle new user setup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  workspace_id uuid;
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

  -- Create user profile
  INSERT INTO profiles (
    id,
    workspace_id,
    first_name,
    last_name,
    email
  )
  VALUES (
    NEW.id,
    workspace_id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    '',
    NEW.email
  );

  -- Create user settings
  INSERT INTO user_settings (user_id)
  VALUES (NEW.id);

  RETURN NEW;
END;
$$;

-- Create trigger on auth.users
CREATE OR REPLACE FUNCTION public.handle_auth_user_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, workspace_id, first_name, last_name, email)
  VALUES (
    NEW.id,
    (SELECT workspace_id FROM workspace_users WHERE user_id = NEW.id LIMIT 1),
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    '',
    NEW.email
  );
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
-- Add admin role to auth schema
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND email = 'beewax99@gmail.com'
  );
$$;

-- Create admin policies for user_settings
DROP POLICY IF EXISTS "Admin can view all user settings" ON user_settings;
DROP POLICY IF EXISTS "Admin can manage all user settings" ON user_settings;

CREATE POLICY "Admin can view all user settings"
  ON user_settings FOR SELECT
  USING (
    is_admin()
  );

CREATE POLICY "Admin can manage all user settings"
  ON user_settings FOR ALL
  USING (
    is_admin()
  )
  WITH CHECK (
    is_admin()
  );

-- Create admin policies for auth.users access
CREATE POLICY "Admin can view auth users"
  ON auth.users FOR SELECT
  USING (
    is_admin()
  );

-- Create admin policies for workspaces
DROP POLICY IF EXISTS "Admin can view all workspaces" ON workspaces;
DROP POLICY IF EXISTS "Admin can manage all workspaces" ON workspaces;

CREATE POLICY "Admin can view all workspaces"
  ON workspaces FOR SELECT
  USING (
    is_admin()
  );

CREATE POLICY "Admin can manage all workspaces"
  ON workspaces FOR ALL
  USING (
    is_admin()
  )
  WITH CHECK (
    is_admin()
  );
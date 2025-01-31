-- Create admin function if it doesn't exist
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

-- Grant necessary permissions
GRANT USAGE ON SCHEMA auth TO postgres, authenticated, anon;
GRANT SELECT ON auth.users TO postgres, authenticated, anon;

-- Create admin policies for auth.users access
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'users' 
    AND schemaname = 'auth' 
    AND policyname = 'Admin can view all users'
  ) THEN
    CREATE POLICY "Admin can view all users"
      ON auth.users
      FOR SELECT
      USING (
        (SELECT is_admin())
      );
  END IF;
END $$;
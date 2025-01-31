-- Create admin policies for auth.users access
CREATE POLICY "Admin can view all users"
  ON auth.users FOR ALL
  USING (
    is_admin()
  );

-- Grant necessary permissions
GRANT SELECT ON auth.users TO postgres;
GRANT SELECT ON auth.users TO authenticated;
GRANT SELECT ON auth.users TO anon;
-- Create trigger function to create user settings
CREATE OR REPLACE FUNCTION create_user_settings()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO user_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Create trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created_settings ON auth.users;
CREATE TRIGGER on_auth_user_created_settings
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_settings();

-- Insert settings for existing users
INSERT INTO user_settings (user_id)
SELECT id FROM auth.users
WHERE NOT EXISTS (
  SELECT 1 FROM user_settings WHERE user_id = auth.users.id
);
/*
  # Add timezone support for messaging hours

  1. Changes
    - Add timezone column to user_settings table
    - Update isWithinMessageWindow function to use timezone
    - Add default timezone (UTC)

  2. Security
    - Maintain existing RLS policies
*/

-- Add timezone column to user_settings
ALTER TABLE user_settings
ADD COLUMN timezone text DEFAULT 'UTC';

-- Create function to check if current time is within message window
CREATE OR REPLACE FUNCTION is_within_message_window(
  p_window_start time,
  p_window_end time,
  p_timezone text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_time_in_zone time;
BEGIN
  -- Get current time in user's timezone
  SELECT CAST(NOW() AT TIME ZONE COALESCE(p_timezone, 'UTC') AS time)
  INTO current_time_in_zone;

  -- Handle cases where window crosses midnight
  IF p_window_start <= p_window_end THEN
    RETURN current_time_in_zone BETWEEN p_window_start AND p_window_end;
  ELSE
    RETURN current_time_in_zone >= p_window_start OR current_time_in_zone <= p_window_end;
  END IF;
END;
$$;
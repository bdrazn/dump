/*
  # Add Stripe Settings Table
  
  1. New Tables
    - `stripe_settings` - Stores Stripe configuration for the workspace
      - `id` (uuid, primary key)
      - `workspace_id` (uuid, foreign key)
      - `public_key` (text)
      - `secret_key` (text)
      - `webhook_secret` (text)
      - `pro_price_id` (text)
      - `business_price_id` (text)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
  
  2. Security
    - Enable RLS
    - Add policies for admin access
*/

-- Create stripe_settings table
CREATE TABLE stripe_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  public_key text,
  secret_key text,
  webhook_secret text,
  pro_price_id text,
  business_price_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(workspace_id)
);

-- Enable RLS
ALTER TABLE stripe_settings ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_stripe_settings_workspace ON stripe_settings(workspace_id);

-- Create policies
CREATE POLICY "Admin can manage stripe settings"
  ON stripe_settings FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE id = auth.uid()
      AND email = 'beewax99@gmail.com'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE id = auth.uid()
      AND email = 'beewax99@gmail.com'
    )
  );

-- Create trigger for updated_at
CREATE TRIGGER update_stripe_settings_updated_at
  BEFORE UPDATE ON stripe_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
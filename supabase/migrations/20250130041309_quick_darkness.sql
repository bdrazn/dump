/*
  # Initial Database Schema for Real Estate CRM
  
  1. Core Tables
    - workspaces
    - workspace_users
    - profiles
    - user_settings
  
  2. Property Management
    - properties
    - property_status_history
    - property_tags
    - tags
    - property_lists
    - property_list_items
  
  3. Contact Management
    - property_contacts
    - phone_numbers
    - property_contact_relations
  
  4. Messaging System
    - message_threads
    - messages
    - message_templates
    - message_wheels
    - message_analytics
  
  5. Activity Tracking
    - activity_logs
*/

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create workspaces table
CREATE TABLE workspaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create workspace_users table
CREATE TABLE workspace_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(workspace_id, user_id)
);

-- Create profiles table
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  first_name text NOT NULL,
  last_name text NOT NULL,
  business_name text,
  email text NOT NULL,
  phone1 text,
  phone2 text,
  phone3 text,
  phone4 text,
  phone5 text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create user_settings table
CREATE TABLE user_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  daily_message_limit integer DEFAULT 100,
  message_window_start time DEFAULT '08:00',
  message_window_end time DEFAULT '20:00',
  phone_number_1 text,
  phone_number_2 text,
  phone_number_3 text,
  phone_number_4 text,
  phone_number_selection text CHECK (phone_number_selection IN ('sequential', 'random')) DEFAULT 'sequential',
  message_wheel_mode text CHECK (message_wheel_mode IN ('sequential', 'random')) DEFAULT 'sequential',
  message_wheel_delay integer DEFAULT 60,
  openai_api_key text,
  deepseek_api_key text,
  active_ai text CHECK (active_ai IN ('openai', 'deepseek')) DEFAULT 'deepseek',
  smrtphone_api_key text,
  smrtphone_webhook_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- Create properties table
CREATE TABLE properties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  address text NOT NULL,
  city text NOT NULL,
  state text NOT NULL,
  zip text NOT NULL,
  units integer DEFAULT 1,
  mailing_address text,
  estimated_value numeric(12,2),
  lead_status text CHECK (lead_status IN ('interested', 'not_interested', 'dnc')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create property_status_history table
CREATE TABLE property_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid REFERENCES properties(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('interested', 'not_interested', 'dnc')),
  changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  source text NOT NULL CHECK (source IN ('user', 'ai')),
  confidence numeric(4,3) CHECK (confidence >= 0 AND confidence <= 1),
  reasoning text,
  created_at timestamptz DEFAULT now()
);

-- Create tags table
CREATE TABLE tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(workspace_id, name)
);

-- Create property_tags table
CREATE TABLE property_tags (
  property_id uuid REFERENCES properties(id) ON DELETE CASCADE,
  tag_id uuid REFERENCES tags(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (property_id, tag_id)
);

-- Create property_lists table
CREATE TABLE property_lists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create property_list_items table
CREATE TABLE property_list_items (
  list_id uuid REFERENCES property_lists(id) ON DELETE CASCADE,
  property_id uuid REFERENCES properties(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (list_id, property_id)
);

-- Create message_threads table
CREATE TABLE message_threads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  contact_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  property_id uuid REFERENCES properties(id) ON DELETE SET NULL,
  status text CHECK (status IN ('interested', 'not_interested', 'dnc')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create messages table
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid REFERENCES message_threads(id) ON DELETE CASCADE,
  sender_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  content text NOT NULL,
  from_number text,
  to_number text,
  status text CHECK (status IN ('sent', 'delivered', 'failed', 'spam')),
  direction text CHECK (direction IN ('inbound', 'outbound')),
  ai_analysis jsonb,
  read_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Create message_templates table
CREATE TABLE message_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  messages jsonb NOT NULL DEFAULT '[]',
  delivery_strategy text CHECK (delivery_strategy IN ('sequential', 'random')) DEFAULT 'sequential',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create message_wheels table
CREATE TABLE message_wheels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  messages jsonb NOT NULL DEFAULT '[]',
  active_count integer DEFAULT 1,
  mode text CHECK (mode IN ('sequential', 'random')) DEFAULT 'sequential',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create message_analytics table
CREATE TABLE message_analytics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  date date NOT NULL,
  messages_sent integer DEFAULT 0,
  messages_delivered integer DEFAULT 0,
  responses_received integer DEFAULT 0,
  interested_count integer DEFAULT 0,
  not_interested_count integer DEFAULT 0,
  dnc_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(workspace_id, date)
);

-- Create activity_logs table
CREATE TABLE activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  action text NOT NULL,
  status text CHECK (status IN ('success', 'error', 'warning', 'info')),
  message text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_wheels ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies
CREATE POLICY "Users can view their workspaces"
  ON workspaces FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM workspace_users wu
    WHERE wu.workspace_id = workspaces.id
    AND wu.user_id = auth.uid()
  ));

CREATE POLICY "Workspace members can view other members"
  ON workspace_users FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM workspace_users wu
    WHERE wu.workspace_id = workspace_users.workspace_id
    AND wu.user_id = auth.uid()
  ));

CREATE POLICY "Users can view profiles in their workspace"
  ON profiles FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM workspace_users wu
    WHERE wu.workspace_id = profiles.workspace_id
    AND wu.user_id = auth.uid()
  ));

CREATE POLICY "Users can manage their own settings"
  ON user_settings FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can view properties in their workspace"
  ON properties FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM workspace_users wu
    WHERE wu.workspace_id = properties.workspace_id
    AND wu.user_id = auth.uid()
  ));

-- Create indexes for performance
CREATE INDEX idx_workspace_users_user ON workspace_users(user_id);
CREATE INDEX idx_workspace_users_workspace ON workspace_users(workspace_id);
CREATE INDEX idx_properties_workspace ON properties(workspace_id);
CREATE INDEX idx_properties_status ON properties(lead_status);
CREATE INDEX idx_messages_thread ON messages(thread_id);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_created ON messages(created_at);
CREATE INDEX idx_threads_workspace ON message_threads(workspace_id);
CREATE INDEX idx_threads_contact ON message_threads(contact_id);
CREATE INDEX idx_threads_property ON message_threads(property_id);
CREATE INDEX idx_analytics_workspace_date ON message_analytics(workspace_id, date);
CREATE INDEX idx_activity_workspace ON activity_logs(workspace_id);
CREATE INDEX idx_activity_user ON activity_logs(user_id);
CREATE INDEX idx_activity_entity ON activity_logs(entity_type, entity_id);

-- Create helper functions
CREATE OR REPLACE FUNCTION get_user_workspace(user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT wu.workspace_id
    FROM workspace_users wu
    WHERE wu.user_id = get_user_workspace.user_id
    LIMIT 1
  );
END;
$$;

-- Create trigger functions
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER update_workspaces_updated_at
  BEFORE UPDATE ON workspaces
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_properties_updated_at
  BEFORE UPDATE ON properties
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_message_threads_updated_at
  BEFORE UPDATE ON message_threads
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_message_analytics_updated_at
  BEFORE UPDATE ON message_analytics
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
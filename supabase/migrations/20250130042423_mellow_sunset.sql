/*
  # Fix RLS Policies to Prevent Recursion
  
  1. Changes
    - Update workspace_users policy to use direct auth.uid() check
    - Add base policies for all tables
    - Fix circular references in policies
  
  2. Security
    - Maintain proper access control
    - Prevent infinite recursion
    - Enable proper data isolation
*/

-- Drop existing policies to recreate them
DROP POLICY IF EXISTS "Users can view their workspaces" ON workspaces;
DROP POLICY IF EXISTS "Workspace members can view other members" ON workspace_users;
DROP POLICY IF EXISTS "Users can view profiles in their workspace" ON profiles;

-- Create base policies that don't cause recursion
CREATE POLICY "Users can view their workspaces"
  ON workspaces FOR SELECT
  USING (
    id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view workspace memberships"
  ON workspace_users FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can view profiles"
  ON profiles FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

-- Add CRUD policies for workspace members
CREATE POLICY "Workspace members can insert properties"
  ON properties FOR INSERT
  WITH CHECK (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Workspace members can view properties"
  ON properties FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Workspace members can update properties"
  ON properties FOR UPDATE
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

CREATE POLICY "Workspace members can delete properties"
  ON properties FOR DELETE
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

-- Add policies for message threads
CREATE POLICY "Users can view message threads"
  ON message_threads FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

-- Add policies for messages
CREATE POLICY "Users can view messages"
  ON messages FOR SELECT
  USING (
    thread_id IN (
      SELECT id 
      FROM message_threads 
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );

-- Add policies for analytics
CREATE POLICY "Users can view analytics"
  ON message_analytics FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

-- Add policies for activity logs
CREATE POLICY "Users can view activity logs"
  ON activity_logs FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );
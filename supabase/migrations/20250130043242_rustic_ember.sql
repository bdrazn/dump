/*
  # Add Jobs and Activity Log Functions

  1. New Functions
    - get_jobs: Paginated function to retrieve jobs
    - get_tasks: Paginated function to retrieve tasks for a job
    - get_activity_logs: Paginated function to retrieve activity logs
  
  2. Changes
    - Add pagination support
    - Add proper workspace filtering
    - Add sorting and filtering options
*/

-- Create jobs table if it doesn't exist
CREATE TABLE IF NOT EXISTS jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE,
  name text NOT NULL,
  status text CHECK (status IN ('pending', 'running', 'paused', 'completed', 'failed')),
  total_tasks integer DEFAULT 0,
  completed_tasks integer DEFAULT 0,
  error_message text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create tasks table if it doesn't exist
CREATE TABLE IF NOT EXISTS tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid REFERENCES jobs(id) ON DELETE CASCADE,
  name text NOT NULL,
  status text CHECK (status IN ('pending', 'running', 'completed', 'failed')),
  error_message text,
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);

-- Enable RLS
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_jobs_workspace ON jobs(workspace_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_tasks_job ON tasks(job_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);

-- Create policies
CREATE POLICY "Users can view jobs"
  ON jobs FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view tasks"
  ON tasks FOR SELECT
  USING (
    job_id IN (
      SELECT id FROM jobs
      WHERE workspace_id IN (
        SELECT workspace_id 
        FROM workspace_users 
        WHERE user_id = auth.uid()
      )
    )
  );

-- Create function to get jobs with pagination
CREATE OR REPLACE FUNCTION get_jobs(
  p_workspace_id uuid,
  p_page integer,
  p_page_size integer
)
RETURNS TABLE (
  id uuid,
  name text,
  status text,
  total_tasks integer,
  completed_tasks integer,
  error_message text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz,
  total_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH job_count AS (
    SELECT count(*)::bigint as total
    FROM jobs
    WHERE workspace_id = p_workspace_id
  )
  SELECT 
    j.id,
    j.name,
    j.status,
    j.total_tasks,
    j.completed_tasks,
    j.error_message,
    j.started_at,
    j.completed_at,
    j.created_at,
    c.total
  FROM jobs j
  CROSS JOIN job_count c
  WHERE j.workspace_id = p_workspace_id
  ORDER BY j.created_at DESC
  LIMIT p_page_size
  OFFSET (p_page - 1) * p_page_size;
END;
$$;

-- Create function to get tasks with pagination
CREATE OR REPLACE FUNCTION get_tasks(
  p_job_id uuid,
  p_page integer,
  p_page_size integer
)
RETURNS TABLE (
  id uuid,
  name text,
  status text,
  error_message text,
  created_at timestamptz,
  completed_at timestamptz,
  total_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH task_count AS (
    SELECT count(*)::bigint as total
    FROM tasks
    WHERE job_id = p_job_id
  )
  SELECT 
    t.id,
    t.name,
    t.status,
    t.error_message,
    t.created_at,
    t.completed_at,
    c.total
  FROM tasks t
  CROSS JOIN task_count c
  WHERE t.job_id = p_job_id
  ORDER BY t.created_at DESC
  LIMIT p_page_size
  OFFSET (p_page - 1) * p_page_size;
END;
$$;

-- Create function to get activity logs with pagination
CREATE OR REPLACE FUNCTION get_activity_logs(
  p_workspace_id uuid,
  p_page integer,
  p_page_size integer
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  entity_type text,
  entity_id uuid,
  action text,
  status text,
  message text,
  created_at timestamptz,
  total_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH log_count AS (
    SELECT count(*)::bigint as total
    FROM activity_logs
    WHERE workspace_id = p_workspace_id
  )
  SELECT 
    l.id,
    l.user_id,
    l.entity_type,
    l.entity_id,
    l.action,
    l.status,
    l.message,
    l.created_at,
    c.total
  FROM activity_logs l
  CROSS JOIN log_count c
  WHERE l.workspace_id = p_workspace_id
  ORDER BY l.created_at DESC
  LIMIT p_page_size
  OFFSET (p_page - 1) * p_page_size;
END;
$$;

-- Create triggers for updated_at
CREATE TRIGGER update_jobs_updated_at
  BEFORE UPDATE ON jobs
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_tasks_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
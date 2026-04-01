-- Create an enum for approval status if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'approval_status') THEN
        CREATE TYPE public.approval_status AS ENUM ('pending', 'approved', 'rejected', 'expired');
    END IF;
END
$$;

-- Add approval-related columns to project_updates
ALTER TABLE public.project_updates 
  ADD COLUMN IF NOT EXISTS requires_approval BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_blocker BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS status public.approval_status DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS rejection_comment TEXT;

-- Update RLS policies to allow authenticated users to update the status and rejection comment
-- only if the project associated with the update belongs to their client.
CREATE POLICY "Clients can update approval status of their project updates" ON public.project_updates
  FOR UPDATE TO authenticated
  USING (
    (SELECT client_id FROM public.projects WHERE public.projects.id = project_updates.project_id) = public.get_user_client()
  )
  WITH CHECK (
    (SELECT client_id FROM public.projects WHERE public.projects.id = project_updates.project_id) = public.get_user_client()
  );

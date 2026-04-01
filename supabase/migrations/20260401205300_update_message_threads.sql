-- 1. Add 'follow_up' to the approval_status enum
ALTER TYPE public.approval_status ADD VALUE IF NOT EXISTS 'follow_up';

-- 2. Create the update_comments table for the message thread
CREATE TABLE IF NOT EXISTS public.update_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    update_id UUID NOT NULL REFERENCES public.project_updates(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Enable RLS for update_comments
ALTER TABLE public.update_comments ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policy: Users can view comments for projects they have access to
CREATE POLICY "Users can view comments for their projects" ON public.update_comments
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.project_updates pu
    JOIN public.projects p ON pu.project_id = p.id
    WHERE pu.id = update_comments.update_id
    AND (
      p.client_id = (SELECT client_id FROM public.users WHERE id = auth.uid())
      OR (SELECT is_system_admin FROM public.users WHERE id = auth.uid())
    )
  )
);

-- 5. RLS Policy: Users can insert comments for their projects
CREATE POLICY "Users can insert comments for their projects" ON public.update_comments
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.project_updates pu
    JOIN public.projects p ON pu.project_id = p.id
    WHERE pu.id = update_comments.update_id
    AND (
      p.client_id = (SELECT client_id FROM public.users WHERE id = auth.uid())
      OR (SELECT is_system_admin FROM public.users WHERE id = auth.uid())
    )
  )
);

-- 6. Data Migration: Move existing feedback to comments
INSERT INTO public.update_comments (update_id, author_id, content, created_at)
SELECT 
    id, 
    COALESCE(approved_by, author_id), 
    client_feedback, 
    COALESCE(approved_at, created_at)
FROM public.project_updates
WHERE client_feedback IS NOT NULL;


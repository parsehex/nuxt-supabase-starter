-- Migration for project_updates
CREATE TABLE public.project_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  author_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  update_type TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Turn on RLS
ALTER TABLE public.project_updates ENABLE ROW LEVEL SECURITY;

-- System Admins can always manage project updates
CREATE POLICY "System admins can manage all project updates" ON public.project_updates
  FOR ALL TO authenticated USING (public.is_system_admin());

-- Users can read project updates for their client
CREATE POLICY "Users can read project updates for their client" ON public.project_updates
  FOR SELECT TO authenticated USING (
    (SELECT client_id FROM public.projects WHERE public.projects.id = project_updates.project_id) = public.get_user_client()
  );

-- Fix the foreign key for approved_by to point to public.users instead of auth.users
-- This allows PostgREST to perform the join for the activity feed.
ALTER TABLE public.project_updates 
  DROP CONSTRAINT IF EXISTS project_updates_approved_by_fkey,
  ADD CONSTRAINT project_updates_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id) ON DELETE SET NULL;

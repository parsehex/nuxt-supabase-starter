-- Rename rejection_comment to client_feedback to account for both approvals and rejections
ALTER TABLE public.project_updates 
  RENAME COLUMN rejection_comment TO client_feedback;

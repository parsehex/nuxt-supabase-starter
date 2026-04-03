-- 1. Extend the clients table with speculative and rich tracking info
ALTER TABLE public.clients
  ADD COLUMN is_speculative BOOLEAN DEFAULT FALSE,
  ADD COLUMN contact_email TEXT,
  ADD COLUMN contact_name TEXT,
  ADD COLUMN website TEXT,
  ADD COLUMN source TEXT,
  ADD COLUMN notes TEXT,
  ADD COLUMN deal_value TEXT,
  ADD COLUMN share_token UUID UNIQUE DEFAULT gen_random_uuid(), -- Note: initially existing clients will get a token
  ADD COLUMN converted_at TIMESTAMPTZ;

-- 2. Create prospect_notes for threaded workspace
CREATE TABLE public.prospect_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.prospect_notes(id) ON DELETE CASCADE, -- Support nesting
  content TEXT NOT NULL,
  public_content TEXT,
  is_shareable BOOLEAN DEFAULT FALSE,
  tag TEXT, -- "idea", "link", "pricing", "scope", etc.
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create prospect_links for shared resources
CREATE TABLE public.prospect_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  label TEXT,
  description TEXT,
  is_public BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Create pitch_views for tracking
CREATE TABLE public.pitch_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ DEFAULT NOW(),
  ip_hash TEXT,
  user_agent TEXT,
  referrer TEXT
);

-- Enable RLS
ALTER TABLE public.prospect_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prospect_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pitch_views ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- System Admin: Full access to everything
CREATE POLICY "System admins can manage all prospect_notes" ON public.prospect_notes
  FOR ALL TO authenticated USING (public.is_system_admin());

CREATE POLICY "System admins can manage all prospect_links" ON public.prospect_links
  FOR ALL TO authenticated USING (public.is_system_admin());

CREATE POLICY "System admins can manage all pitch_views" ON public.pitch_views
  FOR ALL TO authenticated USING (public.is_system_admin());

-- Public Access via share_token
-- This requires checking the client's share_token

-- A helper function for token-based access would be clean
CREATE OR REPLACE FUNCTION public.get_client_id_by_token(token UUID)
RETURNS UUID AS $$
  SELECT id FROM public.clients WHERE share_token = token;
$$ LANGUAGE sql SECURITY DEFINER;

-- Prospect access to shared notes
CREATE POLICY "Public can view shareable notes via token" ON public.prospect_notes
  FOR SELECT TO anon USING (
    is_shareable = true AND 
    client_id IN (SELECT id FROM public.clients WHERE share_token IS NOT NULL)
  );

-- Prospect access to shared links
CREATE POLICY "Public can view shared links via token" ON public.prospect_links
  FOR SELECT TO anon USING (
    is_public = true AND 
    client_id IN (SELECT id FROM public.clients WHERE share_token IS NOT NULL)
  );

-- Prospect can register a view
CREATE POLICY "Public can insert pitch_views" ON public.pitch_views
  FOR INSERT TO anon WITH CHECK (
    client_id IN (SELECT id FROM public.clients WHERE share_token IS NOT NULL)
  );

-- Missing policy to allow anonymous users to find a client record by their share_token
CREATE POLICY "Public can view basic client info via token" ON public.clients
  FOR SELECT TO anon USING (share_token IS NOT NULL);

-- Refine existing policies to ensure they work for anon
-- (The subqueries in migrations/20260403104500_speculative_clients.sql will now work because anon can "see" the clients table)

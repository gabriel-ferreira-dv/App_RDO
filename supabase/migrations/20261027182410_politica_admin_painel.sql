drop policy if exists "Enable delete for users based on user_id" on public.admins_painel;
revoke insert, update, delete, truncate on public.admins_painel from anon, authenticated;
create policy "admin le a propria linha" on public.admins_painel
  for select to authenticated using (user_id = (select auth.uid()));
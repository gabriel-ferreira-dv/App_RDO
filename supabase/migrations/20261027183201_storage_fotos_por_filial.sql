-- admin e gestor só leem no storage as fotos da própria filial, igual já é nas
-- tabelas. A filial é a primeira pasta do caminho (010152/joao_silva/foto.jpg).
-- Quem vê todas as filiais (gestor sem filial ou admin geral) continua vendo tudo.

drop policy if exists "admin do painel le os arquivos das fotos" on storage.objects;
create policy "admin do painel le os arquivos das fotos" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'fotos'
    and (select public.sou_admin_painel())
    and (
      (storage.foldername(name))[1] = (select public.filial_atual())
      or (select public.ve_todas_as_filiais())
      or (select public.sou_admin_geral())
    )
  );

drop policy if exists "gestor le todas as fotos no storage" on storage.objects;
drop policy if exists "gestor le as fotos da propria filial no storage" on storage.objects;
create policy "gestor le as fotos da propria filial no storage" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'fotos'
    and exists (select 1 from public.gestores_painel g where g.user_id = (select auth.uid()))
    and (
      (storage.foldername(name))[1] = (select public.filial_atual())
      or (select public.ve_todas_as_filiais())
    )
  );

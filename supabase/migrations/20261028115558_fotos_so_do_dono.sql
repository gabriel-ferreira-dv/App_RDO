-- foto nova (ou carimbo trocado) só no registro da própria pessoa ou da equipe
-- do supervisor, e com o arquivo na pasta da filial dela. Antes o insert e o
-- update aceitavam qualquer caminho (with check true), e dava pra apontar a
-- linha pra foto de outra pessoa e ganhar acesso a ela no storage.
-- Vale também pras fotos de paralisação, que tinham o mesmo problema.

-- caminho vazio, na pasta da filial da pessoa, ou o que a foto já tinha
-- (na troca do carimbo só muda a carimbada; a original e o minimapa ficam)
create or replace function public.caminho_de_foto_permitido(p_caminho text, p_foto_id bigint)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(p_caminho, '') = ''
      or (storage.foldername(p_caminho))[1] = public.filial_atual()
      or exists (
        select 1 from public.fotos_app f
         where f.id = p_foto_id
           and p_caminho in (f.caminho_storage, f.caminho_original_storage,
                             f.caminho_minimapa_storage)
      );
$$;
revoke all on function public.caminho_de_foto_permitido(text, bigint) from public, anon;
grant execute on function public.caminho_de_foto_permitido(text, bigint) to authenticated;

drop policy if exists "app insere fotos" on public.fotos_app;
create policy "app insere fotos" on public.fotos_app
  for insert to authenticated
  with check (
    exists (
      select 1 from public.registros_app r
       where r.dispositivo_id = fotos_app.dispositivo_id
         and r.id_local = fotos_app.registro_id_local
         and (
           trim(r.usuario_matricula) = (select public.matricula_atual())
           or ((select public.e_supervisor()) and exists (
                 select 1 from public.equipes_supervisor e
                  where e.supervisor_matricula = (select public.matricula_atual())
                    and e.encarregado_matricula = trim(r.usuario_matricula)))
         )
    )
    and public.caminho_de_foto_permitido(caminho_storage, id)
    and public.caminho_de_foto_permitido(caminho_original_storage, id)
    and public.caminho_de_foto_permitido(caminho_minimapa_storage, id)
  );

drop policy if exists "dono ou supervisor troca a foto carimbada" on public.fotos_app;
create policy "dono ou supervisor troca a foto carimbada" on public.fotos_app
  for update to authenticated
  using (
    exists (
      select 1 from public.registros_app r
       where r.dispositivo_id = fotos_app.dispositivo_id
         and r.id_local = fotos_app.registro_id_local
         and (
           trim(r.usuario_matricula) = (select public.matricula_atual())
           or ((select public.e_supervisor()) and exists (
                 select 1 from public.equipes_supervisor e
                  where e.supervisor_matricula = (select public.matricula_atual())
                    and e.encarregado_matricula = trim(r.usuario_matricula)))
         )
    )
  )
  with check (
    exists (
      select 1 from public.registros_app r
       where r.dispositivo_id = fotos_app.dispositivo_id
         and r.id_local = fotos_app.registro_id_local
         and (
           trim(r.usuario_matricula) = (select public.matricula_atual())
           or ((select public.e_supervisor()) and exists (
                 select 1 from public.equipes_supervisor e
                  where e.supervisor_matricula = (select public.matricula_atual())
                    and e.encarregado_matricula = trim(r.usuario_matricula)))
         )
    )
    and public.caminho_de_foto_permitido(caminho_storage, id)
    and public.caminho_de_foto_permitido(caminho_original_storage, id)
    and public.caminho_de_foto_permitido(caminho_minimapa_storage, id)
  );

drop policy if exists "usuario envia fotos das proprias paralisacoes" on public.paralisacao_fotos_app;
create policy "usuario envia fotos das proprias paralisacoes" on public.paralisacao_fotos_app
  for insert to authenticated
  with check (
    exists (
      select 1 from public.paralisacoes_app p
       where p.dispositivo_id = paralisacao_fotos_app.dispositivo_id
         and p.id_local = paralisacao_fotos_app.paralisacao_id_local
         and p.usuario_matricula = (select public.matricula_atual())
    )
    and public.caminho_de_foto_permitido(caminho_storage, null)
  );

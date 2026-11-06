-- registro novo só em nome próprio. Antes o insert aceitava qualquer matrícula
-- (with check true) e dava pra criar registro no nome de outra pessoa.
-- O supervisor continua podendo lançar em nome de alguém da equipe dele
-- (aí o dono é o encarregado e o supervisor vai em registrado_por_matricula).

drop policy if exists "app insere registros" on public.registros_app;
create policy "app insere registros" on public.registros_app
  for insert to authenticated
  with check (
    (
      trim(usuario_matricula) = (select public.matricula_atual())
      and coalesce(trim(registrado_por_matricula), '') in ('', (select public.matricula_atual()))
    )
    or (
      trim(registrado_por_matricula) = (select public.matricula_atual())
      and (select public.e_supervisor())
      and exists (
        select 1 from public.equipes_supervisor e
         where e.supervisor_matricula = (select public.matricula_atual())
           and e.encarregado_matricula = trim(registros_app.usuario_matricula)
      )
    )
  );

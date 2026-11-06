-- supervisor não conseguia montar a equipe: a tela lista os encarregados do
-- apontamento de hoje e ontem, mas a policy só deixava o supervisor ver os
-- encarregados que já estavam na equipe dele. com a equipe vazia, a lista
-- vinha vazia.
--
-- agora o supervisor lê o apontamento inteiro, igual ao gestor do painel. a
-- tabela não tem filial: é o relatório Equipe Apontada do SIMOVA da obra.

drop policy if exists "le a equipe apontada propria, da equipe ou do painel" on public.equipe_apontada;
drop policy if exists "le a equipe apontada propria, do supervisor ou do painel" on public.equipe_apontada;
create policy "le a equipe apontada propria, do supervisor ou do painel"
  on public.equipe_apontada
  for select to authenticated
  using (
    split_part(encarregado, '::', 1) = (select public.matricula_atual())
    or (select public.e_supervisor())
    or exists (
      select 1 from public.gestores_painel g where g.user_id = (select auth.uid())
    )
  );

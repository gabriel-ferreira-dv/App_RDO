-- mensagens por filial, e cada um só recebe a sua. Antes qualquer um lia
-- todas, até sem login (anon), com o e-mail de quem era o destinatário, e o
-- app é que filtrava no celular.
--
-- filial_id vazio = todas as filiais (as mensagens antigas ficam assim).
-- Mensagem que o gestor de uma filial manda já sai com a filial dele.
-- Pelo SQL Editor ou Table Editor, preencha filial_id pra mandar só pra uma obra.

alter table public.mensagens
  add column if not exists filial_id text default public.filial_atual()
    references public.filiais (id) on update cascade;

revoke all on table public.mensagens from anon;

drop policy if exists "app le mensagens" on public.mensagens;
drop policy if exists "le mensagens da propria filial" on public.mensagens;
create policy "le mensagens da propria filial" on public.mensagens
  for select to authenticated
  using (
    (
      filial_id is null
      or filial_id = (select public.filial_atual())
      or (select public.ve_todas_as_filiais())
    )
    and (
      coalesce(trim(destinatario_email), '') = ''
      or lower(trim(destinatario_email)) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
      -- o gestor vê todas as da filial, pra conferir o que mandou
      or exists (select 1 from public.gestores_painel g where g.user_id = (select auth.uid()))
    )
  );

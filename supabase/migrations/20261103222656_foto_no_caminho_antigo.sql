-- o app de antes de 26/10 sobe a foto em "nome/arquivo.jpg", sem a pasta da
-- filial na frente, e o banco recusava a linha em fotos_app. quem estiver na
-- tabela abaixo pode gravar a foto nesse caminho antigo, desde que o arquivo
-- tenha sido subido por ele mesmo (não dá pra apontar pra foto de outro).
-- é provisório: tira a pessoa da tabela quando ela atualizar o app.

create table if not exists public.fotos_caminho_antigo_liberado (
  matricula text primary key,
  motivo text not null default '',
  liberado_em timestamptz not null default now()
);

-- sem policy: o app não lê nem altera, só a função abaixo e o SQL Editor.
alter table public.fotos_caminho_antigo_liberado enable row level security;

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
      )
      or (
        exists (select 1 from public.fotos_caminho_antigo_liberado l
                 where l.matricula = public.matricula_atual())
        and exists (select 1 from storage.objects o
                     where o.bucket_id = 'fotos'
                       and o.name = p_caminho
                       and o.owner = auth.uid())
      );
$$;

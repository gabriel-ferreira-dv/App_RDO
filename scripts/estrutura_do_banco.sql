-- Usado pelo copiar_estrutura_do_banco.ps1. Pega o que o pg_dump não pega
-- porque está nos esquemas do Supabase. Cada linha que sai já é um comando.

select '-- ## extensoes';
select format('create extension if not exists %I with schema %I;',
              e.extname, n.nspname)
  from pg_extension e
  join pg_namespace n on n.oid = e.extnamespace
 where e.extname not in ('plpgsql', 'pgcrypto', 'uuid-ossp', 'pg_graphql',
                         'pg_stat_statements', 'supabase_vault', 'pgsodium',
                         'pgjwt')
 order by e.extname;

-- policies do storage.objects
select '-- ## politicas_auth_storage';
select format('create policy %I on %I.%I as %s for %s to %s%s%s;',
              policyname, schemaname, tablename, permissive, cmd,
              array_to_string(roles, ', '),
              coalesce(' using (' || qual || ')', ''),
              coalesce(' with check (' || with_check || ')', ''))
  from pg_policies
 where schemaname in ('auth', 'storage')
 order by schemaname, tablename, policyname;

-- triggers que eu criei no auth (ex.: auth.users), os do Supabase não entram
select '-- ## gatilhos_auth_storage';
select pg_get_triggerdef(t.oid) || ';'
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  join pg_proc p on p.oid = t.tgfoid
  join pg_namespace pn on pn.oid = p.pronamespace
 where n.nspname in ('auth', 'storage')
   and pn.nspname not in ('auth', 'storage')
   and not t.tgisinternal
 order by n.nspname, c.relname, t.tgname;

select '-- ## buckets';
select format('insert into storage.buckets (id, name, public, file_size_limit, '
              'allowed_mime_types) values (%L, %L, %L, %s, %L) '
              'on conflict (id) do nothing;',
              id, name, public, coalesce(file_size_limit::text, 'null'),
              allowed_mime_types)
  from storage.buckets
 order by id;

-- jobs do cron, só pra conferir (podem ter chave no comando)
select '-- ## cron';
select exists (select 1 from pg_namespace where nspname = 'cron') as tem_cron
\gset
\if :tem_cron
select format('select cron.schedule(%L, %L, %L);', jobname, schedule, command)
  from cron.job
 order by jobname;
\endif

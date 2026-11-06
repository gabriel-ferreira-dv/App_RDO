-- Estrutura do banco de produção em 26/10/2026, sem dados
-- (scripts/copiar_estrutura_do_banco.ps1).
-- Na produção já foi marcada como aplicada com migration repair, então só roda
-- nos bancos de teste dos PRs.
-- O cron registro-diario-horario não entra aqui porque chama a produção.

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_cron; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";


--
-- Name: pg_net; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "public";


--
-- Name: hypopg; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "hypopg" WITH SCHEMA "extensions";


--
-- Name: index_advisor; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "index_advisor" WITH SCHEMA "extensions";


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";


--
-- Name: aplicar_acessos_de_usuario("uuid", "text", boolean, "text", boolean, "text", boolean, "text", boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."aplicar_acessos_de_usuario"("p_user" "uuid", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean, "p_conta_nova" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_nome text := trim(coalesce(p_nome, ''));
  v_matricula text := trim(coalesce(p_matricula, ''));
  v_filial text := nullif(trim(coalesce(p_filial, '')), '');
  v_filial_painel text := nullif(trim(coalesce(p_filial_painel, '')), '');
  v_geral boolean := public.sou_admin_geral();
  v_minha text := public.filial_do_admin();
begin
  if v_nome = '' then
    raise exception 'Informe o nome.';
  end if;
  if not coalesce(p_app, false) and not coalesce(p_painel, false) then
    raise exception 'Marque pelo menos um acesso: app ou painel.';
  end if;
  if coalesce(p_admin, false) and not coalesce(p_painel, false) then
    raise exception 'Administrador precisa ter acesso ao painel.';
  end if;
  if p_user = auth.uid() and not coalesce(p_admin, false) then
    raise exception 'Você não pode tirar o seu próprio acesso de administrador.';
  end if;
  if p_user = auth.uid() and not coalesce(p_painel, false) then
    raise exception 'Você não pode tirar o seu próprio acesso ao painel.';
  end if;
  if p_user = auth.uid() and v_geral and v_filial_painel is not null then
    raise exception 'Você não pode limitar o seu próprio painel a uma filial (deixaria de ser ADMapp).';
  end if;

  if not v_geral then
    if coalesce(p_admin, false) then
      raise exception 'Só o ADMapp cria ou altera administradores.' using errcode = '42501';
    end if;
    if coalesce(p_app, false) and v_filial is distinct from v_minha then
      raise exception 'Você só cadastra pessoas na sua obra (%).', v_minha using errcode = '42501';
    end if;
    if coalesce(p_painel, false) and v_filial_painel is distinct from v_minha then
      raise exception 'O painel de quem você cadastra fica limitado à sua obra (%).', v_minha using errcode = '42501';
    end if;
  end if;

  if coalesce(p_app, false) then
    if v_matricula = '' then
      raise exception 'Informe a matrícula de quem usa o app.';
    end if;
    if v_filial is null then
      raise exception 'Escolha a filial de quem usa o app.';
    end if;
    if not exists (select 1 from public.filiais f where f.id = v_filial) then
      raise exception 'A filial % não existe.', v_filial;
    end if;
    if exists (select 1 from public.perfis_app p
               where p.matricula = v_matricula and p.user_id <> p_user) then
      raise exception 'A matrícula % já pertence a outra conta.', v_matricula;
    end if;
    insert into public.perfis_app (user_id, matricula, supervisor, nome, filial_id)
    values (p_user, v_matricula, coalesce(p_supervisor, false), v_nome, v_filial)
    on conflict (user_id) do update
      set matricula  = excluded.matricula,
          supervisor = excluded.supervisor,
          nome       = excluded.nome,
          filial_id  = excluded.filial_id;
  else
    delete from public.perfis_app where user_id = p_user;
  end if;

  if coalesce(p_painel, false) then
    if v_filial_painel is not null
       and not exists (select 1 from public.filiais f where f.id = v_filial_painel) then
      raise exception 'A filial % não existe.', v_filial_painel;
    end if;
    insert into public.gestores_painel (user_id, nome, filial_id, trocar_senha)
    values (p_user, v_nome, v_filial_painel, coalesce(p_conta_nova, false))
    on conflict (user_id) do update
      set nome      = excluded.nome,
          filial_id = excluded.filial_id;
  else
    delete from public.gestores_painel where user_id = p_user;
  end if;

  if v_geral then
    if coalesce(p_admin, false) then
      insert into public.admins_painel (user_id) values (p_user) on conflict do nothing;
    else
      delete from public.admins_painel where user_id = p_user;
    end if;
    -- ADMapp = administrador com o painel em todas as filiais.
    if coalesce(p_admin, false) and v_filial_painel is null then
      insert into public.gestor_app (user_id) values (p_user) on conflict do nothing;
    else
      delete from public.gestor_app where user_id = p_user;
    end if;
  end if;

  update auth.users u
     set raw_user_meta_data = coalesce(u.raw_user_meta_data, '{}'::jsonb)
           || jsonb_build_object('nome', v_nome)
           || case when coalesce(p_app, false)
                then jsonb_build_object(
                       'matricula', v_matricula,
                       'perfil', case when coalesce(p_supervisor, false) then 'supervisor' else '' end)
                else '{}'::jsonb
              end,
         updated_at = now()
   where u.id = p_user;
end;
$$;


--
-- Name: aviso_privacidade_marca_edicao(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."aviso_privacidade_marca_edicao"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;


--
-- Name: concluir_troca_de_senha(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."concluir_troca_de_senha"() RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  update public.gestores_painel
     set trocar_senha = false
   where user_id = auth.uid();
  update public.perfis_app
     set trocar_senha = false
   where user_id = auth.uid();
$$;


--
-- Name: concluir_troca_de_senha_app(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."concluir_troca_de_senha_app"() RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  update public.perfis_app
     set trocar_senha = false
   where user_id = auth.uid();
  update public.gestores_painel
     set trocar_senha = false
   where user_id = auth.uid();
$$;


--
-- Name: criar_perfil_da_nova_conta(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."criar_perfil_da_nova_conta"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if coalesce(trim(new.raw_user_meta_data ->> 'matricula'), '') <> '' then
    insert into public.perfis_app (user_id, matricula, supervisor, nome)
    values (new.id,
            trim(new.raw_user_meta_data ->> 'matricula'),
            false,
            coalesce(new.raw_user_meta_data ->> 'nome', ''))
    on conflict do nothing;
  end if;
  return new;
end;
$$;


--
-- Name: dados_da_obra_painel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."dados_da_obra_painel"() RETURNS TABLE("filial_id" "text", "filial_nome" "text", "nome" "text", "tipo" "text", "rotulo" "text", "linhas" integer, "colunas" integer, "versao" integer, "arquivo" "text", "atualizado_em" timestamp with time zone, "atualizado_por" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with alvo as (
    select f.id, f.nome, f.config
    from public.filiais f
    where public.pode_administrar('dados', f.id)
  ),
  itens as (
    select a.id, a.nome as filial_nome, c.nome, 'csv' as tipo, c.rotulo,
           null::integer as linhas, null::integer as colunas, c.ordem::bigint as ordem
    from alvo a
    cross join (values ('SevNotaveis.csv', 'Serviços notáveis', 1),
                       ('KMxEst.csv', 'KM x estaca', 2),
                       ('estacas_coords.csv', 'Coordenadas das estacas', 3)) c(nome, rotulo, ordem)
    union all
    select a.id, a.nome, m ->> 'nome', 'mapa',
           coalesce(m ->> 'rotulo', 'Mapa ' || (m ->> 'nome')),
           (m ->> 'linhas')::integer, (m ->> 'colunas')::integer, 10 + x.ordem
    from alvo a
    cross join lateral jsonb_array_elements(case when jsonb_typeof(a.config -> 'mapas') = 'array'
                                                 then a.config -> 'mapas' else '[]'::jsonb end)
         with ordinality x(m, ordem)
  )
  select i.id, i.filial_nome, i.nome, i.tipo, i.rotulo, i.linhas, i.colunas,
         d.versao, d.arquivo, d.atualizado_em,
         coalesce(g.nome, u.email::text)
  from itens i
  left join public.dados_da_obra d on d.filial_id = i.id and d.nome = i.nome
  left join auth.users u on u.id = d.atualizado_por
  left join public.gestores_painel g on g.user_id = d.atualizado_por
  order by i.id, i.ordem
$$;


--
-- Name: dados_registrar_envio("text", "text", "text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."dados_registrar_envio"("p_filial" "text", "p_nome" "text", "p_arquivo" "text") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_filial text := trim(coalesce(p_filial, ''));
  v_nome text := trim(coalesce(p_nome, ''));
  v_arquivo text := trim(coalesce(p_arquivo, ''));
  v_csv boolean := v_nome in ('SevNotaveis.csv', 'KMxEst.csv', 'estacas_coords.csv');
  v_versao integer;
begin
  if not exists (select 1 from public.filiais f where f.id = v_filial) then
    raise exception 'A filial % não existe.', v_filial;
  end if;
  if not public.pode_administrar('dados', v_filial) then
    raise exception 'O ADMapp não liberou a atualização dos dados da obra %.', v_filial using errcode = '42501';
  end if;
  if not v_csv and not exists (
      select 1 from public.filiais f,
                    jsonb_array_elements(case when jsonb_typeof(f.config -> 'mapas') = 'array'
                                              then f.config -> 'mapas' else '[]'::jsonb end) m
      where f.id = v_filial and m ->> 'nome' = v_nome) then
    raise exception 'O arquivo "%" não é um dos dados da obra % (CSV conhecido ou mapa da configuração).', v_nome, v_filial;
  end if;
  if left(v_arquivo, length(v_filial) + 1) <> v_filial || '/' or not public.pode_enviar_dados(v_arquivo) then
    raise exception 'Caminho inválido: o arquivo precisa estar na pasta da filial %.', v_filial;
  end if;
  if v_csv and lower(v_arquivo) !~ '\.csv$' then
    raise exception 'Para % envie um arquivo .csv.', v_nome;
  end if;
  if not v_csv and lower(v_arquivo) !~ '\.zip$' then
    raise exception 'Para o mapa % envie um arquivo .zip.', v_nome;
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'dados' and o.name = v_arquivo) then
    raise exception 'O arquivo % não chegou ao Storage. Envie de novo.', v_arquivo;
  end if;

  insert into public.dados_da_obra as d (filial_id, nome, versao, arquivo, atualizado_em, atualizado_por)
  values (v_filial, v_nome, 2, v_arquivo, now(), auth.uid())
  on conflict (filial_id, nome) do update
    set versao         = d.versao + 1,
        arquivo        = excluded.arquivo,
        atualizado_em  = excluded.atualizado_em,
        atualizado_por = excluded.atualizado_por
  returning d.versao into v_versao;

  insert into public.uso_painel (user_id, evento, detalhes)
  values (auth.uid(), 'dados_enviados',
          jsonb_build_object('filial', v_filial, 'nome', v_nome, 'versao', v_versao, 'arquivo', v_arquivo));
  return v_versao;
end;
$_$;


--
-- Name: e_supervisor(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."e_supervisor"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    (select supervisor from public.perfis_app where user_id = auth.uid()),
    false)
$$;


--
-- Name: encarregados_do_painel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."encarregados_do_painel"() RETURNS TABLE("matricula" "text", "filial_id" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select p.matricula, p.filial_id
  from public.perfis_app p
  where exists (select 1 from public.gestores_painel g where g.user_id = auth.uid())
    and coalesce(p.supervisor, false) = false
    and trim(coalesce(p.matricula, '')) <> ''
    and not exists (select 1 from public.admins_painel a where a.user_id = p.user_id)
    and not exists (select 1 from public.gestores_painel g2 where g2.user_id = p.user_id)
    and (p.filial_id = public.filial_atual() or public.ve_todas_as_filiais())
$$;


--
-- Name: espelhar_dados_no_app_antigo(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."espelhar_dados_no_app_antigo"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.filial_id = '010152' then
    insert into public.versoes_dados (nome, versao, arquivo, atualizado_em)
    values (new.nome, new.versao, new.arquivo, new.atualizado_em)
    on conflict (nome) do update
      set versao        = excluded.versao,
          arquivo       = excluded.arquivo,
          atualizado_em = excluded.atualizado_em;
  end if;
  return new;
end;
$$;


--
-- Name: excluir_foto_painel(bigint, "text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."excluir_foto_painel"("p_id" bigint, "p_motivo" "text" DEFAULT ''::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not exists (select 1 from public.fotos_app f
                 where f.id = p_id and public.pode_administrar('registros', f.filial_id)) then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  update public.fotos_app
     set excluida = true,
         excluida_em = now(),
         excluida_por = auth.uid(),
         motivo_exclusao = coalesce(trim(p_motivo), '')
   where id = p_id and not excluida;
  if not found then
    raise exception 'foto não encontrada ou já excluída';
  end if;
  insert into public.uso_painel (user_id, evento, detalhes)
  values (auth.uid(), 'foto_excluida', jsonb_build_object('foto_id', p_id, 'motivo', coalesce(trim(p_motivo), '')));
end;
$$;


--
-- Name: excluir_registro_painel(bigint, "text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."excluir_registro_painel"("p_id" bigint, "p_motivo" "text" DEFAULT ''::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not exists (select 1 from public.registros_app r
                 where r.id = p_id and public.pode_administrar('registros', r.filial_id)) then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  update public.registros_app
     set excluido = true,
         excluido_em = now(),
         excluido_por = auth.uid(),
         motivo_exclusao = coalesce(trim(p_motivo), '')
   where id = p_id and not excluido;
  if not found then
    raise exception 'registro não encontrado ou já excluído';
  end if;
  insert into public.uso_painel (user_id, evento, detalhes)
  values (auth.uid(), 'registro_excluido', jsonb_build_object('registro_id', p_id, 'motivo', coalesce(trim(p_motivo), '')));
end;
$$;


--
-- Name: exigir_admin_geral(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."exigir_admin_geral"() RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.sou_admin_geral() then
    raise exception 'Só o ADMapp (gestor geral) pode fazer isso.' using errcode = '42501';
  end if;
end;
$$;


--
-- Name: exigir_admin_painel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."exigir_admin_painel"() RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.sou_admin_painel() then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
end;
$$;


--
-- Name: exigir_gestao_de_usuario("uuid"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."exigir_gestao_de_usuario"("p_user" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_filial text := public.filial_do_admin();
begin
  if public.sou_admin_geral() then
    return;
  end if;
  if v_filial is null or not public.pode_administrar('usuarios', v_filial) then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  if exists (select 1 from public.admins_painel a where a.user_id = p_user) then
    raise exception 'Contas de administrador só o ADMapp altera.' using errcode = '42501';
  end if;
  if exists (select 1 from public.gestores_painel g where g.user_id = p_user and g.filial_id is null) then
    raise exception 'Contas da diretoria (painel em todas as filiais) só o ADMapp altera.' using errcode = '42501';
  end if;
  if not exists (
      select 1 from auth.users u
      left join public.perfis_app p on p.user_id = u.id
      left join public.gestores_painel g on g.user_id = u.id
      where u.id = p_user
        and (p.filial_id = v_filial or g.filial_id = v_filial)
        and (p.filial_id is null or p.filial_id = v_filial)
        and (g.user_id is null or g.filial_id = v_filial)) then
    raise exception 'Esta conta não é da sua obra.' using errcode = '42501';
  end if;
end;
$$;


--
-- Name: filial_atual(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."filial_atual"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    (select filial_id from public.perfis_app where user_id = auth.uid()),
    (select filial_id from public.gestores_painel where user_id = auth.uid())
  )
$$;


--
-- Name: filial_do_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."filial_do_admin"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select g.filial_id
  from public.admins_painel a
  join public.gestores_painel g on g.user_id = a.user_id
  where a.user_id = auth.uid() and g.filial_id is not null
$$;


--
-- Name: fotos_excluidas_painel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."fotos_excluidas_painel"() RETURNS TABLE("id" bigint, "caminho_storage" "text", "foto_criada_em" timestamp with time zone, "excluida_em" timestamp with time zone, "excluida_por" "text", "motivo" "text", "encarregado" "text", "trecho" "text", "servico" "text", "estacas" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_geral boolean := public.sou_admin_geral();
  v_minha text := public.filial_do_admin();
begin
  if not public.sou_admin_painel() then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  return query
    select f.id, f.caminho_storage, f.criado_em, f.excluida_em,
           case when v_geral or f.excluida_por = auth.uid()
                     or not exists (select 1 from public.admins_painel a where a.user_id = f.excluida_por)
                then coalesce(g.nome, u.email::text) else 'Administrador' end,
           f.motivo_exclusao,
           r.usuario_nome, r.trecho, r.servico_notavel,
           case when r.estaca_inicial = r.estaca_final then r.estaca_inicial
                else r.estaca_inicial || ' a ' || r.estaca_final end
    from public.fotos_app f
    left join auth.users u on u.id = f.excluida_por
    left join public.gestores_painel g on g.user_id = f.excluida_por
    left join public.registros_app r
      on r.dispositivo_id = f.dispositivo_id and r.id_local = f.registro_id_local
    where f.excluida and (v_geral or f.filial_id = v_minha)
    order by f.excluida_em desc
    limit 500;
end;
$$;


--
-- Name: gerar_senha_provisoria(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."gerar_senha_provisoria"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  letras constant text := 'abcdefghjkmnpqrstuvwxyz';
  b bytea := extensions.gen_random_bytes(8);
  s text := '';
  k int;
begin
  for k in 0..3 loop
    s := s || substr(letras, 1 + get_byte(b, k) % length(letras), 1);
  end loop;
  s := upper(left(s, 1)) || substr(s, 2) || '-';
  for k in 4..7 loop
    s := s || (get_byte(b, k) % 10)::text;
  end loop;
  return s;
end;
$$;


--
-- Name: gestao_bloquear_usuario("uuid", boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."gestao_bloquear_usuario"("p_user" "uuid", "p_bloquear" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_user = auth.uid() then
    raise exception 'Você não pode bloquear a sua própria conta.';
  end if;
  perform public.exigir_gestao_de_usuario(p_user);
  update auth.users
     set banned_until = case when p_bloquear then 'infinity'::timestamptz else null end,
         updated_at = now()
   where id = p_user;
  if not found then
    raise exception 'Conta não encontrada.';
  end if;
  if p_bloquear then
    begin
      delete from auth.sessions where user_id = p_user;
    exception when others then
      null;
    end;
  end if;
end;
$$;


--
-- Name: gestao_criar_usuario("text", "text", boolean, "text", boolean, "text", boolean, "text", boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."gestao_criar_usuario"("p_email" "text", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_id uuid := gen_random_uuid();
  v_senha text := public.gerar_senha_provisoria();
  v_meta jsonb;
  v_minha text := public.filial_do_admin();
begin
  if not public.sou_admin_geral()
     and (v_minha is null or not public.pode_administrar('usuarios', v_minha)) then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'E-mail inválido.';
  end if;
  if exists (select 1 from auth.users u where u.email = v_email) then
    raise exception 'Já existe uma conta com o e-mail %. Procure na lista e use Editar.', v_email;
  end if;

  v_meta := jsonb_build_object('nome', trim(coalesce(p_nome, '')));
  if coalesce(p_app, false) then
    v_meta := v_meta || jsonb_build_object(
      'matricula', trim(coalesce(p_matricula, '')),
      'perfil', case when coalesce(p_supervisor, false) then 'supervisor' else '' end);
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    v_email, extensions.crypt(v_senha, extensions.gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}'::jsonb, v_meta,
    now(), now(),
    '', '', '', ''
  );

  insert into auth.identities (
    id, user_id, provider_id, provider, identity_data,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_id, v_id::text, 'email',
    jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true),
    now(), now(), now()
  );

  perform public.aplicar_acessos_de_usuario(
    v_id, p_nome, p_app, p_matricula, p_supervisor, p_filial,
    p_painel, p_filial_painel, p_admin, true);
  update public.perfis_app set trocar_senha = true where user_id = v_id;

  return v_senha;
end;
$_$;


--
-- Name: gestao_listar_filiais(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."gestao_listar_filiais"() RETURNS TABLE("id" "text", "nome" "text", "config" "jsonb", "permissoes_adm" "jsonb", "pessoas_app" bigint, "gestores" bigint, "criado_em" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
#variable_conflict use_column
declare
  v_geral boolean := public.sou_admin_geral();
  v_minha text := public.filial_do_admin();
begin
  perform public.exigir_admin_painel();
  return query
    select f.id, f.nome,
           case when v_geral then f.config else '{}'::jsonb end,
           f.permissoes_adm,
           (select count(*) from public.perfis_app p where p.filial_id = f.id),
           (select count(*) from public.gestores_painel g where g.filial_id = f.id),
           f.criado_em
    from public.filiais f
    where v_geral or f.id = v_minha
    order by f.id;
end;
$$;


--
-- Name: gestao_listar_usuarios(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."gestao_listar_usuarios"() RETURNS TABLE("user_id" "uuid", "email" "text", "nome" "text", "matricula" "text", "supervisor" boolean, "filial_app" "text", "usa_app" boolean, "gestor" boolean, "filial_painel" "text", "admin" boolean, "trocar_senha" boolean, "bloqueado" boolean, "ultimo_login" timestamp with time zone, "criado_em" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
#variable_conflict use_column
declare
  v_geral boolean := public.sou_admin_geral();
  v_minha text := public.filial_do_admin();
begin
  if not v_geral and (v_minha is null or not public.pode_administrar('usuarios', v_minha)) then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  return query
    select u.id,
           u.email::text,
           coalesce(nullif(g.nome, ''), nullif(p.nome, ''),
                    nullif(u.raw_user_meta_data ->> 'nome', ''), split_part(u.email::text, '@', 1)),
           p.matricula,
           coalesce(p.supervisor, false),
           p.filial_id,
           p.user_id is not null,
           g.user_id is not null,
           g.filial_id,
           a.user_id is not null,
           coalesce(g.trocar_senha, false) or coalesce(p.trocar_senha, false),
           coalesce(u.banned_until > now(), false),
           u.last_sign_in_at,
           u.created_at
    from auth.users u
    left join public.perfis_app p on p.user_id = u.id
    left join public.gestores_painel g on g.user_id = u.id
    left join public.admins_painel a on a.user_id = u.id
    where v_geral
       or ((p.filial_id = v_minha or g.filial_id = v_minha)
           and (a.user_id is null or a.user_id = auth.uid()))
    order by 3;
end;
$$;


--
-- Name: gestao_salvar_filial("text", "text", "jsonb", "text", "jsonb"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."gestao_salvar_filial"("p_id" "text", "p_nome" "text", "p_config" "jsonb" DEFAULT NULL::"jsonb", "p_copiar_de" "text" DEFAULT NULL::"text", "p_permissoes" "jsonb" DEFAULT NULL::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_id text := trim(coalesce(p_id, ''));
  v_nome text := trim(coalesce(p_nome, ''));
  v_perm jsonb;
begin
  perform public.exigir_admin_geral();
  if v_id = '' or v_nome = '' then
    raise exception 'Informe o código e o nome da filial.';
  end if;
  if p_config is not null and jsonb_typeof(p_config) <> 'object' then
    raise exception 'A configuração precisa ser um objeto JSON ({ ... }).';
  end if;
  if p_permissoes is not null then
    v_perm := jsonb_build_object(
      'usuarios',  coalesce((p_permissoes ->> 'usuarios')::boolean, false),
      'registros', coalesce((p_permissoes ->> 'registros')::boolean, false),
      'dados',     coalesce((p_permissoes ->> 'dados')::boolean, false));
  end if;
  insert into public.filiais as alvo (id, nome, config, permissoes_adm)
  values (v_id, v_nome,
          coalesce(p_config,
                   (select f.config from public.filiais f where f.id = p_copiar_de),
                   '{}'::jsonb),
          coalesce(v_perm, '{"usuarios": true, "registros": true, "dados": false}'::jsonb))
  on conflict (id) do update
    set nome           = excluded.nome,
        config         = coalesce(p_config, alvo.config),
        permissoes_adm = coalesce(v_perm, alvo.permissoes_adm);
end;
$$;


--
-- Name: gestao_salvar_usuario("uuid", "text", boolean, "text", boolean, "text", boolean, "text", boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."gestao_salvar_usuario"("p_user" "uuid", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not exists (select 1 from auth.users u where u.id = p_user) then
    raise exception 'Conta não encontrada.';
  end if;
  perform public.exigir_gestao_de_usuario(p_user);
  perform public.aplicar_acessos_de_usuario(
    p_user, p_nome, p_app, p_matricula, p_supervisor, p_filial,
    p_painel, p_filial_painel, p_admin, false);
end;
$$;


--
-- Name: gestao_senha_provisoria("uuid"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."gestao_senha_provisoria"("p_user" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_senha text := public.gerar_senha_provisoria();
begin
  if p_user = auth.uid() then
    raise exception 'Para a sua própria senha, use a troca de senha normal.';
  end if;
  perform public.exigir_gestao_de_usuario(p_user);
  update auth.users
     set encrypted_password = extensions.crypt(v_senha, extensions.gen_salt('bf')),
         updated_at = now()
   where id = p_user;
  if not found then
    raise exception 'Conta não encontrada.';
  end if;
  update public.gestores_painel set trocar_senha = true where user_id = p_user;
  update public.perfis_app set trocar_senha = true where user_id = p_user;
  begin
    delete from auth.sessions where user_id = p_user;
  exception when others then
    null;
  end;
  return v_senha;
end;
$$;


--
-- Name: marcar_edicao_registro(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."marcar_edicao_registro"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  antes  jsonb := to_jsonb(old);
  depois jsonb := to_jsonb(new);
  quem   text  := coalesce(public.matricula_atual(), '');
  campo  text;
  mudou  boolean := false;
begin
  if public.sou_admin_painel() then
    select 'admin ' || coalesce(u.email, '') into quem
    from auth.users u where u.id = auth.uid();
  end if;

  foreach campo in array array['trecho', 'km', 'km_final', 'via', 'atividade',
                               'estaca_inicial', 'estaca_final', 'servico_notavel',
                               'servico_notavel_detalhe', 'quantidade', 'unidade',
                               'descricao'] loop
    if antes -> campo is distinct from depois -> campo then
      mudou := true;
      insert into public.registros_edicoes
        (dispositivo_id, id_local, campo, valor_antigo, valor_novo, editado_por_matricula)
      values
        (new.dispositivo_id, new.id_local, campo, antes ->> campo, depois ->> campo, quem);
    end if;
  end loop;

  if mudou then
    new.editado_em := now();
    new.editado_por_matricula := quem;
  end if;
  return new;
end;
$$;


--
-- Name: matricula_atual(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."matricula_atual"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select matricula from public.perfis_app where user_id = auth.uid()
$$;


--
-- Name: meu_papel_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."meu_papel_admin"() RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select case
    when public.sou_admin_geral() then
      jsonb_build_object('papel', 'geral',
                         'permissoes', '{"usuarios": true, "registros": true, "dados": true}'::jsonb)
    when public.filial_do_admin() is not null then
      (select jsonb_build_object('papel', 'obra', 'filial', f.id, 'filial_nome', f.nome,
                                 'permissoes', f.permissoes_adm)
       from public.filiais f where f.id = public.filial_do_admin())
    else jsonb_build_object('papel', null)
  end
$$;


--
-- Name: movimentacoes_painel(timestamp with time zone, timestamp with time zone, "uuid", "text", integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."movimentacoes_painel"("p_de" timestamp with time zone, "p_ate" timestamp with time zone, "p_user" "uuid" DEFAULT NULL::"uuid", "p_evento" "text" DEFAULT NULL::"text", "p_limite" integer DEFAULT 2000) RETURNS TABLE("criado_em" timestamp with time zone, "user_id" "uuid", "nome" "text", "email" "text", "evento" "text", "detalhes" "jsonb", "dispositivo" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_geral boolean := public.sou_admin_geral();
  v_minha text := public.filial_do_admin();
begin
  if not public.sou_admin_painel() then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  return query
    select p.criado_em, p.user_id, coalesce(g.nome, u.email::text), u.email::text,
           p.evento, p.detalhes, p.dispositivo
    from public.uso_painel p
    join auth.users u on u.id = p.user_id
    left join public.gestores_painel g on g.user_id = p.user_id
    where p.criado_em >= p_de
      and p.criado_em <= p_ate
      and (p_user is null or p.user_id = p_user)
      and (p_evento is null or p.evento = p_evento)
      and (v_geral
           or (g.filial_id = v_minha
               and (p.user_id = auth.uid()
                    or not exists (select 1 from public.admins_painel a where a.user_id = p.user_id))))
    order by p.criado_em desc
    limit least(greatest(p_limite, 1), 10000);
end;
$$;


--
-- Name: pode_administrar("text", "text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."pode_administrar"("p_permissao" "text", "p_filial" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.sou_admin_geral()
      or exists (
        select 1
        from public.admins_painel a
        join public.gestores_painel g on g.user_id = a.user_id
        join public.filiais f on f.id = g.filial_id
        where a.user_id = auth.uid()
          and g.filial_id = p_filial
          and coalesce((f.permissoes_adm ->> p_permissao)::boolean, false)
      )
$$;


--
-- Name: pode_enviar_dados("text"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."pode_enviar_dados"("p_caminho" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
  select coalesce(
    p_caminho !~ '\.\.'
    and lower(p_caminho) ~ '\.(csv|zip)$'
    and array_length(storage.foldername(p_caminho), 1) >= 1
    and exists (select 1 from public.filiais f where f.id = (storage.foldername(p_caminho))[1])
    and public.pode_administrar('dados', (storage.foldername(p_caminho))[1]),
    false)
$_$;


--
-- Name: registros_excluidos_painel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."registros_excluidos_painel"() RETURNS TABLE("id" bigint, "criado_em" timestamp with time zone, "encarregado" "text", "trecho" "text", "km" "text", "estacas" "text", "atividade" "text", "servico" "text", "fotos" bigint, "excluido_em" timestamp with time zone, "excluido_por" "text", "motivo" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_geral boolean := public.sou_admin_geral();
  v_minha text := public.filial_do_admin();
begin
  if not public.sou_admin_painel() then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  return query
    select r.id, r.criado_em, r.usuario_nome, r.trecho, r.km,
           case when r.estaca_inicial = r.estaca_final then r.estaca_inicial
                else r.estaca_inicial || ' a ' || r.estaca_final end,
           r.atividade, r.servico_notavel,
           (select count(*) from public.fotos_app f
             where f.dispositivo_id = r.dispositivo_id and f.registro_id_local = r.id_local),
           r.excluido_em,
           case when v_geral or r.excluido_por = auth.uid()
                     or not exists (select 1 from public.admins_painel a where a.user_id = r.excluido_por)
                then coalesce(g.nome, u.email::text) else 'Administrador' end,
           r.motivo_exclusao
    from public.registros_app r
    left join auth.users u on u.id = r.excluido_por
    left join public.gestores_painel g on g.user_id = r.excluido_por
    where r.excluido and (v_geral or r.filial_id = v_minha)
    order by r.excluido_em desc
    limit 500;
end;
$$;


--
-- Name: restaurar_foto_painel(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."restaurar_foto_painel"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not exists (select 1 from public.fotos_app f
                 where f.id = p_id and public.pode_administrar('registros', f.filial_id)) then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  update public.fotos_app
     set excluida = false, excluida_em = null, excluida_por = null, motivo_exclusao = ''
   where id = p_id and excluida;
  if not found then
    raise exception 'foto não encontrada ou não está excluída';
  end if;
  insert into public.uso_painel (user_id, evento, detalhes)
  values (auth.uid(), 'foto_restaurada', jsonb_build_object('foto_id', p_id));
end;
$$;


--
-- Name: restaurar_registro_painel(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."restaurar_registro_painel"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not exists (select 1 from public.registros_app r
                 where r.id = p_id and public.pode_administrar('registros', r.filial_id)) then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  update public.registros_app
     set excluido = false, excluido_em = null, excluido_por = null, motivo_exclusao = ''
   where id = p_id and excluido;
  if not found then
    raise exception 'registro não encontrado ou não está excluído';
  end if;
  insert into public.uso_painel (user_id, evento, detalhes)
  values (auth.uid(), 'registro_restaurado', jsonb_build_object('registro_id', p_id));
end;
$$;


--
-- Name: resumo_uso_painel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."resumo_uso_painel"() RETURNS TABLE("user_id" "uuid", "nome" "text", "email" "text", "liberado_em" timestamp with time zone, "ultimo_login" timestamp with time zone, "trocar_senha" boolean, "ultimo_uso" timestamp with time zone, "acessos_30d" bigint, "dias_30d" bigint, "pdfs_30d" bigint, "mapas_30d" bigint, "dispositivos" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_geral boolean := public.sou_admin_geral();
  v_minha text := public.filial_do_admin();
begin
  if not public.sou_admin_painel() then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  return query
    select
      g.user_id,
      g.nome,
      u.email::text,
      g.criado_em,
      u.last_sign_in_at,
      g.trocar_senha,
      max(p.criado_em),
      count(*) filter (where p.evento = 'acesso' and p.criado_em >= now() - interval '30 days'),
      count(distinct (p.criado_em at time zone 'America/Sao_Paulo')::date)
        filter (where p.criado_em >= now() - interval '30 days'),
      count(*) filter (where p.evento = 'pdf' and p.criado_em >= now() - interval '30 days'),
      count(*) filter (where p.evento = 'mapa' and p.criado_em >= now() - interval '30 days'),
      string_agg(distinct split_part(p.dispositivo, ' · ', 1), ', ')
    from public.gestores_painel g
    join auth.users u on u.id = g.user_id
    left join public.uso_painel p on p.user_id = g.user_id
    where v_geral
       or (g.filial_id = v_minha
           and (g.user_id = auth.uid()
                or not exists (select 1 from public.admins_painel a where a.user_id = g.user_id)))
    group by g.user_id, g.nome, u.email, g.criado_em, u.last_sign_in_at, g.trocar_senha;
end;
$$;


--
-- Name: sou_admin_geral(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."sou_admin_geral"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.gestor_app ga where ga.user_id = auth.uid())
$$;


--
-- Name: sou_admin_painel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."sou_admin_painel"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.admins_painel a where a.user_id = auth.uid());
$$;


--
-- Name: ve_todas_as_filiais(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION "public"."ve_todas_as_filiais"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.gestores_painel
                 where user_id = auth.uid() and filial_id is null)
$$;


SET default_tablespace = '';

SET default_table_access_method = "heap";

--
-- Name: admins_painel; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."admins_painel" (
    "user_id" "uuid" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: aviso_privacidade; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."aviso_privacidade" (
    "filial_id" "text" NOT NULL,
    "versao" integer DEFAULT 1 NOT NULL,
    "texto" "text" NOT NULL,
    "atualizado_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "aviso_privacidade_versao_check1" CHECK (("versao" >= 1))
);


--
-- Name: clima_dia_app; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."clima_dia_app" (
    "usuario_matricula" "text" NOT NULL,
    "data" "date" NOT NULL,
    "usuario_nome" "text" DEFAULT ''::"text" NOT NULL,
    "clima_manha" "text" DEFAULT ''::"text" NOT NULL,
    "clima_tarde" "text" DEFAULT ''::"text" NOT NULL,
    "clima_noite" "text" DEFAULT ''::"text" NOT NULL,
    "atualizado_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    "filial_id" "text" DEFAULT "public"."filial_atual"() NOT NULL
);


--
-- Name: dados_da_obra; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."dados_da_obra" (
    "filial_id" "text" NOT NULL,
    "nome" "text" NOT NULL,
    "versao" integer DEFAULT 1 NOT NULL,
    "arquivo" "text" NOT NULL,
    "atualizado_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    "atualizado_por" "uuid"
);


--
-- Name: equipe_apontada; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."equipe_apontada" (
    "id" bigint NOT NULL,
    "funcionario" "text" NOT NULL,
    "encarregado" "text" NOT NULL,
    "funcao" "text" NOT NULL,
    "data" "text" NOT NULL,
    "coletado_em" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: equipe_apontada_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE "public"."equipe_apontada" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."equipe_apontada_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: equipe_apontamento; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW "public"."equipe_apontamento" WITH ("security_invoker"='true') AS
 SELECT "encarregado",
    "funcionario",
    "funcao",
    "data" AS "data_inicial"
   FROM "public"."equipe_apontada";


--
-- Name: VIEW "equipe_apontamento"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW "public"."equipe_apontamento" IS 'Equipe apontada por dia, lida pelo app para montar a equipe do RDO. Origem: tabela equipe_apontada (relatório Equipe Apontada do SIMOVA).';


--
-- Name: equipes_supervisor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."equipes_supervisor" (
    "supervisor_matricula" "text" NOT NULL,
    "encarregado_matricula" "text" NOT NULL,
    "encarregado_nome" "text" DEFAULT ''::"text" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    "filial_id" "text" DEFAULT "public"."filial_atual"() NOT NULL
);


--
-- Name: filiais; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."filiais" (
    "id" "text" NOT NULL,
    "nome" "text" NOT NULL,
    "config" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    "permissoes_adm" "jsonb" DEFAULT '{"dados": false, "usuarios": true, "registros": true}'::"jsonb" NOT NULL
);


--
-- Name: fotos_app; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."fotos_app" (
    "id" bigint NOT NULL,
    "dispositivo_id" "text" NOT NULL,
    "id_local" bigint NOT NULL,
    "registro_id_local" bigint NOT NULL,
    "caminho_storage" "text" NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    "criado_em" timestamp with time zone NOT NULL,
    "recebido_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    "excluida" boolean DEFAULT false NOT NULL,
    "excluida_em" timestamp with time zone,
    "excluida_por" "uuid",
    "motivo_exclusao" "text" DEFAULT ''::"text" NOT NULL,
    "filial_id" "text" DEFAULT "public"."filial_atual"() NOT NULL,
    "caminho_original_storage" "text" DEFAULT ''::"text" NOT NULL,
    "caminho_minimapa_storage" "text" DEFAULT ''::"text" NOT NULL
);


--
-- Name: fotos_app_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE "public"."fotos_app" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."fotos_app_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: gestor_app; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."gestor_app" (
    "user_id" "uuid" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: gestores_painel; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."gestores_painel" (
    "user_id" "uuid" NOT NULL,
    "nome" "text" DEFAULT ''::"text" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    "trocar_senha" boolean DEFAULT true NOT NULL,
    "filial_id" "text"
);


--
-- Name: mapas_usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."mapas_usuario" (
    "user_id" "uuid" NOT NULL,
    "grupo" "text" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: mensagens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."mensagens" (
    "id" bigint NOT NULL,
    "titulo" "text" NOT NULL,
    "corpo" "text" NOT NULL,
    "destinatario_email" "text",
    "criado_em" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: mensagens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE "public"."mensagens" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."mensagens_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: paralisacao_fotos_app; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."paralisacao_fotos_app" (
    "id" bigint NOT NULL,
    "dispositivo_id" "text" NOT NULL,
    "id_local" bigint NOT NULL,
    "paralisacao_id_local" bigint NOT NULL,
    "caminho_storage" "text" NOT NULL,
    "latitude" double precision,
    "longitude" double precision,
    "criado_em" timestamp with time zone NOT NULL,
    "recebido_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    "filial_id" "text" DEFAULT "public"."filial_atual"() NOT NULL
);


--
-- Name: paralisacao_fotos_app_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE "public"."paralisacao_fotos_app" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."paralisacao_fotos_app_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: paralisacoes_app; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."paralisacoes_app" (
    "id" bigint NOT NULL,
    "dispositivo_id" "text" NOT NULL,
    "id_local" bigint NOT NULL,
    "usuario_matricula" "text" NOT NULL,
    "usuario_nome" "text" DEFAULT ''::"text" NOT NULL,
    "motivo" "text" NOT NULL,
    "observacao" "text" DEFAULT ''::"text" NOT NULL,
    "trecho" "text" DEFAULT ''::"text" NOT NULL,
    "km" "text" DEFAULT ''::"text" NOT NULL,
    "inicio" timestamp with time zone NOT NULL,
    "fim" timestamp with time zone,
    "excluida" boolean DEFAULT false NOT NULL,
    "criado_em" timestamp with time zone NOT NULL,
    "atualizado_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    "recebido_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    "filial_id" "text" DEFAULT "public"."filial_atual"() NOT NULL
);


--
-- Name: paralisacoes_app_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE "public"."paralisacoes_app" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."paralisacoes_app_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: perfis_app; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."perfis_app" (
    "user_id" "uuid" NOT NULL,
    "matricula" "text" NOT NULL,
    "supervisor" boolean DEFAULT false NOT NULL,
    "nome" "text" DEFAULT ''::"text" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    "filial_id" "text" DEFAULT '010152'::"text" NOT NULL,
    "trocar_senha" boolean DEFAULT false NOT NULL
);


--
-- Name: registros_app; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."registros_app" (
    "id" bigint NOT NULL,
    "dispositivo_id" "text" NOT NULL,
    "id_local" bigint NOT NULL,
    "usuario_email" "text" NOT NULL,
    "usuario_nome" "text" NOT NULL,
    "trecho" "text" NOT NULL,
    "km" "text" NOT NULL,
    "via" "text" NOT NULL,
    "atividade" "text" NOT NULL,
    "estaca_inicial" "text" NOT NULL,
    "estaca_final" "text" NOT NULL,
    "servico_notavel" "text" NOT NULL,
    "descricao" "text",
    "criado_em" timestamp with time zone NOT NULL,
    "recebido_em" timestamp with time zone DEFAULT "now"() NOT NULL,
    "servico_notavel_detalhe" "text" DEFAULT ''::"text" NOT NULL,
    "quantidade" double precision,
    "unidade" "text" DEFAULT ''::"text" NOT NULL,
    "usuario_matricula" "text" DEFAULT ''::"text" NOT NULL,
    "registrado_por_nome" "text" DEFAULT ''::"text" NOT NULL,
    "registrado_por_matricula" "text" DEFAULT ''::"text" NOT NULL,
    "km_final" "text" DEFAULT ''::"text" NOT NULL,
    "excluido" boolean DEFAULT false NOT NULL,
    "excluido_em" timestamp with time zone,
    "excluido_por" "uuid",
    "motivo_exclusao" "text" DEFAULT ''::"text" NOT NULL,
    "filial_id" "text" DEFAULT "public"."filial_atual"() NOT NULL,
    "editado_em" timestamp with time zone,
    "editado_por_matricula" "text" DEFAULT ''::"text" NOT NULL
);


--
-- Name: COLUMN "registros_app"."servico_notavel_detalhe"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN "public"."registros_app"."servico_notavel_detalhe" IS 'Passo do serviço notável (coluna "SERVIÇO CORRELATO (PASSO)" da planilha). Vazio nos registros enviados por versões anteriores do app.';


--
-- Name: COLUMN "registros_app"."quantidade"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN "public"."registros_app"."quantidade" IS 'Quantidade medida do serviço (medição). Nula quando não informada.';


--
-- Name: COLUMN "registros_app"."unidade"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN "public"."registros_app"."unidade" IS 'Unidade da quantidade (m³, m², m, un, kg, t, vb). Vazia quando não informada.';


--
-- Name: COLUMN "registros_app"."km_final"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN "public"."registros_app"."km_final" IS 'KM da estaca final quando o serviço atravessa o KM. Vazio = mesmo KM do início.';


--
-- Name: registros_app_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE "public"."registros_app" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."registros_app_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: registros_edicoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."registros_edicoes" (
    "id" bigint NOT NULL,
    "dispositivo_id" "text" NOT NULL,
    "id_local" bigint NOT NULL,
    "campo" "text" NOT NULL,
    "valor_antigo" "text",
    "valor_novo" "text",
    "editado_por_matricula" "text" DEFAULT ''::"text" NOT NULL,
    "editado_em" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: registros_edicoes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE "public"."registros_edicoes" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."registros_edicoes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: uso_painel; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."uso_painel" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "evento" "text" NOT NULL,
    "detalhes" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "dispositivo" "text" DEFAULT ''::"text" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: uso_painel_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE "public"."uso_painel" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."uso_painel_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: versao_app; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."versao_app" (
    "plataforma" "text" NOT NULL,
    "versao_codigo" integer NOT NULL,
    "versao_nome" "text" DEFAULT ''::"text" NOT NULL,
    "arquivo" "text" NOT NULL,
    "versao_minima" integer DEFAULT 0 NOT NULL,
    "novidades" "text" DEFAULT ''::"text" NOT NULL,
    "atualizado_em" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: versoes_dados; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE "public"."versoes_dados" (
    "nome" "text" NOT NULL,
    "versao" integer DEFAULT 1 NOT NULL,
    "arquivo" "text" NOT NULL,
    "atualizado_em" timestamp with time zone DEFAULT "now"() NOT NULL
);


--
-- Name: admins_painel admins_painel_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."admins_painel"
    ADD CONSTRAINT "admins_painel_pkey" PRIMARY KEY ("user_id");


--
-- Name: aviso_privacidade aviso_privacidade_pkey1; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."aviso_privacidade"
    ADD CONSTRAINT "aviso_privacidade_pkey1" PRIMARY KEY ("filial_id");


--
-- Name: clima_dia_app clima_dia_app_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."clima_dia_app"
    ADD CONSTRAINT "clima_dia_app_pkey" PRIMARY KEY ("usuario_matricula", "data");


--
-- Name: dados_da_obra dados_da_obra_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."dados_da_obra"
    ADD CONSTRAINT "dados_da_obra_pkey" PRIMARY KEY ("filial_id", "nome");


--
-- Name: equipe_apontada equipe_apontada_funcionario_encarregado_funcao_data_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."equipe_apontada"
    ADD CONSTRAINT "equipe_apontada_funcionario_encarregado_funcao_data_key" UNIQUE ("funcionario", "encarregado", "funcao", "data");


--
-- Name: equipe_apontada equipe_apontada_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."equipe_apontada"
    ADD CONSTRAINT "equipe_apontada_pkey" PRIMARY KEY ("id");


--
-- Name: equipes_supervisor equipes_supervisor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."equipes_supervisor"
    ADD CONSTRAINT "equipes_supervisor_pkey" PRIMARY KEY ("supervisor_matricula", "encarregado_matricula");


--
-- Name: filiais filiais_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."filiais"
    ADD CONSTRAINT "filiais_pkey" PRIMARY KEY ("id");


--
-- Name: fotos_app fotos_app_dispositivo_id_id_local_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."fotos_app"
    ADD CONSTRAINT "fotos_app_dispositivo_id_id_local_key" UNIQUE ("dispositivo_id", "id_local");


--
-- Name: fotos_app fotos_app_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."fotos_app"
    ADD CONSTRAINT "fotos_app_pkey" PRIMARY KEY ("id");


--
-- Name: gestor_app gestor_app_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."gestor_app"
    ADD CONSTRAINT "gestor_app_pkey" PRIMARY KEY ("user_id");


--
-- Name: gestores_painel gestores_painel_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."gestores_painel"
    ADD CONSTRAINT "gestores_painel_pkey" PRIMARY KEY ("user_id");


--
-- Name: mapas_usuario mapas_usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."mapas_usuario"
    ADD CONSTRAINT "mapas_usuario_pkey" PRIMARY KEY ("user_id", "grupo");


--
-- Name: mensagens mensagens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."mensagens"
    ADD CONSTRAINT "mensagens_pkey" PRIMARY KEY ("id");


--
-- Name: paralisacao_fotos_app paralisacao_fotos_app_dispositivo_id_id_local_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."paralisacao_fotos_app"
    ADD CONSTRAINT "paralisacao_fotos_app_dispositivo_id_id_local_key" UNIQUE ("dispositivo_id", "id_local");


--
-- Name: paralisacao_fotos_app paralisacao_fotos_app_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."paralisacao_fotos_app"
    ADD CONSTRAINT "paralisacao_fotos_app_pkey" PRIMARY KEY ("id");


--
-- Name: paralisacoes_app paralisacoes_app_dispositivo_id_id_local_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."paralisacoes_app"
    ADD CONSTRAINT "paralisacoes_app_dispositivo_id_id_local_key" UNIQUE ("dispositivo_id", "id_local");


--
-- Name: paralisacoes_app paralisacoes_app_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."paralisacoes_app"
    ADD CONSTRAINT "paralisacoes_app_pkey" PRIMARY KEY ("id");


--
-- Name: perfis_app perfis_app_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."perfis_app"
    ADD CONSTRAINT "perfis_app_pkey" PRIMARY KEY ("user_id");


--
-- Name: registros_app registros_app_dispositivo_id_id_local_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."registros_app"
    ADD CONSTRAINT "registros_app_dispositivo_id_id_local_key" UNIQUE ("dispositivo_id", "id_local");


--
-- Name: registros_app registros_app_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."registros_app"
    ADD CONSTRAINT "registros_app_pkey" PRIMARY KEY ("id");


--
-- Name: registros_edicoes registros_edicoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."registros_edicoes"
    ADD CONSTRAINT "registros_edicoes_pkey" PRIMARY KEY ("id");


--
-- Name: uso_painel uso_painel_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."uso_painel"
    ADD CONSTRAINT "uso_painel_pkey" PRIMARY KEY ("id");


--
-- Name: versao_app versao_app_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."versao_app"
    ADD CONSTRAINT "versao_app_pkey" PRIMARY KEY ("plataforma");


--
-- Name: versoes_dados versoes_dados_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."versoes_dados"
    ADD CONSTRAINT "versoes_dados_pkey" PRIMARY KEY ("nome");


--
-- Name: clima_dia_app_filial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "clima_dia_app_filial_idx" ON "public"."clima_dia_app" USING "btree" ("filial_id");


--
-- Name: equipe_apontada_encarregado_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "equipe_apontada_encarregado_data" ON "public"."equipe_apontada" USING "btree" ("encarregado", "data");


--
-- Name: equipe_apontada_matricula_encarregado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "equipe_apontada_matricula_encarregado" ON "public"."equipe_apontada" USING "btree" ("split_part"("encarregado", '::'::"text", 1));


--
-- Name: equipes_supervisor_filial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "equipes_supervisor_filial_idx" ON "public"."equipes_supervisor" USING "btree" ("filial_id");


--
-- Name: fotos_app_caminho_storage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "fotos_app_caminho_storage" ON "public"."fotos_app" USING "btree" ("caminho_storage");


--
-- Name: fotos_app_filial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "fotos_app_filial_idx" ON "public"."fotos_app" USING "btree" ("filial_id");


--
-- Name: paralisacao_fotos_app_caminho; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "paralisacao_fotos_app_caminho" ON "public"."paralisacao_fotos_app" USING "btree" ("caminho_storage");


--
-- Name: paralisacao_fotos_app_filial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "paralisacao_fotos_app_filial_idx" ON "public"."paralisacao_fotos_app" USING "btree" ("filial_id");


--
-- Name: paralisacao_fotos_app_paralisacao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "paralisacao_fotos_app_paralisacao" ON "public"."paralisacao_fotos_app" USING "btree" ("dispositivo_id", "paralisacao_id_local");


--
-- Name: paralisacoes_app_filial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "paralisacoes_app_filial_idx" ON "public"."paralisacoes_app" USING "btree" ("filial_id");


--
-- Name: paralisacoes_app_matricula_inicio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "paralisacoes_app_matricula_inicio" ON "public"."paralisacoes_app" USING "btree" ("usuario_matricula", "inicio");


--
-- Name: perfis_app_matricula_unica; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "perfis_app_matricula_unica" ON "public"."perfis_app" USING "btree" ("matricula");


--
-- Name: registros_app_editado_em_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "registros_app_editado_em_idx" ON "public"."registros_app" USING "btree" ("editado_em") WHERE ("editado_em" IS NOT NULL);


--
-- Name: registros_app_filial_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "registros_app_filial_idx" ON "public"."registros_app" USING "btree" ("filial_id");


--
-- Name: registros_app_matricula_dia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "registros_app_matricula_dia" ON "public"."registros_app" USING "btree" ("usuario_matricula", "criado_em");


--
-- Name: registros_edicoes_registro_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "registros_edicoes_registro_idx" ON "public"."registros_edicoes" USING "btree" ("dispositivo_id", "id_local");


--
-- Name: uso_painel_criado_em; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "uso_painel_criado_em" ON "public"."uso_painel" USING "btree" ("criado_em" DESC);


--
-- Name: uso_painel_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "uso_painel_usuario" ON "public"."uso_painel" USING "btree" ("user_id", "criado_em" DESC);


--
-- Name: aviso_privacidade aviso_privacidade_marca_edicao; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "aviso_privacidade_marca_edicao" BEFORE UPDATE ON "public"."aviso_privacidade" FOR EACH ROW EXECUTE FUNCTION "public"."aviso_privacidade_marca_edicao"();


--
-- Name: dados_da_obra espelhar_no_app_antigo; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "espelhar_no_app_antigo" AFTER INSERT OR UPDATE ON "public"."dados_da_obra" FOR EACH ROW EXECUTE FUNCTION "public"."espelhar_dados_no_app_antigo"();


--
-- Name: registros_app registro_editado; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "registro_editado" BEFORE UPDATE ON "public"."registros_app" FOR EACH ROW EXECUTE FUNCTION "public"."marcar_edicao_registro"();


--
-- Name: admins_painel admins_painel_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."admins_painel"
    ADD CONSTRAINT "admins_painel_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: aviso_privacidade aviso_privacidade_filial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."aviso_privacidade"
    ADD CONSTRAINT "aviso_privacidade_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: clima_dia_app clima_dia_app_filial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."clima_dia_app"
    ADD CONSTRAINT "clima_dia_app_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON UPDATE CASCADE;


--
-- Name: dados_da_obra dados_da_obra_atualizado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."dados_da_obra"
    ADD CONSTRAINT "dados_da_obra_atualizado_por_fkey" FOREIGN KEY ("atualizado_por") REFERENCES "auth"."users"("id") ON DELETE SET NULL;


--
-- Name: dados_da_obra dados_da_obra_filial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."dados_da_obra"
    ADD CONSTRAINT "dados_da_obra_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: equipes_supervisor equipes_supervisor_filial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."equipes_supervisor"
    ADD CONSTRAINT "equipes_supervisor_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON UPDATE CASCADE;


--
-- Name: fotos_app fotos_app_excluida_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."fotos_app"
    ADD CONSTRAINT "fotos_app_excluida_por_fkey" FOREIGN KEY ("excluida_por") REFERENCES "auth"."users"("id");


--
-- Name: fotos_app fotos_app_filial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."fotos_app"
    ADD CONSTRAINT "fotos_app_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON UPDATE CASCADE;


--
-- Name: gestor_app gestor_app_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."gestor_app"
    ADD CONSTRAINT "gestor_app_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: gestores_painel gestores_painel_filial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."gestores_painel"
    ADD CONSTRAINT "gestores_painel_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON UPDATE CASCADE;


--
-- Name: gestores_painel gestores_painel_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."gestores_painel"
    ADD CONSTRAINT "gestores_painel_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: mapas_usuario mapas_usuario_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."mapas_usuario"
    ADD CONSTRAINT "mapas_usuario_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: paralisacao_fotos_app paralisacao_fotos_app_filial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."paralisacao_fotos_app"
    ADD CONSTRAINT "paralisacao_fotos_app_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON UPDATE CASCADE;


--
-- Name: paralisacoes_app paralisacoes_app_filial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."paralisacoes_app"
    ADD CONSTRAINT "paralisacoes_app_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON UPDATE CASCADE;


--
-- Name: perfis_app perfis_app_filial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."perfis_app"
    ADD CONSTRAINT "perfis_app_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON UPDATE CASCADE;


--
-- Name: perfis_app perfis_app_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."perfis_app"
    ADD CONSTRAINT "perfis_app_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: registros_app registros_app_excluido_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."registros_app"
    ADD CONSTRAINT "registros_app_excluido_por_fkey" FOREIGN KEY ("excluido_por") REFERENCES "auth"."users"("id");


--
-- Name: registros_app registros_app_filial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."registros_app"
    ADD CONSTRAINT "registros_app_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON UPDATE CASCADE;


--
-- Name: uso_painel uso_painel_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "public"."uso_painel"
    ADD CONSTRAINT "uso_painel_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: admins_painel Enable delete for users based on user_id; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable delete for users based on user_id" ON "public"."admins_painel" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));


--
-- Name: registros_app admin do painel edita registros; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "admin do painel edita registros" ON "public"."registros_app" FOR UPDATE TO "authenticated" USING ((( SELECT "public"."sou_admin_painel"() AS "sou_admin_painel") AND "public"."pode_administrar"('registros'::"text", "filial_id"))) WITH CHECK ((( SELECT "public"."sou_admin_painel"() AS "sou_admin_painel") AND "public"."pode_administrar"('registros'::"text", "filial_id")));


--
-- Name: fotos_app admin do painel le todas as fotos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "admin do painel le todas as fotos" ON "public"."fotos_app" FOR SELECT TO "authenticated" USING (( SELECT "public"."sou_admin_painel"() AS "sou_admin_painel"));


--
-- Name: registros_app admin do painel le todos os registros; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "admin do painel le todos os registros" ON "public"."registros_app" FOR SELECT TO "authenticated" USING (( SELECT "public"."sou_admin_painel"() AS "sou_admin_painel"));


--
-- Name: admins_painel; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."admins_painel" ENABLE ROW LEVEL SECURITY;

--
-- Name: fotos_app app insere fotos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "app insere fotos" ON "public"."fotos_app" FOR INSERT TO "authenticated" WITH CHECK (true);


--
-- Name: registros_app app insere registros; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "app insere registros" ON "public"."registros_app" FOR INSERT TO "authenticated" WITH CHECK (true);


--
-- Name: aviso_privacidade app le aviso de privacidade; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "app le aviso de privacidade" ON "public"."aviso_privacidade" FOR SELECT TO "authenticated", "anon" USING (true);


--
-- Name: mensagens app le mensagens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "app le mensagens" ON "public"."mensagens" FOR SELECT TO "authenticated", "anon" USING (true);


--
-- Name: versao_app app le versao do app; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "app le versao do app" ON "public"."versao_app" FOR SELECT TO "authenticated", "anon" USING (true);


--
-- Name: versoes_dados app le versoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "app le versoes" ON "public"."versoes_dados" FOR SELECT TO "authenticated", "anon" USING (true);


--
-- Name: aviso_privacidade; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."aviso_privacidade" ENABLE ROW LEVEL SECURITY;

--
-- Name: clima_dia_app; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."clima_dia_app" ENABLE ROW LEVEL SECURITY;

--
-- Name: dados_da_obra; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."dados_da_obra" ENABLE ROW LEVEL SECURITY;

--
-- Name: registros_app dono edita os proprios registros; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "dono edita os proprios registros" ON "public"."registros_app" FOR UPDATE TO "authenticated" USING (("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual"))) WITH CHECK (("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")));


--
-- Name: fotos_app dono ou supervisor troca a foto carimbada; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "dono ou supervisor troca a foto carimbada" ON "public"."fotos_app" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."registros_app" "r"
  WHERE (("r"."dispositivo_id" = "fotos_app"."dispositivo_id") AND ("r"."id_local" = "fotos_app"."registro_id_local") AND (("r"."usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")) OR (( SELECT "public"."e_supervisor"() AS "e_supervisor") AND (EXISTS ( SELECT 1
           FROM "public"."equipes_supervisor" "e"
          WHERE (("e"."supervisor_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")) AND ("e"."encarregado_matricula" = "r"."usuario_matricula")))))))))) WITH CHECK (true);


--
-- Name: equipe_apontada; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."equipe_apontada" ENABLE ROW LEVEL SECURITY;

--
-- Name: equipes_supervisor; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."equipes_supervisor" ENABLE ROW LEVEL SECURITY;

--
-- Name: filiais; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."filiais" ENABLE ROW LEVEL SECURITY;

--
-- Name: fotos_app; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."fotos_app" ENABLE ROW LEVEL SECURITY;

--
-- Name: gestores_painel gestor le a propria linha; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "gestor le a propria linha" ON "public"."gestores_painel" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));


--
-- Name: registros_edicoes gestor le as edicoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "gestor le as edicoes" ON "public"."registros_edicoes" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."gestores_painel" "g"
  WHERE ("g"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));


--
-- Name: fotos_app gestor le todas as fotos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "gestor le todas as fotos" ON "public"."fotos_app" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."gestores_painel" "g"
  WHERE ("g"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));


--
-- Name: registros_app gestor le todos os registros; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "gestor le todos os registros" ON "public"."registros_app" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."gestores_painel" "g"
  WHERE ("g"."user_id" = ( SELECT "auth"."uid"() AS "uid")))));


--
-- Name: uso_painel gestor registra o proprio uso; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "gestor registra o proprio uso" ON "public"."uso_painel" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) AND (EXISTS ( SELECT 1
   FROM "public"."gestores_painel" "g"
  WHERE ("g"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));


--
-- Name: gestor_app; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."gestor_app" ENABLE ROW LEVEL SECURITY;

--
-- Name: gestores_painel; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."gestores_painel" ENABLE ROW LEVEL SECURITY;

--
-- Name: filiais le a config da propria filial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "le a config da propria filial" ON "public"."filiais" FOR SELECT TO "authenticated" USING ((("id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais")));


--
-- Name: equipe_apontada le a equipe apontada propria, da equipe ou do painel; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "le a equipe apontada propria, da equipe ou do painel" ON "public"."equipe_apontada" FOR SELECT TO "authenticated" USING ((("split_part"("encarregado", '::'::"text", 1) = ( SELECT "public"."matricula_atual"() AS "matricula_atual")) OR ("split_part"("encarregado", '::'::"text", 1) IN ( SELECT "e"."encarregado_matricula"
   FROM "public"."equipes_supervisor" "e"
  WHERE (( SELECT "public"."e_supervisor"() AS "e_supervisor") AND ("e"."supervisor_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual"))))) OR (EXISTS ( SELECT 1
   FROM "public"."gestores_painel" "g"
  WHERE ("g"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));


--
-- Name: paralisacao_fotos_app le fotos de paralisacao proprias ou da equipe; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "le fotos de paralisacao proprias ou da equipe" ON "public"."paralisacao_fotos_app" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."paralisacoes_app" "p"
  WHERE (("p"."dispositivo_id" = "paralisacao_fotos_app"."dispositivo_id") AND ("p"."id_local" = "paralisacao_fotos_app"."paralisacao_id_local") AND (("p"."usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")) OR (( SELECT "public"."e_supervisor"() AS "e_supervisor") AND (EXISTS ( SELECT 1
           FROM "public"."equipes_supervisor" "e"
          WHERE (("e"."supervisor_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")) AND ("e"."encarregado_matricula" = "p"."usuario_matricula"))))))))));


--
-- Name: dados_da_obra le os dados da propria filial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "le os dados da propria filial" ON "public"."dados_da_obra" FOR SELECT TO "authenticated" USING ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais") OR "public"."pode_administrar"('dados'::"text", "filial_id")));


--
-- Name: mapas_usuario; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."mapas_usuario" ENABLE ROW LEVEL SECURITY;

--
-- Name: mensagens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."mensagens" ENABLE ROW LEVEL SECURITY;

--
-- Name: paralisacao_fotos_app; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."paralisacao_fotos_app" ENABLE ROW LEVEL SECURITY;

--
-- Name: paralisacoes_app; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."paralisacoes_app" ENABLE ROW LEVEL SECURITY;

--
-- Name: perfis_app; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."perfis_app" ENABLE ROW LEVEL SECURITY;

--
-- Name: registros_app; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."registros_app" ENABLE ROW LEVEL SECURITY;

--
-- Name: registros_edicoes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."registros_edicoes" ENABLE ROW LEVEL SECURITY;

--
-- Name: clima_dia_app so a propria filial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "so a propria filial" ON "public"."clima_dia_app" AS RESTRICTIVE TO "authenticated" USING ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais"))) WITH CHECK ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais")));


--
-- Name: equipes_supervisor so a propria filial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "so a propria filial" ON "public"."equipes_supervisor" AS RESTRICTIVE TO "authenticated" USING ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais"))) WITH CHECK ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais")));


--
-- Name: fotos_app so a propria filial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "so a propria filial" ON "public"."fotos_app" AS RESTRICTIVE TO "authenticated" USING ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais"))) WITH CHECK ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais")));


--
-- Name: paralisacao_fotos_app so a propria filial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "so a propria filial" ON "public"."paralisacao_fotos_app" AS RESTRICTIVE TO "authenticated" USING ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais"))) WITH CHECK ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais")));


--
-- Name: paralisacoes_app so a propria filial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "so a propria filial" ON "public"."paralisacoes_app" AS RESTRICTIVE TO "authenticated" USING ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais"))) WITH CHECK ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais")));


--
-- Name: registros_app so a propria filial; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "so a propria filial" ON "public"."registros_app" AS RESTRICTIVE TO "authenticated" USING ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais"))) WITH CHECK ((("filial_id" = ( SELECT "public"."filial_atual"() AS "filial_atual")) OR ( SELECT "public"."ve_todas_as_filiais"() AS "ve_todas_as_filiais")));


--
-- Name: registros_app supervisor edita registros da equipe; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "supervisor edita registros da equipe" ON "public"."registros_app" FOR UPDATE TO "authenticated" USING ((( SELECT "public"."e_supervisor"() AS "e_supervisor") AND (EXISTS ( SELECT 1
   FROM "public"."equipes_supervisor" "e"
  WHERE (("e"."supervisor_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")) AND ("e"."encarregado_matricula" = "registros_app"."usuario_matricula")))))) WITH CHECK ((( SELECT "public"."e_supervisor"() AS "e_supervisor") AND (EXISTS ( SELECT 1
   FROM "public"."equipes_supervisor" "e"
  WHERE (("e"."supervisor_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")) AND ("e"."encarregado_matricula" = "registros_app"."usuario_matricula"))))));


--
-- Name: equipes_supervisor supervisor gerencia a propria equipe; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "supervisor gerencia a propria equipe" ON "public"."equipes_supervisor" TO "authenticated" USING ((( SELECT "public"."e_supervisor"() AS "e_supervisor") AND ("supervisor_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")))) WITH CHECK ((( SELECT "public"."e_supervisor"() AS "e_supervisor") AND ("supervisor_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual"))));


--
-- Name: clima_dia_app supervisor le clima da equipe; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "supervisor le clima da equipe" ON "public"."clima_dia_app" FOR SELECT TO "authenticated" USING ((( SELECT "public"."e_supervisor"() AS "e_supervisor") AND (EXISTS ( SELECT 1
   FROM "public"."equipes_supervisor" "e"
  WHERE (("e"."supervisor_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")) AND ("e"."encarregado_matricula" = "clima_dia_app"."usuario_matricula"))))));


--
-- Name: fotos_app supervisor le fotos da equipe; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "supervisor le fotos da equipe" ON "public"."fotos_app" FOR SELECT TO "authenticated" USING ((( SELECT "public"."e_supervisor"() AS "e_supervisor") AND (EXISTS ( SELECT 1
   FROM ("public"."registros_app" "r"
     JOIN "public"."equipes_supervisor" "e" ON (("e"."encarregado_matricula" = "r"."usuario_matricula")))
  WHERE (("r"."dispositivo_id" = "fotos_app"."dispositivo_id") AND ("r"."id_local" = "fotos_app"."registro_id_local") AND ("e"."supervisor_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")))))));


--
-- Name: paralisacoes_app supervisor le paralisacoes da equipe; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "supervisor le paralisacoes da equipe" ON "public"."paralisacoes_app" FOR SELECT TO "authenticated" USING ((( SELECT "public"."e_supervisor"() AS "e_supervisor") AND (EXISTS ( SELECT 1
   FROM "public"."equipes_supervisor" "e"
  WHERE (("e"."supervisor_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")) AND ("e"."encarregado_matricula" = "paralisacoes_app"."usuario_matricula"))))));


--
-- Name: registros_app supervisor le registros da equipe; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "supervisor le registros da equipe" ON "public"."registros_app" FOR SELECT TO "authenticated" USING ((( SELECT "public"."e_supervisor"() AS "e_supervisor") AND (EXISTS ( SELECT 1
   FROM "public"."equipes_supervisor" "e"
  WHERE (("e"."supervisor_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")) AND ("e"."encarregado_matricula" = "registros_app"."usuario_matricula"))))));


--
-- Name: uso_painel; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."uso_painel" ENABLE ROW LEVEL SECURITY;

--
-- Name: paralisacoes_app usuario corrige as proprias paralisacoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuario corrige as proprias paralisacoes" ON "public"."paralisacoes_app" FOR UPDATE TO "authenticated" USING (("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual"))) WITH CHECK (("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")));


--
-- Name: clima_dia_app usuario corrige o proprio clima; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuario corrige o proprio clima" ON "public"."clima_dia_app" FOR UPDATE TO "authenticated" USING (("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual"))) WITH CHECK (("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")));


--
-- Name: paralisacoes_app usuario envia as proprias paralisacoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuario envia as proprias paralisacoes" ON "public"."paralisacoes_app" FOR INSERT TO "authenticated" WITH CHECK (("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")));


--
-- Name: paralisacao_fotos_app usuario envia fotos das proprias paralisacoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuario envia fotos das proprias paralisacoes" ON "public"."paralisacao_fotos_app" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."paralisacoes_app" "p"
  WHERE (("p"."dispositivo_id" = "paralisacao_fotos_app"."dispositivo_id") AND ("p"."id_local" = "paralisacao_fotos_app"."paralisacao_id_local") AND ("p"."usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual"))))));


--
-- Name: clima_dia_app usuario envia o proprio clima; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuario envia o proprio clima" ON "public"."clima_dia_app" FOR INSERT TO "authenticated" WITH CHECK (("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")));


--
-- Name: mapas_usuario usuario le a propria permissao de mapa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuario le a propria permissao de mapa" ON "public"."mapas_usuario" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));


--
-- Name: fotos_app usuario le as proprias fotos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuario le as proprias fotos" ON "public"."fotos_app" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."registros_app" "r"
  WHERE (("r"."dispositivo_id" = "fotos_app"."dispositivo_id") AND ("r"."id_local" = "fotos_app"."registro_id_local") AND ("r"."usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual"))))));


--
-- Name: paralisacoes_app usuario le as proprias paralisacoes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuario le as proprias paralisacoes" ON "public"."paralisacoes_app" FOR SELECT TO "authenticated" USING (("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")));


--
-- Name: clima_dia_app usuario le o proprio clima; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuario le o proprio clima" ON "public"."clima_dia_app" FOR SELECT TO "authenticated" USING (("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")));


--
-- Name: perfis_app usuario le o proprio perfil; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuario le o proprio perfil" ON "public"."perfis_app" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));


--
-- Name: registros_app usuario le os proprios registros; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuario le os proprios registros" ON "public"."registros_app" FOR SELECT TO "authenticated" USING (("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")));


--
-- Name: versao_app; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."versao_app" ENABLE ROW LEVEL SECURITY;

--
-- Name: versoes_dados; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE "public"."versoes_dados" ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA "public"; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";


--
-- Name: FUNCTION "aplicar_acessos_de_usuario"("p_user" "uuid", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean, "p_conta_nova" boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."aplicar_acessos_de_usuario"("p_user" "uuid", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean, "p_conta_nova" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."aplicar_acessos_de_usuario"("p_user" "uuid", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean, "p_conta_nova" boolean) TO "service_role";


--
-- Name: FUNCTION "aviso_privacidade_marca_edicao"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."aviso_privacidade_marca_edicao"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."aviso_privacidade_marca_edicao"() TO "service_role";


--
-- Name: FUNCTION "concluir_troca_de_senha"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."concluir_troca_de_senha"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."concluir_troca_de_senha"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."concluir_troca_de_senha"() TO "service_role";


--
-- Name: FUNCTION "concluir_troca_de_senha_app"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."concluir_troca_de_senha_app"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."concluir_troca_de_senha_app"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."concluir_troca_de_senha_app"() TO "service_role";


--
-- Name: FUNCTION "criar_perfil_da_nova_conta"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."criar_perfil_da_nova_conta"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."criar_perfil_da_nova_conta"() TO "service_role";


--
-- Name: FUNCTION "dados_da_obra_painel"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."dados_da_obra_painel"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."dados_da_obra_painel"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."dados_da_obra_painel"() TO "service_role";


--
-- Name: FUNCTION "dados_registrar_envio"("p_filial" "text", "p_nome" "text", "p_arquivo" "text"); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."dados_registrar_envio"("p_filial" "text", "p_nome" "text", "p_arquivo" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."dados_registrar_envio"("p_filial" "text", "p_nome" "text", "p_arquivo" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."dados_registrar_envio"("p_filial" "text", "p_nome" "text", "p_arquivo" "text") TO "service_role";


--
-- Name: FUNCTION "e_supervisor"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."e_supervisor"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."e_supervisor"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."e_supervisor"() TO "service_role";


--
-- Name: FUNCTION "encarregados_do_painel"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."encarregados_do_painel"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."encarregados_do_painel"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."encarregados_do_painel"() TO "service_role";


--
-- Name: FUNCTION "espelhar_dados_no_app_antigo"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."espelhar_dados_no_app_antigo"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."espelhar_dados_no_app_antigo"() TO "service_role";


--
-- Name: FUNCTION "excluir_foto_painel"("p_id" bigint, "p_motivo" "text"); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."excluir_foto_painel"("p_id" bigint, "p_motivo" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."excluir_foto_painel"("p_id" bigint, "p_motivo" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."excluir_foto_painel"("p_id" bigint, "p_motivo" "text") TO "service_role";


--
-- Name: FUNCTION "excluir_registro_painel"("p_id" bigint, "p_motivo" "text"); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."excluir_registro_painel"("p_id" bigint, "p_motivo" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."excluir_registro_painel"("p_id" bigint, "p_motivo" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."excluir_registro_painel"("p_id" bigint, "p_motivo" "text") TO "service_role";


--
-- Name: FUNCTION "exigir_admin_geral"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."exigir_admin_geral"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."exigir_admin_geral"() TO "service_role";


--
-- Name: FUNCTION "exigir_admin_painel"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."exigir_admin_painel"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."exigir_admin_painel"() TO "service_role";


--
-- Name: FUNCTION "exigir_gestao_de_usuario"("p_user" "uuid"); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."exigir_gestao_de_usuario"("p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."exigir_gestao_de_usuario"("p_user" "uuid") TO "service_role";


--
-- Name: FUNCTION "filial_atual"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."filial_atual"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."filial_atual"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."filial_atual"() TO "service_role";


--
-- Name: FUNCTION "filial_do_admin"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."filial_do_admin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."filial_do_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."filial_do_admin"() TO "service_role";


--
-- Name: FUNCTION "fotos_excluidas_painel"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."fotos_excluidas_painel"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."fotos_excluidas_painel"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fotos_excluidas_painel"() TO "service_role";


--
-- Name: FUNCTION "gerar_senha_provisoria"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."gerar_senha_provisoria"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."gerar_senha_provisoria"() TO "service_role";


--
-- Name: FUNCTION "gestao_bloquear_usuario"("p_user" "uuid", "p_bloquear" boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."gestao_bloquear_usuario"("p_user" "uuid", "p_bloquear" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."gestao_bloquear_usuario"("p_user" "uuid", "p_bloquear" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."gestao_bloquear_usuario"("p_user" "uuid", "p_bloquear" boolean) TO "service_role";


--
-- Name: FUNCTION "gestao_criar_usuario"("p_email" "text", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."gestao_criar_usuario"("p_email" "text", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."gestao_criar_usuario"("p_email" "text", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."gestao_criar_usuario"("p_email" "text", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean) TO "service_role";


--
-- Name: FUNCTION "gestao_listar_filiais"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."gestao_listar_filiais"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."gestao_listar_filiais"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."gestao_listar_filiais"() TO "service_role";


--
-- Name: FUNCTION "gestao_listar_usuarios"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."gestao_listar_usuarios"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."gestao_listar_usuarios"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."gestao_listar_usuarios"() TO "service_role";


--
-- Name: FUNCTION "gestao_salvar_filial"("p_id" "text", "p_nome" "text", "p_config" "jsonb", "p_copiar_de" "text", "p_permissoes" "jsonb"); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."gestao_salvar_filial"("p_id" "text", "p_nome" "text", "p_config" "jsonb", "p_copiar_de" "text", "p_permissoes" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."gestao_salvar_filial"("p_id" "text", "p_nome" "text", "p_config" "jsonb", "p_copiar_de" "text", "p_permissoes" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gestao_salvar_filial"("p_id" "text", "p_nome" "text", "p_config" "jsonb", "p_copiar_de" "text", "p_permissoes" "jsonb") TO "service_role";


--
-- Name: FUNCTION "gestao_salvar_usuario"("p_user" "uuid", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."gestao_salvar_usuario"("p_user" "uuid", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."gestao_salvar_usuario"("p_user" "uuid", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."gestao_salvar_usuario"("p_user" "uuid", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean) TO "service_role";


--
-- Name: FUNCTION "gestao_senha_provisoria"("p_user" "uuid"); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."gestao_senha_provisoria"("p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."gestao_senha_provisoria"("p_user" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gestao_senha_provisoria"("p_user" "uuid") TO "service_role";


--
-- Name: FUNCTION "marcar_edicao_registro"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."marcar_edicao_registro"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."marcar_edicao_registro"() TO "service_role";


--
-- Name: FUNCTION "matricula_atual"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."matricula_atual"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."matricula_atual"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."matricula_atual"() TO "service_role";


--
-- Name: FUNCTION "meu_papel_admin"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."meu_papel_admin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."meu_papel_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."meu_papel_admin"() TO "service_role";


--
-- Name: FUNCTION "movimentacoes_painel"("p_de" timestamp with time zone, "p_ate" timestamp with time zone, "p_user" "uuid", "p_evento" "text", "p_limite" integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."movimentacoes_painel"("p_de" timestamp with time zone, "p_ate" timestamp with time zone, "p_user" "uuid", "p_evento" "text", "p_limite" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."movimentacoes_painel"("p_de" timestamp with time zone, "p_ate" timestamp with time zone, "p_user" "uuid", "p_evento" "text", "p_limite" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."movimentacoes_painel"("p_de" timestamp with time zone, "p_ate" timestamp with time zone, "p_user" "uuid", "p_evento" "text", "p_limite" integer) TO "service_role";


--
-- Name: FUNCTION "pode_administrar"("p_permissao" "text", "p_filial" "text"); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."pode_administrar"("p_permissao" "text", "p_filial" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pode_administrar"("p_permissao" "text", "p_filial" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pode_administrar"("p_permissao" "text", "p_filial" "text") TO "service_role";


--
-- Name: FUNCTION "pode_enviar_dados"("p_caminho" "text"); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."pode_enviar_dados"("p_caminho" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pode_enviar_dados"("p_caminho" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pode_enviar_dados"("p_caminho" "text") TO "service_role";


--
-- Name: FUNCTION "registros_excluidos_painel"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."registros_excluidos_painel"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."registros_excluidos_painel"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."registros_excluidos_painel"() TO "service_role";


--
-- Name: FUNCTION "restaurar_foto_painel"("p_id" bigint); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."restaurar_foto_painel"("p_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."restaurar_foto_painel"("p_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."restaurar_foto_painel"("p_id" bigint) TO "service_role";


--
-- Name: FUNCTION "restaurar_registro_painel"("p_id" bigint); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."restaurar_registro_painel"("p_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."restaurar_registro_painel"("p_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."restaurar_registro_painel"("p_id" bigint) TO "service_role";


--
-- Name: FUNCTION "resumo_uso_painel"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."resumo_uso_painel"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."resumo_uso_painel"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."resumo_uso_painel"() TO "service_role";


--
-- Name: FUNCTION "sou_admin_geral"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."sou_admin_geral"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sou_admin_geral"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sou_admin_geral"() TO "service_role";


--
-- Name: FUNCTION "sou_admin_painel"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."sou_admin_painel"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sou_admin_painel"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sou_admin_painel"() TO "service_role";


--
-- Name: FUNCTION "ve_todas_as_filiais"(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION "public"."ve_todas_as_filiais"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ve_todas_as_filiais"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."ve_todas_as_filiais"() TO "service_role";


--
-- Name: TABLE "admins_painel"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."admins_painel" TO "anon";
GRANT ALL ON TABLE "public"."admins_painel" TO "authenticated";
GRANT ALL ON TABLE "public"."admins_painel" TO "service_role";


--
-- Name: TABLE "aviso_privacidade"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."aviso_privacidade" TO "anon";
GRANT ALL ON TABLE "public"."aviso_privacidade" TO "authenticated";
GRANT ALL ON TABLE "public"."aviso_privacidade" TO "service_role";


--
-- Name: TABLE "clima_dia_app"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."clima_dia_app" TO "anon";
GRANT ALL ON TABLE "public"."clima_dia_app" TO "authenticated";
GRANT ALL ON TABLE "public"."clima_dia_app" TO "service_role";


--
-- Name: TABLE "dados_da_obra"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."dados_da_obra" TO "anon";
GRANT ALL ON TABLE "public"."dados_da_obra" TO "authenticated";
GRANT ALL ON TABLE "public"."dados_da_obra" TO "service_role";


--
-- Name: TABLE "equipe_apontada"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."equipe_apontada" TO "anon";
GRANT ALL ON TABLE "public"."equipe_apontada" TO "authenticated";
GRANT ALL ON TABLE "public"."equipe_apontada" TO "service_role";


--
-- Name: SEQUENCE "equipe_apontada_id_seq"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE "public"."equipe_apontada_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."equipe_apontada_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."equipe_apontada_id_seq" TO "service_role";


--
-- Name: TABLE "equipe_apontamento"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."equipe_apontamento" TO "authenticated";
GRANT ALL ON TABLE "public"."equipe_apontamento" TO "service_role";


--
-- Name: TABLE "equipes_supervisor"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."equipes_supervisor" TO "anon";
GRANT ALL ON TABLE "public"."equipes_supervisor" TO "authenticated";
GRANT ALL ON TABLE "public"."equipes_supervisor" TO "service_role";


--
-- Name: TABLE "filiais"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."filiais" TO "anon";
GRANT ALL ON TABLE "public"."filiais" TO "authenticated";
GRANT ALL ON TABLE "public"."filiais" TO "service_role";


--
-- Name: TABLE "fotos_app"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."fotos_app" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."fotos_app" TO "authenticated";
GRANT ALL ON TABLE "public"."fotos_app" TO "service_role";


--
-- Name: COLUMN "fotos_app"."caminho_storage"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("caminho_storage") ON TABLE "public"."fotos_app" TO "authenticated";


--
-- Name: SEQUENCE "fotos_app_id_seq"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE "public"."fotos_app_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."fotos_app_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."fotos_app_id_seq" TO "service_role";


--
-- Name: TABLE "gestor_app"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."gestor_app" TO "anon";
GRANT ALL ON TABLE "public"."gestor_app" TO "authenticated";
GRANT ALL ON TABLE "public"."gestor_app" TO "service_role";


--
-- Name: TABLE "gestores_painel"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."gestores_painel" TO "anon";
GRANT ALL ON TABLE "public"."gestores_painel" TO "authenticated";
GRANT ALL ON TABLE "public"."gestores_painel" TO "service_role";


--
-- Name: TABLE "mapas_usuario"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."mapas_usuario" TO "anon";
GRANT ALL ON TABLE "public"."mapas_usuario" TO "authenticated";
GRANT ALL ON TABLE "public"."mapas_usuario" TO "service_role";


--
-- Name: TABLE "mensagens"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."mensagens" TO "anon";
GRANT ALL ON TABLE "public"."mensagens" TO "authenticated";
GRANT ALL ON TABLE "public"."mensagens" TO "service_role";


--
-- Name: SEQUENCE "mensagens_id_seq"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE "public"."mensagens_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."mensagens_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."mensagens_id_seq" TO "service_role";


--
-- Name: TABLE "paralisacao_fotos_app"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."paralisacao_fotos_app" TO "anon";
GRANT ALL ON TABLE "public"."paralisacao_fotos_app" TO "authenticated";
GRANT ALL ON TABLE "public"."paralisacao_fotos_app" TO "service_role";


--
-- Name: SEQUENCE "paralisacao_fotos_app_id_seq"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE "public"."paralisacao_fotos_app_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."paralisacao_fotos_app_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."paralisacao_fotos_app_id_seq" TO "service_role";


--
-- Name: TABLE "paralisacoes_app"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."paralisacoes_app" TO "anon";
GRANT ALL ON TABLE "public"."paralisacoes_app" TO "authenticated";
GRANT ALL ON TABLE "public"."paralisacoes_app" TO "service_role";


--
-- Name: SEQUENCE "paralisacoes_app_id_seq"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE "public"."paralisacoes_app_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."paralisacoes_app_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."paralisacoes_app_id_seq" TO "service_role";


--
-- Name: TABLE "perfis_app"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."perfis_app" TO "anon";
GRANT ALL ON TABLE "public"."perfis_app" TO "authenticated";
GRANT ALL ON TABLE "public"."perfis_app" TO "service_role";


--
-- Name: TABLE "registros_app"; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."registros_app" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."registros_app" TO "authenticated";
GRANT ALL ON TABLE "public"."registros_app" TO "service_role";


--
-- Name: COLUMN "registros_app"."trecho"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("trecho") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: COLUMN "registros_app"."km"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("km") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: COLUMN "registros_app"."via"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("via") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: COLUMN "registros_app"."atividade"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("atividade") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: COLUMN "registros_app"."estaca_inicial"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("estaca_inicial") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: COLUMN "registros_app"."estaca_final"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("estaca_final") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: COLUMN "registros_app"."servico_notavel"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("servico_notavel") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: COLUMN "registros_app"."descricao"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("descricao") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: COLUMN "registros_app"."servico_notavel_detalhe"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("servico_notavel_detalhe") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: COLUMN "registros_app"."quantidade"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("quantidade") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: COLUMN "registros_app"."unidade"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("unidade") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: COLUMN "registros_app"."km_final"; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE("km_final") ON TABLE "public"."registros_app" TO "authenticated";


--
-- Name: SEQUENCE "registros_app_id_seq"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE "public"."registros_app_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."registros_app_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."registros_app_id_seq" TO "service_role";


--
-- Name: TABLE "registros_edicoes"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."registros_edicoes" TO "anon";
GRANT ALL ON TABLE "public"."registros_edicoes" TO "authenticated";
GRANT ALL ON TABLE "public"."registros_edicoes" TO "service_role";


--
-- Name: SEQUENCE "registros_edicoes_id_seq"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE "public"."registros_edicoes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."registros_edicoes_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."registros_edicoes_id_seq" TO "service_role";


--
-- Name: TABLE "uso_painel"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."uso_painel" TO "anon";
GRANT ALL ON TABLE "public"."uso_painel" TO "authenticated";
GRANT ALL ON TABLE "public"."uso_painel" TO "service_role";


--
-- Name: SEQUENCE "uso_painel_id_seq"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE "public"."uso_painel_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."uso_painel_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."uso_painel_id_seq" TO "service_role";


--
-- Name: TABLE "versao_app"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."versao_app" TO "anon";
GRANT ALL ON TABLE "public"."versao_app" TO "authenticated";
GRANT ALL ON TABLE "public"."versao_app" TO "service_role";


--
-- Name: TABLE "versoes_dados"; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE "public"."versoes_dados" TO "anon";
GRANT ALL ON TABLE "public"."versoes_dados" TO "authenticated";
GRANT ALL ON TABLE "public"."versoes_dados" TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";

-- Daqui pra baixo é o que fica no storage e no auth. As funções são do public,
-- e o pg_dump zerou o search_path lá em cima.
SELECT pg_catalog.set_config('search_path', 'public, extensions', false);

-- policies do storage.objects
create policy "adm envia dados da obra" on storage.objects as PERMISSIVE for INSERT to authenticated with check (((bucket_id = 'dados'::text) AND pode_enviar_dados(name)));
create policy "admin do painel le os arquivos das fotos" on storage.objects as PERMISSIVE for SELECT to authenticated using (((bucket_id = 'fotos'::text) AND ( SELECT sou_admin_painel() AS sou_admin_painel)));
create policy "app sobe fotos" on storage.objects as PERMISSIVE for INSERT to authenticated with check ((bucket_id = 'fotos'::text));
create policy "gestor le todas as fotos no storage" on storage.objects as PERMISSIVE for SELECT to authenticated using (((bucket_id = 'fotos'::text) AND (EXISTS ( SELECT 1
   FROM gestores_painel g
  WHERE (g.user_id = auth.uid())))));
create policy "le fotos de paralisacao no storage" on storage.objects as PERMISSIVE for SELECT to authenticated using (((bucket_id = 'fotos'::text) AND (EXISTS ( SELECT 1
   FROM (paralisacao_fotos_app f
     JOIN paralisacoes_app p ON (((p.dispositivo_id = f.dispositivo_id) AND (p.id_local = f.paralisacao_id_local))))
  WHERE ((f.caminho_storage = objects.name) AND ((p.usuario_matricula = matricula_atual()) OR (e_supervisor() AND (EXISTS ( SELECT 1
           FROM equipes_supervisor e
          WHERE ((e.supervisor_matricula = matricula_atual()) AND (e.encarregado_matricula = p.usuario_matricula)))))))))));
create policy "le fotos proprias ou da equipe" on storage.objects as PERMISSIVE for SELECT to authenticated using (((bucket_id = 'fotos'::text) AND (EXISTS ( SELECT 1
   FROM (fotos_app f
     JOIN registros_app r ON (((r.dispositivo_id = f.dispositivo_id) AND (r.id_local = f.registro_id_local))))
  WHERE ((((objects.name = f.caminho_storage) OR (objects.name = f.caminho_original_storage)) OR (objects.name = f.caminho_minimapa_storage)) AND ((r.usuario_matricula = ( SELECT matricula_atual() AS matricula_atual)) OR (( SELECT e_supervisor() AS e_supervisor) AND (EXISTS ( SELECT 1
           FROM equipes_supervisor e
          WHERE ((e.supervisor_matricula = ( SELECT matricula_atual() AS matricula_atual)) AND (e.encarregado_matricula = r.usuario_matricula)))))))))));

-- cria o perfil quando cria a conta
CREATE TRIGGER perfil_da_nova_conta AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION criar_perfil_da_nova_conta();

-- buckets
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('dados', 'dados', 't', null, NULL) on conflict (id) do nothing;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('fotos', 'fotos', 'f', null, NULL) on conflict (id) do nothing;

-- supervisor do app com o mesmo acesso do admObra, só no app: abre
-- "Registros dos usuários", vê os registros e as fotos da filial dele e corrige
-- qualquer registro da filial quando a obra tem a permissão "registros".
--
-- o app pergunta sou_admin_painel() pra mostrar essa tela, então ela passa a
-- dizer true também pro supervisor. o painel não usa essa função (entra por
-- gestores_painel e o papel vem de meu_papel_admin), mas as funções do painel
-- usavam. elas passam a olhar admins_painel direto, em e_admin_do_painel(),
-- pro supervisor não ganhar nada do painel.

-- admin do painel de verdade (linha em admins_painel).
create or replace function public.e_admin_do_painel() returns boolean
  language sql stable security definer
  set search_path to 'public'
as $$
  select exists (select 1 from public.admins_painel a where a.user_id = auth.uid())
$$;

revoke all on function public.e_admin_do_painel() from public;
grant all on function public.e_admin_do_painel() to authenticated;
grant all on function public.e_admin_do_painel() to service_role;

-- funções do painel: continuam só pro admin do painel. o corpo é o mesmo da
-- estrutura inicial, só troca sou_admin_painel() por e_admin_do_painel(). no
-- marcar_edicao_registro, a correção do supervisor fica com a matrícula dele.

CREATE OR REPLACE FUNCTION "public"."exigir_admin_painel"() RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.e_admin_do_painel() then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."fotos_excluidas_painel"() RETURNS TABLE("id" bigint, "caminho_storage" "text", "foto_criada_em" timestamp with time zone, "excluida_em" timestamp with time zone, "excluida_por" "text", "motivo" "text", "encarregado" "text", "trecho" "text", "servico" "text", "estacas" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_geral boolean := public.sou_admin_geral();
  v_minha text := public.filial_do_admin();
begin
  if not public.e_admin_do_painel() then
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

CREATE OR REPLACE FUNCTION "public"."movimentacoes_painel"("p_de" timestamp with time zone, "p_ate" timestamp with time zone, "p_user" "uuid" DEFAULT NULL::"uuid", "p_evento" "text" DEFAULT NULL::"text", "p_limite" integer DEFAULT 2000) RETURNS TABLE("criado_em" timestamp with time zone, "user_id" "uuid", "nome" "text", "email" "text", "evento" "text", "detalhes" "jsonb", "dispositivo" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_geral boolean := public.sou_admin_geral();
  v_minha text := public.filial_do_admin();
begin
  if not public.e_admin_do_painel() then
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

CREATE OR REPLACE FUNCTION "public"."registros_excluidos_painel"() RETURNS TABLE("id" bigint, "criado_em" timestamp with time zone, "encarregado" "text", "trecho" "text", "km" "text", "estacas" "text", "atividade" "text", "servico" "text", "fotos" bigint, "excluido_em" timestamp with time zone, "excluido_por" "text", "motivo" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_geral boolean := public.sou_admin_geral();
  v_minha text := public.filial_do_admin();
begin
  if not public.e_admin_do_painel() then
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

CREATE OR REPLACE FUNCTION "public"."resumo_uso_painel"() RETURNS TABLE("user_id" "uuid", "nome" "text", "email" "text", "liberado_em" timestamp with time zone, "ultimo_login" timestamp with time zone, "trocar_senha" boolean, "ultimo_uso" timestamp with time zone, "acessos_30d" bigint, "dias_30d" bigint, "pdfs_30d" bigint, "mapas_30d" bigint, "dispositivos" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_geral boolean := public.sou_admin_geral();
  v_minha text := public.filial_do_admin();
begin
  if not public.e_admin_do_painel() then
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

CREATE OR REPLACE FUNCTION "public"."marcar_edicao_registro"() RETURNS "trigger"
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
  if public.e_admin_do_painel() then
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

-- o nome é do tempo em que só o admin via essa tela no app.
create or replace function public.sou_admin_painel() returns boolean
  language sql stable security definer
  set search_path to 'public'
as $$
  select public.e_admin_do_painel() or public.e_supervisor()
$$;

-- igual ao admObra: o supervisor corrige qualquer registro da filial quando o
-- ADMapp liberou "registros" pra obra. sem isso, continua só a equipe dele
-- (policy "supervisor edita registros da equipe").
create or replace function public.supervisor_corrige_na_filial(p_filial text) returns boolean
  language sql stable security definer
  set search_path to 'public'
as $$
  select public.e_supervisor()
     and exists (select 1 from public.filiais f
                  where f.id = p_filial
                    and coalesce((f.permissoes_adm ->> 'registros')::boolean, false))
$$;

revoke all on function public.supervisor_corrige_na_filial(text) from public;
grant all on function public.supervisor_corrige_na_filial(text) to authenticated;
grant all on function public.supervisor_corrige_na_filial(text) to service_role;

drop policy if exists "supervisor edita registros da filial" on public.registros_app;
create policy "supervisor edita registros da filial" on public.registros_app
  for update to authenticated
  using (public.supervisor_corrige_na_filial(filial_id))
  with check (public.supervisor_corrige_na_filial(filial_id));

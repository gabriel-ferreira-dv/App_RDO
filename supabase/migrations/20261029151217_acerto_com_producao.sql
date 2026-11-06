-- produção mudou por fora das migrations depois de 26/10: rodaram o
-- supabase_consultas/painel_adm_obra.sql (senha provisória e correção que
-- aparece só como "admin") e mexeram nas policies do bucket dados pelo
-- painel do Supabase. aqui vai o que está em produção hoje, copiado do dump
-- de 29/10, pra preview e produção ficarem iguais. em produção isso não muda
-- nada.
--
-- e corrige a migration do supervisor, que foi feita em cima do dump de 26/10
-- e desfaria a senha provisória e o "admin" na correção. continua valendo:
-- supervisor com acesso de admObra só no app.

-- ── senha provisória ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION "public"."senha_provisoria_pendente"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.gestores_painel g
                 where g.user_id = auth.uid() and g.trocar_senha)
$$;

REVOKE ALL ON FUNCTION "public"."senha_provisoria_pendente"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."senha_provisoria_pendente"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."senha_provisoria_pendente"() TO "service_role";

-- ── quem é admin ──────────────────────────────────────────────────────────
-- admin do painel de verdade: linha em admins_painel e sem senha provisória.
-- as funções do painel conferem esta.

CREATE OR REPLACE FUNCTION "public"."e_admin_do_painel"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.admins_painel a where a.user_id = auth.uid())
     and not public.senha_provisoria_pendente()
$$;

-- o app pergunta esta pra mostrar "Registros dos usuários".

CREATE OR REPLACE FUNCTION "public"."sou_admin_painel"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.e_admin_do_painel() or public.e_supervisor()
$$;

-- em produção chamava sou_admin_painel(): com o supervisor ali dentro,
-- passa a olhar só o admin do painel.

CREATE OR REPLACE FUNCTION "public"."sou_admin_geral"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.gestor_app ga where ga.user_id = auth.uid())
     and public.e_admin_do_painel()
$$;

CREATE OR REPLACE FUNCTION "public"."filial_do_admin"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select g.filial_id
  from public.admins_painel a
  join public.gestores_painel g on g.user_id = a.user_id
  where a.user_id = auth.uid() and g.filial_id is not null and not g.trocar_senha
$$;

CREATE OR REPLACE FUNCTION "public"."pode_administrar"("p_permissao" "text", "p_filial" "text") RETURNS boolean
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
          and not g.trocar_senha
          and coalesce((f.permissoes_adm ->> p_permissao)::boolean, false)
      )
$$;

CREATE OR REPLACE FUNCTION "public"."concluir_troca_de_senha"() RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  update public.gestores_painel set trocar_senha = false where user_id = auth.uid();
  update public.perfis_app set trocar_senha = false where user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION "public"."aplicar_acessos_de_usuario"("p_user" "uuid", "p_nome" "text", "p_app" boolean, "p_matricula" "text", "p_supervisor" boolean, "p_filial" "text", "p_painel" boolean, "p_filial_painel" "text", "p_admin" boolean, "p_conta_nova" boolean) RETURNS "void"
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

-- ── correção de registro ──────────────────────────────────────────────────
-- a versão de produção, olhando só o admin do painel: a correção do
-- supervisor fica com a matrícula dele.

ALTER TABLE "public"."registros_edicoes" ADD COLUMN IF NOT EXISTS "editado_por_uid" "uuid";

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
    quem := 'admin';
  end if;

  foreach campo in array array['trecho', 'km', 'km_final', 'via', 'atividade',
                               'estaca_inicial', 'estaca_final', 'servico_notavel',
                               'servico_notavel_detalhe', 'quantidade', 'unidade',
                               'descricao'] loop
    if antes -> campo is distinct from depois -> campo then
      mudou := true;
      insert into public.registros_edicoes
        (dispositivo_id, id_local, campo, valor_antigo, valor_novo, editado_por_matricula, editado_por_uid)
      values
        (new.dispositivo_id, new.id_local, campo, antes ->> campo, depois ->> campo, quem, auth.uid());
    end if;
  end loop;

  if mudou then
    new.editado_em := now();
    new.editado_por_matricula := quem;
  end if;
  return new;
end;
$$;

-- ── policies ──────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "senha provisoria so ve o proprio" ON "public"."registros_app";
CREATE POLICY "senha provisoria so ve o proprio" ON "public"."registros_app" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (((NOT ( SELECT "public"."senha_provisoria_pendente"() AS "senha_provisoria_pendente")) OR ("usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual"))));

DROP POLICY IF EXISTS "senha provisoria so ve o proprio" ON "public"."fotos_app";
CREATE POLICY "senha provisoria so ve o proprio" ON "public"."fotos_app" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (((NOT ( SELECT "public"."senha_provisoria_pendente"() AS "senha_provisoria_pendente")) OR (EXISTS ( SELECT 1
   FROM "public"."registros_app" "r"
  WHERE (("r"."dispositivo_id" = "fotos_app"."dispositivo_id") AND ("r"."id_local" = "fotos_app"."registro_id_local") AND ("r"."usuario_matricula" = ( SELECT "public"."matricula_atual"() AS "matricula_atual")))))));

DROP POLICY IF EXISTS "admin do painel edita registros" ON "public"."registros_app";
CREATE POLICY "admin do painel edita registros" ON "public"."registros_app" FOR UPDATE TO "authenticated" USING ((( SELECT "public"."sou_admin_geral"() AS "sou_admin_geral") OR (( SELECT "public"."sou_admin_painel"() AS "sou_admin_painel") AND "public"."pode_administrar"('registros'::"text", "filial_id")))) WITH CHECK ((( SELECT "public"."sou_admin_geral"() AS "sou_admin_geral") OR (( SELECT "public"."sou_admin_painel"() AS "sou_admin_painel") AND "public"."pode_administrar"('registros'::"text", "filial_id"))));

-- ── storage ───────────────────────────────────────────────────────────────
-- a "adm envia dados da obra" virou duas no painel do Supabase.
drop policy if exists "adm envia dados da obra" on storage.objects;

drop policy if exists "adm envia dados da obra 1krhyj_0" on storage.objects;
create policy "adm envia dados da obra 1krhyj_0" on storage.objects as PERMISSIVE for INSERT to authenticated with check (((bucket_id = 'dados'::text) AND public.pode_enviar_dados(name)));

drop policy if exists "adm envia dados da obra 1krhyj_1" on storage.objects;
create policy "adm envia dados da obra 1krhyj_1" on storage.objects as PERMISSIVE for SELECT to authenticated using (((bucket_id = 'dados'::text) AND public.pode_enviar_dados(name)));

drop policy if exists "senha provisoria so ve o proprio" on storage.objects;
create policy "senha provisoria so ve o proprio" on storage.objects as RESTRICTIVE for SELECT to authenticated using (((bucket_id <> 'fotos'::text) OR (NOT ( SELECT public.senha_provisoria_pendente() AS senha_provisoria_pendente)) OR (owner = ( SELECT auth.uid() AS uid))));

--
-- PostgreSQL database dump
--

\restrict 1gl6zjN6ALPiXpZ3xB2ov7zz6k9PgEEyTrHfcaAedSG0jUjSrazHIvqdfPOOXKO

-- Dumped from database version 16.15
-- Dumped by pg_dump version 16.15

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: api; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA api;


--
-- Name: admin_sessions_auto_approve(); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.admin_sessions_auto_approve() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.level = 'admin' and new.status = 'pending' then
    new.status := 'approved';
    new.decided_at := now();
  end if;
  return new;
end
$$;


--
-- Name: checkin_monitor(integer, boolean); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.checkin_monitor(recent_limit integer DEFAULT 8, only_test boolean DEFAULT false) RETURNS json
    LANGUAGE sql STABLE
    AS $$
  with own as (
    select * from api.owners where is_test = only_test
  ),
  checked as (
    select o.id, o.queue_number, o.name, o.companions, c.checked_in_at
    from own o
    join api.checkins c on c.owner_id = o.id and c.post = 'reg_ulang'
  ),
  unchecked as (
    select o.queue_number
    from own o
    where not exists (select 1 from api.checkins c where c.owner_id = o.id and c.post = 'reg_ulang')
  ),
  side(odd) as (values (true), (false)),
  recent as (
    select s.odd, r.*
    from side s
    cross join lateral (
      select ch.id, ch.queue_number, ch.name, ch.companions, ch.checked_in_at
      from checked ch
      where (ch.queue_number % 2 = 1) = s.odd
      order by ch.checked_in_at desc
      limit greatest(recent_limit, 1)
    ) r
  )
  select json_build_object(
    'odd',  json_build_object(
      'total',   (select count(*) from own where queue_number % 2 = 1),
      'checked', (select count(*) from checked where queue_number % 2 = 1),
      'next',    (select min(u.queue_number) from unchecked u
                  where u.queue_number % 2 = 1
                    and u.queue_number > coalesce((select max(queue_number) from checked where queue_number % 2 = 1), 0)),
      'skipped', coalesce((select json_agg(x.n order by x.n) from (
                    select u.queue_number as n from unchecked u
                    where u.queue_number % 2 = 1
                      and u.queue_number < coalesce((select max(queue_number) from checked where queue_number % 2 = 1), 0)
                    order by 1 limit 10) x), '[]'::json),
      'recent',  coalesce((
        select json_agg(json_build_object(
          'queue_number', r.queue_number, 'name', r.name, 'companions', r.companions,
          'checked_in_at', r.checked_in_at,
          'pets', (select coalesce(json_agg(json_build_object('name', p.name, 'type', p.type)), '[]'::json)
                   from api.pets p where p.owner_id = r.id)
        ) order by r.checked_in_at desc)
        from recent r where r.odd), '[]'::json)
    ),
    'even', json_build_object(
      'total',   (select count(*) from own where queue_number % 2 = 0),
      'checked', (select count(*) from checked where queue_number % 2 = 0),
      'next',    (select min(u.queue_number) from unchecked u
                  where u.queue_number % 2 = 0
                    and u.queue_number > coalesce((select max(queue_number) from checked where queue_number % 2 = 0), 0)),
      'skipped', coalesce((select json_agg(x.n order by x.n) from (
                    select u.queue_number as n from unchecked u
                    where u.queue_number % 2 = 0
                      and u.queue_number < coalesce((select max(queue_number) from checked where queue_number % 2 = 0), 0)
                    order by 1 limit 10) x), '[]'::json),
      'recent',  coalesce((
        select json_agg(json_build_object(
          'queue_number', r.queue_number, 'name', r.name, 'companions', r.companions,
          'checked_in_at', r.checked_in_at,
          'pets', (select coalesce(json_agg(json_build_object('name', p.name, 'type', p.type)), '[]'::json)
                   from api.pets p where p.owner_id = r.id)
        ) order by r.checked_in_at desc)
        from recent r where not r.odd), '[]'::json)
    )
  );
$$;


--
-- Name: checkins_set_wrong_desk(); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.checkins_set_wrong_desk() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare q bigint;
begin
  if new.desk is not null then
    select queue_number into q from api.owners where id = new.owner_id;
    new.wrong_desk := (new.desk <> case when q % 2 = 1 then 'A' else 'B' end);
  else
    new.wrong_desk := false;
  end if;
  return new;
end $$;


--
-- Name: session_ok(); Type: FUNCTION; Schema: api; Owner: -
--

CREATE FUNCTION api.session_ok() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'api', 'pg_temp'
    AS $$
  select exists (
    select 1 from api.admin_sessions s
    where s.id::text = current_setting('request.jwt.claims', true)::json->>'sid'
      and s.status = 'approved'
  )
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_sessions; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.admin_sessions (
    id uuid NOT NULL,
    level text NOT NULL,
    device text NOT NULL,
    user_agent text,
    ip text,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    decided_at timestamp with time zone,
    CONSTRAINT admin_sessions_level_check CHECK ((level = ANY (ARRAY['admin'::text, 'superadmin'::text]))),
    CONSTRAINT admin_sessions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


--
-- Name: checkins; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.checkins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_id uuid NOT NULL,
    post text NOT NULL,
    checked_in_at timestamp with time zone DEFAULT now() NOT NULL,
    desk text,
    wrong_desk boolean DEFAULT false NOT NULL,
    CONSTRAINT checkins_desk_check CHECK ((desk = ANY (ARRAY['A'::text, 'B'::text]))),
    CONSTRAINT checkins_post_check CHECK ((post = ANY (ARRAY['reg_ulang'::text, 'pos1'::text, 'pos2'::text, 'pos3'::text])))
);


--
-- Name: owners; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.owners (
    id uuid NOT NULL,
    name text NOT NULL,
    phone text NOT NULL,
    is_parishioner text NOT NULL,
    parish_origin text,
    donation_amount text,
    donation_has_proof boolean DEFAULT false NOT NULL,
    agreed_tos boolean DEFAULT false NOT NULL,
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    queue_number bigint NOT NULL,
    companions integer DEFAULT 0 NOT NULL,
    donation_proof_base64 text,
    is_test boolean DEFAULT false NOT NULL,
    CONSTRAINT owners_companions_check CHECK (((companions >= 0) AND (companions <= 20))),
    CONSTRAINT owners_is_parishioner_check CHECK ((is_parishioner = ANY (ARRAY['ya'::text, 'bukan'::text])))
);


--
-- Name: owners_queue_number_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.owners_queue_number_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: owners_queue_number_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.owners_queue_number_seq OWNED BY api.owners.queue_number;


--
-- Name: pawrade_checkins; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.pawrade_checkins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_id uuid NOT NULL,
    checked_in_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pawrade_owners; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.pawrade_owners (
    id uuid NOT NULL,
    name text NOT NULL,
    phone text NOT NULL,
    is_parishioner text NOT NULL,
    parish_origin text,
    companions integer DEFAULT 0 NOT NULL,
    donation_amount text,
    donation_has_proof boolean DEFAULT false NOT NULL,
    donation_proof_base64 text,
    agreed_tos boolean DEFAULT false NOT NULL,
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    queue_number bigint NOT NULL,
    CONSTRAINT pawrade_owners_companions_check CHECK (((companions >= 0) AND (companions <= 20))),
    CONSTRAINT pawrade_owners_is_parishioner_check CHECK ((is_parishioner = ANY (ARRAY['ya'::text, 'bukan'::text])))
);


--
-- Name: pawrade_owners_queue_number_seq; Type: SEQUENCE; Schema: api; Owner: -
--

CREATE SEQUENCE api.pawrade_owners_queue_number_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pawrade_owners_queue_number_seq; Type: SEQUENCE OWNED BY; Schema: api; Owner: -
--

ALTER SEQUENCE api.pawrade_owners_queue_number_seq OWNED BY api.pawrade_owners.queue_number;


--
-- Name: pawrade_pets; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.pawrade_pets (
    id uuid NOT NULL,
    owner_id uuid NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    has_photo boolean DEFAULT false NOT NULL,
    photo_base64 text,
    notes text
);


--
-- Name: pawrade_wa_queue; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.pawrade_wa_queue (
    id uuid NOT NULL,
    owner_id uuid NOT NULL,
    phone text NOT NULL,
    short_code text NOT NULL,
    qr_image_base64 text NOT NULL,
    owner_name text NOT NULL,
    pet_summary text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone,
    CONSTRAINT pawrade_wa_queue_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sent'::text, 'failed'::text])))
);


--
-- Name: pets; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.pets (
    id uuid NOT NULL,
    owner_id uuid NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    has_photo boolean DEFAULT false NOT NULL,
    notes text,
    mcfbooth_session_code text,
    certificate_url text,
    photo_base64 text
);


--
-- Name: wa_correction_queue; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.wa_correction_queue (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_id uuid NOT NULL,
    phone text NOT NULL,
    owner_name text NOT NULL,
    short_code text NOT NULL,
    qr_image_base64 text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone,
    CONSTRAINT wa_correction_queue_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sent'::text, 'failed'::text])))
);


--
-- Name: wa_followup_queue; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.wa_followup_queue (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_id uuid NOT NULL,
    phone text NOT NULL,
    owner_name text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone,
    CONSTRAINT wa_followup_queue_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sent'::text, 'failed'::text])))
);


--
-- Name: wa_queue; Type: TABLE; Schema: api; Owner: -
--

CREATE TABLE api.wa_queue (
    id uuid NOT NULL,
    owner_id uuid NOT NULL,
    phone text NOT NULL,
    short_code text NOT NULL,
    qr_image_base64 text NOT NULL,
    owner_name text NOT NULL,
    pet_summary text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone,
    CONSTRAINT wa_queue_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sent'::text, 'failed'::text])))
);


--
-- Name: owners queue_number; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.owners ALTER COLUMN queue_number SET DEFAULT nextval('api.owners_queue_number_seq'::regclass);


--
-- Name: pawrade_owners queue_number; Type: DEFAULT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.pawrade_owners ALTER COLUMN queue_number SET DEFAULT nextval('api.pawrade_owners_queue_number_seq'::regclass);


--
-- Name: admin_sessions admin_sessions_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.admin_sessions
    ADD CONSTRAINT admin_sessions_pkey PRIMARY KEY (id);


--
-- Name: checkins checkins_owner_id_post_key; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.checkins
    ADD CONSTRAINT checkins_owner_id_post_key UNIQUE (owner_id, post);


--
-- Name: checkins checkins_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.checkins
    ADD CONSTRAINT checkins_pkey PRIMARY KEY (id);


--
-- Name: owners owners_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.owners
    ADD CONSTRAINT owners_pkey PRIMARY KEY (id);


--
-- Name: pawrade_checkins pawrade_checkins_owner_id_key; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.pawrade_checkins
    ADD CONSTRAINT pawrade_checkins_owner_id_key UNIQUE (owner_id);


--
-- Name: pawrade_checkins pawrade_checkins_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.pawrade_checkins
    ADD CONSTRAINT pawrade_checkins_pkey PRIMARY KEY (id);


--
-- Name: pawrade_owners pawrade_owners_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.pawrade_owners
    ADD CONSTRAINT pawrade_owners_pkey PRIMARY KEY (id);


--
-- Name: pawrade_pets pawrade_pets_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.pawrade_pets
    ADD CONSTRAINT pawrade_pets_pkey PRIMARY KEY (id);


--
-- Name: pawrade_wa_queue pawrade_wa_queue_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.pawrade_wa_queue
    ADD CONSTRAINT pawrade_wa_queue_pkey PRIMARY KEY (id);


--
-- Name: pets pets_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.pets
    ADD CONSTRAINT pets_pkey PRIMARY KEY (id);


--
-- Name: wa_correction_queue wa_correction_queue_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.wa_correction_queue
    ADD CONSTRAINT wa_correction_queue_pkey PRIMARY KEY (id);


--
-- Name: wa_followup_queue wa_followup_queue_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.wa_followup_queue
    ADD CONSTRAINT wa_followup_queue_pkey PRIMARY KEY (id);


--
-- Name: wa_queue wa_queue_pkey; Type: CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.wa_queue
    ADD CONSTRAINT wa_queue_pkey PRIMARY KEY (id);


--
-- Name: pawrade_pets_owner_id_idx; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX pawrade_pets_owner_id_idx ON api.pawrade_pets USING btree (owner_id);


--
-- Name: pets_owner_id_idx; Type: INDEX; Schema: api; Owner: -
--

CREATE INDEX pets_owner_id_idx ON api.pets USING btree (owner_id);


--
-- Name: admin_sessions admin_sessions_auto_approve; Type: TRIGGER; Schema: api; Owner: -
--

CREATE TRIGGER admin_sessions_auto_approve BEFORE INSERT ON api.admin_sessions FOR EACH ROW EXECUTE FUNCTION api.admin_sessions_auto_approve();


--
-- Name: checkins checkins_wrong_desk; Type: TRIGGER; Schema: api; Owner: -
--

CREATE TRIGGER checkins_wrong_desk BEFORE INSERT ON api.checkins FOR EACH ROW EXECUTE FUNCTION api.checkins_set_wrong_desk();


--
-- Name: checkins checkins_owner_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.checkins
    ADD CONSTRAINT checkins_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES api.owners(id) ON DELETE CASCADE;


--
-- Name: pawrade_checkins pawrade_checkins_owner_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.pawrade_checkins
    ADD CONSTRAINT pawrade_checkins_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES api.pawrade_owners(id) ON DELETE CASCADE;


--
-- Name: pawrade_pets pawrade_pets_owner_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.pawrade_pets
    ADD CONSTRAINT pawrade_pets_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES api.pawrade_owners(id) ON DELETE CASCADE;


--
-- Name: pawrade_wa_queue pawrade_wa_queue_owner_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.pawrade_wa_queue
    ADD CONSTRAINT pawrade_wa_queue_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES api.pawrade_owners(id) ON DELETE CASCADE;


--
-- Name: pets pets_owner_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.pets
    ADD CONSTRAINT pets_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES api.owners(id) ON DELETE CASCADE;


--
-- Name: wa_correction_queue wa_correction_queue_owner_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.wa_correction_queue
    ADD CONSTRAINT wa_correction_queue_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES api.owners(id) ON DELETE CASCADE;


--
-- Name: wa_followup_queue wa_followup_queue_owner_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.wa_followup_queue
    ADD CONSTRAINT wa_followup_queue_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES api.owners(id) ON DELETE CASCADE;


--
-- Name: wa_queue wa_queue_owner_id_fkey; Type: FK CONSTRAINT; Schema: api; Owner: -
--

ALTER TABLE ONLY api.wa_queue
    ADD CONSTRAINT wa_queue_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES api.owners(id) ON DELETE CASCADE;


--
-- Name: admin_sessions admin_own_admin_session; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY admin_own_admin_session ON api.admin_sessions FOR SELECT TO web_admin USING (((id)::text = ((current_setting('request.jwt.claims'::text, true))::json ->> 'sid'::text)));


--
-- Name: owners admin_select_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY admin_select_owners ON api.owners FOR SELECT TO web_admin USING (api.session_ok());


--
-- Name: pawrade_owners admin_select_pawrade_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY admin_select_pawrade_owners ON api.pawrade_owners FOR SELECT TO web_admin USING (api.session_ok());


--
-- Name: pawrade_pets admin_select_pawrade_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY admin_select_pawrade_pets ON api.pawrade_pets FOR SELECT TO web_admin USING (api.session_ok());


--
-- Name: pets admin_select_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY admin_select_pets ON api.pets FOR SELECT TO web_admin USING (api.session_ok());


--
-- Name: admin_sessions; Type: ROW SECURITY; Schema: api; Owner: -
--

ALTER TABLE api.admin_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: owners admin_update_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY admin_update_owners ON api.owners FOR UPDATE TO web_admin USING (api.session_ok()) WITH CHECK (api.session_ok());


--
-- Name: pawrade_owners admin_update_pawrade_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY admin_update_pawrade_owners ON api.pawrade_owners FOR UPDATE TO web_admin USING (api.session_ok()) WITH CHECK (api.session_ok());


--
-- Name: pawrade_pets admin_update_pawrade_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY admin_update_pawrade_pets ON api.pawrade_pets FOR UPDATE TO web_admin USING (api.session_ok()) WITH CHECK (api.session_ok());


--
-- Name: pets admin_update_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY admin_update_pets ON api.pets FOR UPDATE TO web_admin USING (api.session_ok()) WITH CHECK (api.session_ok());


--
-- Name: owners anon_insert_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY anon_insert_owners ON api.owners FOR INSERT TO web_anon WITH CHECK (true);


--
-- Name: pawrade_wa_queue anon_insert_pawrade_wa_queue; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY anon_insert_pawrade_wa_queue ON api.pawrade_wa_queue FOR INSERT TO web_registrant WITH CHECK (true);


--
-- Name: pets anon_insert_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY anon_insert_pets ON api.pets FOR INSERT TO web_anon WITH CHECK (true);


--
-- Name: wa_queue anon_insert_wa_queue; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY anon_insert_wa_queue ON api.wa_queue FOR INSERT TO web_anon WITH CHECK (true);


--
-- Name: owners booth_select_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY booth_select_owners ON api.owners FOR SELECT TO booth_worker USING (true);


--
-- Name: pets booth_select_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY booth_select_pets ON api.pets FOR SELECT TO booth_worker USING (true);


--
-- Name: pets booth_update_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY booth_update_pets ON api.pets FOR UPDATE TO booth_worker USING (true) WITH CHECK (true);


--
-- Name: owners certbot_select_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY certbot_select_owners ON api.owners FOR SELECT TO certificate_bot USING (true);


--
-- Name: pets certbot_select_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY certbot_select_pets ON api.pets FOR SELECT TO certificate_bot USING (true);


--
-- Name: checkins; Type: ROW SECURITY; Schema: api; Owner: -
--

ALTER TABLE api.checkins ENABLE ROW LEVEL SECURITY;

--
-- Name: owners; Type: ROW SECURITY; Schema: api; Owner: -
--

ALTER TABLE api.owners ENABLE ROW LEVEL SECURITY;

--
-- Name: checkins panitia_all_checkins; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY panitia_all_checkins ON api.checkins TO web_panitia USING (true) WITH CHECK (true);


--
-- Name: owners panitia_select_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY panitia_select_owners ON api.owners FOR SELECT TO web_panitia USING (true);


--
-- Name: pets panitia_select_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY panitia_select_pets ON api.pets FOR SELECT TO web_panitia USING (true);


--
-- Name: pawrade_checkins; Type: ROW SECURITY; Schema: api; Owner: -
--

ALTER TABLE api.pawrade_checkins ENABLE ROW LEVEL SECURITY;

--
-- Name: pawrade_owners; Type: ROW SECURITY; Schema: api; Owner: -
--

ALTER TABLE api.pawrade_owners ENABLE ROW LEVEL SECURITY;

--
-- Name: pawrade_pets; Type: ROW SECURITY; Schema: api; Owner: -
--

ALTER TABLE api.pawrade_pets ENABLE ROW LEVEL SECURITY;

--
-- Name: pawrade_wa_queue; Type: ROW SECURITY; Schema: api; Owner: -
--

ALTER TABLE api.pawrade_wa_queue ENABLE ROW LEVEL SECURITY;

--
-- Name: pets; Type: ROW SECURITY; Schema: api; Owner: -
--

ALTER TABLE api.pets ENABLE ROW LEVEL SECURITY;

--
-- Name: owners registrant_insert_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY registrant_insert_owners ON api.owners FOR INSERT TO web_registrant WITH CHECK (true);


--
-- Name: pawrade_owners registrant_insert_pawrade_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY registrant_insert_pawrade_owners ON api.pawrade_owners FOR INSERT TO web_registrant WITH CHECK (true);


--
-- Name: pawrade_pets registrant_insert_pawrade_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY registrant_insert_pawrade_pets ON api.pawrade_pets FOR INSERT TO web_registrant WITH CHECK (true);


--
-- Name: pets registrant_insert_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY registrant_insert_pets ON api.pets FOR INSERT TO web_registrant WITH CHECK (true);


--
-- Name: wa_queue registrant_insert_wa_queue; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY registrant_insert_wa_queue ON api.wa_queue FOR INSERT TO web_registrant WITH CHECK (true);


--
-- Name: admin_sessions superadmin_all_admin_sessions; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_all_admin_sessions ON api.admin_sessions TO web_superadmin USING (true) WITH CHECK (true);


--
-- Name: checkins superadmin_all_checkins; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_all_checkins ON api.checkins TO web_superadmin USING (true) WITH CHECK (true);


--
-- Name: pawrade_checkins superadmin_all_pawrade_checkins; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_all_pawrade_checkins ON api.pawrade_checkins TO web_superadmin USING (true) WITH CHECK (true);


--
-- Name: owners superadmin_delete_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_delete_owners ON api.owners FOR DELETE TO web_superadmin USING (true);


--
-- Name: pawrade_owners superadmin_delete_pawrade_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_delete_pawrade_owners ON api.pawrade_owners FOR DELETE TO web_superadmin USING (true);


--
-- Name: pawrade_pets superadmin_delete_pawrade_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_delete_pawrade_pets ON api.pawrade_pets FOR DELETE TO web_superadmin USING (true);


--
-- Name: pawrade_wa_queue superadmin_delete_pawrade_wa_queue; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_delete_pawrade_wa_queue ON api.pawrade_wa_queue FOR DELETE TO web_superadmin USING (true);


--
-- Name: pets superadmin_delete_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_delete_pets ON api.pets FOR DELETE TO web_superadmin USING (true);


--
-- Name: wa_queue superadmin_delete_wa_queue; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_delete_wa_queue ON api.wa_queue FOR DELETE TO web_superadmin USING (true);


--
-- Name: owners superadmin_select_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_select_owners ON api.owners FOR SELECT TO web_superadmin USING (true);


--
-- Name: pawrade_owners superadmin_select_pawrade_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_select_pawrade_owners ON api.pawrade_owners FOR SELECT TO web_superadmin USING (true);


--
-- Name: pawrade_pets superadmin_select_pawrade_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_select_pawrade_pets ON api.pawrade_pets FOR SELECT TO web_superadmin USING (true);


--
-- Name: pawrade_wa_queue superadmin_select_pawrade_wa_queue; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_select_pawrade_wa_queue ON api.pawrade_wa_queue FOR SELECT TO web_superadmin USING (true);


--
-- Name: pets superadmin_select_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_select_pets ON api.pets FOR SELECT TO web_superadmin USING (true);


--
-- Name: wa_queue superadmin_select_wa_queue; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_select_wa_queue ON api.wa_queue FOR SELECT TO web_superadmin USING (true);


--
-- Name: owners superadmin_update_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_update_owners ON api.owners FOR UPDATE TO web_superadmin USING (true) WITH CHECK (true);


--
-- Name: pawrade_owners superadmin_update_pawrade_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_update_pawrade_owners ON api.pawrade_owners FOR UPDATE TO web_superadmin USING (true) WITH CHECK (true);


--
-- Name: pawrade_pets superadmin_update_pawrade_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_update_pawrade_pets ON api.pawrade_pets FOR UPDATE TO web_superadmin USING (true) WITH CHECK (true);


--
-- Name: pets superadmin_update_pets; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY superadmin_update_pets ON api.pets FOR UPDATE TO web_superadmin USING (true) WITH CHECK (true);


--
-- Name: wa_correction_queue; Type: ROW SECURITY; Schema: api; Owner: -
--

ALTER TABLE api.wa_correction_queue ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_followup_queue; Type: ROW SECURITY; Schema: api; Owner: -
--

ALTER TABLE api.wa_followup_queue ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_queue; Type: ROW SECURITY; Schema: api; Owner: -
--

ALTER TABLE api.wa_queue ENABLE ROW LEVEL SECURITY;

--
-- Name: pawrade_wa_queue worker_all_pawrade_wa_queue; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY worker_all_pawrade_wa_queue ON api.pawrade_wa_queue TO wa_worker USING (true) WITH CHECK (true);


--
-- Name: wa_correction_queue worker_all_wa_correction_queue; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY worker_all_wa_correction_queue ON api.wa_correction_queue TO wa_worker USING (true) WITH CHECK (true);


--
-- Name: wa_followup_queue worker_all_wa_followup_queue; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY worker_all_wa_followup_queue ON api.wa_followup_queue TO wa_worker USING (true) WITH CHECK (true);


--
-- Name: wa_queue worker_all_wa_queue; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY worker_all_wa_queue ON api.wa_queue TO wa_worker USING (true) WITH CHECK (true);


--
-- Name: owners worker_select_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY worker_select_owners ON api.owners FOR SELECT TO wa_worker USING (true);


--
-- Name: pawrade_owners worker_select_pawrade_owners; Type: POLICY; Schema: api; Owner: -
--

CREATE POLICY worker_select_pawrade_owners ON api.pawrade_owners FOR SELECT TO wa_worker USING (true);


--
-- Name: SCHEMA api; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA api TO web_anon;
GRANT USAGE ON SCHEMA api TO web_panitia;
GRANT USAGE ON SCHEMA api TO wa_worker;
GRANT USAGE ON SCHEMA api TO web_registrant;
GRANT USAGE ON SCHEMA api TO web_admin;
GRANT USAGE ON SCHEMA api TO web_superadmin;
GRANT USAGE ON SCHEMA api TO booth_worker;
GRANT USAGE ON SCHEMA api TO certificate_bot;


--
-- Name: FUNCTION checkin_monitor(recent_limit integer, only_test boolean); Type: ACL; Schema: api; Owner: -
--

REVOKE ALL ON FUNCTION api.checkin_monitor(recent_limit integer, only_test boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION api.checkin_monitor(recent_limit integer, only_test boolean) TO web_superadmin;


--
-- Name: FUNCTION session_ok(); Type: ACL; Schema: api; Owner: -
--

GRANT ALL ON FUNCTION api.session_ok() TO web_admin;
GRANT ALL ON FUNCTION api.session_ok() TO web_superadmin;


--
-- Name: TABLE admin_sessions; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT,INSERT,UPDATE ON TABLE api.admin_sessions TO web_superadmin;
GRANT SELECT ON TABLE api.admin_sessions TO web_admin;


--
-- Name: TABLE checkins; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT,INSERT ON TABLE api.checkins TO web_panitia;
GRANT SELECT,INSERT,DELETE ON TABLE api.checkins TO web_superadmin;


--
-- Name: TABLE owners; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT ON TABLE api.owners TO web_panitia;
GRANT SELECT ON TABLE api.owners TO wa_worker;
GRANT INSERT ON TABLE api.owners TO web_registrant;
GRANT SELECT,UPDATE ON TABLE api.owners TO web_admin;
GRANT SELECT,DELETE,UPDATE ON TABLE api.owners TO web_superadmin;


--
-- Name: COLUMN owners.id; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT(id) ON TABLE api.owners TO booth_worker;
GRANT SELECT(id) ON TABLE api.owners TO certificate_bot;


--
-- Name: COLUMN owners.name; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT(name) ON TABLE api.owners TO booth_worker;
GRANT SELECT(name) ON TABLE api.owners TO certificate_bot;


--
-- Name: COLUMN owners.queue_number; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT(queue_number) ON TABLE api.owners TO booth_worker;
GRANT SELECT(queue_number) ON TABLE api.owners TO certificate_bot;


--
-- Name: COLUMN owners.is_test; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT(is_test) ON TABLE api.owners TO booth_worker;
GRANT SELECT(is_test) ON TABLE api.owners TO certificate_bot;


--
-- Name: SEQUENCE owners_queue_number_seq; Type: ACL; Schema: api; Owner: -
--

GRANT USAGE ON SEQUENCE api.owners_queue_number_seq TO web_registrant;


--
-- Name: TABLE pawrade_checkins; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT,INSERT,DELETE ON TABLE api.pawrade_checkins TO web_superadmin;


--
-- Name: TABLE pawrade_owners; Type: ACL; Schema: api; Owner: -
--

GRANT INSERT ON TABLE api.pawrade_owners TO web_registrant;
GRANT SELECT,UPDATE ON TABLE api.pawrade_owners TO web_admin;
GRANT SELECT,DELETE,UPDATE ON TABLE api.pawrade_owners TO web_superadmin;


--
-- Name: COLUMN pawrade_owners.id; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT(id) ON TABLE api.pawrade_owners TO wa_worker;


--
-- Name: COLUMN pawrade_owners.queue_number; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT(queue_number) ON TABLE api.pawrade_owners TO wa_worker;


--
-- Name: SEQUENCE pawrade_owners_queue_number_seq; Type: ACL; Schema: api; Owner: -
--

GRANT USAGE ON SEQUENCE api.pawrade_owners_queue_number_seq TO web_registrant;


--
-- Name: TABLE pawrade_pets; Type: ACL; Schema: api; Owner: -
--

GRANT INSERT ON TABLE api.pawrade_pets TO web_registrant;
GRANT SELECT,UPDATE ON TABLE api.pawrade_pets TO web_admin;
GRANT SELECT,DELETE,UPDATE ON TABLE api.pawrade_pets TO web_superadmin;


--
-- Name: TABLE pawrade_wa_queue; Type: ACL; Schema: api; Owner: -
--

GRANT INSERT ON TABLE api.pawrade_wa_queue TO web_registrant;
GRANT SELECT,UPDATE ON TABLE api.pawrade_wa_queue TO wa_worker;
GRANT SELECT,DELETE,UPDATE ON TABLE api.pawrade_wa_queue TO web_superadmin;


--
-- Name: TABLE pets; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT ON TABLE api.pets TO web_panitia;
GRANT INSERT ON TABLE api.pets TO web_registrant;
GRANT SELECT,UPDATE ON TABLE api.pets TO web_admin;
GRANT SELECT,DELETE,UPDATE ON TABLE api.pets TO web_superadmin;


--
-- Name: COLUMN pets.id; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT(id) ON TABLE api.pets TO booth_worker;
GRANT SELECT(id) ON TABLE api.pets TO certificate_bot;


--
-- Name: COLUMN pets.owner_id; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT(owner_id) ON TABLE api.pets TO booth_worker;
GRANT SELECT(owner_id) ON TABLE api.pets TO certificate_bot;


--
-- Name: COLUMN pets.name; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT(name) ON TABLE api.pets TO booth_worker;
GRANT SELECT(name) ON TABLE api.pets TO certificate_bot;


--
-- Name: COLUMN pets.type; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT(type) ON TABLE api.pets TO booth_worker;
GRANT SELECT(type) ON TABLE api.pets TO certificate_bot;


--
-- Name: COLUMN pets.mcfbooth_session_code; Type: ACL; Schema: api; Owner: -
--

GRANT UPDATE(mcfbooth_session_code) ON TABLE api.pets TO booth_worker;
GRANT SELECT(mcfbooth_session_code) ON TABLE api.pets TO certificate_bot;


--
-- Name: COLUMN pets.certificate_url; Type: ACL; Schema: api; Owner: -
--

GRANT UPDATE(certificate_url) ON TABLE api.pets TO booth_worker;
GRANT SELECT(certificate_url) ON TABLE api.pets TO certificate_bot;


--
-- Name: TABLE wa_correction_queue; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT,UPDATE ON TABLE api.wa_correction_queue TO wa_worker;


--
-- Name: TABLE wa_followup_queue; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT,UPDATE ON TABLE api.wa_followup_queue TO wa_worker;


--
-- Name: TABLE wa_queue; Type: ACL; Schema: api; Owner: -
--

GRANT SELECT,UPDATE ON TABLE api.wa_queue TO wa_worker;
GRANT INSERT ON TABLE api.wa_queue TO web_registrant;
GRANT SELECT,DELETE ON TABLE api.wa_queue TO web_superadmin;


--
-- PostgreSQL database dump complete
--

\unrestrict 1gl6zjN6ALPiXpZ3xB2ov7zz6k9PgEEyTrHfcaAedSG0jUjSrazHIvqdfPOOXKO


--
-- PostgreSQL database cluster dump
--

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Databases
--

--
-- Database "template1" dump
--

\connect template1

--
-- PostgreSQL database dump
--

-- Dumped from database version 13.1 (Debian 13.1-1.pgdg100+1)
-- Dumped by pg_dump version 13.1 (Debian 13.1-1.pgdg100+1)

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
-- PostgreSQL database dump complete
--

--
-- Database "kamailio" dump
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 13.1 (Debian 13.1-1.pgdg100+1)
-- Dumped by pg_dump version 13.1 (Debian 13.1-1.pgdg100+1)

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
-- Name: kamailio; Type: DATABASE; Schema: -; Owner: postgres
--

-- CREATE DATABASE kamailio WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.utf8';


ALTER DATABASE kamailio OWNER TO postgres;

\connect kamailio

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
-- Name: moddatetime; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS moddatetime WITH SCHEMA public;


--
-- Name: EXTENSION moddatetime; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION moddatetime IS 'functions for tracking last modification time';


--
-- Name: concat(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.concat(text, text) RETURNS text
    LANGUAGE sql
    AS $_$SELECT $1 || $2;$_$;


ALTER FUNCTION public.concat(text, text) OWNER TO postgres;


--
-- Name: rand(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rand() RETURNS double precision
    LANGUAGE sql
    AS $$SELECT random();$$;


ALTER FUNCTION public.rand() OWNER TO postgres;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: acc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.acc (
    id integer NOT NULL,
    method character varying(16) DEFAULT ''::character varying NOT NULL,
    from_tag character varying(128) DEFAULT ''::character varying NOT NULL,
    to_tag character varying(128) DEFAULT ''::character varying NOT NULL,
    callid character varying(255) DEFAULT ''::character varying NOT NULL,
    sip_code character varying(3) DEFAULT ''::character varying NOT NULL,
    sip_reason character varying(128) DEFAULT ''::character varying NOT NULL,
    "time" timestamp without time zone NOT NULL
);


ALTER TABLE public.acc OWNER TO postgres;

--
-- Name: acc_cdrs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.acc_cdrs (
    id integer NOT NULL,
    start_time timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    end_time timestamp without time zone DEFAULT '2000-01-01 00:00:00'::timestamp without time zone NOT NULL,
    duration real DEFAULT 0 NOT NULL,
    caller character varying,
    src_domain character varying,
    src_ip character varying,
    callee character varying,
    dst_domain character varying,
    method character varying,
    callid character varying,
    user_agent character varying,
    destination_uri character varying,
    customer_id integer
);


ALTER TABLE public.acc_cdrs OWNER TO postgres;

--
-- Name: acc_cdrs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.acc_cdrs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.acc_cdrs_id_seq OWNER TO postgres;

--
-- Name: acc_cdrs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.acc_cdrs_id_seq OWNED BY public.acc_cdrs.id;


--
-- Name: acc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.acc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.acc_id_seq OWNER TO postgres;

--
-- Name: acc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.acc_id_seq OWNED BY public.acc.id;


--
-- Name: address; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.address (
    id integer NOT NULL,
    grp integer DEFAULT 1 NOT NULL,
    ip_addr character varying(50) NOT NULL,
    mask integer DEFAULT 32 NOT NULL,
    port integer DEFAULT 0 NOT NULL,
    tag character varying(64)
);


ALTER TABLE public.address OWNER TO postgres;

--
-- Name: address_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.address_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.address_id_seq OWNER TO postgres;

--
-- Name: address_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.address_id_seq OWNED BY public.address.id;


--
-- Name: aliases; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aliases (
    id integer NOT NULL,
    ruid character varying(64) DEFAULT ''::character varying NOT NULL,
    username character varying(64) DEFAULT ''::character varying NOT NULL,
    domain character varying(64) DEFAULT NULL::character varying,
    contact character varying(255) DEFAULT ''::character varying NOT NULL,
    received character varying(255) DEFAULT NULL::character varying,
    path character varying(512) DEFAULT NULL::character varying,
    expires timestamp without time zone DEFAULT '2030-05-28 21:32:15'::timestamp without time zone NOT NULL,
    q real DEFAULT 1.0 NOT NULL,
    callid character varying(255) DEFAULT 'Default-Call-ID'::character varying NOT NULL,
    cseq integer DEFAULT 1 NOT NULL,
    last_modified timestamp without time zone DEFAULT '2000-01-01 00:00:01'::timestamp without time zone NOT NULL,
    flags integer DEFAULT 0 NOT NULL,
    cflags integer DEFAULT 0 NOT NULL,
    user_agent character varying(255) DEFAULT ''::character varying NOT NULL,
    socket character varying(64) DEFAULT NULL::character varying,
    methods integer,
    instance character varying(255) DEFAULT NULL::character varying,
    reg_id integer DEFAULT 0 NOT NULL,
    server_id integer DEFAULT 0 NOT NULL,
    connection_id integer DEFAULT 0 NOT NULL,
    keepalive integer DEFAULT 0 NOT NULL,
    partition integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.aliases OWNER TO postgres;

--
-- Name: aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aliases_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.aliases_id_seq OWNER TO postgres;

--
-- Name: aliases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aliases_id_seq OWNED BY public.aliases.id;


--
-- Name: dbaliases; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dbaliases (
    id integer NOT NULL,
    alias_username character varying(64) DEFAULT ''::character varying NOT NULL,
    alias_domain character varying(64) DEFAULT ''::character varying NOT NULL,
    username character varying(64) DEFAULT ''::character varying NOT NULL,
    domain character varying(64) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.dbaliases OWNER TO postgres;

--
-- Name: dbaliases_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dbaliases_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dbaliases_id_seq OWNER TO postgres;

--
-- Name: dbaliases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dbaliases_id_seq OWNED BY public.dbaliases.id;


--
-- Name: dialog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dialog (
    id integer NOT NULL,
    hash_entry integer NOT NULL,
    hash_id integer NOT NULL,
    callid character varying(255) NOT NULL,
    from_uri character varying(255) NOT NULL,
    from_tag character varying(128) NOT NULL,
    to_uri character varying(255) NOT NULL,
    to_tag character varying(128) NOT NULL,
    caller_cseq character varying(20) NOT NULL,
    callee_cseq character varying(20) NOT NULL,
    caller_route_set character varying(512),
    callee_route_set character varying(512),
    caller_contact character varying(255) NOT NULL,
    callee_contact character varying(255) NOT NULL,
    caller_sock character varying(64) NOT NULL,
    callee_sock character varying(64) NOT NULL,
    state integer NOT NULL,
    start_time integer NOT NULL,
    timeout integer DEFAULT 0 NOT NULL,
    sflags integer DEFAULT 0 NOT NULL,
    iflags integer DEFAULT 0 NOT NULL,
    toroute_name character varying(32),
    req_uri character varying(255) NOT NULL,
    xdata character varying(512)
);


ALTER TABLE public.dialog OWNER TO postgres;

--
-- Name: dialog_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dialog_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dialog_id_seq OWNER TO postgres;

--
-- Name: dialog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dialog_id_seq OWNED BY public.dialog.id;


--
-- Name: dialog_vars; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dialog_vars (
    id integer NOT NULL,
    hash_entry integer NOT NULL,
    hash_id integer NOT NULL,
    dialog_key character varying(128) NOT NULL,
    dialog_value character varying(512) NOT NULL
);


ALTER TABLE public.dialog_vars OWNER TO postgres;

--
-- Name: dialog_vars_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dialog_vars_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dialog_vars_id_seq OWNER TO postgres;

--
-- Name: dialog_vars_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dialog_vars_id_seq OWNED BY public.dialog_vars.id;


--
-- Name: dialplan; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dialplan (
    id integer NOT NULL,
    dpid integer NOT NULL,
    pr integer NOT NULL,
    match_op integer NOT NULL,
    match_exp character varying(64) NOT NULL,
    match_len integer NOT NULL,
    subst_exp character varying(64) NOT NULL,
    repl_exp character varying(256) NOT NULL,
    attrs character varying(64) NOT NULL,
    created_at timestamp(0) without time zone DEFAULT timezone('utc'::text, now()),
    last_modified timestamp(0) without time zone DEFAULT timezone('utc'::text, now()),
    name character varying(64)
);


ALTER TABLE public.dialplan OWNER TO postgres;

--
-- Name: COLUMN dialplan.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.dialplan.name IS 'name of the rules';


--
-- Name: dialplan_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dialplan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dialplan_id_seq OWNER TO postgres;

--
-- Name: dialplan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dialplan_id_seq OWNED BY public.dialplan.id;


--
-- Name: dispatcher; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dispatcher (
    id integer NOT NULL,
    setid integer DEFAULT 0,
    destination character varying(192) DEFAULT ''::character varying NOT NULL,
    flags integer DEFAULT 0 NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    attrs character varying(128) DEFAULT ''::character varying NOT NULL,
    description character varying(64) DEFAULT ''::character varying NOT NULL,
    created_at timestamp(0) without time zone DEFAULT timezone('utc'::text, now()),
    last_modified timestamp(0) without time zone DEFAULT timezone('utc'::text, now())
);


ALTER TABLE public.dispatcher OWNER TO postgres;

--
-- Name: dispatcher_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dispatcher_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dispatcher_id_seq OWNER TO postgres;

--
-- Name: dispatcher_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dispatcher_id_seq OWNED BY public.dispatcher.id;


--
-- Name: domain; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.domain (
    id integer NOT NULL,
    domain character varying(64) NOT NULL,
    did character varying(64) DEFAULT NULL::character varying,
    created_at timestamp(0) without time zone DEFAULT timezone('utc'::text, now()),
    last_modified timestamp(0) without time zone DEFAULT timezone('utc'::text, now())
);


ALTER TABLE public.domain OWNER TO postgres;

--
-- Name: domain_attrs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.domain_attrs (
    id integer NOT NULL,
    did character varying(64) NOT NULL,
    name character varying(32) NOT NULL,
    type integer NOT NULL,
    value character varying(255) NOT NULL,
    last_modified timestamp without time zone DEFAULT '2000-01-01 00:00:01'::timestamp without time zone NOT NULL
);


ALTER TABLE public.domain_attrs OWNER TO postgres;

--
-- Name: domain_attrs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.domain_attrs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.domain_attrs_id_seq OWNER TO postgres;

--
-- Name: domain_attrs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.domain_attrs_id_seq OWNED BY public.domain_attrs.id;


--
-- Name: domain_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.domain_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.domain_id_seq OWNER TO postgres;

--
-- Name: domain_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.domain_id_seq OWNED BY public.domain.id;


--
-- Name: globalblocklist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.globalblocklist (
    id integer NOT NULL,
    prefix character varying(64) DEFAULT ''::character varying NOT NULL,
    allowlist smallint DEFAULT 0 NOT NULL,
    description character varying(255) DEFAULT NULL::character varying
);


ALTER TABLE public.globalblocklist OWNER TO postgres;

--
-- Name: globalblocklist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.globalblocklist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.globalblocklist_id_seq OWNER TO postgres;

--
-- Name: globalblocklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.globalblocklist_id_seq OWNED BY public.globalblocklist.id;


--
-- Name: grp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.grp (
    id integer NOT NULL,
    username character varying(64) DEFAULT ''::character varying NOT NULL,
    domain character varying(64) DEFAULT ''::character varying NOT NULL,
    grp character varying(64) DEFAULT ''::character varying NOT NULL,
    last_modified timestamp without time zone DEFAULT '2000-01-01 00:00:01'::timestamp without time zone NOT NULL
);


ALTER TABLE public.grp OWNER TO postgres;

--
-- Name: grp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.grp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.grp_id_seq OWNER TO postgres;

--
-- Name: grp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.grp_id_seq OWNED BY public.grp.id;


--
-- Name: htable; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.htable (
    id integer NOT NULL,
    key_name character varying(64) DEFAULT ''::character varying NOT NULL,
    key_type integer DEFAULT 0 NOT NULL,
    value_type integer DEFAULT 0 NOT NULL,
    key_value character varying(128) DEFAULT ''::character varying NOT NULL,
    expires integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.htable OWNER TO postgres;

--
-- Name: htable_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.htable_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.htable_id_seq OWNER TO postgres;

--
-- Name: htable_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.htable_id_seq OWNED BY public.htable.id;


--
-- Name: lcr_gw; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lcr_gw (
    id integer NOT NULL,
    lcr_id smallint NOT NULL,
    gw_name character varying(128),
    ip_addr character varying(50),
    hostname character varying(64),
    port integer,
    params character varying(64),
    uri_scheme smallint,
    transport smallint,
    strip smallint,
    prefix character varying(16) DEFAULT NULL::character varying,
    tag character varying(64) DEFAULT NULL::character varying,
    flags integer DEFAULT 0 NOT NULL,
    defunct integer
);


ALTER TABLE public.lcr_gw OWNER TO postgres;

--
-- Name: lcr_gw_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lcr_gw_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lcr_gw_id_seq OWNER TO postgres;

--
-- Name: lcr_gw_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lcr_gw_id_seq OWNED BY public.lcr_gw.id;


--
-- Name: lcr_rule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lcr_rule (
    id integer NOT NULL,
    lcr_id smallint NOT NULL,
    prefix character varying(16) DEFAULT NULL::character varying,
    from_uri character varying(64) DEFAULT NULL::character varying,
    request_uri character varying(64) DEFAULT NULL::character varying,
    mt_tvalue character varying(128) DEFAULT NULL::character varying,
    stopper integer DEFAULT 0 NOT NULL,
    enabled integer DEFAULT 1 NOT NULL
);


ALTER TABLE public.lcr_rule OWNER TO postgres;

--
-- Name: lcr_rule_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lcr_rule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lcr_rule_id_seq OWNER TO postgres;

--
-- Name: lcr_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lcr_rule_id_seq OWNED BY public.lcr_rule.id;


--
-- Name: lcr_rule_target; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lcr_rule_target (
    id integer NOT NULL,
    lcr_id smallint NOT NULL,
    rule_id integer NOT NULL,
    gw_id integer NOT NULL,
    priority smallint NOT NULL,
    weight integer DEFAULT 1 NOT NULL
);


ALTER TABLE public.lcr_rule_target OWNER TO postgres;

--
-- Name: lcr_rule_target_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lcr_rule_target_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lcr_rule_target_id_seq OWNER TO postgres;

--
-- Name: lcr_rule_target_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lcr_rule_target_id_seq OWNED BY public.lcr_rule_target.id;


--
-- Name: location; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.location (
    id integer NOT NULL,
    ruid character varying(64) DEFAULT ''::character varying NOT NULL,
    username character varying(64) DEFAULT ''::character varying NOT NULL,
    domain character varying(64) DEFAULT NULL::character varying,
    contact character varying(512) DEFAULT ''::character varying NOT NULL,
    received character varying(128) DEFAULT NULL::character varying,
    path character varying(512) DEFAULT NULL::character varying,
    expires timestamp without time zone DEFAULT '2030-05-28 21:32:15'::timestamp without time zone NOT NULL,
    q real DEFAULT 1.0 NOT NULL,
    callid character varying(255) DEFAULT 'Default-Call-ID'::character varying NOT NULL,
    cseq integer DEFAULT 1 NOT NULL,
    last_modified timestamp without time zone DEFAULT '2000-01-01 00:00:01'::timestamp without time zone NOT NULL,
    flags integer DEFAULT 0 NOT NULL,
    cflags integer DEFAULT 0 NOT NULL,
    user_agent character varying(255) DEFAULT ''::character varying NOT NULL,
    socket character varying(64) DEFAULT NULL::character varying,
    methods integer,
    instance character varying(255) DEFAULT NULL::character varying,
    reg_id integer DEFAULT 0 NOT NULL,
    server_id integer DEFAULT 0 NOT NULL,
    connection_id integer DEFAULT 0 NOT NULL,
    keepalive integer DEFAULT 0 NOT NULL,
    partition integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.location OWNER TO postgres;

--
-- Name: location_attrs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.location_attrs (
    id integer NOT NULL,
    ruid character varying(64) DEFAULT ''::character varying NOT NULL,
    username character varying(64) DEFAULT ''::character varying NOT NULL,
    domain character varying(64) DEFAULT NULL::character varying,
    aname character varying(64) DEFAULT ''::character varying NOT NULL,
    atype integer DEFAULT 0 NOT NULL,
    avalue character varying(512) DEFAULT ''::character varying NOT NULL,
    last_modified timestamp without time zone DEFAULT '2000-01-01 00:00:01'::timestamp without time zone NOT NULL
);


ALTER TABLE public.location_attrs OWNER TO postgres;

--
-- Name: location_attrs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.location_attrs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.location_attrs_id_seq OWNER TO postgres;

--
-- Name: location_attrs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.location_attrs_id_seq OWNED BY public.location_attrs.id;


--
-- Name: location_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.location_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.location_id_seq OWNER TO postgres;

--
-- Name: location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.location_id_seq OWNED BY public.location.id;


--
-- Name: missed_calls; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.missed_calls (
    id integer NOT NULL,
    method character varying(16) DEFAULT ''::character varying NOT NULL,
    from_tag character varying(128) DEFAULT ''::character varying NOT NULL,
    to_tag character varying(128) DEFAULT ''::character varying NOT NULL,
    callid character varying(255) DEFAULT ''::character varying NOT NULL,
    sip_code character varying(3) DEFAULT ''::character varying NOT NULL,
    sip_reason character varying(128) DEFAULT ''::character varying NOT NULL,
    "time" timestamp without time zone NOT NULL
);


ALTER TABLE public.missed_calls OWNER TO postgres;

--
-- Name: missed_calls_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.missed_calls_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.missed_calls_id_seq OWNER TO postgres;

--
-- Name: missed_calls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.missed_calls_id_seq OWNED BY public.missed_calls.id;


--
-- Name: pdt; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pdt (
    id integer NOT NULL,
    sdomain character varying(255) NOT NULL,
    prefix character varying(32) NOT NULL,
    domain character varying(255) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.pdt OWNER TO postgres;

--
-- Name: pdt_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pdt_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pdt_id_seq OWNER TO postgres;

--
-- Name: pdt_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pdt_id_seq OWNED BY public.pdt.id;


--
-- Name: re_grp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.re_grp (
    id integer NOT NULL,
    reg_exp character varying(128) DEFAULT ''::character varying NOT NULL,
    group_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.re_grp OWNER TO postgres;

--
-- Name: re_grp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.re_grp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.re_grp_id_seq OWNER TO postgres;

--
-- Name: re_grp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.re_grp_id_seq OWNED BY public.re_grp.id;


--
-- Name: rtpengine; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rtpengine (
    id integer NOT NULL,
    setid integer DEFAULT 0 NOT NULL,
    url character varying(64) NOT NULL,
    weight integer DEFAULT 1 NOT NULL,
    disabled integer DEFAULT 0 NOT NULL,
    stamp timestamp without time zone DEFAULT '2023-01-01 00:00:01'::timestamp without time zone NOT NULL
);


ALTER TABLE public.rtpengine OWNER TO postgres;

--
-- Name: rtpengine_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rtpengine_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rtpengine_id_seq OWNER TO postgres;

--
-- Name: rtpengine_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rtpengine_id_seq OWNED BY public.rtpengine.id;


--
-- Name: silo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.silo (
    id integer NOT NULL,
    src_addr character varying(255) DEFAULT ''::character varying NOT NULL,
    dst_addr character varying(255) DEFAULT ''::character varying NOT NULL,
    username character varying(64) DEFAULT ''::character varying NOT NULL,
    domain character varying(64) DEFAULT ''::character varying NOT NULL,
    inc_time integer DEFAULT 0 NOT NULL,
    exp_time integer DEFAULT 0 NOT NULL,
    snd_time integer DEFAULT 0 NOT NULL,
    ctype character varying(32) DEFAULT 'text/plain'::character varying NOT NULL,
    body bytea,
    extra_hdrs text,
    callid character varying(128) DEFAULT ''::character varying NOT NULL,
    status integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.silo OWNER TO postgres;

--
-- Name: silo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.silo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.silo_id_seq OWNER TO postgres;

--
-- Name: silo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.silo_id_seq OWNED BY public.silo.id;


--
-- Name: speed_dial; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.speed_dial (
    id integer NOT NULL,
    username character varying(64) DEFAULT ''::character varying NOT NULL,
    domain character varying(64) DEFAULT ''::character varying NOT NULL,
    sd_username character varying(64) DEFAULT ''::character varying NOT NULL,
    sd_domain character varying(64) DEFAULT ''::character varying NOT NULL,
    new_uri character varying(255) DEFAULT ''::character varying NOT NULL,
    fname character varying(64) DEFAULT ''::character varying NOT NULL,
    lname character varying(64) DEFAULT ''::character varying NOT NULL,
    description character varying(64) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.speed_dial OWNER TO postgres;

--
-- Name: speed_dial_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.speed_dial_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.speed_dial_id_seq OWNER TO postgres;

--
-- Name: speed_dial_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.speed_dial_id_seq OWNED BY public.speed_dial.id;


--
-- Name: subscriber; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.subscriber (
    id integer NOT NULL,
    username character varying(64) DEFAULT ''::character varying NOT NULL,
    domain character varying(64) DEFAULT ''::character varying NOT NULL,
    password character varying(64) DEFAULT ''::character varying NOT NULL,
    ha1 character varying(128) DEFAULT ''::character varying NOT NULL,
    ha1b character varying(128) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.subscriber OWNER TO postgres;

--
-- Name: subscriber_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.subscriber_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.subscriber_id_seq OWNER TO postgres;

--
-- Name: subscriber_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.subscriber_id_seq OWNED BY public.subscriber.id;


--
-- Name: topos_d; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.topos_d (
    id integer NOT NULL,
    rectime timestamp without time zone NOT NULL,
    s_method character varying(64) DEFAULT ''::character varying NOT NULL,
    s_cseq character varying(64) DEFAULT ''::character varying NOT NULL,
    a_callid character varying(255) DEFAULT ''::character varying NOT NULL,
    a_uuid character varying(255) DEFAULT ''::character varying NOT NULL,
    b_uuid character varying(255) DEFAULT ''::character varying NOT NULL,
    a_contact character varying(512) DEFAULT ''::character varying NOT NULL,
    b_contact character varying(512) DEFAULT ''::character varying NOT NULL,
    as_contact character varying(512) DEFAULT ''::character varying NOT NULL,
    bs_contact character varying(512) DEFAULT ''::character varying NOT NULL,
    a_tag character varying(255) DEFAULT ''::character varying NOT NULL,
    b_tag character varying(255) DEFAULT ''::character varying NOT NULL,
    a_rr text,
    b_rr text,
    s_rr text,
    iflags integer DEFAULT 0 NOT NULL,
    a_uri character varying(255) DEFAULT ''::character varying NOT NULL,
    b_uri character varying(255) DEFAULT ''::character varying NOT NULL,
    r_uri character varying(255) DEFAULT ''::character varying NOT NULL,
    a_srcaddr character varying(128) DEFAULT ''::character varying NOT NULL,
    b_srcaddr character varying(128) DEFAULT ''::character varying NOT NULL,
    a_socket character varying(128) DEFAULT ''::character varying NOT NULL,
    b_socket character varying(128) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.topos_d OWNER TO postgres;

--
-- Name: topos_d_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.topos_d_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.topos_d_id_seq OWNER TO postgres;

--
-- Name: topos_d_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.topos_d_id_seq OWNED BY public.topos_d.id;


--
-- Name: topos_t; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.topos_t (
    id integer NOT NULL,
    rectime timestamp without time zone NOT NULL,
    s_method character varying(64) DEFAULT ''::character varying NOT NULL,
    s_cseq character varying(64) DEFAULT ''::character varying NOT NULL,
    a_callid character varying(255) DEFAULT ''::character varying NOT NULL,
    a_uuid character varying(255) DEFAULT ''::character varying NOT NULL,
    b_uuid character varying(255) DEFAULT ''::character varying NOT NULL,
    direction integer DEFAULT 0 NOT NULL,
    x_via text,
    x_vbranch character varying(255) DEFAULT ''::character varying NOT NULL,
    x_rr text,
    y_rr text,
    s_rr text,
    x_uri character varying(255) DEFAULT ''::character varying NOT NULL,
    a_contact character varying(512) DEFAULT ''::character varying NOT NULL,
    b_contact character varying(512) DEFAULT ''::character varying NOT NULL,
    as_contact character varying(512) DEFAULT ''::character varying NOT NULL,
    bs_contact character varying(512) DEFAULT ''::character varying NOT NULL,
    x_tag character varying(255) DEFAULT ''::character varying NOT NULL,
    a_tag character varying(255) DEFAULT ''::character varying NOT NULL,
    b_tag character varying(255) DEFAULT ''::character varying NOT NULL,
    a_srcaddr character varying(255) DEFAULT ''::character varying NOT NULL,
    b_srcaddr character varying(255) DEFAULT ''::character varying NOT NULL,
    a_socket character varying(128) DEFAULT ''::character varying NOT NULL,
    b_socket character varying(128) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE public.topos_t OWNER TO postgres;

--
-- Name: topos_t_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.topos_t_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.topos_t_id_seq OWNER TO postgres;

--
-- Name: topos_t_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.topos_t_id_seq OWNED BY public.topos_t.id;


--
-- Name: trusted; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trusted (
    id integer NOT NULL,
    src_ip character varying(50) NOT NULL,
    proto character varying(4) NOT NULL,
    from_pattern character varying(64) DEFAULT NULL::character varying,
    ruri_pattern character varying(64) DEFAULT NULL::character varying,
    tag character varying(64),
    priority integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.trusted OWNER TO postgres;

--
-- Name: trusted_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trusted_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.trusted_id_seq OWNER TO postgres;

--
-- Name: trusted_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trusted_id_seq OWNED BY public.trusted.id;


--
-- Name: uri; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.uri (
    id integer NOT NULL,
    username character varying(64) DEFAULT ''::character varying NOT NULL,
    domain character varying(64) DEFAULT ''::character varying NOT NULL,
    uri_user character varying(64) DEFAULT ''::character varying NOT NULL,
    last_modified timestamp without time zone DEFAULT '2000-01-01 00:00:01'::timestamp without time zone NOT NULL
);


ALTER TABLE public.uri OWNER TO postgres;

--
-- Name: uri_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.uri_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.uri_id_seq OWNER TO postgres;

--
-- Name: uri_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.uri_id_seq OWNED BY public.uri.id;



--
-- Name: userblocklist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.userblocklist (
    id integer NOT NULL,
    username character varying(64) DEFAULT ''::character varying NOT NULL,
    domain character varying(64) DEFAULT ''::character varying NOT NULL,
    prefix character varying(64) DEFAULT ''::character varying NOT NULL,
    allowlist smallint DEFAULT 0 NOT NULL,
    created_at timestamp(0) without time zone DEFAULT timezone('utc'::text, now()),
    last_modified timestamp(0) without time zone DEFAULT timezone('utc'::text, now())
);


ALTER TABLE public.userblocklist OWNER TO postgres;

--
-- Name: userblocklist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.userblocklist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.userblocklist_id_seq OWNER TO postgres;

--
-- Name: userblocklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.userblocklist_id_seq OWNED BY public.userblocklist.id;


--
-- Name: usr_preferences; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usr_preferences (
    id integer NOT NULL,
    uuid character varying(64) DEFAULT ''::character varying NOT NULL,
    username character varying(255) DEFAULT 0 NOT NULL,
    domain character varying(64) DEFAULT ''::character varying NOT NULL,
    attribute character varying(32) DEFAULT ''::character varying NOT NULL,
    type integer DEFAULT 0 NOT NULL,
    value character varying(128) DEFAULT ''::character varying NOT NULL,
    last_modified timestamp without time zone DEFAULT '2000-01-01 00:00:01'::timestamp without time zone NOT NULL
);


ALTER TABLE public.usr_preferences OWNER TO postgres;

--
-- Name: usr_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usr_preferences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usr_preferences_id_seq OWNER TO postgres;

--
-- Name: usr_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usr_preferences_id_seq OWNED BY public.usr_preferences.id;


--
-- Name: version; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.version (
    id integer NOT NULL,
    table_name character varying(32) NOT NULL,
    table_version integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.version OWNER TO postgres;

--
-- Name: version_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.version_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.version_id_seq OWNER TO postgres;

--
-- Name: version_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.version_id_seq OWNED BY public.version.id;


--
-- Name: acc id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acc ALTER COLUMN id SET DEFAULT nextval('public.acc_id_seq'::regclass);


--
-- Name: acc_cdrs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acc_cdrs ALTER COLUMN id SET DEFAULT nextval('public.acc_cdrs_id_seq'::regclass);


--
-- Name: address id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.address ALTER COLUMN id SET DEFAULT nextval('public.address_id_seq'::regclass);


--
-- Name: aliases id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aliases ALTER COLUMN id SET DEFAULT nextval('public.aliases_id_seq'::regclass);


--
-- Name: dbaliases id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dbaliases ALTER COLUMN id SET DEFAULT nextval('public.dbaliases_id_seq'::regclass);


--
-- Name: dialog id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dialog ALTER COLUMN id SET DEFAULT nextval('public.dialog_id_seq'::regclass);


--
-- Name: dialog_vars id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dialog_vars ALTER COLUMN id SET DEFAULT nextval('public.dialog_vars_id_seq'::regclass);


--
-- Name: dialplan id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dialplan ALTER COLUMN id SET DEFAULT nextval('public.dialplan_id_seq'::regclass);


--
-- Name: dispatcher id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispatcher ALTER COLUMN id SET DEFAULT nextval('public.dispatcher_id_seq'::regclass);


--
-- Name: domain id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.domain ALTER COLUMN id SET DEFAULT nextval('public.domain_id_seq'::regclass);


--
-- Name: domain_attrs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.domain_attrs ALTER COLUMN id SET DEFAULT nextval('public.domain_attrs_id_seq'::regclass);


--
-- Name: globalblocklist id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.globalblocklist ALTER COLUMN id SET DEFAULT nextval('public.globalblocklist_id_seq'::regclass);


--
-- Name: grp id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grp ALTER COLUMN id SET DEFAULT nextval('public.grp_id_seq'::regclass);


--
-- Name: htable id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.htable ALTER COLUMN id SET DEFAULT nextval('public.htable_id_seq'::regclass);


--
-- Name: lcr_gw id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lcr_gw ALTER COLUMN id SET DEFAULT nextval('public.lcr_gw_id_seq'::regclass);


--
-- Name: lcr_rule id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lcr_rule ALTER COLUMN id SET DEFAULT nextval('public.lcr_rule_id_seq'::regclass);


--
-- Name: lcr_rule_target id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lcr_rule_target ALTER COLUMN id SET DEFAULT nextval('public.lcr_rule_target_id_seq'::regclass);


--
-- Name: location id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location ALTER COLUMN id SET DEFAULT nextval('public.location_id_seq'::regclass);


--
-- Name: location_attrs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location_attrs ALTER COLUMN id SET DEFAULT nextval('public.location_attrs_id_seq'::regclass);


--
-- Name: missed_calls id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.missed_calls ALTER COLUMN id SET DEFAULT nextval('public.missed_calls_id_seq'::regclass);


--
-- Name: pdt id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pdt ALTER COLUMN id SET DEFAULT nextval('public.pdt_id_seq'::regclass);


--
-- Name: re_grp id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.re_grp ALTER COLUMN id SET DEFAULT nextval('public.re_grp_id_seq'::regclass);


--
-- Name: rtpengine id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rtpengine ALTER COLUMN id SET DEFAULT nextval('public.rtpengine_id_seq'::regclass);


--
-- Name: silo id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.silo ALTER COLUMN id SET DEFAULT nextval('public.silo_id_seq'::regclass);


--
-- Name: speed_dial id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.speed_dial ALTER COLUMN id SET DEFAULT nextval('public.speed_dial_id_seq'::regclass);


--
-- Name: subscriber id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subscriber ALTER COLUMN id SET DEFAULT nextval('public.subscriber_id_seq'::regclass);


--
-- Name: topos_d id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topos_d ALTER COLUMN id SET DEFAULT nextval('public.topos_d_id_seq'::regclass);


--
-- Name: topos_t id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topos_t ALTER COLUMN id SET DEFAULT nextval('public.topos_t_id_seq'::regclass);


--
-- Name: trusted id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trusted ALTER COLUMN id SET DEFAULT nextval('public.trusted_id_seq'::regclass);


--
-- Name: uri id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uri ALTER COLUMN id SET DEFAULT nextval('public.uri_id_seq'::regclass);


--
-- Name: userblocklist id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.userblocklist ALTER COLUMN id SET DEFAULT nextval('public.userblocklist_id_seq'::regclass);


--
-- Name: usr_preferences id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usr_preferences ALTER COLUMN id SET DEFAULT nextval('public.usr_preferences_id_seq'::regclass);


--
-- Name: version id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.version ALTER COLUMN id SET DEFAULT nextval('public.version_id_seq'::regclass);




--
-- Name: acc_cdrs acc_cdrs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acc_cdrs
    ADD CONSTRAINT acc_cdrs_pkey PRIMARY KEY (id);


--
-- Name: acc acc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.acc
    ADD CONSTRAINT acc_pkey PRIMARY KEY (id);


--
-- Name: address address_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (id);


--
-- Name: aliases aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aliases
    ADD CONSTRAINT aliases_pkey PRIMARY KEY (id);


--
-- Name: aliases aliases_ruid_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aliases
    ADD CONSTRAINT aliases_ruid_idx UNIQUE (ruid);


--
-- Name: dbaliases dbaliases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dbaliases
    ADD CONSTRAINT dbaliases_pkey PRIMARY KEY (id);


--
-- Name: dialog dialog_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dialog
    ADD CONSTRAINT dialog_pkey PRIMARY KEY (id);


--
-- Name: dialog_vars dialog_vars_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dialog_vars
    ADD CONSTRAINT dialog_vars_pkey PRIMARY KEY (id);


--
-- Name: dialplan dialplan_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dialplan
    ADD CONSTRAINT dialplan_pkey PRIMARY KEY (id);


--
-- Name: dispatcher dispatcher_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispatcher
    ADD CONSTRAINT dispatcher_pkey PRIMARY KEY (id);


--
-- Name: domain_attrs domain_attrs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.domain_attrs
    ADD CONSTRAINT domain_attrs_pkey PRIMARY KEY (id);


--
-- Name: domain domain_domain_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.domain
    ADD CONSTRAINT domain_domain_idx UNIQUE (domain);


--
-- Name: domain domain_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.domain
    ADD CONSTRAINT domain_pkey PRIMARY KEY (id);


--
-- Name: globalblocklist globalblocklist_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.globalblocklist
    ADD CONSTRAINT globalblocklist_idx UNIQUE (prefix);


--
-- Name: globalblocklist globalblocklist_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.globalblocklist
    ADD CONSTRAINT globalblocklist_pkey PRIMARY KEY (id);


--
-- Name: grp grp_account_group_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grp
    ADD CONSTRAINT grp_account_group_idx UNIQUE (username, domain, grp);


--
-- Name: grp grp_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grp
    ADD CONSTRAINT grp_pkey PRIMARY KEY (id);


--
-- Name: htable htable_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.htable
    ADD CONSTRAINT htable_pkey PRIMARY KEY (id);


--
-- Name: lcr_gw lcr_gw_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lcr_gw
    ADD CONSTRAINT lcr_gw_pkey PRIMARY KEY (id);


--
-- Name: lcr_rule lcr_rule_lcr_id_prefix_from_uri_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lcr_rule
    ADD CONSTRAINT lcr_rule_lcr_id_prefix_from_uri_idx UNIQUE (lcr_id, prefix, from_uri);


--
-- Name: lcr_rule lcr_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lcr_rule
    ADD CONSTRAINT lcr_rule_pkey PRIMARY KEY (id);


--
-- Name: lcr_rule_target lcr_rule_target_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lcr_rule_target
    ADD CONSTRAINT lcr_rule_target_pkey PRIMARY KEY (id);


--
-- Name: lcr_rule_target lcr_rule_target_rule_id_gw_id_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lcr_rule_target
    ADD CONSTRAINT lcr_rule_target_rule_id_gw_id_idx UNIQUE (rule_id, gw_id);


--
-- Name: location_attrs location_attrs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location_attrs
    ADD CONSTRAINT location_attrs_pkey PRIMARY KEY (id);


--
-- Name: location location_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location
    ADD CONSTRAINT location_pkey PRIMARY KEY (id);


--
-- Name: location location_ruid_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location
    ADD CONSTRAINT location_ruid_idx UNIQUE (ruid);


--
-- Name: missed_calls missed_calls_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.missed_calls
    ADD CONSTRAINT missed_calls_pkey PRIMARY KEY (id);


--
-- Name: pdt pdt_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pdt
    ADD CONSTRAINT pdt_pkey PRIMARY KEY (id);


--
-- Name: pdt pdt_sdomain_prefix_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pdt
    ADD CONSTRAINT pdt_sdomain_prefix_idx UNIQUE (sdomain, prefix);


--
-- Name: re_grp re_grp_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.re_grp
    ADD CONSTRAINT re_grp_pkey PRIMARY KEY (id);


--
-- Name: rtpengine rtpengine_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rtpengine
    ADD CONSTRAINT rtpengine_pkey PRIMARY KEY (id);


--
-- Name: rtpengine rtpengine_rtpengine_nodes; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rtpengine
    ADD CONSTRAINT rtpengine_rtpengine_nodes UNIQUE (setid, url);


--
-- Name: silo silo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.silo
    ADD CONSTRAINT silo_pkey PRIMARY KEY (id);


--
-- Name: speed_dial speed_dial_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.speed_dial
    ADD CONSTRAINT speed_dial_pkey PRIMARY KEY (id);


--
-- Name: speed_dial speed_dial_speed_dial_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.speed_dial
    ADD CONSTRAINT speed_dial_speed_dial_idx UNIQUE (username, domain, sd_domain, sd_username);


--
-- Name: subscriber subscriber_account_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subscriber
    ADD CONSTRAINT subscriber_account_idx UNIQUE (username, domain);


--
-- Name: subscriber subscriber_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subscriber
    ADD CONSTRAINT subscriber_pkey PRIMARY KEY (id);


--
-- Name: topos_d topos_d_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topos_d
    ADD CONSTRAINT topos_d_pkey PRIMARY KEY (id);


--
-- Name: topos_t topos_t_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.topos_t
    ADD CONSTRAINT topos_t_pkey PRIMARY KEY (id);


--
-- Name: trusted trusted_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trusted
    ADD CONSTRAINT trusted_pkey PRIMARY KEY (id);


--
-- Name: uri uri_account_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uri
    ADD CONSTRAINT uri_account_idx UNIQUE (username, domain, uri_user);


--
-- Name: uri uri_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uri
    ADD CONSTRAINT uri_pkey PRIMARY KEY (id);


--
-- Name: userblocklist userblocklist_id_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.userblocklist
    ADD CONSTRAINT userblocklist_id_idx UNIQUE (id);


--
-- Name: userblocklist userblocklist_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.userblocklist
    ADD CONSTRAINT userblocklist_idx UNIQUE (username, domain, prefix);


--
-- Name: usr_preferences usr_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usr_preferences
    ADD CONSTRAINT usr_preferences_pkey PRIMARY KEY (id);


--
-- Name: version version_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.version
    ADD CONSTRAINT version_pkey PRIMARY KEY (id);


--
-- Name: version version_table_name_idx; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.version
    ADD CONSTRAINT version_table_name_idx UNIQUE (table_name);


--
-- Name: acc_callid_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX acc_callid_idx ON public.acc USING btree (callid);


--
-- Name: acc_cdrs_start_time_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX acc_cdrs_start_time_idx ON public.acc_cdrs USING btree (start_time);


--
-- Name: aliases_account_contact_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aliases_account_contact_idx ON public.aliases USING btree (username, domain, contact);


--
-- Name: aliases_expires_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX aliases_expires_idx ON public.aliases USING btree (expires);


--
-- Name: dbaliases_alias_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX dbaliases_alias_idx ON public.dbaliases USING btree (alias_username, alias_domain);


--
-- Name: dbaliases_alias_user_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX dbaliases_alias_user_idx ON public.dbaliases USING btree (alias_username);


--
-- Name: dbaliases_target_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX dbaliases_target_idx ON public.dbaliases USING btree (username, domain);


--
-- Name: dialog_hash_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX dialog_hash_idx ON public.dialog USING btree (hash_entry, hash_id);


--
-- Name: dialog_vars_hash_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX dialog_vars_hash_idx ON public.dialog_vars USING btree (hash_entry, hash_id);


--
-- Name: domain_attrs_domain_attrs_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX domain_attrs_domain_attrs_idx ON public.domain_attrs USING btree (did, name);


--
-- Name: lcr_gw_lcr_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX lcr_gw_lcr_id_idx ON public.lcr_gw USING btree (lcr_id);


--
-- Name: lcr_rule_target_lcr_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX lcr_rule_target_lcr_id_idx ON public.lcr_rule_target USING btree (lcr_id);


--
-- Name: location_account_contact_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX location_account_contact_idx ON public.location USING btree (username, domain, contact);


--
-- Name: location_attrs_account_record_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX location_attrs_account_record_idx ON public.location_attrs USING btree (username, domain, ruid);


--
-- Name: location_attrs_last_modified_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX location_attrs_last_modified_idx ON public.location_attrs USING btree (last_modified);


--
-- Name: location_connection_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX location_connection_idx ON public.location USING btree (server_id, connection_id);


--
-- Name: location_expires_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX location_expires_idx ON public.location USING btree (expires);


--
-- Name: missed_calls_callid_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX missed_calls_callid_idx ON public.missed_calls USING btree (callid);


--
-- Name: re_grp_group_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX re_grp_group_idx ON public.re_grp USING btree (group_id);


--
-- Name: silo_account_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX silo_account_idx ON public.silo USING btree (username, domain);


--
-- Name: subscriber_username_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX subscriber_username_idx ON public.subscriber USING btree (username);


--
-- Name: topos_d_a_callid_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX topos_d_a_callid_idx ON public.topos_d USING btree (a_callid);


--
-- Name: topos_d_a_uuid_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX topos_d_a_uuid_idx ON public.topos_d USING btree (a_uuid);


--
-- Name: topos_d_b_uuid_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX topos_d_b_uuid_idx ON public.topos_d USING btree (b_uuid);


--
-- Name: topos_d_rectime_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX topos_d_rectime_idx ON public.topos_d USING btree (rectime);


--
-- Name: topos_t_a_callid_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX topos_t_a_callid_idx ON public.topos_t USING btree (a_callid);


--
-- Name: topos_t_a_uuid_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX topos_t_a_uuid_idx ON public.topos_t USING btree (a_uuid);


--
-- Name: topos_t_rectime_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX topos_t_rectime_idx ON public.topos_t USING btree (rectime);


--
-- Name: topos_t_x_vbranch_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX topos_t_x_vbranch_idx ON public.topos_t USING btree (x_vbranch);


--
-- Name: trusted_peer_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX trusted_peer_idx ON public.trusted USING btree (src_ip);


--
-- Name: usr_preferences_ua_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX usr_preferences_ua_idx ON public.usr_preferences USING btree (uuid, attribute);


--
-- Name: usr_preferences_uda_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX usr_preferences_uda_idx ON public.usr_preferences USING btree (username, domain, attribute);


--
-- Name: dialplan update_last_modified; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_last_modified BEFORE UPDATE ON public.dialplan FOR EACH ROW EXECUTE FUNCTION public.moddatetime('last_modified');


--
-- Name: dispatcher update_last_modified; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_last_modified BEFORE UPDATE ON public.dispatcher FOR EACH ROW EXECUTE FUNCTION public.moddatetime('last_modified');


--
-- Name: domain update_last_modified; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_last_modified BEFORE UPDATE ON public.domain FOR EACH ROW EXECUTE FUNCTION public.moddatetime('last_modified');


--
-- Name: userblocklist update_last_modified; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_last_modified BEFORE UPDATE ON public.userblocklist FOR EACH ROW EXECUTE FUNCTION public.moddatetime('last_modified');



--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA public TO postgres;


--
-- PostgreSQL database dump complete
--

--
-- Database "postgres" dump
--

\connect postgres

--
-- PostgreSQL database dump
--

-- Dumped from database version 13.1 (Debian 13.1-1.pgdg100+1)
-- Dumped by pg_dump version 13.1 (Debian 13.1-1.pgdg100+1)

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
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database cluster dump complete
--


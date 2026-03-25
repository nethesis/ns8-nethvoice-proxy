-- Slot-based port binding for multi-trunk support (Vianova)
-- These tables follow the Kamailio htable schema for dbmode=1 compatibility

-- Table for special domains requiring slot-based port assignment
-- Used by htable "slotdomains"
CREATE TABLE public.slot_domains (
    id integer NOT NULL,
    key_name character varying(64) DEFAULT ''::character varying NOT NULL,
    key_type integer DEFAULT 0 NOT NULL,
    value_type integer DEFAULT 0 NOT NULL,
    key_value character varying(128) DEFAULT ''::character varying NOT NULL,
    expires integer DEFAULT 0 NOT NULL
);

ALTER TABLE public.slot_domains OWNER TO postgres;

CREATE SEQUENCE public.slot_domains_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.slot_domains_id_seq OWNER TO postgres;

ALTER TABLE ONLY public.slot_domains ALTER COLUMN id SET DEFAULT nextval('public.slot_domains_id_seq'::regclass);

ALTER TABLE ONLY public.slot_domains
    ADD CONSTRAINT slot_domains_pkey PRIMARY KEY (id);

CREATE UNIQUE INDEX slot_domains_key_name_idx ON public.slot_domains (key_name);

-- Table for slot assignments: (username::domain) -> slot_name
-- Used by htable "slotassign"
CREATE TABLE public.slot_assignments (
    id integer NOT NULL,
    key_name character varying(128) DEFAULT ''::character varying NOT NULL,
    key_type integer DEFAULT 0 NOT NULL,
    value_type integer DEFAULT 0 NOT NULL,
    key_value character varying(64) DEFAULT ''::character varying NOT NULL,
    expires integer DEFAULT 0 NOT NULL
);

ALTER TABLE public.slot_assignments OWNER TO postgres;

CREATE SEQUENCE public.slot_assignments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.slot_assignments_id_seq OWNER TO postgres;

ALTER TABLE ONLY public.slot_assignments ALTER COLUMN id SET DEFAULT nextval('public.slot_assignments_id_seq'::regclass);

ALTER TABLE ONLY public.slot_assignments
    ADD CONSTRAINT slot_assignments_pkey PRIMARY KEY (id);

CREATE UNIQUE INDEX slot_assignments_key_name_idx ON public.slot_assignments (key_name);

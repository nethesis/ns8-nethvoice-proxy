CREATE TYPE route_type_e AS ENUM ('domain', 'trunk');

CREATE TABLE public.nethvoice_proxy_routes (
    id integer NOT NULL,
    target character varying(64) NOT NULL,
    route_type route_type_e NOT NULL,
    setid integer NOT NULL
);

ALTER TABLE ONLY public.nethvoice_proxy_routes
    ADD CONSTRAINT nethvoice_proxy_routes_pkey PRIMARY KEY (id);

CREATE SEQUENCE public.nethvoice_proxy_routes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE SEQUENCE public.nethvoice_proxy_routes_setid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ONLY public.nethvoice_proxy_routes ALTER COLUMN id SET DEFAULT nextval('public.nethvoice_proxy_routes_id_seq'::regclass);
ALTER TABLE ONLY public.nethvoice_proxy_routes ALTER COLUMN setid SET DEFAULT nextval('public.nethvoice_proxy_routes_setid_seq'::regclass);

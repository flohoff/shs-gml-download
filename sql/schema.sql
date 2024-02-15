
CREATE TABLE public.flur (
    id integer NOT NULL,
    gemeinde character varying,
    gemarkung character varying,
    flur character varying,
    response jsonb,
    geom public.geometry,
    downloaded timestamp without time zone,
    downloadlasttry timestamp without time zone,
    CONSTRAINT enforce_dims_geom CHECK ((public.st_ndims(geom) = 2)),
    CONSTRAINT enforce_geotype_geom CHECK (((public.geometrytype(geom) = 'MULTIPOLYGON'::text) OR (geom IS NULL))),
    CONSTRAINT enforce_srid_geom CHECK ((public.st_srid(geom) = 4326))
);

CREATE SEQUENCE public.flur_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


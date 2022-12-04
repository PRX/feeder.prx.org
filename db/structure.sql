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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: episode_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.episode_images (
    id integer NOT NULL,
    episode_id integer,
    type character varying,
    status integer,
    guid character varying,
    url character varying,
    link character varying,
    original_url character varying,
    description character varying,
    title character varying,
    format character varying,
    height integer,
    width integer,
    size integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: episode_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.episode_images_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: episode_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.episode_images_id_seq OWNED BY public.episode_images.id;


--
-- Name: episodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.episodes (
    id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    podcast_id integer,
    overrides text,
    guid character varying,
    prx_uri character varying,
    deleted_at timestamp without time zone,
    original_guid character varying,
    published_at timestamp without time zone,
    url character varying,
    author_name character varying,
    author_email character varying,
    title text,
    subtitle text,
    content text,
    summary text,
    explicit character varying,
    keywords text,
    description text,
    categories text,
    block boolean,
    is_closed_captioned boolean,
    "position" integer,
    feedburner_orig_link character varying,
    feedburner_orig_enclosure_link character varying,
    is_perma_link boolean,
    source_updated_at timestamp without time zone,
    keyword_xid character varying,
    season_number integer,
    episode_number integer,
    itunes_type character varying DEFAULT 'full'::character varying,
    clean_title text,
    itunes_block boolean DEFAULT false,
    released_at timestamp without time zone,
    prx_audio_version_uri character varying,
    audio_version character varying,
    segment_count integer
);


--
-- Name: episodes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.episodes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: episodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.episodes_id_seq OWNED BY public.episodes.id;


--
-- Name: feed_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feed_images (
    id integer NOT NULL,
    feed_id integer,
    guid character varying,
    url character varying,
    link character varying,
    original_url character varying,
    description character varying,
    title character varying,
    format character varying,
    height integer,
    width integer,
    size integer,
    status integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: feed_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.feed_images_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: feed_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.feed_images_id_seq OWNED BY public.feed_images.id;


--
-- Name: feed_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feed_tokens (
    id integer NOT NULL,
    feed_id integer,
    label character varying,
    token character varying NOT NULL,
    expires_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: feed_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.feed_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: feed_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.feed_tokens_id_seq OWNED BY public.feed_tokens.id;


--
-- Name: feeds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feeds (
    id integer NOT NULL,
    podcast_id integer,
    slug character varying,
    file_name character varying NOT NULL,
    private boolean DEFAULT true,
    title text,
    url character varying,
    new_feed_url character varying,
    display_episodes_count integer,
    display_full_episodes_count integer,
    episode_offset_seconds integer,
    include_zones text,
    include_tags text,
    audio_format text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    enclosure_prefix character varying,
    enclosure_template character varying,
    exclude_tags text,
    subtitle text,
    description text,
    summary text,
    include_podcast_value boolean DEFAULT true,
    include_donation_url boolean DEFAULT true
);


--
-- Name: feeds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.feeds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: feeds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.feeds_id_seq OWNED BY public.feeds.id;


--
-- Name: itunes_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.itunes_categories (
    id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    podcast_id integer,
    name character varying NOT NULL,
    subcategories character varying
);


--
-- Name: itunes_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.itunes_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: itunes_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.itunes_categories_id_seq OWNED BY public.itunes_categories.id;


--
-- Name: itunes_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.itunes_images (
    id integer NOT NULL,
    feed_id integer,
    guid character varying,
    url character varying,
    link character varying,
    original_url character varying,
    description character varying,
    title character varying,
    format character varying,
    height integer,
    width integer,
    size integer,
    status integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: itunes_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.itunes_images_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: itunes_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.itunes_images_id_seq OWNED BY public.itunes_images.id;


--
-- Name: media_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_resources (
    id integer NOT NULL,
    episode_id integer,
    "position" integer,
    type character varying,
    url character varying,
    mime_type character varying,
    file_size integer,
    is_default boolean,
    medium character varying,
    expression character varying,
    bit_rate integer,
    frame_rate integer,
    sample_rate numeric,
    channels integer,
    duration numeric,
    height integer,
    width integer,
    lang character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    original_url character varying,
    guid character varying,
    status integer
);


--
-- Name: media_resources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.media_resources_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_resources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.media_resources_id_seq OWNED BY public.media_resources.id;


--
-- Name: podcasts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.podcasts (
    id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    title text,
    link character varying,
    language character varying,
    managing_editor_name character varying,
    categories character varying,
    keywords character varying,
    update_period character varying,
    update_frequency integer,
    update_base timestamp without time zone,
    copyright character varying,
    author_name character varying,
    owner_name character varying,
    owner_email character varying,
    path character varying,
    max_episodes integer,
    prx_uri character varying,
    author_email character varying,
    source_url character varying,
    complete boolean,
    feedburner_url character varying,
    deleted_at timestamp without time zone,
    managing_editor_email character varying,
    duration_padding numeric,
    explicit character varying,
    prx_account_uri character varying,
    published_at timestamp without time zone,
    source_updated_at timestamp without time zone,
    serial_order boolean DEFAULT false,
    locked boolean DEFAULT false,
    itunes_block boolean DEFAULT false,
    restrictions text,
    payment_pointer character varying,
    donation_url character varying
);


--
-- Name: podcasts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.podcasts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: podcasts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.podcasts_id_seq OWNED BY public.podcasts.id;


--
-- Name: say_when_job_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.say_when_job_executions (
    id integer NOT NULL,
    job_id integer,
    status character varying,
    result text,
    start_at timestamp without time zone,
    end_at timestamp without time zone
);


--
-- Name: say_when_job_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.say_when_job_executions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: say_when_job_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.say_when_job_executions_id_seq OWNED BY public.say_when_job_executions.id;


--
-- Name: say_when_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.say_when_jobs (
    id integer NOT NULL,
    "group" character varying,
    name character varying,
    status character varying,
    trigger_strategy character varying,
    trigger_options text,
    last_fire_at timestamp without time zone,
    next_fire_at timestamp without time zone,
    start_at timestamp without time zone,
    end_at timestamp without time zone,
    job_class character varying,
    job_method character varying,
    data text,
    scheduled_type character varying,
    scheduled_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: say_when_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.say_when_jobs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: say_when_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.say_when_jobs_id_seq OWNED BY public.say_when_jobs.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id integer NOT NULL,
    owner_type character varying,
    owner_id integer,
    type character varying,
    status integer DEFAULT 0 NOT NULL,
    logged_at timestamp without time zone,
    job_id character varying,
    options text,
    result text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tasks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


--
-- Name: episode_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.episode_images ALTER COLUMN id SET DEFAULT nextval('public.episode_images_id_seq'::regclass);


--
-- Name: episodes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.episodes ALTER COLUMN id SET DEFAULT nextval('public.episodes_id_seq'::regclass);


--
-- Name: feed_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_images ALTER COLUMN id SET DEFAULT nextval('public.feed_images_id_seq'::regclass);


--
-- Name: feed_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_tokens ALTER COLUMN id SET DEFAULT nextval('public.feed_tokens_id_seq'::regclass);


--
-- Name: feeds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feeds ALTER COLUMN id SET DEFAULT nextval('public.feeds_id_seq'::regclass);


--
-- Name: itunes_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itunes_categories ALTER COLUMN id SET DEFAULT nextval('public.itunes_categories_id_seq'::regclass);


--
-- Name: itunes_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itunes_images ALTER COLUMN id SET DEFAULT nextval('public.itunes_images_id_seq'::regclass);


--
-- Name: media_resources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_resources ALTER COLUMN id SET DEFAULT nextval('public.media_resources_id_seq'::regclass);


--
-- Name: podcasts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.podcasts ALTER COLUMN id SET DEFAULT nextval('public.podcasts_id_seq'::regclass);


--
-- Name: say_when_job_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.say_when_job_executions ALTER COLUMN id SET DEFAULT nextval('public.say_when_job_executions_id_seq'::regclass);


--
-- Name: say_when_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.say_when_jobs ALTER COLUMN id SET DEFAULT nextval('public.say_when_jobs_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: episode_images episode_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.episode_images
    ADD CONSTRAINT episode_images_pkey PRIMARY KEY (id);


--
-- Name: episodes episodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.episodes
    ADD CONSTRAINT episodes_pkey PRIMARY KEY (id);


--
-- Name: feed_images feed_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_images
    ADD CONSTRAINT feed_images_pkey PRIMARY KEY (id);


--
-- Name: feed_tokens feed_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_tokens
    ADD CONSTRAINT feed_tokens_pkey PRIMARY KEY (id);


--
-- Name: feeds feeds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feeds
    ADD CONSTRAINT feeds_pkey PRIMARY KEY (id);


--
-- Name: itunes_categories itunes_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itunes_categories
    ADD CONSTRAINT itunes_categories_pkey PRIMARY KEY (id);


--
-- Name: itunes_images itunes_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itunes_images
    ADD CONSTRAINT itunes_images_pkey PRIMARY KEY (id);


--
-- Name: media_resources media_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_resources
    ADD CONSTRAINT media_resources_pkey PRIMARY KEY (id);


--
-- Name: podcasts podcasts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.podcasts
    ADD CONSTRAINT podcasts_pkey PRIMARY KEY (id);


--
-- Name: say_when_job_executions say_when_job_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.say_when_job_executions
    ADD CONSTRAINT say_when_job_executions_pkey PRIMARY KEY (id);


--
-- Name: say_when_jobs say_when_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.say_when_jobs
    ADD CONSTRAINT say_when_jobs_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: index_episode_images_on_episode_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_episode_images_on_episode_id ON public.episode_images USING btree (episode_id);


--
-- Name: index_episode_images_on_guid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_episode_images_on_guid ON public.episode_images USING btree (guid);


--
-- Name: index_episodes_on_guid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_episodes_on_guid ON public.episodes USING btree (guid);


--
-- Name: index_episodes_on_keyword_xid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_episodes_on_keyword_xid ON public.episodes USING btree (keyword_xid);


--
-- Name: index_episodes_on_original_guid_and_podcast_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_episodes_on_original_guid_and_podcast_id ON public.episodes USING btree (original_guid, podcast_id) WHERE ((deleted_at IS NULL) AND (original_guid IS NOT NULL));


--
-- Name: index_episodes_on_prx_uri; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_episodes_on_prx_uri ON public.episodes USING btree (prx_uri);


--
-- Name: index_episodes_on_published_at_and_podcast_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_episodes_on_published_at_and_podcast_id ON public.episodes USING btree (published_at, podcast_id);


--
-- Name: index_feed_images_on_feed_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_feed_images_on_feed_id ON public.feed_images USING btree (feed_id);


--
-- Name: index_feed_images_on_guid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_feed_images_on_guid ON public.feed_images USING btree (guid);


--
-- Name: index_feed_tokens_on_feed_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_feed_tokens_on_feed_id ON public.feed_tokens USING btree (feed_id);


--
-- Name: index_feed_tokens_on_feed_id_and_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_feed_tokens_on_feed_id_and_token ON public.feed_tokens USING btree (feed_id, token);


--
-- Name: index_feeds_on_podcast_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_feeds_on_podcast_id ON public.feeds USING btree (podcast_id);


--
-- Name: index_feeds_on_podcast_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_feeds_on_podcast_id_and_slug ON public.feeds USING btree (podcast_id, slug) WHERE (slug IS NOT NULL);


--
-- Name: index_feeds_on_podcast_id_default; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_feeds_on_podcast_id_default ON public.feeds USING btree (podcast_id) WHERE (slug IS NULL);


--
-- Name: index_itunes_images_on_feed_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_itunes_images_on_feed_id ON public.itunes_images USING btree (feed_id);


--
-- Name: index_itunes_images_on_guid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_itunes_images_on_guid ON public.itunes_images USING btree (guid);


--
-- Name: index_media_resources_on_episode_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_media_resources_on_episode_id ON public.media_resources USING btree (episode_id);


--
-- Name: index_media_resources_on_guid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_media_resources_on_guid ON public.media_resources USING btree (guid);


--
-- Name: index_media_resources_on_original_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_media_resources_on_original_url ON public.media_resources USING btree (original_url);


--
-- Name: index_podcasts_on_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_podcasts_on_path ON public.podcasts USING btree (path);


--
-- Name: index_podcasts_on_prx_uri; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_podcasts_on_prx_uri ON public.podcasts USING btree (prx_uri);


--
-- Name: index_podcasts_on_source_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_podcasts_on_source_url ON public.podcasts USING btree (source_url) WHERE ((deleted_at IS NULL) AND (source_url IS NOT NULL));


--
-- Name: index_say_when_job_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_say_when_job_executions_on_job_id ON public.say_when_job_executions USING btree (job_id);


--
-- Name: index_say_when_job_executions_on_status_and_start_at_and_end_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_say_when_job_executions_on_status_and_start_at_and_end_at ON public.say_when_job_executions USING btree (status, start_at, end_at);


--
-- Name: index_say_when_jobs_on_next_fire_at_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_say_when_jobs_on_next_fire_at_and_status ON public.say_when_jobs USING btree (next_fire_at, status);


--
-- Name: index_say_when_jobs_on_scheduled_type_and_scheduled_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_say_when_jobs_on_scheduled_type_and_scheduled_id ON public.say_when_jobs USING btree (scheduled_type, scheduled_id);


--
-- Name: index_tasks_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_job_id ON public.tasks USING btree (job_id);


--
-- Name: index_tasks_on_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_owner ON public.tasks USING btree (owner_type, owner_id);


--
-- Name: index_tasks_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_status ON public.tasks USING btree (status);


--
-- Name: feeds fk_rails_ba103032b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feeds
    ADD CONSTRAINT fk_rails_ba103032b9 FOREIGN KEY (podcast_id) REFERENCES public.podcasts(id);


--
-- Name: feed_tokens fk_rails_c6adc92c5e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_tokens
    ADD CONSTRAINT fk_rails_c6adc92c5e FOREIGN KEY (feed_id) REFERENCES public.feeds(id);


--
-- Name: itunes_images fk_rails_e47e471e3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itunes_images
    ADD CONSTRAINT fk_rails_e47e471e3f FOREIGN KEY (feed_id) REFERENCES public.feeds(id);


--
-- Name: feed_images fk_rails_fdbb95f64b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_images
    ADD CONSTRAINT fk_rails_fdbb95f64b FOREIGN KEY (feed_id) REFERENCES public.feeds(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20141212193255'),
('20141212204151'),
('20141212212757'),
('20141217190838'),
('20141217192717'),
('20141217212323'),
('20141217215330'),
('20141218173519'),
('20141222182251'),
('20150105204957'),
('20150105211403'),
('20150106173954'),
('20150203013418'),
('20150204221200'),
('20150205175613'),
('20150604184449'),
('20150605130436'),
('20150605181622'),
('20150605213849'),
('20150605224030'),
('20150606154517'),
('20150608194749'),
('20150701142651'),
('20150825182150'),
('20150922184417'),
('20150923141439'),
('20150923142208'),
('20151003004616'),
('20151005185404'),
('20151008163401'),
('20151105175033'),
('20151109165806'),
('20151110173743'),
('20151110214928'),
('20151112022708'),
('20151117195934'),
('20151117214252'),
('20151118023919'),
('20151208181322'),
('20160215031227'),
('20160216190727'),
('20160308215641'),
('20160721152111'),
('20161014123500'),
('20161114233540'),
('20161118210927'),
('20161120134824'),
('20161121171637'),
('20161218183833'),
('20170110154352'),
('20170120221323'),
('20170123205547'),
('20170223114125'),
('20170223174042'),
('20170309181410'),
('20170621213139'),
('20170921182535'),
('20170926204117'),
('20170926210603'),
('20170928174959'),
('20180214144148'),
('20180214150849'),
('20180515172031'),
('20190724191053'),
('20200312201710'),
('20200312202854'),
('20200427153653'),
('20201214170208'),
('20210204184430'),
('20220118221746'),
('20220207234307'),
('20220707203621'),
('20220707204115'),
('20220801154805'),
('20220817212106'),
('20220823044927'),
('20220928174716');



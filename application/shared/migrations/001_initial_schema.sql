CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY,
    job_type TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    processing_token UUID,
    processing_started_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS job_results (
    id UUID PRIMARY KEY,
    job_id UUID NOT NULL UNIQUE REFERENCES jobs(id) ON DELETE CASCADE,
    result JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_events (
    id UUID PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    action TEXT NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS object_metadata (
    id UUID PRIMARY KEY,
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    object_key TEXT NOT NULL,
    object_type TEXT NOT NULL,
    owner_ref TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (job_id, object_key)
);

CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS job_outbox (
    id UUID PRIMARY KEY,
    event_type TEXT NOT NULL,
    version INTEGER NOT NULL,
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'publishing', 'published', 'failed')),
    attempts INTEGER NOT NULL DEFAULT 0,
    locked_at TIMESTAMPTZ,
    claim_token UUID,
    published_at TIMESTAMPTZ,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_customers_created_at ON customers (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_status_created_at ON jobs (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_entity ON audit_events (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_object_metadata_job_id ON object_metadata (job_id);
CREATE INDEX IF NOT EXISTS idx_object_metadata_key ON object_metadata (object_key);
CREATE INDEX IF NOT EXISTS idx_job_outbox_status_created_at ON job_outbox (status, created_at);
CREATE INDEX IF NOT EXISTS idx_jobs_processing_lease ON jobs (status, processing_started_at);
CREATE INDEX IF NOT EXISTS idx_job_outbox_publishing_lease ON job_outbox (status, locked_at);

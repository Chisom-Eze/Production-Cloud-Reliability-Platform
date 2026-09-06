ALTER TABLE jobs
    ADD COLUMN IF NOT EXISTS processing_token UUID,
    ADD COLUMN IF NOT EXISTS processing_started_at TIMESTAMPTZ;

ALTER TABLE job_outbox
    ADD COLUMN IF NOT EXISTS claim_token UUID;

CREATE INDEX IF NOT EXISTS idx_jobs_processing_lease ON jobs (status, processing_started_at);
CREATE INDEX IF NOT EXISTS idx_job_outbox_publishing_lease ON job_outbox (status, locked_at);

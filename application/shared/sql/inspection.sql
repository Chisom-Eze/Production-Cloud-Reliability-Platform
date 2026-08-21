-- Inspect recent customers.
SELECT id, name, email, created_at
FROM customers
ORDER BY created_at DESC
LIMIT 10;

-- Inspect jobs with any generated artifact metadata.
SELECT
    j.id,
    j.job_type,
    j.status,
    j.attempts,
    o.object_key,
    r.result,
    j.created_at,
    j.updated_at
FROM jobs j
LEFT JOIN job_results r ON r.job_id = j.id
LEFT JOIN object_metadata o ON o.job_id = j.id
ORDER BY j.created_at DESC
LIMIT 10;

-- Inspect audit history.
SELECT entity_type, entity_id, action, details, created_at
FROM audit_events
ORDER BY created_at DESC
LIMIT 20;

-- Use this shape when discussing query plans.
EXPLAIN
SELECT j.id, j.status, o.object_key
FROM jobs j
LEFT JOIN object_metadata o ON o.job_id = j.id
WHERE j.status = 'completed';


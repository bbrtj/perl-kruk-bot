-- Deploy kruk:snippets to sqlite

BEGIN;

CREATE TABLE snippets(
	id VARCHAR(26) PRIMARY KEY NOT NULL,
	syntax VARCHAR(32) NULL,
	snippet TEXT NOT NULL,
	created_at INTEGER NOT NULL
);

CREATE INDEX ind_snippets_lookup ON snippets (created_at);

COMMIT;


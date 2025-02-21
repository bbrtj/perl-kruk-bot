-- Deploy kruk:notes to pg

BEGIN;

CREATE TABLE notes(
	id SERIAL PRIMARY KEY NOT NULL,
	context VARCHAR(64) NULL,
	content TEXT NOT NULL,
	reason VARCHAR(64) NOT NULL,
	created_at INTEGER NOT NULL
);

COMMIT;


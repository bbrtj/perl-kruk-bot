-- Deploy kruk:notes to sqlite

BEGIN;

CREATE TABLE notes(
	id INTEGER PRIMARY KEY NOT NULL,
	context VARCHAR(64) NULL,
	content TEXT NOT NULL,
	reason VARCHAR(64) NOT NULL,
	created_at INTEGER NOT NULL
);

COMMIT;


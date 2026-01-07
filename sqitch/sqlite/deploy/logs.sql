-- Deploy kruk:logs to sqlite

BEGIN;

CREATE TABLE logs(
	id INTEGER PRIMARY KEY NOT NULL,
	channel VARCHAR(64) NULL,
	username VARCHAR(64) NULL,
	message TEXT NOT NULL,
	created_at INTEGER NOT NULL
);

CREATE INDEX ind_logs_lookup ON logs (channel, created_at);

COMMIT;


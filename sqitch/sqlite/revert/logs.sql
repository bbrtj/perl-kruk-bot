-- Revert kruk:logs from sqlite

BEGIN;

DROP TABLE logs;

COMMIT;


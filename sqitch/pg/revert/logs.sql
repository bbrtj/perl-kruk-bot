-- Revert kruk:logs from pg

BEGIN;

DROP TABLE logs;

COMMIT;


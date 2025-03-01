-- Revert kruk:snippets from pg

BEGIN;

DROP TABLE snippets;

COMMIT;


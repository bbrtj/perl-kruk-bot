-- Revert kruk:snippets from sqlite

BEGIN;

DROP TABLE snippets;

COMMIT;


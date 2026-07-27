-- Run once against your Turso DB to initialise the schema.
-- turso db shell <db-name> < lib/schema.sql

CREATE TABLE IF NOT EXISTS licenses (
  key           TEXT PRIMARY KEY,
  machine_id    TEXT,
  activated_at  TEXT,
  revoked       INTEGER NOT NULL DEFAULT 0,
  notes         TEXT     -- e.g. "twitter.com/user/status/123 · 142 likes"
);

CREATE TABLE IF NOT EXISTS waitlist (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  email         TEXT NOT NULL UNIQUE,
  twitter       TEXT,
  source        TEXT NOT NULL DEFAULT 'landing',  -- 'landing' | 'footer' | 'cta'
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

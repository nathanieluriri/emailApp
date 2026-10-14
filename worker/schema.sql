CREATE TABLE IF NOT EXISTS threads (
  id TEXT PRIMARY KEY,
  subject TEXT,
  last_message_at INTEGER NOT NULL,
  message_count INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  thread_id TEXT NOT NULL REFERENCES threads(id),
  message_id_header TEXT UNIQUE,
  in_reply_to TEXT,
  references_hdr TEXT,
  direction TEXT NOT NULL CHECK (direction IN ('in', 'out')),
  from_addr TEXT NOT NULL,
  from_name TEXT,
  to_json TEXT NOT NULL DEFAULT '[]',
  cc_json TEXT NOT NULL DEFAULT '[]',
  bcc_json TEXT NOT NULL DEFAULT '[]',
  subject TEXT,
  snippet TEXT,
  html TEXT,
  text TEXT,
  date INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  read INTEGER NOT NULL DEFAULT 0,
  starred INTEGER NOT NULL DEFAULT 0,
  archived INTEGER NOT NULL DEFAULT 0,
  has_attachments INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_messages_thread ON messages(thread_id, date);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(direction, created_at);

CREATE TABLE IF NOT EXISTS attachments (
  id TEXT PRIMARY KEY,
  message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  filename TEXT,
  mime_type TEXT,
  size INTEGER,
  content_id TEXT,
  r2_key TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_attachments_message ON attachments(message_id);

CREATE TABLE IF NOT EXISTS labels (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  color TEXT,
  system INTEGER NOT NULL DEFAULT 0
);
INSERT OR IGNORE INTO labels (id, name, system) VALUES
  ('inbox', 'Inbox', 1), ('sent', 'Sent', 1), ('spam', 'Spam', 1), ('trash', 'Trash', 1);

CREATE TABLE IF NOT EXISTS message_labels (
  message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  label_id TEXT NOT NULL REFERENCES labels(id) ON DELETE CASCADE,
  PRIMARY KEY (message_id, label_id)
);
CREATE INDEX IF NOT EXISTS idx_message_labels_label ON message_labels(label_id);

CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
  subject, from_name, from_addr, text, content='messages', content_rowid='rowid'
);
CREATE TRIGGER IF NOT EXISTS messages_ai AFTER INSERT ON messages BEGIN
  INSERT INTO messages_fts(rowid, subject, from_name, from_addr, text)
  VALUES (new.rowid, new.subject, new.from_name, new.from_addr, new.text);
END;
CREATE TRIGGER IF NOT EXISTS messages_ad AFTER DELETE ON messages BEGIN
  INSERT INTO messages_fts(messages_fts, rowid, subject, from_name, from_addr, text)
  VALUES ('delete', old.rowid, old.subject, old.from_name, old.from_addr, old.text);
END;

CREATE TABLE IF NOT EXISTS templates (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  subject TEXT,
  html TEXT,
  blocks_json TEXT,
  variables_json TEXT NOT NULL DEFAULT '[]',
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS signatures (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  html TEXT,
  sender_address TEXT,
  is_default INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT
);

CREATE TABLE IF NOT EXISTS message_owners (
  message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  address TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('from', 'to')),
  PRIMARY KEY (address, role, message_id)
);
CREATE INDEX IF NOT EXISTS idx_message_owners_message ON message_owners(message_id);

CREATE TABLE IF NOT EXISTS device_mailboxes (
  device_id TEXT NOT NULL,
  address TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (device_id, address)
);
CREATE INDEX IF NOT EXISTS idx_device_mailboxes_address ON device_mailboxes(address);

-- Gives mail stored before mailboxes existed to its sender and recipients.
INSERT OR IGNORE INTO message_owners (message_id, address, role)
  SELECT id, lower(from_addr), 'from' FROM messages WHERE direction = 'out';
INSERT OR IGNORE INTO message_owners (message_id, address, role)
  SELECT m.id, lower(json_extract(r.value, '$.address')), 'to'
  FROM messages m, json_each(m.to_json) r WHERE m.direction = 'in' AND json_extract(r.value, '$.address') IS NOT NULL;
INSERT OR IGNORE INTO message_owners (message_id, address, role)
  SELECT m.id, lower(json_extract(r.value, '$.address')), 'to'
  FROM messages m, json_each(m.cc_json) r WHERE m.direction = 'in' AND json_extract(r.value, '$.address') IS NOT NULL;

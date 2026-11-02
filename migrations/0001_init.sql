-- Safe to run more than once: the Worker runs this automatically on first use.

-- Users: admins can manage workflow + users, staff can manage enquiries.
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'staff')),
  password_hash TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  failed_logins INTEGER NOT NULL DEFAULT 0,
  locked_until INTEGER,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

-- Pipeline stages (fully editable by admins).
CREATE TABLE IF NOT EXISTS stages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  color TEXT NOT NULL DEFAULT '#8a9a8b',
  position INTEGER NOT NULL DEFAULT 0,
  is_won INTEGER NOT NULL DEFAULT 0,
  is_lost INTEGER NOT NULL DEFAULT 0
);

-- Custom fields shown on the enquiry form (fully editable by admins).
-- type: text | textarea | email | phone | number | date | select | checkbox | duration
-- options: JSON array of choices for select fields
-- config: JSON, e.g. {"from":"date_of_enquiry","to":"booking_confirmed"} for duration fields
CREATE TABLE IF NOT EXISTS fields (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  key TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  type TEXT NOT NULL,
  options TEXT NOT NULL DEFAULT '[]',
  config TEXT NOT NULL DEFAULT '{}',
  section TEXT NOT NULL DEFAULT 'Details',
  required INTEGER NOT NULL DEFAULT 0,
  show_in_list INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL DEFAULT 0,
  archived INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS enquiries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id INTEGER REFERENCES stages(id) ON DELETE SET NULL,
  data TEXT NOT NULL DEFAULT '{}',
  assigned_to INTEGER REFERENCES users(id) ON DELETE SET NULL,
  created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  updated_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_enquiries_stage ON enquiries(stage_id);

CREATE TABLE IF NOT EXISTS activity (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  enquiry_id INTEGER NOT NULL REFERENCES enquiries(id) ON DELETE CASCADE,
  user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  kind TEXT NOT NULL, -- created | updated | note
  message TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_activity_enquiry ON activity(enquiry_id);

-- Default birthday party workflow (editable in Admin settings → Workflow stages).
INSERT OR IGNORE INTO stages (id, name, color, position, is_won, is_lost) VALUES
  (1, 'New enquiry',     '#e0a030', 1, 0, 0),
  (2, 'Responded',       '#5b8fd1', 2, 0, 0),
  (3, 'Booked',          '#4e9e63', 3, 1, 0),
  (4, 'Lost / declined', '#b05a5a', 4, 0, 1);

-- config.form = the matching question in the Google Form / response sheet, so form answers land in the right field.
INSERT OR IGNORE INTO fields (key, label, type, options, config, section, required, show_in_list, position) VALUES
  ('child_name',       'Birthday star',            'text',     '[]', '{"form":"Who''s the Star of the show?"}', 'The party', 0, 1, 3),
  ('age',              'Turning (candles)',        'text',     '[]', '{"form":"How many candles are on the cake this year?"}', 'The party', 0, 1, 4),
  ('party_date',       'Preferred date',           'date',     '[]', '{"form":"When’s the big adventure happening?"}', 'The party', 0, 1, 5),
  ('plan_b',           'Plan B date',              'text',     '[]', '{"form":"Got a Plan B?"}', 'The party', 0, 0, 6),
  ('session_time',     'Morning or afternoon',     'select',   '[]', '{"form":"Is your adventurer a morning explorer or an afternoon thrill-seeker?"}', 'The party', 0, 1, 7),
  ('kids',             'Kids (adventure crew)',    'text',     '[]', '{"form":"How big is the adventure crew?"}', 'The party', 0, 1, 8),
  ('adults',           'Grown-ups / spectators',   'text',     '[]', '{"form":"How many grown-ups / spectators will be tagging along?"}', 'The party', 0, 0, 9),
  ('package',          'Package',                  'select',   '[]', '{"form":"We’ve got birthday party packages to suit every adventurer—from self-led fun with full-day access (9am-5pm) to fully hosted experiences with a party area and a 1.5-hour Laser Skirmish session! Check out our website and let us know which adventure you''re excited to book!"}', 'The party', 0, 1, 10),
  ('camping',          'Camping',                  'text',     '[]', '{"form":"Want to keep the adventure going? Add a night of camping for just $10 per camper! Let us know how many campers and for which night."}', 'Extras', 0, 0, 14),
  ('party_bags',       'Party bags',               'select',   '[]', '{"form":"Party bags? Yes, please! We can deliver them in a keepsake Woodhouse camping mug for just $14 per child! Sound like a plan?"}', 'Extras', 0, 0, 15),
  ('how_woodhouse',    'How Woodhouse are you?',   'select',   '[]', '{"form":"How Woodhouse are you?"}', 'Extras', 0, 0, 16),
  ('form_notes',       'Anything else (from form)','textarea', '[]', '{"form":"Anything else you''d like us to know???"}', 'Extras', 0, 0, 17),
  ('contact_name',     'Contact name',             'text',     '[]', '{"form":"Who should we call for all the details?"}', 'Contact', 0, 1, 11),
  ('phone',            'Phone',                    'phone',    '[]', '{"form":"Where can we reach you?"}', 'Contact', 0, 1, 12),
  ('email',            'Email',                    'email',    '[]', '{"form":"Email Address"}', 'Contact', 0, 0, 13),
  ('date_of_enquiry',  'Date of enquiry',          'date',     '[]', '{"form":"Timestamp"}', 'Enquiry', 0, 1, 1),
  ('enquiry_source',   'Enquiry source',           'select',
     '["Google Form","Phone","Email","Walk-in","Facebook","Instagram","Other"]', '{}', 'Enquiry', 0, 0, 2),
  ('date_responded',   'Date responded',           'date',     '[]', '{}', 'Response', 0, 0, 18),
  ('days_to_respond',  'Days to respond',          'duration', '[]', '{"from":"date_of_enquiry","to":"date_responded"}', 'Response', 0, 0, 19),
  ('dates_offered',    'Dates offered',            'textarea', '[]', '{}', 'Response', 0, 0, 20),
  ('confirmed_date',   'Confirmed party date',     'date',     '[]', '{}', 'Booking', 0, 1, 21),
  ('booked_venuelife', 'Booked in VenueLife',      'checkbox', '[]', '{}', 'Booking', 0, 0, 22),
  ('rostered',         'Rostered',                 'checkbox', '[]', '{}', 'Booking', 0, 0, 23),
  ('comments',         'Staff notes',              'textarea', '[]', '{}', 'Notes',   0, 0, 24);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
INSERT OR IGNORE INTO settings (key, value) VALUES ('app_name', 'Birthday Enquiries');

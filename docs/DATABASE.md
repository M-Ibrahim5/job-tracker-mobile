# JobTrail — MySQL Schema

MySQL 8.0+, InnoDB, `utf8mb4` / `utf8mb4_0900_ai_ci`. All timestamps stored in **UTC** (`DATETIME(3)`); `applied_date` is a calendar `DATE`. Ids are `BIGINT UNSIGNED AUTO_INCREMENT` (API serializes as JSON numbers; they fit Dart `int`).

All user-owned tables carry `user_id`; every query MUST filter by the authenticated user.

```sql
CREATE TABLE users (
  id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email            VARCHAR(254) NOT NULL,
  password_hash    VARCHAR(255) NOT NULL,
  full_name        VARCHAR(100) NOT NULL,
  phone            VARCHAR(30)  NULL,
  job_role         VARCHAR(100) NULL,   -- API field `currentRole` (avoid reserved word CURRENT_ROLE)
  looking_for      VARCHAR(100) NULL,
  location         VARCHAR(100) NULL,
  avatar_path      VARCHAR(255) NULL,
  email_verified_at DATETIME(3) NULL,
  created_at       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_users_email (email)
);

CREATE TABLE refresh_tokens (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id      BIGINT UNSIGNED NOT NULL,
  token_hash   CHAR(64) NOT NULL,            -- sha256 of the opaque token
  expires_at   DATETIME(3) NOT NULL,
  revoked_at   DATETIME(3) NULL,
  created_at   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_refresh_hash (token_hash),
  KEY idx_refresh_user (user_id),
  CONSTRAINT fk_refresh_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE device_tokens (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id      BIGINT UNSIGNED NOT NULL,
  token_hash   CHAR(64) NOT NULL,            -- sha256 of the opaque device token
  device_name  VARCHAR(100) NULL,
  expires_at   DATETIME(3) NOT NULL,         -- slides forward 90 days on every use
  last_used_at DATETIME(3) NULL,
  revoked_at   DATETIME(3) NULL,
  created_at   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_device_hash (token_hash),
  KEY idx_device_user (user_id),
  CONSTRAINT fk_device_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
-- Added by migration V2__device_tokens.sql (fingerprint login).

CREATE TABLE user_settings (
  user_id                      BIGINT UNSIGNED PRIMARY KEY,
  theme                        ENUM('system','light','dark') NOT NULL DEFAULT 'system',
  interview_reminders_enabled  TINYINT(1) NOT NULL DEFAULT 1,
  followup_reminders_enabled   TINYINT(1) NOT NULL DEFAULT 1,
  status_alerts_enabled        TINYINT(1) NOT NULL DEFAULT 1,
  default_reminder_offsets     JSON NOT NULL,          -- minutes before event, default [1440, 60]
  default_followup_days        TINYINT UNSIGNED NULL,  -- NULL = off; allowed 3,5,7,14
  CONSTRAINT fk_settings_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE job_applications (
  id                BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id           BIGINT UNSIGNED NOT NULL,
  job_title         VARCHAR(100) NOT NULL,
  company_name      VARCHAR(100) NOT NULL,
  location          VARCHAR(100) NOT NULL,
  work_arrangement  ENUM('onsite','hybrid','remote') NOT NULL,
  job_description   MEDIUMTEXT NULL,                    -- app enforces <= 10,000 chars
  application_link  VARCHAR(2048) NULL,
  employment_type   ENUM('fullTime','partTime','contract','internship') NULL,
  salary_range      VARCHAR(100) NULL,
  source            ENUM('linkedIn','jobStreet','indeed','companySite','referral','other') NULL,
  applied_date      DATE NOT NULL,
  status            ENUM('applied','screening','interview','offer','rejected') NOT NULL DEFAULT 'applied',
  notes             TEXT NULL,
  contact_name      VARCHAR(100) NULL,
  contact_email     VARCHAR(254) NULL,
  follow_up_at      DATETIME(3) NULL,
  created_at        DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at        DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  KEY idx_app_user_status (user_id, status),
  KEY idx_app_user_applied (user_id, applied_date),
  KEY idx_app_user_followup (user_id, follow_up_at),
  CONSTRAINT fk_app_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE status_history (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id         BIGINT UNSIGNED NOT NULL,
  application_id  BIGINT UNSIGNED NOT NULL,
  from_status     ENUM('applied','screening','interview','offer','rejected') NULL,  -- NULL = initial entry
  to_status       ENUM('applied','screening','interview','offer','rejected') NOT NULL,
  changed_at      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  note            VARCHAR(500) NULL,
  KEY idx_hist_app (application_id, changed_at),
  KEY idx_hist_user_changed (user_id, changed_at),
  CONSTRAINT fk_hist_app FOREIGN KEY (application_id) REFERENCES job_applications(id) ON DELETE CASCADE,
  CONSTRAINT fk_hist_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE interviews (
  id                BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id           BIGINT UNSIGNED NOT NULL,
  application_id    BIGINT UNSIGNED NOT NULL,
  title             VARCHAR(150) NOT NULL,
  type              ENUM('phone','video','onsite','technical','hr','finalRound','other') NOT NULL,
  scheduled_at      DATETIME(3) NOT NULL,
  duration_minutes  SMALLINT UNSIGNED NOT NULL DEFAULT 60,
  location_or_link  VARCHAR(2048) NULL,
  interviewer_name  VARCHAR(100) NULL,
  notes             TEXT NULL,
  reminder_offsets  JSON NOT NULL,                   -- minutes before scheduled_at, e.g. [1440, 60]
  outcome           ENUM('pending','passed','failed','cancelled') NOT NULL DEFAULT 'pending',
  created_at        DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at        DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_interview_slot (application_id, scheduled_at),
  KEY idx_int_user_time (user_id, scheduled_at),
  CONSTRAINT fk_int_app FOREIGN KEY (application_id) REFERENCES job_applications(id) ON DELETE CASCADE,
  CONSTRAINT fk_int_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE notifications (
  id                      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id                 BIGINT UNSIGNED NOT NULL,
  type                    ENUM('interviewReminder','followUpReminder','statusChange','system') NOT NULL,
  title                   VARCHAR(150) NOT NULL,
  body                    VARCHAR(500) NOT NULL,
  related_application_id  BIGINT UNSIGNED NULL,
  related_interview_id    BIGINT UNSIGNED NULL,
  visible_at              DATETIME(3) NOT NULL,       -- reminders: their fire time; others: created time
  is_read                 TINYINT(1) NOT NULL DEFAULT 0,
  created_at              DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_notif_user_visible (user_id, visible_at),
  KEY idx_notif_user_unread (user_id, is_read, visible_at),
  CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_notif_app FOREIGN KEY (related_application_id) REFERENCES job_applications(id) ON DELETE CASCADE,
  CONSTRAINT fk_notif_int FOREIGN KEY (related_interview_id) REFERENCES interviews(id) ON DELETE CASCADE
);
```

## Rules

- **Enum values are camelCase strings exactly as above**; they are identical in the API and the Flutter enums (`finalRound`, not `final`).
- **Initial history row**: creating an application inserts a `status_history` row (`from_status` NULL, `to_status` = status). Changing status is the only way to modify `status` (PATCH ignores it). Both writes in one transaction.
- **Reminder notifications**: when an interview is created/updated, delete its unfired reminder rows (`related_interview_id = ? AND visible_at > NOW()`), then insert one row per offset with `visible_at = scheduled_at - offset`, only if in the future and the user's `interview_reminders_enabled`. Same idea for `follow_up_at` (`followUpReminder`). The API only lists rows with `visible_at <= NOW()`, so reminders "appear" at fire time. Status changes insert a `statusChange` row immediately (if `status_alerts_enabled`).
- **Delete all data** removes applications (cascades history, interviews, notifications) for the user, keeps the account and settings.
- Migrations: Flyway, in `backend/common/src/main/resources/db/migration` (`V1__init.sql` is this schema). Never edit applied migrations; add `V2__...sql`.
- **Table ownership** (microservices share this one schema, but each service only reads/writes its own tables): `users`, `refresh_tokens`, `device_tokens`, `user_settings` → user-service; `job_applications`, `status_history`, `interviews`, `notifications` → tracker-service. The foreign keys to `users` (and their `ON DELETE CASCADE`) stay: deleting an account removes everything. The tracker gets a user's reminder preferences from the user service, not from `user_settings`.
- Dashboard "weeks" are Monday-start in the **user's timezone**; the client sends `tz` (IANA name) with dashboard/calendar requests.

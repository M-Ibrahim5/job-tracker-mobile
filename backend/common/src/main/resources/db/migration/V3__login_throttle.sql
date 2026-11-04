-- Failed password attempts per account (keyed by e-mail, also for e-mails that have no account, so
-- the throttle does not reveal which addresses exist). Rows are short-lived and purged nightly.
CREATE TABLE `login_throttle` (
    `email` VARCHAR(254) NOT NULL,
    `failures` INT UNSIGNED NOT NULL,
    `window_started_at` DATETIME(3) NOT NULL,
    `locked_until` DATETIME(3) NULL,

    INDEX `idx_throttle_window`(`window_started_at`),
    PRIMARY KEY (`email`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- Speeds up the nightly purge of expired and revoked tokens.
CREATE INDEX `idx_refresh_expires` ON `refresh_tokens`(`expires_at`);
CREATE INDEX `idx_device_expires` ON `device_tokens`(`expires_at`);

-- JobTrail schema v1 (mirrors docs/DATABASE.md). Never edit once applied; add V2__... instead.
-- Databases created earlier by Prisma are adopted by Flyway's baseline-on-migrate (version 1).
CREATE TABLE `users` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `email` VARCHAR(254) NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `full_name` VARCHAR(100) NOT NULL,
    `phone` VARCHAR(30) NULL,
    `job_role` VARCHAR(100) NULL,
    `looking_for` VARCHAR(100) NULL,
    `location` VARCHAR(100) NULL,
    `avatar_path` VARCHAR(255) NULL,
    `email_verified_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `uq_users_email`(`email`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `refresh_tokens` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT UNSIGNED NOT NULL,
    `token_hash` CHAR(64) NOT NULL,
    `expires_at` DATETIME(3) NOT NULL,
    `revoked_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `uq_refresh_hash`(`token_hash`),
    INDEX `idx_refresh_user`(`user_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `user_settings` (
    `user_id` BIGINT UNSIGNED NOT NULL,
    `theme` ENUM('system', 'light', 'dark') NOT NULL DEFAULT 'system',
    `interview_reminders_enabled` BOOLEAN NOT NULL DEFAULT true,
    `followup_reminders_enabled` BOOLEAN NOT NULL DEFAULT true,
    `status_alerts_enabled` BOOLEAN NOT NULL DEFAULT true,
    `default_reminder_offsets` JSON NOT NULL,
    `default_followup_days` TINYINT UNSIGNED NULL,

    PRIMARY KEY (`user_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `job_applications` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT UNSIGNED NOT NULL,
    `job_title` VARCHAR(100) NOT NULL,
    `company_name` VARCHAR(100) NOT NULL,
    `location` VARCHAR(100) NOT NULL,
    `work_arrangement` ENUM('onsite', 'hybrid', 'remote') NOT NULL,
    `job_description` MEDIUMTEXT NULL,
    `application_link` VARCHAR(2048) NULL,
    `employment_type` ENUM('fullTime', 'partTime', 'contract', 'internship') NULL,
    `salary_range` VARCHAR(100) NULL,
    `source` ENUM('linkedIn', 'jobStreet', 'indeed', 'companySite', 'referral', 'other') NULL,
    `applied_date` DATE NOT NULL,
    `status` ENUM('applied', 'screening', 'interview', 'offer', 'rejected') NOT NULL DEFAULT 'applied',
    `notes` TEXT NULL,
    `contact_name` VARCHAR(100) NULL,
    `contact_email` VARCHAR(254) NULL,
    `follow_up_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    INDEX `idx_app_user_status`(`user_id`, `status`),
    INDEX `idx_app_user_applied`(`user_id`, `applied_date`),
    INDEX `idx_app_user_followup`(`user_id`, `follow_up_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `status_history` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT UNSIGNED NOT NULL,
    `application_id` BIGINT UNSIGNED NOT NULL,
    `from_status` ENUM('applied', 'screening', 'interview', 'offer', 'rejected') NULL,
    `to_status` ENUM('applied', 'screening', 'interview', 'offer', 'rejected') NOT NULL,
    `changed_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `note` VARCHAR(500) NULL,

    INDEX `idx_hist_app`(`application_id`, `changed_at`),
    INDEX `idx_hist_user_changed`(`user_id`, `changed_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `interviews` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT UNSIGNED NOT NULL,
    `application_id` BIGINT UNSIGNED NOT NULL,
    `title` VARCHAR(150) NOT NULL,
    `type` ENUM('phone', 'video', 'onsite', 'technical', 'hr', 'finalRound', 'other') NOT NULL,
    `scheduled_at` DATETIME(3) NOT NULL,
    `duration_minutes` SMALLINT UNSIGNED NOT NULL DEFAULT 60,
    `location_or_link` VARCHAR(2048) NULL,
    `interviewer_name` VARCHAR(100) NULL,
    `notes` TEXT NULL,
    `reminder_offsets` JSON NOT NULL,
    `outcome` ENUM('pending', 'passed', 'failed', 'cancelled') NOT NULL DEFAULT 'pending',
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

    INDEX `idx_int_user_time`(`user_id`, `scheduled_at`),
    UNIQUE INDEX `uq_interview_slot`(`application_id`, `scheduled_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `notifications` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT UNSIGNED NOT NULL,
    `type` ENUM('interviewReminder', 'followUpReminder', 'statusChange', 'system') NOT NULL,
    `title` VARCHAR(150) NOT NULL,
    `body` VARCHAR(500) NOT NULL,
    `related_application_id` BIGINT UNSIGNED NULL,
    `related_interview_id` BIGINT UNSIGNED NULL,
    `visible_at` DATETIME(3) NOT NULL,
    `is_read` BOOLEAN NOT NULL DEFAULT false,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `idx_notif_user_visible`(`user_id`, `visible_at`),
    INDEX `idx_notif_user_unread`(`user_id`, `is_read`, `visible_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

ALTER TABLE `refresh_tokens` ADD CONSTRAINT `fk_refresh_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `user_settings` ADD CONSTRAINT `fk_settings_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `job_applications` ADD CONSTRAINT `fk_app_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `status_history` ADD CONSTRAINT `fk_hist_app` FOREIGN KEY (`application_id`) REFERENCES `job_applications`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `status_history` ADD CONSTRAINT `fk_hist_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `interviews` ADD CONSTRAINT `fk_int_app` FOREIGN KEY (`application_id`) REFERENCES `job_applications`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `interviews` ADD CONSTRAINT `fk_int_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `notifications` ADD CONSTRAINT `fk_notif_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `notifications` ADD CONSTRAINT `fk_notif_app` FOREIGN KEY (`related_application_id`) REFERENCES `job_applications`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `notifications` ADD CONSTRAINT `fk_notif_int` FOREIGN KEY (`related_interview_id`) REFERENCES `interviews`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

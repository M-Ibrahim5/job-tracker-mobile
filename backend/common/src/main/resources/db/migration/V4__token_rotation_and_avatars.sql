-- Refresh-token rotation details, so a client that lost a refresh response can retry briefly
-- without being treated as a thief: when a token was rotated and which token replaced it.
ALTER TABLE `refresh_tokens`
    ADD COLUMN `rotated_at` DATETIME(3) NULL,
    ADD COLUMN `replaced_by` BIGINT UNSIGNED NULL;

-- Avatar images live in the database (not on one server's disk), so every user-service instance can
-- serve them. Images are re-encoded to at most 512 px, so rows stay small.
CREATE TABLE `user_avatars` (
    `file_name` VARCHAR(100) NOT NULL,
    `user_id` BIGINT UNSIGNED NOT NULL,
    `content_type` VARCHAR(30) NOT NULL,
    `bytes` MEDIUMBLOB NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `idx_avatar_user`(`user_id`),
    PRIMARY KEY (`file_name`),
    CONSTRAINT `fk_avatar_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- Lets the nightly retention job find old, read notifications without scanning every row.
CREATE INDEX `idx_notif_read_visible` ON `notifications`(`is_read`, `visible_at`);

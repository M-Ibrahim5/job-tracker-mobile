-- Run once as a MySQL admin:  mysql -u root -p < docs/sql/00-create-databases.sql
-- Change the user name/password first. Do NOT commit real credentials.
-- Tables are created by Flyway when a service (or the seed) starts; the user only needs DDL + DML rights.
CREATE DATABASE IF NOT EXISTS jobtrail
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE DATABASE IF NOT EXISTS jobtrail_test
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE USER IF NOT EXISTS 'jobtrail'@'localhost' IDENTIFIED BY 'CHANGE_ME';
GRANT ALL PRIVILEGES ON jobtrail.*      TO 'jobtrail'@'localhost';
GRANT ALL PRIVILEGES ON jobtrail_test.* TO 'jobtrail'@'localhost';
FLUSH PRIVILEGES;

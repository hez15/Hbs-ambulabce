-- HBS Ambulance — database schema
-- Run once; safe to re-run (uses IF NOT EXISTS / IF NOT EXISTS column checks)

CREATE TABLE IF NOT EXISTS `hbs_injuries` (
    `citizenid`  VARCHAR(50)  NOT NULL,
    `body_part`  VARCHAR(20)  NOT NULL,
    `severity`   VARCHAR(20)  NOT NULL,
    PRIMARY KEY (`citizenid`, `body_part`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Migration for existing installs where column was named 'part' instead of 'body_part'.
-- Safe to re-run if already on the correct name (will error silently and be ignored
-- by oxmysql's schema runner — or just run manually: ALTER TABLE hbs_injuries RENAME COLUMN part TO body_part)
ALTER TABLE `hbs_injuries` CHANGE `part` `body_part` VARCHAR(20) NOT NULL;

CREATE TABLE IF NOT EXISTS `hbs_stress` (
    `citizenid`  VARCHAR(50)  NOT NULL,
    `stress`     INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hbs_addiction` (
    `citizenid`  VARCHAR(50)  NOT NULL,
    `substance`  VARCHAR(50)  NOT NULL,
    `level`      INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`, `substance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hbs_ems_research` (
    `citizenid`  VARCHAR(50)  NOT NULL,
    `tier`       INT          NOT NULL DEFAULT 0,
    `xp`         INT          NOT NULL DEFAULT 0,
    `unlocks`    LONGTEXT     DEFAULT NULL,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hbs_diseases` (
    `citizenid`  VARCHAR(50)  NOT NULL,
    `disease`    VARCHAR(50)  NOT NULL,
    `stage`      INT          NOT NULL DEFAULT 1,
    PRIMARY KEY (`citizenid`, `disease`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

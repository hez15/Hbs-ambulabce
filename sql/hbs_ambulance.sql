-- HBS Ambulance Database Schema
-- Run this SQL on your database before starting the resource

CREATE TABLE IF NOT EXISTS `hbs_injuries` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `citizenid`  VARCHAR(50)  NOT NULL,
    `body_part`  VARCHAR(30)  NOT NULL,
    `severity`   VARCHAR(20)  NOT NULL DEFAULT 'scratch',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hbs_bills` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `amount` INT(11) NOT NULL DEFAULT 0,
    `reason` VARCHAR(150) NOT NULL,
    `paid` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid_paid` (`citizenid`, `paid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hbs_stress` (
    `citizenid` VARCHAR(50) NOT NULL,
    `stress` INT(11) DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hbs_addiction` (
    `citizenid` VARCHAR(50) NOT NULL,
    `substance` VARCHAR(50) NOT NULL,
    `level` TINYINT(1) DEFAULT 0 COMMENT '0=none,1=developing,2=moderate,3=severe,4=critical',
    `last_use` TIMESTAMP NULL DEFAULT NULL,
    `total_uses` INT(11) DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `substance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

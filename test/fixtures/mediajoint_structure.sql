-- MySQL dump 10.13  Distrib 8.0.33, for macos12.6 (arm64)
--
-- Host: 127.0.0.1    Database: mediajoint_production
-- ------------------------------------------------------
-- Server version	5.7.12

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `account_applications`
--

DROP TABLE IF EXISTS `account_applications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `account_applications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `client_application_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_account_applications_uniq` (`account_id`,`client_application_id`)
) ENGINE=InnoDB AUTO_INCREMENT=877 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary view structure for view `account_fragments`
--

DROP TABLE IF EXISTS `account_fragments`;
/*!50001 DROP VIEW IF EXISTS `account_fragments`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `account_fragments` AS SELECT 
 1 AS `id`,
 1 AS `type`,
 1 AS `name`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `account_images`
--

DROP TABLE IF EXISTS `account_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `account_images` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `filename` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `thumbnail` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `width` int(11) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  `aspect_ratio` float DEFAULT NULL,
  `account_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `upload_path` text COLLATE utf8mb4_swedish_ci,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `caption` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `credit` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `purpose` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `account_images_account_id_fk` (`account_id`),
  KEY `parent_id_idx` (`parent_id`),
  KEY `index_account_images_on_updated_at` (`updated_at`)
) ENGINE=InnoDB AUTO_INCREMENT=11941 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `account_memberships`
--

DROP TABLE IF EXISTS `account_memberships`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `account_memberships` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `size_limit` int(11) DEFAULT NULL,
  `payment_status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `payment_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `price_paid` int(11) DEFAULT NULL,
  `account_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `notes` text COLLATE utf8mb4_swedish_ci,
  PRIMARY KEY (`id`),
  KEY `current_membership_idx` (`account_id`,`start_date`,`end_date`),
  KEY `account_id_idx` (`account_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7966 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `account_message_types`
--

DROP TABLE IF EXISTS `account_message_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `account_message_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `message_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `user_recipients` text COLLATE utf8mb4_swedish_ci,
  `email_recipients` text COLLATE utf8mb4_swedish_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `default_recipients` text COLLATE utf8mb4_swedish_ci,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12836 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accounts`
--

DROP TABLE IF EXISTS `accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `accounts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `opener_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `station_call_letters` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `station_frequency` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `station_coverage_area` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `contact_phone` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `contact_email` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `contact_id` int(11) DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `request_description` text COLLATE utf8mb4_swedish_ci,
  `description` text COLLATE utf8mb4_swedish_ci,
  `opener_role` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `intended_uses` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `address_id` int(11) DEFAULT NULL,
  `request_licensing_at` datetime DEFAULT NULL,
  `contact_first_name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `contact_last_name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `station_total_revenue` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `station_total_revenue_year` int(11) DEFAULT NULL,
  `planned_programming` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `path` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `phone` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `outside_purchaser_at` datetime DEFAULT NULL,
  `outside_purchaser_default_option` tinyint(1) DEFAULT NULL,
  `total_points_earned` int(11) DEFAULT '0',
  `total_points_spent` int(11) DEFAULT '0',
  `additional_size_limit` int(11) DEFAULT '0',
  `api_key` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `npr_org_id` int(11) DEFAULT NULL,
  `delivery_ftp_password` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `stripe_customer_token` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `card_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `card_last_four` int(11) DEFAULT NULL,
  `card_exp_month` int(11) DEFAULT NULL,
  `card_exp_year` int(11) DEFAULT NULL,
  `short_name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `delivery_ftp_user` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `accounts_opener_id_fk` (`opener_id`),
  KEY `accounts_contact_id_fk` (`contact_id`),
  KEY `path_idx` (`path`),
  KEY `deleted_at_idx` (`deleted_at`),
  KEY `outside_purchaser_at_idx` (`outside_purchaser_at`),
  KEY `status_idx` (`status`),
  KEY `index_accounts_on_api_key` (`api_key`)
) ENGINE=InnoDB AUTO_INCREMENT=240501 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `addresses`
--

DROP TABLE IF EXISTS `addresses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `addresses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `addressable_id` int(11) DEFAULT NULL,
  `addressable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `street_1` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `street_2` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `street_3` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `postal_code` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `city` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `state` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `country` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_addresses_on_addressable_type_and_addressable_id` (`addressable_type`,`addressable_id`),
  KEY `index_addresses_on_updated_at` (`updated_at`)
) ENGINE=InnoDB AUTO_INCREMENT=548212 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `affiliations`
--

DROP TABLE IF EXISTS `affiliations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `affiliations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `affiliable_id` int(11) DEFAULT NULL,
  `affiliable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2695 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `alerts`
--

DROP TABLE IF EXISTS `alerts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `alerts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `account_id` int(11) DEFAULT NULL,
  `end_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `alerted_id` int(11) DEFAULT NULL,
  `alerted_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `query_key` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT '',
  `options` text COLLATE utf8mb4_swedish_ci,
  `resolution` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_alerts_on_account_id` (`account_id`),
  KEY `index_alerts_on_alerted_id_and_alerted_type` (`alerted_id`,`alerted_type`),
  KEY `index_alerts_on_key` (`query_key`)
) ENGINE=InnoDB AUTO_INCREMENT=119274 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `audio_file_deliveries`
--

DROP TABLE IF EXISTS `audio_file_deliveries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audio_file_deliveries` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `job_id` int(11) DEFAULT NULL,
  `audio_file_id` int(11) DEFAULT NULL,
  `delivery_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `cart_number` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `destination` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `segment_number` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_audio_file_deliveries_on_delivery_id` (`delivery_id`)
) ENGINE=InnoDB AUTO_INCREMENT=22812567 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `audio_file_listenings`
--

DROP TABLE IF EXISTS `audio_file_listenings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audio_file_listenings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `audio_file_id` int(11) NOT NULL DEFAULT '0',
  `thirty_seconds` tinyint(1) DEFAULT '0',
  `user_id` int(11) DEFAULT NULL,
  `cookie` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `ip_address` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `from_page` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `audio_file_id_idx` (`audio_file_id`)
) ENGINE=InnoDB AUTO_INCREMENT=974928 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `audio_file_templates`
--

DROP TABLE IF EXISTS `audio_file_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audio_file_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `audio_version_template_id` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `label` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `length_minimum` int(11) DEFAULT NULL,
  `length_maximum` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2547 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `audio_files`
--

DROP TABLE IF EXISTS `audio_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audio_files` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `position` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `audio_version_id` int(11) DEFAULT NULL,
  `account_id` int(11) DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `filename` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `parent_id` int(11) DEFAULT NULL,
  `label` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `length` int(11) DEFAULT NULL,
  `layer` int(11) DEFAULT NULL,
  `bit_rate` int(11) NOT NULL DEFAULT '0',
  `frequency` decimal(5,2) NOT NULL DEFAULT '0.00',
  `channel_mode` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `format` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `listenable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `listenable_id` int(11) DEFAULT NULL,
  `upload_path` text COLLATE utf8mb4_swedish_ci,
  `current_job_id` int(11) DEFAULT NULL,
  `status_message` text COLLATE utf8mb4_swedish_ci,
  `integrated_loudness` decimal(15,10) DEFAULT NULL,
  `loudness_range` decimal(15,10) DEFAULT NULL,
  `true_peak` decimal(15,10) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `audio_files_audio_version_id_fk` (`audio_version_id`),
  KEY `audio_files_account_id_fk` (`account_id`),
  KEY `audio_files_parent_id_fk` (`parent_id`),
  KEY `position_idx` (`position`),
  KEY `status_idx` (`status`),
  KEY `listenable_idx` (`listenable_type`,`listenable_id`),
  KEY `index_audio_files_on_account_id_and_filename` (`account_id`,`filename`)
) ENGINE=InnoDB AUTO_INCREMENT=4232325 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `audio_version_templates`
--

DROP TABLE IF EXISTS `audio_version_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audio_version_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `series_id` int(11) DEFAULT NULL,
  `label` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `promos` tinyint(1) DEFAULT NULL,
  `length_minimum` int(11) DEFAULT NULL,
  `segment_count` int(11) DEFAULT NULL,
  `length_maximum` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1463 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `audio_versions`
--

DROP TABLE IF EXISTS `audio_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audio_versions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `piece_id` int(11) DEFAULT NULL,
  `label` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `content_advisory` text COLLATE utf8mb4_swedish_ci,
  `timing_and_cues` text COLLATE utf8mb4_swedish_ci,
  `transcript` mediumtext COLLATE utf8mb4_swedish_ci,
  `news_hole_break` tinyint(1) DEFAULT NULL,
  `floating_break` tinyint(1) DEFAULT NULL,
  `bottom_of_hour_break` tinyint(1) DEFAULT NULL,
  `twenty_forty_break` tinyint(1) DEFAULT NULL,
  `promos` tinyint(1) NOT NULL DEFAULT '0',
  `deleted_at` datetime DEFAULT NULL,
  `audio_version_template_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `explicit` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `status_message` text COLLATE utf8mb4_swedish_ci,
  PRIMARY KEY (`id`),
  KEY `audio_versions_piece_id_fk` (`piece_id`),
  KEY `index_audio_versions_on_updated_at` (`updated_at`)
) ENGINE=InnoDB AUTO_INCREMENT=935633 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `available_for_tasks`
--

DROP TABLE IF EXISTS `available_for_tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `available_for_tasks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `available_for_tasks_user_id_fk` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=25447 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `awards`
--

DROP TABLE IF EXISTS `awards`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `awards` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `awardable_id` int(11) DEFAULT NULL,
  `awardable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `awarded_on` date DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2284 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `badges_privileges`
--

DROP TABLE IF EXISTS `badges_privileges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `badges_privileges` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_badges_privileges_on_name` (`name`),
  KEY `name_idx` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=93 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `badges_role_privileges`
--

DROP TABLE IF EXISTS `badges_role_privileges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `badges_role_privileges` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `role_id` int(11) DEFAULT NULL,
  `privilege_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_badges_role_privileges_on_role_id_and_privilege_id` (`role_id`,`privilege_id`)
) ENGINE=InnoDB AUTO_INCREMENT=225 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `badges_roles`
--

DROP TABLE IF EXISTS `badges_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `badges_roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_badges_roles_on_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `badges_user_roles`
--

DROP TABLE IF EXISTS `badges_user_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `badges_user_roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `role_id` int(11) DEFAULT NULL,
  `authorizable_id` int(11) DEFAULT NULL,
  `authorizable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_badges_user_roles_on_user_id` (`user_id`),
  KEY `user_role_authorize` (`user_id`,`role_id`,`authorizable_type`,`authorizable_id`),
  KEY `authorizable_idx` (`authorizable_type`,`authorizable_id`)
) ENGINE=InnoDB AUTO_INCREMENT=714443 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `blacklists`
--

DROP TABLE IF EXISTS `blacklists`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `blacklists` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `domain` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_blacklists_on_domain` (`domain`)
) ENGINE=InnoDB AUTO_INCREMENT=194 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `carriages`
--

DROP TABLE IF EXISTS `carriages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `carriages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `purchase_id` int(11) DEFAULT NULL,
  `comments` text COLLATE utf8mb4_swedish_ci,
  `aired_at` datetime DEFAULT NULL,
  `air_time` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `medium` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `purchase_id_idx` (`purchase_id`)
) ENGINE=InnoDB AUTO_INCREMENT=343017 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cart_number_sequences`
--

DROP TABLE IF EXISTS `cart_number_sequences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cart_number_sequences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `numbered_id` int(11) DEFAULT NULL,
  `numbered_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `start_number` int(11) DEFAULT NULL,
  `end_number` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=370 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `client_applications`
--

DROP TABLE IF EXISTS `client_applications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `client_applications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `support_url` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `callback_url` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `key` varchar(40) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `secret` varchar(40) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `image_url` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `template_name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `auto_grant` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_client_applications_on_key` (`key`),
  UNIQUE KEY `client_applications_unique_name_idx` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=45 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cms_say_when_job_executions`
--

DROP TABLE IF EXISTS `cms_say_when_job_executions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cms_say_when_job_executions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job_id` int(11) DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `result` text COLLATE utf8mb4_swedish_ci,
  `start_at` datetime DEFAULT NULL,
  `end_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_cms_say_when_job_executions_on_job_id` (`job_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cms_say_when_jobs`
--

DROP TABLE IF EXISTS `cms_say_when_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cms_say_when_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `group` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `trigger_strategy` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `trigger_options` text COLLATE utf8mb4_swedish_ci,
  `last_fire_at` datetime DEFAULT NULL,
  `next_fire_at` datetime DEFAULT NULL,
  `start_at` datetime DEFAULT NULL,
  `end_at` datetime DEFAULT NULL,
  `job_class` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `job_method` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `data` text COLLATE utf8mb4_swedish_ci,
  `scheduled_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `scheduled_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_cms_say_when_jobs_on_next_fire_at_and_status` (`next_fire_at`,`status`),
  KEY `index_cms_say_when_jobs_on_scheduled_type_and_scheduled_id` (`scheduled_type`,`scheduled_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comatose_files`
--

DROP TABLE IF EXISTS `comatose_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comatose_files` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `filename` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `thumbnail` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `width` int(11) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  `aspect_ratio` float DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=9437 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comatose_page_files`
--

DROP TABLE IF EXISTS `comatose_page_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comatose_page_files` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `page_id` int(11) DEFAULT NULL,
  `file_attachment_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2411 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comatose_page_versions`
--

DROP TABLE IF EXISTS `comatose_page_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comatose_page_versions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `comatose_page_id` int(11) DEFAULT NULL,
  `version` int(11) DEFAULT NULL,
  `parent_id` bigint(11) DEFAULT NULL,
  `full_path` text COLLATE utf8mb4_swedish_ci,
  `title` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `slug` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `keywords` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `body` mediumtext COLLATE utf8mb4_swedish_ci,
  `filter_type` varchar(25) COLLATE utf8mb4_swedish_ci DEFAULT 'Textile',
  `author` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `position` bigint(11) DEFAULT '0',
  `updated_on` datetime DEFAULT NULL,
  `created_on` datetime DEFAULT NULL,
  `status` varchar(20) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `published_on` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `comatose_page_id_idx` (`comatose_page_id`),
  KEY `version_idx` (`version`),
  KEY `comatose_page_id_version_idx` (`comatose_page_id`,`version`)
) ENGINE=InnoDB AUTO_INCREMENT=9546 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comatose_pages`
--

DROP TABLE IF EXISTS `comatose_pages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comatose_pages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) DEFAULT NULL,
  `full_path` text COLLATE utf8mb4_swedish_ci,
  `title` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `slug` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `keywords` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `body` mediumtext COLLATE utf8mb4_swedish_ci,
  `filter_type` varchar(25) COLLATE utf8mb4_swedish_ci DEFAULT 'Textile',
  `author` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `position` int(11) DEFAULT '0',
  `version` int(11) DEFAULT NULL,
  `updated_on` datetime DEFAULT NULL,
  `created_on` datetime DEFAULT NULL,
  `status` varchar(40) COLLATE utf8mb4_swedish_ci DEFAULT 'draft',
  `published_on` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=305 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comment_ratings`
--

DROP TABLE IF EXISTS `comment_ratings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comment_ratings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `comment_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `helpful` tinyint(1) DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=796 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comments`
--

DROP TABLE IF EXISTS `comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `commentable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `commentable_id` int(11) DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `body` text COLLATE utf8mb4_swedish_ci,
  `user_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_comments_on_commentable_type_and_commentable_id` (`commentable_type`,`commentable_id`),
  KEY `deleted_at_idx` (`deleted_at`),
  KEY `user_id_idx` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=21444 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `contact_associations`
--

DROP TABLE IF EXISTS `contact_associations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `contact_associations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `contact_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `confirmed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5994 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `date_peg_instances`
--

DROP TABLE IF EXISTS `date_peg_instances`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `date_peg_instances` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `date_peg_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=496 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `date_pegs`
--

DROP TABLE IF EXISTS `date_pegs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `date_pegs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `playlist_id` int(11) DEFAULT NULL,
  `slug` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=108 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `default_images`
--

DROP TABLE IF EXISTS `default_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `default_images` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `filename` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `width` int(11) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  `aspect_ratio` float DEFAULT NULL,
  `thumbnail` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `caption` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `credit` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `tone` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `credit_url` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `delegations`
--

DROP TABLE IF EXISTS `delegations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `delegations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `delegate_account_id` int(11) DEFAULT NULL,
  `role` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_delegations_on_account_id_and_delegate_account_id_and_role` (`account_id`,`delegate_account_id`,`role`),
  KEY `index_delegations_on_delegate_account_id` (`delegate_account_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1140 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `deliveries`
--

DROP TABLE IF EXISTS `deliveries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `deliveries` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `subscription_id` int(11) DEFAULT NULL,
  `piece_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `purchase_id` int(11) DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `transport_method` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `filename_format` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `audio_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `cart_number_start` int(11) DEFAULT NULL,
  `end_air_days` int(11) DEFAULT NULL,
  `audio_version_id` int(11) DEFAULT NULL,
  `deliver_promos` tinyint(1) DEFAULT NULL,
  `episode_number` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_deliveries_on_subscription_id_and_episode_number` (`subscription_id`,`episode_number`)
) ENGINE=InnoDB AUTO_INCREMENT=5793038 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `delivery_logs`
--

DROP TABLE IF EXISTS `delivery_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `delivery_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `delivery_id` int(11) DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `message` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `result` text COLLATE utf8mb4_swedish_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `audio_file_delivery_id` int(11) DEFAULT NULL,
  `logged_at` datetime(3) DEFAULT NULL,
  `porter_execution_id` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `porter_job_id` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `porter_state` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `delivery_logs_audio_logged_status_index` (`audio_file_delivery_id`,`logged_at`,`status`),
  KEY `delivery_delivery_logs` (`delivery_id`,`audio_file_delivery_id`,`logged_at`)
) ENGINE=InnoDB AUTO_INCREMENT=80987004 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `delivery_logs_archive`
--

DROP TABLE IF EXISTS `delivery_logs_archive`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `delivery_logs_archive` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `delivery_id` int(11) DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `message` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `result` text COLLATE utf8mb4_swedish_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `audio_file_delivery_id` int(11) DEFAULT NULL,
  `logged_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `delivery_logs_audio_logged_status_index` (`audio_file_delivery_id`,`logged_at`,`status`),
  KEY `delivery_delivery_logs` (`delivery_id`,`audio_file_delivery_id`,`logged_at`)
) ENGINE=InnoDB AUTO_INCREMENT=69929612 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `discounts`
--

DROP TABLE IF EXISTS `discounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `discounts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `discountable_id` int(11) DEFAULT NULL,
  `discountable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `amount` float DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `note` text COLLATE utf8mb4_swedish_ci,
  `expires_at` date DEFAULT NULL,
  `starts_at` date DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=584 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `distribution_templates`
--

DROP TABLE IF EXISTS `distribution_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `distribution_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `distribution_id` int(11) DEFAULT NULL,
  `audio_version_template_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_distribution_templates` (`distribution_id`,`audio_version_template_id`)
) ENGINE=InnoDB AUTO_INCREMENT=873 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `distributions`
--

DROP TABLE IF EXISTS `distributions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `distributions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `distributable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `distributable_id` int(11) DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `guid` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `properties` text COLLATE utf8mb4_swedish_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_distributions_on_distributable_type_and_distributable_id` (`distributable_type`,`distributable_id`)
) ENGINE=InnoDB AUTO_INCREMENT=575 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `educational_experiences`
--

DROP TABLE IF EXISTS `educational_experiences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `educational_experiences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `degree` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `school` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `graduated_on` date DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `educational_experiences_user_id_fk` (`user_id`),
  CONSTRAINT `educational_experiences_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3495 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `episode_imports`
--

DROP TABLE IF EXISTS `episode_imports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `episode_imports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `podcast_import_id` int(11) DEFAULT NULL,
  `piece_id` int(11) DEFAULT NULL,
  `guid` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `entry` text COLLATE utf8mb4_swedish_ci,
  `audio` text COLLATE utf8mb4_swedish_ci,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `has_duplicate_guid` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_episode_imports_on_podcast_import_id` (`podcast_import_id`),
  KEY `index_episode_imports_on_has_duplicate_guid` (`has_duplicate_guid`)
) ENGINE=InnoDB AUTO_INCREMENT=19122 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `equipment`
--

DROP TABLE IF EXISTS `equipment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `equipment` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `equipment_user_id_fk` (`user_id`),
  CONSTRAINT `equipment_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10289 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `financial_transactions`
--

DROP TABLE IF EXISTS `financial_transactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `financial_transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `paypal_transaction_id` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `paypal_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `received_at` datetime DEFAULT NULL,
  `gross` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `fee` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `currency` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `account_membership_id` int(11) DEFAULT NULL,
  `account` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `invoice` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3857 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flags`
--

DROP TABLE IF EXISTS `flags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `flags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `flaggable_id` int(11) DEFAULT NULL,
  `flaggable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `reason` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `flaggable_idx` (`flaggable_id`,`flaggable_type`)
) ENGINE=InnoDB AUTO_INCREMENT=566 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `formats`
--

DROP TABLE IF EXISTS `formats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `formats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `piece_id` int(11) DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `formats_piece_id_fk` (`piece_id`),
  KEY `name_idx` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=360506 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ftp_addresses`
--

DROP TABLE IF EXISTS `ftp_addresses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ftp_addresses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ftpable_id` int(11) DEFAULT NULL,
  `ftpable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `host` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `port` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `user` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `password` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `directory` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `options` text COLLATE utf8mb4_swedish_ci,
  `protocol` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT 'ftp',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=38909 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `geo_data`
--

DROP TABLE IF EXISTS `geo_data`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `geo_data` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `zip_code` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `zip_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `city` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `city_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `county` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `county_fips` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `state` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `state_abbr` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `state_fips` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `msa_code` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `area_code` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `time_zone` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `utc` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `dst` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `latitude` float DEFAULT NULL,
  `longitude` float DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `zip_code_idx` (`zip_code`),
  KEY `area_code_idx` (`area_code`),
  KEY `time_zone_idx` (`time_zone`),
  KEY `latitude_idx` (`latitude`),
  KEY `longitude_idx` (`longitude`)
) ENGINE=InnoDB AUTO_INCREMENT=41817 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `geocodes`
--

DROP TABLE IF EXISTS `geocodes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `geocodes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `latitude` decimal(15,12) DEFAULT NULL,
  `longitude` decimal(15,12) DEFAULT NULL,
  `query` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `street` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `locality` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `region` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `postal_code` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `country` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `approximate` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `geocodes_query_index` (`query`),
  KEY `geocodes_longitude_index` (`longitude`),
  KEY `geocodes_latitude_index` (`latitude`)
) ENGINE=InnoDB AUTO_INCREMENT=88296 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `geocodings`
--

DROP TABLE IF EXISTS `geocodings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `geocodings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `geocodable_id` int(11) DEFAULT NULL,
  `geocode_id` int(11) DEFAULT NULL,
  `geocodable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `geocodings_geocodable_type_index` (`geocodable_type`),
  KEY `geocodings_geocode_id_index` (`geocode_id`),
  KEY `geocodings_geocodable_id_index` (`geocodable_id`)
) ENGINE=InnoDB AUTO_INCREMENT=561526 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `greylistings`
--

DROP TABLE IF EXISTS `greylistings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `greylistings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `piece_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `piece_id_idx` (`piece_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `identities`
--

DROP TABLE IF EXISTS `identities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `identities` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `provider` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `accesstoken` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `uid` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `image_url` text COLLATE utf8mb4_swedish_ci,
  `secrettoken` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `refreshtoken` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_identities_on_user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2067 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `languages`
--

DROP TABLE IF EXISTS `languages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `languages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `languages_user_id_fk` (`user_id`),
  CONSTRAINT `languages_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5088 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `license_versions`
--

DROP TABLE IF EXISTS `license_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `license_versions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `license_id` int(11) DEFAULT NULL,
  `version` int(11) DEFAULT NULL,
  `piece_id` bigint(11) DEFAULT NULL,
  `website_usage` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `allow_edit` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `additional_terms` text COLLATE utf8mb4_swedish_ci,
  `version_user_id` bigint(11) DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_license_versions_on_license_id_and_version` (`license_id`,`version`)
) ENGINE=InnoDB AUTO_INCREMENT=811038 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `licenses`
--

DROP TABLE IF EXISTS `licenses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `licenses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `piece_id` int(11) DEFAULT NULL,
  `website_usage` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `allow_edit` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `additional_terms` text COLLATE utf8mb4_swedish_ci,
  `version_user_id` int(11) DEFAULT NULL,
  `version` int(11) DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `licenses_piece_id_fk` (`piece_id`),
  KEY `index_licenses_on_updated_at` (`updated_at`)
) ENGINE=InnoDB AUTO_INCREMENT=406672 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `memberships`
--

DROP TABLE IF EXISTS `memberships`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `memberships` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `request` text COLLATE utf8mb4_swedish_ci,
  `approved` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `role` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_user_account` (`account_id`,`user_id`),
  KEY `memberships_account_id_fk` (`account_id`),
  KEY `memberships_user_id_fk` (`user_id`),
  KEY `index_memberships_on_updated_at` (`updated_at`)
) ENGINE=InnoDB AUTO_INCREMENT=473718 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `memberships_archive`
--

DROP TABLE IF EXISTS `memberships_archive`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `memberships_archive` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `request` text COLLATE utf8mb4_swedish_ci,
  `approved` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `role` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `memberships_account_id_fk` (`account_id`),
  KEY `memberships_user_id_fk` (`user_id`),
  KEY `index_memberships_on_updated_at` (`updated_at`)
) ENGINE=InnoDB AUTO_INCREMENT=206496 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `memberships_old`
--

DROP TABLE IF EXISTS `memberships_old`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `memberships_old` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `request` text COLLATE utf8mb4_swedish_ci,
  `approved` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `role` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `memberships_account_id_fk` (`account_id`),
  KEY `memberships_user_id_fk` (`user_id`),
  KEY `index_memberships_on_updated_at` (`updated_at`),
  CONSTRAINT `memberships_account_id_fk` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`),
  CONSTRAINT `memberships_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=17474 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `message_receptions`
--

DROP TABLE IF EXISTS `message_receptions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_receptions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `message_id` int(11) DEFAULT NULL,
  `recipient_id` int(11) DEFAULT NULL,
  `read` tinyint(1) DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `deleted_by_recipient` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `by_recipient` (`recipient_id`,`deleted_by_recipient`),
  KEY `index_message_receptions_on_message_id` (`message_id`),
  KEY `message_receptions_inbox_index` (`recipient_id`,`message_id`,`deleted_by_recipient`)
) ENGINE=InnoDB AUTO_INCREMENT=29107656 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `message_recipient_finders`
--

DROP TABLE IF EXISTS `message_recipient_finders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_recipient_finders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `finder_expression` text COLLATE utf8mb4_swedish_ci,
  `label` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sender_id` int(11) DEFAULT NULL,
  `subject` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `body` text COLLATE utf8mb4_swedish_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `parent_id` int(11) DEFAULT NULL,
  `deleted_by_sender` tinyint(1) DEFAULT '0',
  `type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `priority` int(11) DEFAULT NULL,
  `message_recipient_finder_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_messages_on_parent_id` (`parent_id`),
  KEY `index_messages_on_sender_id_and_deleted_by_sender` (`sender_id`,`deleted_by_sender`)
) ENGINE=InnoDB AUTO_INCREMENT=18063530 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `musical_works`
--

DROP TABLE IF EXISTS `musical_works`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `musical_works` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `position` int(11) DEFAULT NULL,
  `piece_id` int(11) DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `artist` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `album` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `label` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `year` int(11) DEFAULT NULL,
  `excerpt_length` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `musical_works_piece_id_fk` (`piece_id`),
  KEY `index_musical_works_on_updated_at` (`updated_at`)
) ENGINE=InnoDB AUTO_INCREMENT=415319 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `network_files`
--

DROP TABLE IF EXISTS `network_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `network_files` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `network_memberships`
--

DROP TABLE IF EXISTS `network_memberships`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `network_memberships` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `network_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1235 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `network_pieces`
--

DROP TABLE IF EXISTS `network_pieces`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `network_pieces` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `piece_id` int(11) DEFAULT NULL,
  `network_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `point_level` int(11) DEFAULT NULL,
  `custom_points` int(11) DEFAULT NULL,
  `has_custom_points_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `network_pieces_piece_id_fk` (`piece_id`),
  KEY `network_pieces_network_id_fk` (`network_id`),
  CONSTRAINT `network_pieces_network_id_fk` FOREIGN KEY (`network_id`) REFERENCES `networks` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=20327 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `network_requests`
--

DROP TABLE IF EXISTS `network_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `network_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `pricing_strategy` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT '',
  `publishing_strategy` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT '',
  `notification_strategy` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT '',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `state` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT 'pending',
  `note` text COLLATE utf8mb4_swedish_ci,
  `reviewed_at` datetime DEFAULT NULL,
  `path` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=55 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `networks`
--

DROP TABLE IF EXISTS `networks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `networks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `pricing_strategy` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `publishing_strategy` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT '',
  `notification_strategy` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT '',
  `path` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=43 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `numeric_sequences`
--

DROP TABLE IF EXISTS `numeric_sequences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `numeric_sequences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `last_number` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_numeric_sequences_on_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `oauth_access_grants`
--

DROP TABLE IF EXISTS `oauth_access_grants`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `oauth_access_grants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `resource_owner_id` int(11) NOT NULL,
  `application_id` int(11) NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL,
  `expires_in` int(11) NOT NULL,
  `redirect_uri` text COLLATE utf8mb4_swedish_ci NOT NULL,
  `created_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `scopes` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_oauth_access_grants_on_token` (`token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `oauth_access_tokens`
--

DROP TABLE IF EXISTS `oauth_access_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `oauth_access_tokens` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `resource_owner_id` int(11) DEFAULT NULL,
  `application_id` int(11) DEFAULT NULL,
  `token` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL,
  `refresh_token` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `expires_in` int(11) DEFAULT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `scopes` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `previous_refresh_token` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_oauth_access_tokens_on_token` (`token`),
  UNIQUE KEY `index_oauth_access_tokens_on_refresh_token` (`refresh_token`),
  KEY `index_oauth_access_tokens_on_resource_owner_id` (`resource_owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `oauth_applications`
--

DROP TABLE IF EXISTS `oauth_applications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `oauth_applications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL,
  `uid` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL,
  `secret` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL,
  `redirect_uri` text COLLATE utf8mb4_swedish_ci NOT NULL,
  `scopes` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT '',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_oauth_applications_on_uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `oauth_nonces`
--

DROP TABLE IF EXISTS `oauth_nonces`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `oauth_nonces` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nonce` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `timestamp` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_oauth_nonces_on_nonce_and_timestamp` (`nonce`,`timestamp`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `oauth_tokens`
--

DROP TABLE IF EXISTS `oauth_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `oauth_tokens` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `type` varchar(20) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `client_application_id` int(11) DEFAULT NULL,
  `token` varchar(40) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `secret` varchar(40) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `callback_url` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `verifier` varchar(20) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `scope` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `authorized_at` datetime DEFAULT NULL,
  `invalidated_at` datetime DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_oauth_tokens_on_token` (`token`)
) ENGINE=InnoDB AUTO_INCREMENT=7255 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `open_id_associations`
--

DROP TABLE IF EXISTS `open_id_associations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `open_id_associations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_url` blob NOT NULL,
  `handle` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL,
  `secret` blob NOT NULL,
  `issued` int(11) NOT NULL,
  `lifetime` int(11) NOT NULL,
  `assoc_type` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=904519 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `open_id_nonces`
--

DROP TABLE IF EXISTS `open_id_nonces`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `open_id_nonces` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `server_url` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL,
  `timestamp` int(11) NOT NULL,
  `salt` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `outside_purchaser_info_versions`
--

DROP TABLE IF EXISTS `outside_purchaser_info_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `outside_purchaser_info_versions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `outside_purchaser_info_id` int(11) DEFAULT NULL,
  `version` int(11) DEFAULT NULL,
  `outside_purchaser_id` bigint(11) DEFAULT NULL,
  `payment_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `purchaser_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `rate` decimal(9,2) DEFAULT NULL,
  `terms` text COLLATE utf8mb4_swedish_ci,
  `description` text COLLATE utf8mb4_swedish_ci,
  `payment_terms` text COLLATE utf8mb4_swedish_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `version_user_id` bigint(11) DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=297 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `outside_purchaser_infos`
--

DROP TABLE IF EXISTS `outside_purchaser_infos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `outside_purchaser_infos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `outside_purchaser_id` int(11) DEFAULT NULL,
  `payment_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `purchaser_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `rate` decimal(9,2) DEFAULT NULL,
  `terms` text COLLATE utf8mb4_swedish_ci,
  `description` text COLLATE utf8mb4_swedish_ci,
  `payment_terms` text COLLATE utf8mb4_swedish_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `version_user_id` int(11) DEFAULT NULL,
  `version` int(11) DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `outside_purchaser_infos_outside_purchaser_id_fk` (`outside_purchaser_id`),
  CONSTRAINT `outside_purchaser_infos_outside_purchaser_id_fk` FOREIGN KEY (`outside_purchaser_id`) REFERENCES `accounts` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=85 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `outside_purchaser_optins`
--

DROP TABLE IF EXISTS `outside_purchaser_optins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `outside_purchaser_optins` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `piece_id` int(11) DEFAULT NULL,
  `outside_purchaser_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `outside_purchaser_pieces_piece_id_fk` (`piece_id`),
  KEY `outside_purchaser_pieces_outside_purchaser_id_fk` (`outside_purchaser_id`),
  CONSTRAINT `outside_purchaser_pieces_outside_purchaser_id_fk` FOREIGN KEY (`outside_purchaser_id`) REFERENCES `accounts` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=965702 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `outside_purchaser_preferences`
--

DROP TABLE IF EXISTS `outside_purchaser_preferences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `outside_purchaser_preferences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `outside_purchaser_id` int(11) DEFAULT NULL,
  `allow` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `account_outside_purchaser_options_account_id_fk` (`account_id`),
  KEY `account_outside_purchaser_options_outside_purchaser_id_fk` (`outside_purchaser_id`),
  CONSTRAINT `account_outside_purchaser_options_account_id_fk` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`),
  CONSTRAINT `account_outside_purchaser_options_outside_purchaser_id_fk` FOREIGN KEY (`outside_purchaser_id`) REFERENCES `accounts` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=20943 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `piece_date_pegs`
--

DROP TABLE IF EXISTS `piece_date_pegs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `piece_date_pegs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `piece_id` int(11) DEFAULT NULL,
  `date_peg_id` int(11) DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `year` int(11) DEFAULT NULL,
  `month` int(11) DEFAULT NULL,
  `day` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `piece_date_pegs_piece_id_fk` (`piece_id`),
  KEY `piece_date_pegs_date_peg_id_fk` (`date_peg_id`)
) ENGINE=InnoDB AUTO_INCREMENT=32393 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `piece_files`
--

DROP TABLE IF EXISTS `piece_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `piece_files` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `piece_id` int(11) DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `filename` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `label` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `piece_files_piece_id_fk` (`piece_id`)
) ENGINE=InnoDB AUTO_INCREMENT=55428 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `piece_images`
--

DROP TABLE IF EXISTS `piece_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `piece_images` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `filename` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `thumbnail` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `width` int(11) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  `aspect_ratio` float DEFAULT NULL,
  `piece_id` int(11) DEFAULT NULL,
  `caption` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `credit` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `upload_path` text COLLATE utf8mb4_swedish_ci,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `purpose` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `piece_images_piece_id_fk` (`piece_id`),
  KEY `parent_id_idx` (`parent_id`),
  KEY `position_idx` (`position`)
) ENGINE=InnoDB AUTO_INCREMENT=855788 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pieces`
--

DROP TABLE IF EXISTS `pieces`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pieces` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `position` int(11) DEFAULT NULL,
  `account_id` int(11) DEFAULT NULL,
  `creator_id` int(11) DEFAULT NULL,
  `series_id` int(11) DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `short_description` mediumtext COLLATE utf8mb4_swedish_ci,
  `description` mediumtext COLLATE utf8mb4_swedish_ci,
  `produced_on` date DEFAULT NULL,
  `language` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `related_website` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `credits` mediumtext COLLATE utf8mb4_swedish_ci,
  `broadcast_history` mediumtext COLLATE utf8mb4_swedish_ci,
  `intro` mediumtext COLLATE utf8mb4_swedish_ci,
  `outro` mediumtext COLLATE utf8mb4_swedish_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `length` int(11) DEFAULT NULL,
  `point_level` int(11) DEFAULT NULL,
  `published_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `legacy_musical_works` mediumtext COLLATE utf8mb4_swedish_ci,
  `episode_number` int(11) DEFAULT NULL,
  `network_only_at` datetime DEFAULT NULL,
  `image_id` int(11) DEFAULT NULL,
  `featured_at` datetime DEFAULT NULL,
  `allow_comments` tinyint(1) DEFAULT '1',
  `average_rating` float DEFAULT NULL,
  `npr_story_id` int(11) DEFAULT NULL,
  `is_exportable_at` datetime DEFAULT NULL,
  `custom_points` int(11) DEFAULT NULL,
  `is_shareable_at` datetime DEFAULT NULL,
  `has_custom_points_at` datetime DEFAULT NULL,
  `publish_on_valid` tinyint(1) DEFAULT NULL,
  `publish_notified_at` datetime DEFAULT NULL,
  `publish_on_valid_at` datetime DEFAULT NULL,
  `promos_only_at` datetime DEFAULT NULL,
  `episode_identifier` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `app_version` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT 'v3',
  `marketplace_subtitle` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `marketplace_information` mediumtext COLLATE utf8mb4_swedish_ci,
  `network_id` int(11) DEFAULT NULL,
  `released_at` datetime DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `status_message` mediumtext COLLATE utf8mb4_swedish_ci,
  `season_identifier` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `clean_title` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `production_notes` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `pieces_account_id_fk` (`account_id`),
  KEY `pieces_creator_id_fk` (`creator_id`),
  KEY `pieces_series_id_fk` (`series_id`),
  KEY `by_published_at` (`published_at`),
  KEY `deleted_at_idx` (`deleted_at`),
  KEY `public_pieces_index` (`deleted_at`,`published_at`,`network_only_at`),
  KEY `created_published_index` (`created_at`,`published_at`),
  KEY `series_episodes` (`series_id`,`deleted_at`),
  KEY `index_pieces_on_episode_number_and_series_id` (`episode_number`,`series_id`),
  KEY `index_pieces_on_network_id_and_network_only_at_and_deleted_at` (`network_id`,`network_only_at`,`deleted_at`)
) ENGINE=InnoDB AUTO_INCREMENT=478879 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `playlist_images`
--

DROP TABLE IF EXISTS `playlist_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `playlist_images` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `filename` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `thumbnail` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `width` int(11) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  `aspect_ratio` float DEFAULT NULL,
  `playlist_id` int(11) DEFAULT NULL,
  `caption` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `credit` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `upload_path` text COLLATE utf8mb4_swedish_ci,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=14271 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `playlist_sections`
--

DROP TABLE IF EXISTS `playlist_sections`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `playlist_sections` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `playlist_id` int(11) DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `comment` text COLLATE utf8mb4_swedish_ci,
  PRIMARY KEY (`id`),
  KEY `playlist_idx` (`playlist_id`),
  KEY `position_idx` (`position`)
) ENGINE=InnoDB AUTO_INCREMENT=404944 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `playlisting_images`
--

DROP TABLE IF EXISTS `playlisting_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `playlisting_images` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `filename` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `thumbnail` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `width` int(11) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  `aspect_ratio` float DEFAULT NULL,
  `playlisting_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `caption` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `credit` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `upload_path` text COLLATE utf8mb4_swedish_ci,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `playlisting_images_playlisting_id_fk` (`playlisting_id`),
  CONSTRAINT `playlisting_images_playlisting_id_fk` FOREIGN KEY (`playlisting_id`) REFERENCES `playlistings` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `playlistings`
--

DROP TABLE IF EXISTS `playlistings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `playlistings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `playlist_section_id` int(11) DEFAULT NULL,
  `playlistable_id` int(11) DEFAULT NULL,
  `playlistable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `comment` text COLLATE utf8mb4_swedish_ci,
  `editors_title` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `playlist_section_id_idx` (`playlist_section_id`),
  KEY `playlistable_idx` (`playlistable_id`,`playlistable_type`)
) ENGINE=InnoDB AUTO_INCREMENT=98123 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `playlists`
--

DROP TABLE IF EXISTS `playlists`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `playlists` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `account_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `description` text COLLATE utf8mb4_swedish_ci,
  `position` int(11) DEFAULT NULL,
  `curated_at` datetime DEFAULT NULL,
  `featured_at` datetime DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `published_at` datetime DEFAULT NULL,
  `allow_free_purchase_at` datetime DEFAULT NULL,
  `path` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `deleted_at_idx` (`deleted_at`),
  KEY `account_idx` (`account_id`),
  KEY `published_at_idx` (`published_at`),
  KEY `type_idx` (`type`)
) ENGINE=InnoDB AUTO_INCREMENT=404022 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `podcast_imports`
--

DROP TABLE IF EXISTS `podcast_imports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `podcast_imports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `account_id` int(11) DEFAULT NULL,
  `series_id` int(11) DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `config` longtext COLLATE utf8mb4_swedish_ci,
  `feed_episode_count` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=192 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `point_package_versions`
--

DROP TABLE IF EXISTS `point_package_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `point_package_versions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `point_package_id` int(11) DEFAULT NULL,
  `version` int(11) DEFAULT NULL,
  `account_id` bigint(11) DEFAULT NULL,
  `seller_id` bigint(11) DEFAULT NULL,
  `points` bigint(11) DEFAULT NULL,
  `expires_on` date DEFAULT NULL,
  `total_station_revenue` bigint(11) DEFAULT NULL,
  `price` decimal(9,2) DEFAULT NULL,
  `list` decimal(9,2) DEFAULT NULL,
  `discount` decimal(9,2) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `notes` text COLLATE utf8mb4_swedish_ci,
  `deleted_at` datetime DEFAULT NULL,
  `prx_cut` decimal(9,2) DEFAULT NULL,
  `royalty_cut` decimal(9,2) DEFAULT NULL,
  `package_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `ends_on` date DEFAULT NULL,
  `prx_percentage` bigint(11) DEFAULT NULL,
  `subscription_id` bigint(11) DEFAULT NULL,
  `points_purchased` bigint(11) DEFAULT NULL,
  `version_user_id` bigint(11) DEFAULT NULL,
  `witholding` decimal(9,2) DEFAULT NULL,
  `locked` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=75001 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `point_packages`
--

DROP TABLE IF EXISTS `point_packages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `point_packages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `seller_id` int(11) DEFAULT NULL,
  `points` int(11) DEFAULT NULL,
  `expires_on` date DEFAULT NULL,
  `total_station_revenue` int(11) DEFAULT NULL,
  `price` decimal(9,2) DEFAULT NULL,
  `list` decimal(9,2) DEFAULT NULL,
  `discount` decimal(9,2) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `notes` text COLLATE utf8mb4_swedish_ci,
  `deleted_at` datetime DEFAULT NULL,
  `prx_cut` decimal(9,2) DEFAULT NULL,
  `royalty_cut` decimal(9,2) DEFAULT NULL,
  `package_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `ends_on` date DEFAULT NULL,
  `prx_percentage` int(11) DEFAULT NULL,
  `subscription_id` int(11) DEFAULT NULL,
  `points_purchased` int(11) DEFAULT NULL,
  `version_user_id` int(11) DEFAULT NULL,
  `version` int(11) DEFAULT NULL,
  `witholding` decimal(9,2) DEFAULT NULL,
  `locked` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `point_packages_account_id_fk` (`account_id`),
  KEY `point_packages_seller_id_fk` (`seller_id`),
  CONSTRAINT `point_packages_account_id_fk` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`),
  CONSTRAINT `point_packages_seller_id_fk` FOREIGN KEY (`seller_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6624 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pricing_tiers`
--

DROP TABLE IF EXISTS `pricing_tiers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pricing_tiers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `minimum_tsr` int(11) DEFAULT NULL,
  `maximum_tsr` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pricing_tiers_seasons`
--

DROP TABLE IF EXISTS `pricing_tiers_seasons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pricing_tiers_seasons` (
  `pricing_tier_id` int(11) DEFAULT NULL,
  `season_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `privacy_settings`
--

DROP TABLE IF EXISTS `privacy_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `privacy_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `protect_id` int(11) DEFAULT NULL,
  `protect_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `level` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `information` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `protect_idx` (`protect_id`,`protect_type`),
  KEY `information_idx` (`information`)
) ENGINE=InnoDB AUTO_INCREMENT=764800 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `producers`
--

DROP TABLE IF EXISTS `producers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `producers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `piece_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `invited_at` datetime DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `producers_piece_id_fk` (`piece_id`),
  KEY `producers_user_id_fk` (`user_id`),
  KEY `index_producers_on_updated_at` (`updated_at`),
  CONSTRAINT `producers_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=381677 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `purchase_allocations`
--

DROP TABLE IF EXISTS `purchase_allocations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `purchase_allocations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `purchase_id` int(11) DEFAULT NULL,
  `point_package_id` int(11) DEFAULT NULL,
  `quantity` decimal(9,2) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=67201 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `purchases`
--

DROP TABLE IF EXISTS `purchases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `purchases` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `seller_account_id` int(11) DEFAULT NULL,
  `purchaser_account_id` int(11) DEFAULT NULL,
  `purchaser_id` int(11) DEFAULT NULL,
  `purchased_id` int(11) DEFAULT NULL,
  `license_version` int(11) DEFAULT NULL,
  `purchased_at` datetime DEFAULT NULL,
  `expires_on` date DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `price` decimal(9,2) DEFAULT NULL,
  `unit` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `payment_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `royalty_base` decimal(9,2) DEFAULT NULL,
  `royalty_bonus` decimal(9,2) DEFAULT NULL,
  `royalty_subsidy` decimal(9,2) DEFAULT NULL,
  `purchased_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `network_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `purchases_seller_account_id_fk` (`seller_account_id`),
  KEY `purchases_purchaser_account_id_fk` (`purchaser_account_id`),
  KEY `purchases_purchaser_id_fk` (`purchaser_id`),
  KEY `purchased_idx` (`purchased_id`,`purchased_type`),
  KEY `purchased_at_idx` (`purchased_at`),
  CONSTRAINT `purchases_purchaser_account_id_fk` FOREIGN KEY (`purchaser_account_id`) REFERENCES `accounts` (`id`),
  CONSTRAINT `purchases_purchaser_id_fk` FOREIGN KEY (`purchaser_id`) REFERENCES `users` (`id`),
  CONSTRAINT `purchases_seller_account_id_fk` FOREIGN KEY (`seller_account_id`) REFERENCES `accounts` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=583891 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ratings`
--

DROP TABLE IF EXISTS `ratings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ratings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `value` int(11) NOT NULL DEFAULT '0',
  `ratable_id` int(11) NOT NULL DEFAULT '0',
  `ratable_type` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `index_ratings_on_ratable_type_and_ratable_id` (`ratable_type`,`ratable_id`)
) ENGINE=InnoDB AUTO_INCREMENT=27334 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `say_when_job_executions`
--

DROP TABLE IF EXISTS `say_when_job_executions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `say_when_job_executions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job_id` int(11) DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `result` text COLLATE utf8mb4_swedish_ci,
  `start_at` datetime DEFAULT NULL,
  `end_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_say_when_job_executions_on_job_id` (`job_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7254941 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `say_when_jobs`
--

DROP TABLE IF EXISTS `say_when_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `say_when_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `group` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `trigger_strategy` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `trigger_options` text COLLATE utf8mb4_swedish_ci,
  `last_fire_at` datetime DEFAULT NULL,
  `next_fire_at` datetime DEFAULT NULL,
  `start_at` datetime DEFAULT NULL,
  `end_at` datetime DEFAULT NULL,
  `job_class` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `job_method` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `data` text COLLATE utf8mb4_swedish_ci,
  `scheduled_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `scheduled_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_say_when_jobs_on_status` (`status`),
  KEY `index_say_when_jobs_on_next_fire_at` (`next_fire_at`)
) ENGINE=InnoDB AUTO_INCREMENT=150433 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `schedules`
--

DROP TABLE IF EXISTS `schedules`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `schedules` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `series_id` int(11) DEFAULT NULL,
  `day` int(11) DEFAULT NULL,
  `hour` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_schedules_on_series_id` (`series_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2188 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `schema_migrations`
--

DROP TABLE IF EXISTS `schema_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `schema_migrations` (
  `version` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT '',
  UNIQUE KEY `unique_schema_migrations` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `seasons_series`
--

DROP TABLE IF EXISTS `seasons_series`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `seasons_series` (
  `season_id` int(11) DEFAULT NULL,
  `series_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `series`
--

DROP TABLE IF EXISTS `series`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `series` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `short_description` text COLLATE utf8mb4_swedish_ci,
  `description` text COLLATE utf8mb4_swedish_ci,
  `frequency` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `production_notes` text COLLATE utf8mb4_swedish_ci,
  `creator_id` int(11) DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `file_prefix` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `time_zone` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `episode_start_number` int(11) DEFAULT NULL,
  `episode_start_at` datetime DEFAULT NULL,
  `subscription_approval_status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `evergreen_piece_id` int(11) DEFAULT NULL,
  `due_before_hours` int(11) DEFAULT NULL,
  `prx_billing_at` datetime DEFAULT NULL,
  `promos_days_early` int(11) DEFAULT NULL,
  `subauto_bill_me_at` datetime DEFAULT NULL,
  `subscriber_only_at` datetime DEFAULT NULL,
  `app_version` varchar(255) COLLATE utf8mb4_swedish_ci NOT NULL DEFAULT 'v3',
  `check_language` tinyint(1) DEFAULT '0',
  `use_porter` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_series_on_account_id` (`account_id`)
) ENGINE=InnoDB AUTO_INCREMENT=44773 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `series_files`
--

DROP TABLE IF EXISTS `series_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `series_files` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `series_id` int(11) DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `filename` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `label` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `series_files_series_id_fk` (`series_id`),
  CONSTRAINT `series_files_series_id_fk` FOREIGN KEY (`series_id`) REFERENCES `series` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2260 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `series_images`
--

DROP TABLE IF EXISTS `series_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `series_images` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `filename` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `thumbnail` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `width` int(11) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  `aspect_ratio` float DEFAULT NULL,
  `series_id` int(11) DEFAULT NULL,
  `caption` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `credit` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `upload_path` text COLLATE utf8mb4_swedish_ci,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `purpose` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `series_images_series_id_fk` (`series_id`),
  CONSTRAINT `series_images_series_id_fk` FOREIGN KEY (`series_id`) REFERENCES `series` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=30600 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `site_message_receptions`
--

DROP TABLE IF EXISTS `site_message_receptions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `site_message_receptions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `site_message_id` int(11) DEFAULT NULL,
  `recipient_id` int(11) DEFAULT NULL,
  `read_at` datetime DEFAULT NULL,
  `dismissed_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=215664 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `site_messages`
--

DROP TABLE IF EXISTS `site_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `site_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sender_id` int(11) DEFAULT NULL,
  `body` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `published_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=227 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `skills`
--

DROP TABLE IF EXISTS `skills`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `skills` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `skills_user_id_fk` (`user_id`),
  CONSTRAINT `skills_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=25295 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `station_accounts`
--

DROP TABLE IF EXISTS `station_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `station_accounts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `station_formats`
--

DROP TABLE IF EXISTS `station_formats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `station_formats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `format` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `station_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `station_formats_station_id_fk` (`station_id`),
  CONSTRAINT `station_formats_station_id_fk` FOREIGN KEY (`station_id`) REFERENCES `accounts` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=655 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `story_distributions`
--

DROP TABLE IF EXISTS `story_distributions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `story_distributions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `distribution_id` int(11) DEFAULT NULL,
  `piece_id` int(11) DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `guid` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `properties` text COLLATE utf8mb4_swedish_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_story_distributions_on_distribution_id_and_piece_id` (`distribution_id`,`piece_id`)
) ENGINE=InnoDB AUTO_INCREMENT=63552 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subscription_invoices`
--

DROP TABLE IF EXISTS `subscription_invoices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subscription_invoices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `subscription_id` int(11) DEFAULT NULL,
  `date` date DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=13475 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subscription_line_items`
--

DROP TABLE IF EXISTS `subscription_line_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subscription_line_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `description` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `subscription_invoice_id` int(11) DEFAULT NULL,
  `discount_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subscription_prices`
--

DROP TABLE IF EXISTS `subscription_prices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subscription_prices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `series_id` int(11) DEFAULT NULL,
  `pricing_tier_id` int(11) DEFAULT NULL,
  `value` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `season_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6190 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subscription_seasons`
--

DROP TABLE IF EXISTS `subscription_seasons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subscription_seasons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `label` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `pricing_due_date` date DEFAULT NULL,
  `nonstandard` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subscriptions`
--

DROP TABLE IF EXISTS `subscriptions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subscriptions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `series_id` int(11) DEFAULT NULL,
  `account_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `end_air_days` int(11) DEFAULT NULL,
  `delivery_audio_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `file_delivery_at` datetime DEFAULT NULL,
  `cart_number_start` int(11) DEFAULT NULL,
  `cart_number_factor` int(11) DEFAULT NULL,
  `delivery_filename_format` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `delivery_transport_method` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `audio_version_template_id` int(11) DEFAULT NULL,
  `producer_app_id` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `approved_by_subscriber` tinyint(1) DEFAULT NULL,
  `approved_by_producer` tinyint(1) DEFAULT NULL,
  `agreed_to_terms_at` datetime DEFAULT NULL,
  `subscriber_id` int(11) DEFAULT NULL,
  `approved_at` datetime DEFAULT NULL,
  `days_early` int(11) DEFAULT NULL,
  `days_late` int(11) DEFAULT NULL,
  `billing_name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `billing_phone` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `billing_email` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `promos_cart_number_start` int(11) DEFAULT NULL,
  `promos_cart_number_factor` int(11) DEFAULT NULL,
  `billing_frequency` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `tsr` int(11) DEFAULT NULL,
  `notes` text COLLATE utf8mb4_swedish_ci,
  `active_deliveries_max` int(11) DEFAULT '0',
  `start_air_days_early` int(11) DEFAULT '0',
  `no_pad_byte` tinyint(1) DEFAULT '0',
  `selected_hours` text COLLATE utf8mb4_swedish_ci,
  PRIMARY KEY (`id`),
  KEY `index_subscriptions_on_account_id` (`account_id`),
  KEY `index_subscriptions_on_series_id` (`series_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6587 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `taggings`
--

DROP TABLE IF EXISTS `taggings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `taggings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tag_id` int(11) DEFAULT NULL,
  `taggable_id` int(11) DEFAULT NULL,
  `taggable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_taggings_on_tag_id` (`tag_id`),
  KEY `index_taggings_on_taggable_id_and_taggable_type` (`taggable_id`,`taggable_type`)
) ENGINE=InnoDB AUTO_INCREMENT=1099676 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tags`
--

DROP TABLE IF EXISTS `tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=515948 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tones`
--

DROP TABLE IF EXISTS `tones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tones` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `piece_id` int(11) DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `tones_piece_id_fk` (`piece_id`),
  KEY `name_idx` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=499530 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `topics`
--

DROP TABLE IF EXISTS `topics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `topics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `piece_id` int(11) DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `topics_piece_id_fk` (`piece_id`),
  KEY `name_idx` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=514709 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user_images`
--

DROP TABLE IF EXISTS `user_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_images` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) DEFAULT NULL,
  `content_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `filename` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `thumbnail` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `width` int(11) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  `aspect_ratio` float DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `upload_path` text COLLATE utf8mb4_swedish_ci,
  `status` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `caption` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `credit` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `purpose` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_images_user_id_fk` (`user_id`),
  KEY `index_user_images_on_updated_at` (`updated_at`),
  CONSTRAINT `user_images_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=55310 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `login` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `crypted_password` varchar(40) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `salt` varchar(40) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `remember_token` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `remember_token_expires_at` datetime DEFAULT NULL,
  `activation_code` varchar(40) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `activated_at` datetime DEFAULT NULL,
  `password_reset_code` varchar(40) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `first_name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `last_name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `migrated_at` datetime DEFAULT NULL,
  `old_password` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `user_agreement_at` datetime DEFAULT NULL,
  `subscribed_at` datetime DEFAULT NULL,
  `day_phone` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `eve_phone` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `im_name` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `bio` text COLLATE utf8mb4_swedish_ci,
  `account_id` int(11) DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `favorite_shows` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `influences` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `available` tinyint(1) DEFAULT NULL,
  `has_car` tinyint(1) DEFAULT NULL,
  `will_travel` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `aired_on` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `im_service` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `role` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `time_zone` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `merged_into_user_id` int(11) DEFAULT NULL,
  `ftp_password` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `daily_message_quota` int(11) DEFAULT NULL,
  `category` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `suspended_at` datetime DEFAULT NULL,
  `reset_password_token` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `reset_password_sent_at` datetime DEFAULT NULL,
  `id_admin` tinyint(1) DEFAULT NULL,
  `unconfirmed_email` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_unique_reset_password_token_idx` (`reset_password_token`),
  KEY `login_idx` (`login`),
  KEY `deleted_at_idx` (`deleted_at`),
  KEY `activation_code_idx` (`activation_code`),
  KEY `remember_token_idx` (`remember_token`),
  KEY `index_users_on_account_id` (`account_id`),
  KEY `users_email_idx` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=262356 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `websites`
--

DROP TABLE IF EXISTS `websites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `websites` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `browsable_id` int(11) DEFAULT NULL,
  `browsable_type` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=18826 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `work_experiences`
--

DROP TABLE IF EXISTS `work_experiences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `work_experiences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `position` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `company` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_swedish_ci DEFAULT NULL,
  `current` tinyint(1) DEFAULT NULL,
  `started_on` date DEFAULT NULL,
  `ended_on` date DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `work_experiences_user_id_fk` (`user_id`),
  CONSTRAINT `work_experiences_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5530 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Final view structure for view `account_fragments`
--

/*!50001 DROP VIEW IF EXISTS `account_fragments`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8 */;
/*!50001 SET character_set_results     = utf8 */;
/*!50001 SET collation_connection      = utf8_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`prxadmin`@`%` SQL SECURITY DEFINER */
/*!50001 VIEW `account_fragments` AS select `accounts`.`id` AS `id`,`accounts`.`type` AS `type`,`accounts`.`name` AS `name` from `accounts` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2023-06-16 17:49:10

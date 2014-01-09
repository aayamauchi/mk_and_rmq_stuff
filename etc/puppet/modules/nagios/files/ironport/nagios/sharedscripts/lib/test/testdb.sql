-- DROP DATABASE IF EXISTS testtclopslib;
-- CREATE DATABASE testtclopslib;
CREATE TABLE `testdata` (
       `id` int(11) NOT NULL AUTO_INCREMENT,
       `strdata` varchar(255) NOT NULL COMMENT 'test string data',
       `tinyintdata` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'test tinyint data',
       `strdata2` char(255) COMMENT 'test string data with NULL values',
       `textdata` text COMMENT 'test text data with NULL values',
       PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

INSERT INTO `testdata` (`strdata`, `tinyintdata`, `strdata2`, `textdata`) VALUES ('0. test string 1', 1, 'test string 2', '["magic.mime",
"magic_v5.mime"]');
INSERT INTO `testdata` (`strdata`, `textdata`) VALUES ('1. test string 1', '["magic.mime",
"magic_v5.mime"]');
INSERT INTO `testdata` (`strdata`) VALUES ('2. test string 1');

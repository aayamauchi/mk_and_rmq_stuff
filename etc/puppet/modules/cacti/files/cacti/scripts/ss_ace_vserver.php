<?php

/* do NOT run this script through a web browser */
if (!isset($_SERVER["argv"][0]) || isset($_SERVER['REQUEST_METHOD'])  || isset($_SERVER['REMOTE_ADDR'])) {
   die("<br><strong>This script is only meant to run at the command line.</strong>");
}

$no_http_headers = true;

/* display No errors */
error_reporting(0);

include_once(dirname(__FILE__) . "/../lib/snmp.php");

if (!isset($called_by_script_server)) {
	include_once(dirname(__FILE__) . "/../include/global.php");

	array_shift($_SERVER["argv"]);

	print call_user_func_array("ss_ace_vserver", $_SERVER["argv"]);
}

function ss_ace_vserver($hostname, $host_id, $snmp_auth, $cmd, $arg1 = "", $arg2 = "") {
	$snmp = explode(":", $snmp_auth);
	$snmp_version = $snmp[0];
	$snmp_port    = $snmp[1];
	$snmp_timeout = $snmp[2];

	$snmp_auth_username   = "";
	$snmp_auth_password   = "";
	$snmp_auth_protocol   = "";
	$snmp_priv_passphrase = "";
	$snmp_priv_protocol   = "";
	$snmp_community       = "";
	$snmp_context         = "";

	if ($snmp_version == 3) {
		$snmp_auth_username   = $snmp[4];
		$snmp_auth_password   = $snmp[5];
		$snmp_auth_protocol   = $snmp[6];
		$snmp_priv_passphrase = $snmp[7];
		$snmp_priv_protocol   = $snmp[8];
		$snmp_context         = $snmp[9];
	}else{
		$snmp_community = $snmp[3];
	}

	$oids = array(
		"FarmName" => ".1.3.6.1.4.1.9.9.161.1.4.2.1.2",
		"NumberOfC" => ".1.3.6.1.4.1.9.9.161.1.4.2.1.6",
		"HCTotal" => ".1.3.6.1.4.1.9.9.161.1.4.2.1.7",
		);

	if ($cmd == "get") {
		$target = $oids[$arg1] . "." . $arg2;	
		$value  = cacti_snmp_get($hostname, $snmp_community, $target, $snmp_version, $snmp_auth_username, $snmp_auth_password, $snmp_auth_protocol, $snmp_priv_passphrase, $snmp_priv_protocol, $snmp_context, $snmp_port, $snmp_timeout, read_config_option("snmp_retries"), SNMP_POLLER);
		print $value . "\n";

	} else {
		$index_arr = ace_index(cacti_snmp_walk($hostname, $snmp_community, $oids["FarmName"], $snmp_version, $snmp_auth_username, $snmp_auth_password, $snmp_auth_protocol, $snmp_priv_passphrase, $snmp_priv_protocol, $snmp_context, $snmp_port, $snmp_timeout, read_config_option("snmp_retries"), SNMP_POLLER));
		$catalyst = explode(".",$hostname);

		if ($cmd == "index") {
			for ($i=0;($i<sizeof($index_arr));$i++) {
				print $index_arr[$i]["index"] . "\n";
			}

		} elseif ($cmd == "num_indexes") {
			$num_indexes = count($index_arr);
			print "$num_indexes" . "\n";

		} elseif ($cmd == "query") {
			$arg = $arg1;
			if ($arg == "VServer") {
				for ($i=0;($i<sizeof($index_arr));$i++) {
					print $index_arr[$i]["index"] . "!" . $index_arr[$i]["vserver"] . "\n";
				}

			} elseif ($arg == "Module") {
				for ($i=0;($i<sizeof($index_arr));$i++) {
					print $index_arr[$i]["index"] . "!" . $index_arr[$i]["module"] . "\n";
				}

    	} else {
				$arr = reindex(cacti_snmp_walk($hostname, $snmp_community, $oids[$arg], $snmp_version, $snmp_auth_username, $snmp_auth_password, $snmp_auth_protocol, $snmp_priv_passphrase, $snmp_priv_protocol, $snmp_context, $snmp_port, $snmp_timeout, read_config_option("snmp_retries"), SNMP_POLLER));
				for ($i=0;($i<sizeof($index_arr));$i++) {
				print $index_arr[$i]["index"] . "!" . $arr[$i] . "\n";
				}
			}
		}
	}
}

function ace_index($arr) {
	$return_arr = array();

	for ($i=0;($i<sizeof($arr));$i++) {
		$vserver = '';
		$arr[$i]["oid"]=trim($arr[$i]["oid"],".");
		if ( ereg ("1\.3\.6\.1\.4\.1\.9\.9\.161\.1\.4\.2\.1\.2\.([0-9]*)\.([0-9]*)$", $arr[$i]["oid"], $regs)){
			$return_arr[$i]["module"] = $regs[1];
			$return_arr[$i]["index"] = $regs[1] . "." . $regs[2];
		}
		$return_arr[$i]["vserver"] = $arr[$i]["value"];
	}
	return $return_arr;
}

function reindex($arr) {
	$return_arr = array();

	for ($i=0;($i<sizeof($arr));$i++) {
		$return_arr[$i] = $arr[$i]["value"];
	}
	return $return_arr;
}
?>

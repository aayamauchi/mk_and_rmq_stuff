<?php
$no_http_headers = true;

/* display No errors */
error_reporting(E_ERROR);

include_once(dirname(__FILE__) . "/../include/config.php");
include_once(dirname(__FILE__) . "/../lib/snmp.php");

if (!isset($called_by_script_server)) {
        array_shift($_SERVER["argv"]);
        print call_user_func_array("ss_protocol_udp", $_SERVER["argv"]);
}

function ss_protocol_udp($hostname, $snmp_community, $snmp_version, $snmp_port, $snmp_timeout, $snmpv3_auth_username, $snmpv3_auth_password) {
	
	$result = "";

         if (($snmp_version == "1" | $snmp_version == "2")) {
              $snmpv3_auth_username = "";
              $snmpv3_auth_password = "";
              $snmpv3_auth_protocol = "";
              $snmpv3_priv_passphrase = "";
              $snmpv3_priv_protocol = "";
         }

        $oids = array(
                "udpNoPorts" => ".1.3.6.1.2.1.7.2.0",
                "udpInErrors" => ".1.3.6.1.2.1.7.3.0"
                );

        for ($i=0;$i<(count($oids));$i++) {
                $row = each($oids);
                $var = (cacti_snmp_get($hostname, $snmp_community, $row["value"], $snmp_version, $snmpv3_auth_username, $snmpv3_auth_password, $snmp_port, $snmp_timeout, SNMP_POLLER));
                $result = is_numeric($var) ? ($result . $row["key"] . ":" . $var . " ") : ($result . $row["key"] . ":NaN ");
        }

        return trim($result);
}

?>

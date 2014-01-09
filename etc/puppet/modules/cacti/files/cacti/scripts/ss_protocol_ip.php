<?php
$no_http_headers = true;

/* display No errors */
error_reporting(E_ERROR);

include_once(dirname(__FILE__) . "/../include/config.php");
include_once(dirname(__FILE__) . "/../lib/snmp.php");

if (!isset($called_by_script_server)) {
        array_shift($_SERVER["argv"]);
        print call_user_func_array("ss_protocol_ip", $_SERVER["argv"]);
}

function ss_protocol_ip($hostname, $snmp_community, $snmp_version, $snmp_port, $snmp_timeout, $snmpv3_auth_username, $snmpv3_auth_password) {

	$result = "";

         if (($snmp_version == "1" | $snmp_version == "2")) {
              $snmpv3_auth_username = "";
              $snmpv3_auth_password = "";
              $snmpv3_auth_protocol = "";
              $snmpv3_priv_passphrase = "";
              $snmpv3_priv_protocol = "";
         }

        $oids = array(
                "ipInHdrErrors" => ".1.3.6.1.2.1.4.4.0",
                "ipInAddrErrors" => ".1.3.6.1.2.1.4.5.0",
                "ipForwDatagrams" => ".1.3.6.1.2.1.4.6.0",
                "ipInUnknownProtos" => ".1.3.6.1.2.1.4.7.0",
                "ipInDiscards" => ".1.3.6.1.2.1.4.8.0",
                "ipInDelivers" => ".1.3.6.1.2.1.4.9.0",
                "ipOutDiscards" => ".1.3.6.1.2.1.4.11.0",
                "ipOutNoRoutes" => ".1.3.6.1.2.1.4.12.0",
                "ipRoutingDiscards" => ".1.3.6.1.2.1.4.23.0",
                "ipReasmReqds" => ".1.3.6.1.2.1.4.14.0",
                "ipReasmOKs" => ".1.3.6.1.2.1.4.15.0",
                "ipReasmFails" => ".1.3.6.1.2.1.4.16.0",
                "ipFragOKs" => ".1.3.6.1.2.1.4.17.0",
                "ipFragFails" => ".1.3.6.1.2.1.4.18.0",
                "ipFragCreates" => ".1.3.6.1.2.1.4.19.0"
                );

        for ($i=0;$i<(count($oids));$i++) {
                $row = each($oids);
                $var = (cacti_snmp_get($hostname, $snmp_community, $row["value"], $snmp_version, $snmpv3_auth_username, $snmpv3_auth_password, $snmp_port, $snmp_timeout, SNMP_POLLER));
                $result = is_numeric($var) ? ($result . $row["key"] . ":" . $var . " ") : ($result . $row["key"] . ":NaN ");
        }

        return trim($result);
}

?>

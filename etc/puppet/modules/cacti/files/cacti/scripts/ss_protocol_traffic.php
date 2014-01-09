<?php
$no_http_headers = true;

/* display No errors */
error_reporting(E_ERROR);

include_once(dirname(__FILE__) . "/../include/config.php");
include_once(dirname(__FILE__) . "/../lib/snmp.php");

if (!isset($called_by_script_server)) {
        array_shift($_SERVER["argv"]);
        print call_user_func_array("ss_protocol_traffic", $_SERVER["argv"]);
}

function ss_protocol_traffic($hostname, $snmp_community, $snmp_version, $snmp_port, $snmp_timeout, $snmpv3_auth_username, $snmpv3_auth_password) {

	$result = "";

         if (($snmp_version == "1" | $snmp_version == "2")) {
              $snmpv3_auth_username = "";
              $snmpv3_auth_password = "";
              $snmpv3_auth_protocol = "";
              $snmpv3_priv_passphrase = "";
              $snmpv3_priv_protocol = "";
         }

        $oids = array(
                "ipInReceives" => ".1.3.6.1.2.1.4.3.0",
                "ipOutRequests" => ".1.3.6.1.2.1.4.10.0",
                "tcpInSegs" => ".1.3.6.1.2.1.6.10.0",
                "tcpOutSegs" => ".1.3.6.1.2.1.6.11.0",
                "udpInDatagrams" => ".1.3.6.1.2.1.7.1.0",
                "udpOutDatagrams" => ".1.3.6.1.2.1.7.4.0",
                "snmpInPkts" => ".1.3.6.1.2.1.11.1.0",
                "snmpOutPkts" => ".1.3.6.1.2.1.11.2.0",
                "icmpInMsgs" => ".1.3.6.1.2.1.5.1.0",
                "icmpOutMsgs" => ".1.3.6.1.2.1.5.14.0"
                );

        for ($i=0;$i<(count($oids));$i++) {
                $row = each($oids);
                $var = (cacti_snmp_get($hostname, $snmp_community, $row["value"], $snmp_version, $snmpv3_auth_username, $snmpv3_auth_password, $snmp_port, $snmp_timeout, SNMP_POLLER));
                $result = is_numeric($var) ? ($result . $row["key"] . ":" . $var . " ") : ($result . $row["key"] . ":NaN ");
        }

        return trim($result);
}

?>

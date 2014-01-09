<?php
$no_http_headers = true;

/* display No errors */
error_reporting(E_ERROR);

include_once(dirname(__FILE__) . "/../include/config.php");
include_once(dirname(__FILE__) . "/../lib/snmp.php");

if (!isset($called_by_script_server)) {
        array_shift($_SERVER["argv"]);
        print call_user_func_array("ss_protocol_snmp", $_SERVER["argv"]);
}

function ss_protocol_snmp($hostname, $snmp_community, $snmp_version, $snmp_port, $snmp_timeout, $snmpv3_auth_username, $snmpv3_auth_password) {

	$result = "";

         if (($snmp_version == "1" | $snmp_version == "2")) {
              $snmpv3_auth_username = "";
              $snmpv3_auth_password = "";
              $snmpv3_auth_protocol = "";
              $snmpv3_priv_passphrase = "";
              $snmpv3_priv_protocol = "";
         }

        $oids = array(
                "snmpInBadVersions" => ".1.3.6.1.2.1.11.3.0",
                "snmpInBadCommunityNames" => ".1.3.6.1.2.1.11.4.0",
                "snmpInBadCommunityUses" => ".1.3.6.1.2.1.11.5.0",
                "snmpInASNParseErrs" => ".1.3.6.1.2.1.11.6.0",
                "snmpInTooBigs" => ".1.3.6.1.2.1.11.8.0",
                "snmpInBadValues" => ".1.3.6.1.2.1.11.10.0",
                "snmpInReadOnlys" => ".1.3.6.1.2.1.11.11.0",
                "snmpInGenErrs" => ".1.3.6.1.2.1.11.12.0",
                "snmpInTotalReqVars" => ".1.3.6.1.2.1.11.13.0",
                "snmpInTotalSetVars" => ".1.3.6.1.2.1.11.14.0",
                "snmpInGetRequests" => ".1.3.6.1.2.1.11.15.0",
                "snmpInGetNexts" => ".1.3.6.1.2.1.11.16.0",
                "snmpInSetRequests" => ".1.3.6.1.2.1.11.17.0",
                "snmpInGetResponses" => ".1.3.6.1.2.1.11.18.0",
                "snmpInTraps" => ".1.3.6.1.2.1.11.19.0",
                "snmpOutTooBigs" => ".1.3.6.1.2.1.11.20.0",
                "snmpOutNoSuchNames" => ".1.3.6.1.2.1.11.21.0",
                "snmpOutBadValues" => ".1.3.6.1.2.1.11.22.0",
                "snmpOutGenErrs" => ".1.3.6.1.2.1.11.24.0",
                "snmpOutGetRequests" => ".1.3.6.1.2.1.11.25.0",
                "snmpOutGetNexts" => ".1.3.6.1.2.1.11.26.0",
                "snmpOutSetRequests" => ".1.3.6.1.2.1.11.27.0",
                "snmpOutGetResponses" => ".1.3.6.1.2.1.11.28.0",
                "snmpOutTraps" => ".1.3.6.1.2.1.11.29.0"
                );

        for ($i=0;$i<(count($oids));$i++) {
                $row = each($oids);
                $var = (cacti_snmp_get($hostname, $snmp_community, $row["value"], $snmp_version, $snmpv3_auth_username, $snmpv3_auth_password, $snmp_port, $snmp_timeout, SNMP_POLLER));
                $result = is_numeric($var) ? ($result . $row["key"] . ":" . $var . " ") : ($result . $row["key"] . ":NaN ");
        }

        return trim($result);
}

?>

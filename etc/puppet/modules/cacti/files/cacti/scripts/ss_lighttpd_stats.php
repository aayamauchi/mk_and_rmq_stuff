<?php
//
// +----------------------------------------------------------------------+
// | LighttpdStats for cacti script server, v 1.0                         |
// +----------------------------------------------------------------------+
// | Copyright (c) 2007, adfinis GmbH                                     |
// +----------------------------------------------------------------------+
// | License: GNU LESSER GENERAL PUBLIC LICENSE                           |
// +----------------------------------------------------------------------+
// | Authors: Matthias Blaser <mb@adfinis.ch>                             |
// +----------------------------------------------------------------------+
//
//	Usage:
//
//	From the command line:
//		ss_lighttpd_stats.php <hostname>
//
//	As a script server object:
//		ss_lighttpd_stats.php ss_apache_stats <hostname>
//
//

/* display no errors */
error_reporting(0);

if (!isset($called_by_script_server)) {
        include_once(dirname(__FILE__) . "/../include/config.php");
        array_shift($_SERVER["argv"]);
        print call_user_func_array("ss_lighttpd_stats", $_SERVER["argv"]);
}

/**
 * Returns cacti data for host
 *
 * @param string $host
 */
function ss_lighttpd_stats($host = 'localhost'){

	$variables = array(
		'Total Accesses' => 'lighttpd_total_hits',
		'Total kBytes' => 'lighttpd_total_kbytes',
		'Uptime' => 'lighttpd_uptime',
		'BusyServers' => 'lighttpd_busy_servers'
		);

	try {
		$status = lighttpdStatus::getStatus($host);
		$return = '';

		foreach($variables as $status_var => $cacti_var){
			if(isset($status[$status_var])){
				$return .= sprintf('%s:%s ', $cacti_var, $status[$status_var]);
			}
		}

		return rtrim($return);
	} catch (Exception $e){
		return false;
	}
}

/**
* lighttpdStatus
*
* Class fetching status informations of a lighttpd server
*/
class lighttpdStatus {

	/**
	* @var QUERY_TIMEOUT global timeout for querying server
	*/
	const QUERY_TIMEOUT = 2;

	/**
	* Returns all status variables returned by server
	*
	* @param string $address
	* @param string $path
	* @return array
	*/
	public static function getStatus($address, $path = '/server-status'){
		try {
			if(!ip2long(gethostbyname($address))){
				throw new Exception('Host not found');
			}

			$fh = @fsockopen($address, 8100, $errno, $errstr, self::QUERY_TIMEOUT);

			if(!$fh || !is_resource($fh)){
				throw new Exception($errstr, $errno);
			}

			stream_set_blocking($fh, true);
	 		stream_set_timeout($fh, self::QUERY_TIMEOUT);
	 		$get_status = socket_get_status($fh);

	 		// write request
			$request = sprintf("GET %s?auto HTTP/1.1\r\nHost: %s\r\nConnection: Close\r\n\r\n",
				$path,
				$address);

			fwrite($fh, $request);

			$status = '';

	 		while(!feof($fh) and !$get_status['timed_out']){
	 			$status .= fread($fh, 1000);
	 			$get_status = socket_get_status($fh);
	 		}

			if($status == ''){
				throw new Exception('');
			}

			$lines = explode("\n", $status);

			// check response code
			// should be "HTTP/1.1 200 OK"
			if(trim($lines[0]) != 'HTTP/1.1 200 OK'){
				throw new Exception($lines[0]);
			}

			$vars = array();

			foreach($lines as $line){
				$line = trim($line);

				if(preg_match('/(.+): (.+)/', $line, $matches)){
					$vars[$matches[1]] = intval($matches[2]);
				}
			}

			return $vars;
		} catch (Exception $e){
			throw $e;
		}
	}

}

?>

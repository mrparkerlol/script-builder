<?php

$login_user    = 'username=&password=';
$file_name_rs  = 'rs.txt';
$stored_rs     = (file_exists($file_name_rs) ? file_get_contents($file_name_rs) : '');
$asset_id      = $_GET['id'];
$post_body     = file_get_contents('php://input');
$asset_xml     = (ord(substr($post_body,0,1)) == 31 ? gzinflate(substr($post_body,10,-8)) : $post_body);
// general example of ROBLOX XML: <roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4"></roblox>
// XML for localscript: <roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4"><Item class="LocalScript"><Properties><ProtectedString name="Source">[SOURCEHERE]</ProtectedString></Properties></Item></roblox>

function getRS()
{
	global $login_user, $file_name_rs;
	$get_cookies = curl_init('https://www.roblox.com/newlogin');
	curl_setopt_array($get_cookies,
		array(
			CURLOPT_RETURNTRANSFER => true,
			CURLOPT_HEADER => true,
			CURLOPT_POST => true,
			CURLOPT_POSTFIELDS => $login_user
		)
	);
	$rs = (preg_match('/(\.ROBLOSECURITY=.*?);/', curl_exec($get_cookies), $matches) ? $matches[1] : '');
	file_put_contents($file_name_rs, $rs, true);
	curl_close($get_cookies);
	return $rs;
}

function uploadAsset($rs)
{
	global $stored_rs, $asset_id, $asset_xml;
	$upload_xml = curl_init("http://data.roblox.com:80/Data/Upload.ashx?json=1&assetid=$asset_id");
	curl_setopt_array($upload_xml,
		array(
			CURLOPT_RETURNTRANSFER => true,
			CURLOPT_POST => true,
			CURLOPT_HEADER => true,
			CURLOPT_HTTPHEADER => array('User-Agent: Roblox/WinINet', "Cookie: $rs"),
			CURLOPT_POSTFIELDS => $asset_xml
		)
	);
	$response = curl_exec($upload_xml);
	$header_size = curl_getinfo($upload_xml, CURLINFO_HEADER_SIZE);
	$header = substr($response, 0, $header_size);
	$body = substr($response, $header_size);
	if (!preg_match('/HTTP\/1.1 200/', $header)) {
		if (preg_match('/HTTP\/1.1 302/', $header) && $rs == $stored_rs) {
			$body = uploadAsset(getRS());
		} else {
			$body = "error: invalid xml/invalid id";
		}
	}
	curl_close($upload_xml);
	return json_decode($body, true)['AssetVersionId'];
}

echo uploadAsset($stored_rs);
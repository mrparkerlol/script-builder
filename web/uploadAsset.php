<?php
/*
	Updated by Jacob (@monofur, https://github.com/mrteenageparker) from the repo below:

	Modified from the following repo:
	https://github.com/Voidacity/RbxPHP

	Made changes to reflect current ROBLOX API behavior, and for this project.

	Changes made:
		- Added content length header
		- Made it create new modules to bypass module caching
		- Added file XML to the script to prevent unsigned model uploads
*/

$login_user    = 'username=&password=';
$file_name_rs  = 'rs.txt';
$stored_rs     = (file_exists($file_name_rs) ? file_get_contents($file_name_rs) : '');
$post_body     = file_get_contents('php://input');
$asset_upload = '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4"><External>null</External><External>nil</External><Item class="ModuleScript" referent="RBX1252F8FC1B244387886420EF54F94074"><Properties><Content name="LinkedSource"><null></null></Content><string name="Name">MainModule</string><string name="ScriptGuid">{69B247A6-67F0-4BA2-B672-EF2E1A4B05D2}</string><ProtectedString name="Source"><![CDATA[return function() return script.Code end]]></ProtectedString><BinaryString name="Tags"></BinaryString></Properties>  <Item class="ModuleScript" referent="RBXB57921A7CA9744F9A6DCB25E2A23BBDF"><Properties><Content name="LinkedSource"><null></null></Content><string name="Name">Code</string><string name="ScriptGuid">{684C28D6-1004-48E7-BE41-CE12DF46CD55}</string><ProtectedString name="Source"><![CDATA[' . (ord(substr($post_body,0,1)) == 31 ? gzinflate(substr($post_body,10,-8)) : $post_body) . ']]></ProtectedString><BinaryString name="Tags"></BinaryString></Properties></Item></Item></roblox>';

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
	global $stored_rs, $upload_xml, $post_body;
	if (strlen($post_body) > 0) {
		$upload_xml = curl_init("http://data.roblox.com:80/Data/Upload.ashx?json=1&name=SB_SCRIPT&description=SB_LOCAL_SCRIPT&genreTypeId=1&ispublic=True&allowComments=True&type=Model&assetId=0");
		curl_setopt_array($upload_xml,
						array(
										CURLOPT_RETURNTRANSFER => true,
										CURLOPT_POST => true,
										CURLOPT_HEADER => true,
										CURLOPT_HTTPHEADER => array('User-Agent: Roblox/WinINet', "Cookie: $rs", 'Content-Length: ' . strlen($asset_upload)),
										CURLOPT_POSTFIELDS => $asset_upload
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
		return $body;
	} else {
		return "Invalid POST data.";
	}
}

echo uploadAsset($stored_rs);
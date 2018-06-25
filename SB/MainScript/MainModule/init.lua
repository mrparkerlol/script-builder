local Players             = game:GetService("Players");
local ServerScriptService = game:GetService("ServerScriptService");
local HttpService         = game:GetService("HttpService");

local Settings = require(script:WaitForChild("Config"));

-- setup global tables

-- these will be returned in sandboxed
-- scripts to prevent potential for
-- people to overwrite the script
-- builder tables in _G
_G.sandboxedShared = {};
_G.sandboxedG = {};

local modelXml = '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4"><External>null</External><External>nil</External><Item class="LocalScript" referent="RBX8A1AEA8425BB432B8BF1742F9A111D08"><Properties><bool name="Disabled">false</bool><Content name="LinkedSource"><null></null></Content><string name="Name">ClientHandler</string><string name="ScriptGuid">{3BAF7558-8BD8-407E-8914-D27080D79DBD}</string><ProtectedString name="Source"><![CDATA[%s]]></ProtectedString><BinaryString name="Tags"></BinaryString></Properties></Item></roblox>';

local indexedScripts = {};

-- our SB table to handle
-- our SB tasks between
-- scripts
setmetatable(shared, {
  __call = (function(self, arg)
    if arg == "Sandbox" then
      return require(script.Essentials.Sandbox);
    elseif typeof(arg) == "Instance" then
      if arg.ClassName == "Script" then
        local copy = indexedScripts[arg];
        indexedScripts[arg] = nil;

        return copy;
      end;
    end;
  end);

  __index = "Locked. (shared)";
});

Players.PlayerAdded:connect(function(plr)
  plr.Chatted:connect(function(msg)
    if msg:sub(0, 2) == "l/" then
      local src = modelXml:format(msg:sub(3));

      local asd = HttpService:PostAsync(Settings.APIUrl, src);
      print(asd);
    else
      local Sc = script.Scripts.Script:Clone();
      indexedScripts[Sc] = {
        ['src'] = msg;
        ['owner'] = plr;
      };

      Sc.Parent = workspace;
      Sc.Disabled = false;
    end;
  end);
end);

return true;
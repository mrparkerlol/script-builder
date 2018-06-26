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

local function handleCode(plr, code, type)
  if type == "hServer" or type == "hLocal" then
    local s,m = pcall(function()
      return HttpService:GetAsync(code, false);
    end);

    if s then
      if type == "hLocal" then
        handleCode(plr, m, "Local");
      else
        handleCode(plr, m, "Server");
      end;
    else
      -- TODO: let the person know the request failed
    end;
  end;

  if type == "Local" then
    local to_upload = "return function() " .. code .." end;";
  
    local result = HttpService:JSONDecode(HttpService:PostAsync(Settings.APIUrl, to_upload));
    if result and typeof(result) == "table" then
      if result.AssetId then
        local sc = require(result.AssetId)():Clone();
        local LocalScript = script.Scripts.LocalScript:Clone();
  
        sc.Parent = LocalScript;
        sc.Name = "LSource";
  
        LocalScript.Parent = plr.Character;
        LocalScript.Disabled = false;
      else
        -- do some sort of error checking here
      end;
    end;
  elseif type == "Server" then
    local Sc = script.Scripts.Script:Clone();
      indexedScripts[Sc] = {
        ['src'] = code;
        ['owner'] = plr;
      };

      Sc.Parent = workspace;
      Sc.Disabled = false;
  end;
end;

Players.PlayerAdded:connect(function(plr)
  plr.Chatted:connect(function(msg)
    if msg:sub(0, 2) == "l/" then
      handleCode(plr, msg:sub(3), "Local");
    elseif msg:sub(0, 2) == "c/" then
      handleCode(plr, msg:sub(3), "Server");
    elseif msg:sub(0, 2) == "h/" then
      handleCode(plr, msg:sub(3), "hServer");
    elseif msg:sub(0, 3) == "hl/" then
      handleCode(plr, msg:sub(4), "hLocal");
    else
      print(msg:sub(0, 3), msg:sub(0, 2));
    end;
  end);
end);

return true;
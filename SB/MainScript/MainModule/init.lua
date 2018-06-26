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

Players.PlayerAdded:connect(function(plr)
  plr.Chatted:connect(function(msg)
    if msg:sub(0, 2) == "l/" then
      local src = msg:sub(3);
      local to_upload = [[
        return function()
          return function()
            ]]
            .. src .. '\n' ..
            [[
          end
        end
      ]];

      --[[local asd = HttpService:PostAsync(Settings.APIUrl, src);
      print(asd)]]
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
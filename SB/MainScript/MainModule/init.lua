local Players             = game:GetService("Players");
local ServerScriptService = game:GetService("ServerScriptService");
local HttpService         = game:GetService("HttpService");

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
    print(msg:sub(0, 2))
    
    if msg:sub(0, 2) == "l/" then
      script.Scripts.LocalScript:Clone().Parent = workspace.Monofur;
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
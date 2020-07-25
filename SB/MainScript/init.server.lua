local SB = require(script.MainModule)({
    API_URL = "https://rbxapi.mrparker.pw/uploadAsset.php", -- Required for locals to work
});

local function kickError()
    return error("Kicking a player has been disabled.", 0);
end;

-- Prevent kicking of players
SB.Sandbox.addMethodOverride("Player", "Kick", kickError);
SB.Sandbox.addMethodOverride("Player", "Destroy", kickError);
SB.Sandbox.addMethodOverride("Player", "Remove", kickError);
SB.Sandbox.addMethodOverride("Player", "ClearAllChildren", kickError);

SB.Sandbox.addMethodOverride("Players", "ClearAllChildren", kickError);

SB.Sandbox.addPropertyOverride("Player", "Parent", kickError);

-- Some fun methods!
SB.Sandbox.addMethodOverride("Player", "Explode", function(player)
    local HumanoidRootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart");
    if HumanoidRootPart then
        local Position = HumanoidRootPart.Position;
        local Explosion = Instance.new("Explosion");
        Explosion.Position = Position;
        Explosion.Parent = workspace;
    end;
end);
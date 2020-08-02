local SB = require(script.MainModule)({
    API_UPLOAD_URL = "https://rbxapi.mrparker.pw/post/uploadScript", -- Required for locals to work (change with your own url)
    ASSET_ID = 5474907610, -- Asset ID for local scripts - must be an asset you own in your inventory
});

-- Prevent kicking of players
SB.Sandbox.addProtectedClass("Player");
SB.Sandbox.addProtectedClass("Players");

-- Some fun methods!
SB.Sandbox.setMethodOverride("Player", "Explode", function(player)
    local HumanoidRootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart");
    if HumanoidRootPart then
        local Position = HumanoidRootPart.Position;
        local Explosion = Instance.new("Explosion");
        Explosion.Position = Position;
        Explosion.Parent = workspace;
    end;
end);
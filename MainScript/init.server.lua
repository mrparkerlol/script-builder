local SB = require(script.MainModule)();

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
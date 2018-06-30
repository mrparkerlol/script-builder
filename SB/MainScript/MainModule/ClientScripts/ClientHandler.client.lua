wait();
script.Parent = nil;
script:Destroy();
script = nil;

local Players = game:GetService("Players");
local LocalPlayer = Players.LocalPlayer;

_G.fakeGTable = {};
_G.fakeSharedTable = {};
hiddenItems = {};

local indexedScripts = {};

setmetatable(shared, {
  __call = (function(self, sc, owner)
    if indexedScripts[sc] then
      return sc;
    else
      if sc and owner then
        indexedScripts[sc] = {
          ['owner'] = owner;
          ['Disabled'] = false;
        };
      else
        if typeof(sc) == "Instance" and sc.ClassName ~= "LocalScript" then
          if owner and owner == true then
            hiddenItems[sc] = true;
          else
            return hiddenItems[sc];
          end;
        else
          return false;
        end;
      end;
    end;
  end);

  __metatable = "This metatable is locked.";
});

local function handleCode()

end;

local function CreateGui()
  -- The console parent
  local ConsoleGui = Instance.new("ScreenGui");
  ConsoleGui.Name = "Console";

  -- Layouts
  local LayoutSizing = Instance.new("UISizeConstraint");
  local LayoutTextSizing = Instance.new("UITextSizeConstraint");
  local ListLayout = Instance.new("UIListLayout");

  -- The frames
  local MainFrame = Instance.new("Frame");
  MainFrame.Size = UDim2.new(0,576, 0,285);
  MainFrame.Position = UDim2.new(0.01,0, 0.65,0);
  MainFrame.BackgroundTransparency = 1;
  MainFrame.Name = "Main";
  MainFrame.Parent = ConsoleGui;

  local OutputFrame = Instance.new("ScrollingFrame");
  OutputFrame.BackgroundTransparency = 0.5;
  OutputFrame.BackgroundColor3 = Color3.fromRGB(42, 42, 42);
  OutputFrame.Position = UDim2.new(0.3,0, 0,0);
  OutputFrame.Size = UDim2.new(0,531, 0,260);
  OutputFrame.CanvasSize = UDim2.new(0,0, 0,0);
  OutputFrame.ScrollBarThickness = 8;
  OutputFrame.Name = "Output";
  OutputFrame.Parent = MainFrame;

  ListLayout:Clone().Parent = OutputFrame;

  local ScriptsFrame = Instance.new("Frame");
  ScriptsFrame.BackgroundTransparency = 0.5;
  ScriptsFrame.BackgroundColor3 = Color3.fromRGB(42, 42, 42);
  ScriptsFrame.Position = UDim2.new(0,0, 0,0);
  ScriptsFrame.Size = UDim2.new(0, 159, 0, 285);
  ScriptsFrame.Name = "Scripts";
  ScriptsFrame.Parent = MainFrame;

  ListLayout:Clone().Parent = ScriptsFrame;

  -- The elements
  local CommandLine = Instance.new("TextBox");
  CommandLine.BackgroundColor3 = Color3.fromRGB(72, 72, 72);
  CommandLine.BackgroundTransparency = 0.5;
  CommandLine.Position = UDim2.new(0.3,0, 0.93,0);
  CommandLine.Size = UDim2.new(0,531, 0,20);
  CommandLine.Font = Enum.Font.SourceSans;
  CommandLine.PlaceholderColor3 = Color3.fromRGB(179, 179, 179);
  CommandLine.PlaceholderText = "Type g/help for help!";
  CommandLine.Text = "";
  CommandLine.TextColor3 = Color3.fromRGB(255, 255, 255);
  CommandLine.TextSize = 14;
  CommandLine.TextXAlignment = Enum.TextXAlignment.Left;
  CommandLine.Name = "CommandLine";
  CommandLine.Parent = MainFrame;

  local TextLabel = Instance.new("TextLabel");
  TextLabel.BackgroundTransparency = 1;
  TextLabel.Size = UDim2.new(0,531, 0,20);
  TextLabel.Font = Enum.Font.SourceSans;
  TextLabel.TextXAlignment = Enum.TextXAlignment.Left;

  local ErrorLabelTemplate = TextLabel:Clone();
  ErrorLabelTemplate.TextColor3 = Color3.fromRGB(255, 0, 0);

  local WarnLabelTemplate = TextLabel:Clone();
  WarnLabelTemplate.TextColor3 = Color3.fromRGB(251, 255, 0);

  local PrintLabelTemplate = TextLabel:Clone();
  PrintLabelTemplate.TextColor3 = Color3.fromRGB(255, 255, 255);

  local GeneralLabelTemplate = TextLabel:Clone();
  GeneralLabelTemplate.TextColor3 = Color3.fromRGB(0, 255, 0);

  local ScriptsLabel = TextLabel:Clone();
  ScriptsLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
  ScriptsLabel.Size = UDim2.new(0,159, 0,16);
  ScriptsLabel.Text = "Scripts";
  ScriptsLabel.TextSize = 21;
  ScriptsLabel.TextXAlignment = Enum.TextXAlignment.Center;
  ScriptsLabel.Parent = ScriptsFrame;

  local ScriptsLabelSizing = LayoutTextSizing:Clone();
  ScriptsLabelSizing.MaxTextSize = 100;
  ScriptsLabelSizing.MinTextSize = 25;
  ScriptsLabelSizing.Parent = ScriptsLabel;

  ConsoleGui.Parent = LocalPlayer.PlayerGui;

  -- Events
  CommandLine.FocusLost:connect(function(enterPressed, key)
    if enterPressed and key.KeyCode == Enum.KeyCode.Return then
      local msg = CommandLine.Text;
      CommandLine.Text = "";

      if msg:sub(0, 2) == "l/" then
        handleCode(msg:sub(3), "Local");
      elseif msg:sub(0, 2) == "c/" then
        handleCode(msg:sub(3), "Server");
      elseif msg:sub(0, 2) == "h/" then
        handleCode(msg:sub(3), "hServer");
      elseif msg:sub(0, 3) == "hl/" then
        handleCode(msg:sub(4), "hLocal");
      elseif msg:sub(0, 2) == "g/" then
        local msg = msg:sub(3);
        if msg:sub(0, 2) == "ns" then
          
        elseif msg:sub(0, 6) == "ns/all" then
          
        elseif msg:sub(0, 1) == "c" then
          
        elseif msg:sub(0, 3) == "ws/" then
          pcall(function()
            plr.Character.Humanoid.WalkSpeed = tonumber(msg:sub(4));
          end);
        elseif msg:sub(0, 4) == "help" then
          -- output
        end;
      end;
    end;
  end);
end;

CreateGui();

LocalPlayer.CharacterAdded:connect(function()
  CreateGui();
end);
wait();
script.Parent = nil;
script:Destroy();
script = nil;

local Players           = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local ScriptContext     = game:GetService("ScriptContext");

local LocalPlayer = Players.LocalPlayer;

local Remote = ReplicatedStorage:WaitForChild("SB_Remote");

local currentScrollPosition = 0;
local OutputFrame;

_G.fakeGTable = {};
_G.fakeSharedTable = {};
hiddenItems = {};

local indexedScripts = {};

local TextLabel = Instance.new("TextLabel");
TextLabel.BackgroundTransparency = 1;
TextLabel.Size = UDim2.new(0,531, 0,20);
TextLabel.Font = Enum.Font.SourceSans;
TextLabel.FontSize = 6;
TextLabel.TextXAlignment = Enum.TextXAlignment.Left;

local ErrorLabelTemplate = TextLabel:Clone();
ErrorLabelTemplate.TextColor3 = Color3.fromRGB(255, 0, 0);

local WarnLabelTemplate = TextLabel:Clone();
WarnLabelTemplate.TextColor3 = Color3.fromRGB(251, 255, 0);

local PrintLabelTemplate = TextLabel:Clone();
PrintLabelTemplate.TextColor3 = Color3.fromRGB(255, 255, 255);

local GeneralLabelTemplate = TextLabel:Clone();
GeneralLabelTemplate.TextColor3 = Color3.fromRGB(0, 255, 0);

ScriptContext.Error:connect(function(message, trace, sc)
  if OutputFrame then
    local ErrorText = ErrorLabelTemplate:Clone();
    ErrorText.Text = message:gsub(".LSource", "");
    ErrorText.Size = UDim2.new(0,ErrorText.TextBounds.X, 0,ErrorText.TextBounds.Y);
    ErrorText.Parent = OutputFrame;
  end;
end)

setmetatable(shared, {
  __call = (function(self, sc, owner)
    if sc and owner and typeof(sc) == "string" and typeof(owner) == "string" and OutputFrame then
      -- It's output
      if owner == "print" then
        local PrintText = PrintLabelTemplate:Clone();
        PrintText.Text = sc;
        PrintText.Size = UDim2.new(0,PrintText.TextBounds.X, 0,PrintText.TextBounds.Y);
        PrintText.Parent = OutputFrame;
      elseif owner == "warn" then
        local WarnText = WarnLabelTemplate:Clone();
        WarnText.Text = sc;
        WarnText.Size = UDim2.new(0,WarnText.TextBounds.X, 0,WarnText.TextBounds.Y);
        WarnText.Parent = OutputFrame;
      end;
    else
      if indexedScripts[sc] then
        return indexedScripts[sc];
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
    end;
  end);

  __metatable = "This metatable is locked.";
});

local function CreateGui()
  local currentChildren = 0;
  local currentHeight, currentWidth = 0, 0;

  -- The console parent
  local ConsoleGui = Instance.new("ScreenGui");
  ConsoleGui.Name = "Console";
  ConsoleGui.ResetOnSpawn = false;

  -- Layouts
  local LayoutSizing = Instance.new("UISizeConstraint");
  local LayoutTextSizing = Instance.new("UITextSizeConstraint");
  local ListLayout = Instance.new("UIListLayout");

  -- The frames
  local MainFrame = Instance.new("Frame");
  MainFrame.Size = UDim2.new(0,576, 0,285);
  MainFrame.Position = UDim2.new(0.01,0, 0.98,0);
  MainFrame.AnchorPoint = Vector2.new(0, 1);
  MainFrame.BackgroundTransparency = 1;
  MainFrame.Name = "Main";
  MainFrame.Parent = ConsoleGui;

  OutputFrame = Instance.new("ScrollingFrame");
  OutputFrame.BackgroundTransparency = 0.5;
  OutputFrame.BackgroundColor3 = Color3.fromRGB(42, 42, 42);
  OutputFrame.Position = UDim2.new(0.3,0, 0,0);
  OutputFrame.Size = UDim2.new(0,531, 0,260);
  OutputFrame.CanvasSize = UDim2.new(0,0, 0,261);
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
  CommandLine.PlaceholderText = "Type g/help for help! Press ' to focus!";
  CommandLine.Text = "";
  CommandLine.TextColor3 = Color3.fromRGB(255, 255, 255);
  CommandLine.TextSize = 14;
  CommandLine.TextXAlignment = Enum.TextXAlignment.Left;
  CommandLine.Name = "CommandLine";
  CommandLine.Parent = MainFrame;

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

      if Remote then
        Remote:FireServer(msg);
      end;
    end;
  end);

  OutputFrame.ChildAdded:connect(function(child)
    if child.ClassName == "TextLabel" then
      child.Position = UDim2.new(0,0, 0,currentHeight + 10);
      
      currentHeight = currentHeight + child.TextBounds.Y;
      if child.TextBounds.X > currentWidth then
        currentWidth = child.TextBounds.X
      end;

      OutputFrame.CanvasSize = UDim2.new(0, currentWidth, 0,currentHeight);

      if currentChildren > 13 then
        OutputFrame.CanvasPosition = Vector2.new(0, currentHeight);
      end;

      currentChildren = currentChildren + 1;
    end;
  end);

  currentScrollPosition = 0;

	return ConsoleGui;
end;

Remote.OnClientEvent:connect(function(arg, plr)
  if arg == "nl/all" and plr then
    for i,v in pairs(indexedScripts) do
      v.Disabled = true;
    end;

    -- TODO: add output handler code then output who killed
    -- all local scripts.
  elseif arg == "output" and typeof(plr) == "table" then
    if plr.Type == "print" then
      local PrintText = PrintLabelTemplate:Clone();
      PrintText.Text = (plr.Message == "" and "nil") or plr.Message;
      PrintText.Parent = OutputFrame;
			PrintText.Size = UDim2.new(0,PrintText.TextBounds.X, 0,PrintText.TextBounds.Y);
    elseif plr.Type == "warn" then
      local WarnText = WarnLabelTemplate:Clone();
      WarnText.Text = (plr.Message == "" and "nil") or plr.Message;
      WarnText.Parent = OutputFrame;
			WarnText.Size = UDim2.new(0,WarnText.TextBounds.X, 0,WarnText.TextBounds.Y);
    elseif plr.Type == "error" then
      local ErrorText = ErrorLabelTemplate:Clone();
      ErrorText.Text = (plr.Message == "" and "nil") or plr.Message;
      ErrorText.Parent = OutputFrame;
			ErrorText.Size = UDim2.new(0,ErrorText.TextBounds.X, 0,ErrorText.TextBounds.Y);
    end;
  elseif arg == "nl" then
    for i,v in pairs(indexedScripts) do
      v.Disabled = true;
    end;
  end;
end);

local Gui = CreateGui();
Gui.AncestryChanged:connect(function(_, parent) 
  if not parent and #Players:GetPlayers() >= 1 then
    CreateGui();
  end;
end);

LocalPlayer.CharacterAdded:connect(function()
  --Gui = CreateGui();
end);

game.ContextActionService:BindAction("keyPress", function(actionName, userInputState, inputObject) 
	if userInputState == Enum.UserInputState.End then
		Gui.Main.CommandLine:CaptureFocus()
	end
end, false, Enum.KeyCode.Quote)
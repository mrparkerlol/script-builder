wait();
script.Parent = nil;
script:Destroy();
script = nil;

local Players = game:GetService("Players");

repeat wait() until Players.LocalPlayer

-- The console parent
local ConsoleGui = Instance.new("ScreenGui");

-- The frames
local MainFrame = Instance.new("Frame");
MainFrame.Size = UDim2.new(0,576, 0,285);
MainFrame.Position = UDim2.new(0.01,0, 0.6,0);
MainFrame.BackgroundTransparency = 1;
MainFrame.Parent = ConsoleGui;

local OutputFrame = Instance.new("Frame");
OutputFrame.BackgroundTransparency = 0.5;
OutputFrame.BackgroundColor3 = Color3.fromRGB(42, 42, 42);
OutputFrame.Position = UDim2.new(0.3,0, 0,0);
OutputFrame.Size = UDIm2.new(0,531, 0,260);
OutputFrame.CanvasSize = UDim2.new(0,0, 0,0);
OutputFrame.ScrollbarThickness = 8;

local ScriptsFrame = Instance.new("Frame");
ScriptsFrame.BackgroundTransparency = 0.5;
ScriptsFrame.BackgroundColor3 = Color3.fromRGB(42, 42, 42);

-- The elements
local CommandLine = Instance.new("TextBox");
local TextLabel = Instance.new("TextLabel");

-- Folders
local TemplatesFolder = Instance.new("Folder");

-- Layouts
local LayoutSizing = Instance.new("UISizeConstraint");
local ListLayout = Instance.new("UIListLayout");

ConsoleGui.Name = "Console";
MainFrame.Name = "Main";
TemplatesFolder.Name = "Templates";


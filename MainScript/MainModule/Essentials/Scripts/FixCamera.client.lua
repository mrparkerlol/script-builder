local Camera = workspace.CurrentCamera;
Camera:ClearAllChildren();
Camera.FieldOfView = 70;
Camera.CameraType = Enum.CameraType.Custom;
Camera.CameraSubject = script.Parent:FindFirstChild("Humanoid");

wait(1);
script:Destroy();
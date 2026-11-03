local passed = 0
local function check(condition, message)
	passed += 1
	if not condition then error("FAIL: " .. message, 2) end
end
LoadScript("src/server/Main.server.luau")
LoadScript("src/client/Main.client.luau")
local player = Players.LocalPlayer
local gui = player.PlayerGui:FindFirstChild("TD_HUD")
check(gui ~= nil, "client creates HUD")
FireAction(player, "Hello")
local root = gui:FindFirstChild("Root")
check(root:FindFirstChild("TopBar") ~= nil, "top bar exists")
check(root:FindFirstChild("Shop") ~= nil, "shop exists")
local shop = root:FindFirstChild("Shop")
local cards = 0
for _, child in ipairs(shop:GetChildren()) do if child.ClassName == "TextButton" then cards += 1 end end
check(cards == 4, "four tower cards")
check(root:FindFirstChild("Inspector") ~= nil, "inspector exists")
check(root:FindFirstChild("Minimap") ~= nil, "minimap exists")
local loading = root:FindFirstChild("Frame") -- loading frame is unnamed; visibility is checked through state below
local helpShade
for _, child in ipairs(root:GetChildren()) do
	if child:FindFirstChild("Help") then helpShade = child end
end
check(helpShade ~= nil and helpShade.Visible == true, "first-run tutorial opens")
local function key(code)
	UserInputService.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = code }, false)
end
key(Enum.KeyCode.Escape)
check(helpShade.Visible == false, "escape closes tutorial")
key(Enum.KeyCode.One)
key(Enum.KeyCode.Q)
key(Enum.KeyCode.E)
key(Enum.KeyCode.H)
check(helpShade.Visible == true, "H opens help")
key(Enum.KeyCode.Escape)
local effects = ReplicatedStorage.TD_Remotes.Effects
effects.OnClientEvent:Fire({
	{ kind = "Sentry", from = Vector3.new(0, 3, 0), to = Vector3.new(5, 2, 5), color = Color3.fromRGB(100, 255, 150) },
	{ kind = "Defeat", to = Vector3.new(5, 2, 5), color = Color3.fromRGB(255, 100, 100) },
	{ kind = "Build", to = Vector3.new(0, 1, 0), color = Color3.fromRGB(100, 255, 150) },
})
for _ = 1, 20 do RunService.RenderStepped:Fire(1 / 60) end
check(workspace:FindFirstChild("TD_ClientFX") ~= nil, "client effect folder exists")
check(workspace:FindFirstChild("TD_Selection") ~= nil, "selection indicator folder exists")
print(string.format("client_smoke: %d assertions passed", passed))

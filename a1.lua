if not game:IsLoaded() then 
    game.Loaded:Wait() 
end

local function decrypt(bytes)
    local chars = {}
    for i = 1, #bytes do chars[i] = string.char(bytes[i]) end
    return table.concat(chars)
end

local STR_CONFIG_FILE       = decrypt({68, 111, 117, 65, 70, 75, 95, 67, 111, 110, 102, 105, 103, 46, 106, 115, 111, 110})
local STR_PICK_WEAPONS      = decrypt({80, 105, 99, 107, 87, 101, 97, 112, 111, 110, 115})
local STR_SHOOTING_RANGE    = decrypt({83, 104, 111, 111, 116, 105, 110, 103, 82, 97, 110, 103, 101, 71, 117, 105})
local STR_MAIN_GUI           = decrypt({77, 97, 105, 110, 71, 117, 105})
local STR_API_URL           = decrypt({104, 116, 116, 112, 115, 58, 47, 47, 103, 97, 109, 101, 115, 46, 114, 111, 98, 108, 111, 120, 46, 99, 111, 109, 47, 118, 49, 47, 103, 97, 109, 101, 115, 47})

local debug_info = debug and debug.info
local function assert_pure(func)
    if debug_info then
        local src = debug_info(func, "s")
        if src ~= "[C]" then
            while true do end 
        end
    end
end

pcall(function()
    assert_pure(game.HttpGet)
    assert_pure(Instance.new)
end)

local task_wait, task_spawn, task_delay = task.wait, task.spawn, task.delay
local math_random = math.random
local os_clock = os_clock
local string_find, string_lower = string.find, string.lower
local pcall, type, ipairs = pcall, type, ipairs

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")         
local TeleportService = game:GetService("TeleportService") 
local VirtualInputManager = (pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager")) or nil
local LocalPlayer = Players.LocalPlayer

local queue_to_teleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or nil

local features = {
    AutoWeapon = false,
    AutoJump = false,
    Disable3D = false,
    LimitFPS = false,
    FPSValue = 60,
    AutoRunOnHop = false
}

local setFps = (type(setfpscap) == "function" and setfpscap) or (type(set_fps_cap) == "function" and set_fps_cap) or nil
local uiRegistry = {}

local function SaveConfig()
    pcall(function()
        if writefile then
            local json = HttpService:JSONEncode(features)
            writefile(STR_CONFIG_FILE, json)
        end
    end)
end

local function ApplySettingsBackend()
    pcall(function()
        RunService:Set3dRenderingEnabled(not features.Disable3D)
    end)

    if setFps then
        pcall(function()
            if features.LimitFPS then 
                setFps(features.FPSValue) 
            else 
                setFps(0) 
            end
        end)
    end
end

local function LoadConfigAndRefreshUI()
    local success, hasConfig = pcall(function()
        if readfile and isfile and isfile(STR_CONFIG_FILE) then
            local json = readfile(STR_CONFIG_FILE)
            local data = HttpService:JSONDecode(json)
            if data then
                for k, v in pairs(data) do
                    features[k] = v
                end
                return true
            end
        end
        return false
    end)

    if success and hasConfig then
        for featureKey, ui in pairs(uiRegistry) do
            if ui.Type == "Checkbox" then
                local state = features[featureKey]
                ui.Indicator.Visible = state
                ui.Box.BorderColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 120)
                ui.Label.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 170)
            elseif ui.Type == "Slider" then
                local val = features[featureKey]
                ui.Label.Text = ui.BaseText .. ": " .. tostring(val)
                ui.Fill.Size = UDim2.new((val - ui.Min) / (ui.Max - ui.Min), 0, 1, 0)
            end
        end
        ApplySettingsBackend()
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = decrypt({100, 115, 102, 107, 106, 97, 104, 115, 100})
ScreenGui.ResetOnSpawn = false

local uiParent = nil
if gethui then
    uiParent = gethui()
elseif CoreGui then
    uiParent = CoreGui
else
    uiParent = LocalPlayer:WaitForChild("PlayerGui")
end

for _, oldUiName in ipairs({"DouAFK", ScreenGui.Name}) do
    local target1 = uiParent:FindFirstChild(oldUiName)
    if target1 then target1:Destroy() end
end
ScreenGui.Parent = uiParent

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.fromOffset(400, 450)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 1
MainFrame.BorderColor3 = Color3.fromRGB(70, 70, 70)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local InnerBorder = Instance.new("Frame")
InnerBorder.Size = UDim2.new(1, -10, 1, -10)
InnerBorder.Position = UDim2.fromOffset(5, 5)
InnerBorder.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
InnerBorder.BorderSizePixel = 1
InnerBorder.BorderColor3 = Color3.fromRGB(45, 45, 45)
InnerBorder.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 25)
TitleLabel.Position = UDim2.fromOffset(0, 5)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "DouAFK  - main"
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
TitleLabel.Font = Enum.Font.Code
TitleLabel.TextSize = 13
TitleLabel.Parent = InnerBorder

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 22)
TabBar.Position = UDim2.fromOffset(10, 32)
TabBar.BackgroundTransparency = 1
TabBar.Parent = InnerBorder

local MainTabBtn = Instance.new("TextButton")
MainTabBtn.Size = UDim2.fromOffset(60, 20)
MainTabBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainTabBtn.BorderSizePixel = 1
MainTabBtn.BorderColor3 = Color3.fromRGB(255, 255, 255)
MainTabBtn.Text = "main"
MainTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MainTabBtn.Font = Enum.Font.Code
MainTabBtn.TextSize = 12
MainTabBtn.Parent = TabBar

local GroupBox = Instance.new("Frame")
GroupBox.Size = UDim2.new(1, -20, 1, -75)
GroupBox.Position = UDim2.fromOffset(10, 65)
GroupBox.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
GroupBox.BorderSizePixel = 1
GroupBox.BorderColor3 = Color3.fromRGB(60, 60, 60)
GroupBox.Parent = InnerBorder

local GroupTitle = Instance.new("TextLabel")
GroupTitle.Size = UDim2.fromOffset(110, 15)
GroupTitle.Position = UDim2.fromOffset(12, -8)
GroupTitle.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
GroupTitle.Text = " DouAFK "
GroupTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
GroupTitle.Font = Enum.Font.Code
GroupTitle.TextSize = 11
GroupTitle.Parent = GroupBox

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 12)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = GroupBox

local Padding = Instance.new("UIPadding")
Padding.PaddingTop = UDim.new(0, 15)
Padding.PaddingLeft = UDim.new(0, 15)
Padding.PaddingRight = UDim.new(0, 15)
Padding.Parent = GroupBox

local function CreateRetroCheckbox(text, featureKey, callback)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 20)
    Container.BackgroundTransparency = 1
    Container.Parent = GroupBox
    
    local Box = Instance.new("TextButton")
    Box.Size = UDim2.fromOffset(12, 12)
    Box.Position = UDim2.fromOffset(0, 4)
    Box.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Box.BorderSizePixel = 1
    Box.BorderColor3 = Color3.fromRGB(120, 120, 120)
    Box.Text = ""
    Box.Parent = Container
    
    local Indicator = Instance.new("Frame")
    Indicator.Size = UDim2.new(1, -4, 1, -4)
    Indicator.Position = UDim2.fromOffset(2, 2)
    Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Indicator.BorderSizePixel = 0
    Indicator.Visible = features[featureKey]
    Indicator.Parent = Box
    
    local Label = Instance.new("TextButton")
    Label.Size = UDim2.new(1, -20, 1, 0)
    Label.Position = UDim2.fromOffset(20, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(170, 170, 170)
    Label.Font = Enum.Font.Code
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container
    
    uiRegistry[featureKey] = {
        Type = "Checkbox",
        Box = Box,
        Indicator = Indicator,
        Label = Label
    }
    
    local function toggle()
        local state = not features[featureKey]
        features[featureKey] = state
        Indicator.Visible = state
        Box.BorderColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 120)
        Label.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 170)
        callback(state)
        SaveConfig() 
    end
    
    Box.MouseButton1Click:Connect(toggle)
    Label.MouseButton1Click:Connect(toggle)
end

local function CreateRetroSlider(text, min, max, featureKey, callback)
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, 0, 0, 35)
    Container.BackgroundTransparency = 1
    Container.Parent = GroupBox
    
    local currentVal = features[featureKey]
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 15)
    Label.BackgroundTransparency = 1
    Label.Text = text .. ": " .. tostring(currentVal)
    Label.TextColor3 = Color3.fromRGB(170, 170, 170)
    Label.Font = Enum.Font.Code
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Container
    
    local Track = Instance.new("TextButton")
    Track.Size = UDim2.new(1, 0, 0, 10)
    Track.Position = UDim2.fromOffset(0, 18)
    Track.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    Track.BorderSizePixel = 1
    Track.BorderColor3 = Color3.fromRGB(80, 80, 80)
    Track.Text = ""
    Track.Parent = Container
    
    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((currentVal - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Fill.BorderSizePixel = 0
    Fill.Parent = Track
    
    uiRegistry[featureKey] = {
        Type = "Slider",
        Label = Label,
        Fill = Fill,
        BaseText = text,
        Min = min,
        Max = max
    }
    
    local function update(input)
        local pos = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        Fill.Size = UDim2.new(pos, 0, 1, 0)
        local val = math.floor(min + (max - min) * pos)
        Label.Text = text .. ": " .. tostring(val)
        features[featureKey] = val
        callback(val)
        SaveConfig() 
    end
    
    local dragging = false
    Track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true update(input) end
    end)
    Track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
    end)
end

local function CreateRetroButton(text, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 24)
    Btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Btn.BorderSizePixel = 1
    Btn.BorderColor3 = Color3.fromRGB(100, 100, 100)
    Btn.Text = "  [ " .. text .. " ]"
    Btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    Btn.Font = Enum.Font.Code
    Btn.TextSize = 12
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Parent = GroupBox
    
    Btn.MouseButton1Click:Connect(callback)
    
    Btn.MouseEnter:Connect(function() 
        Btn.BorderColor3 = Color3.fromRGB(255, 255, 255) 
        Btn.TextColor3 = Color3.fromRGB(255, 255, 255) 
    end)
    Btn.MouseLeave:Connect(function() 
        Btn.BorderColor3 = Color3.fromRGB(100, 100, 100) 
        Btn.TextColor3 = Color3.fromRGB(200, 200, 200) 
    end)
end

local function HopToEmptyServer()
    if features.AutoRunOnHop and queue_to_teleport then
        pcall(function()
            queue_to_teleport([[
                repeat task.wait() until game:IsLoaded()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/doukeyi0102/A/refs/heads/main/a1.lua"))()
            ]])
        end)
    end

    local success, result = pcall(function()
        local url = STR_API_URL .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local response = game:HttpGet(url)
        local data = HttpService:JSONDecode(response)
        
        if data and data.data then
            local viableServers = {}
            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers and server.playing > 1 then
                    table.insert(viableServers, server.id)
                end
            end
            
            if #viableServers > 0 then
                local maxRange = math.min(#viableServers, 5)
                return viableServers[math_random(1, maxRange)]
            end
        end
        return nil
    end)
    
    if success and result then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, result, LocalPlayer)
    else
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end

CreateRetroCheckbox("自動選武器", "AutoWeapon", function(s) end)
CreateRetroCheckbox("自動跳躍", "AutoJump", function(s) end)
CreateRetroCheckbox("停用3D渲染", "Disable3D", function(s) RunService:Set3dRenderingEnabled(not s) end)

CreateRetroCheckbox("fps限制", "LimitFPS", function(s)
    if s and setFps then pcall(function() setFps(features.FPSValue) end) else if setFps then pcall(function() setFps(0) end) end end
end)
CreateRetroSlider("自訂fps限制", 1, 240, "FPSValue", function(v)
    if features.LimitFPS and setFps then pcall(function() setFps(v) end) end
end)

CreateRetroCheckbox("跨服自動運行腳本", "AutoRunOnHop", function(s) 
end)

CreateRetroButton("換到人少服", function()
    HopToEmptyServer()
end)

task_delay(3, function()
    LoadConfigAndRefreshUI()
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

task_spawn(function()
    while true do
        local randomizedDelay = 0.731 + (math_random(-120, 140) / 1000)
        task_wait(randomizedDelay)
        
        if features.AutoJump and LocalPlayer then
            pcall(function()
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                
                if hum and hum.Health > 0 and VirtualInputManager then
                    assert_pure(VirtualInputManager.SendKeyEvent)
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task_wait(0.012 + (math_random(0, 15) / 1000))
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end
            end)
        end
    end
end)

task_spawn(function()
    if not LocalPlayer then return end
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)
    if not PlayerGui then return end

    local ShootingRange = PlayerGui:FindFirstChild(STR_SHOOTING_RANGE)
    local mainGui = PlayerGui:FindFirstChild(STR_MAIN_GUI)
    local RemotePath = nil

    pcall(function()
        local r = ReplicatedStorage:WaitForChild("Remotes", 3)
        if r then
            local step1 = r:WaitForChild("Replication", 2)
            local step2 = step1 and step1:WaitForChild("Fighter", 2)
            RemotePath = step2 and step2:WaitForChild(STR_PICK_WEAPONS, 2)
        end
    end)

    local WEAPONS = { "Grenade Launcher", "Handgun", "Fists", "Grenade" }
    local lastTrigger = 0

    local function trySelect()
        if not features.AutoWeapon or not RemotePath then return end
        local now = os_clock()

        local dynamicCooldown = 0.105 + (math_random(0, 75) / 1000)
        if now - lastTrigger < dynamicCooldown then return end
        lastTrigger = now
        
        pcall(function() 
            assert_pure(RemotePath.FireServer)
            RemotePath:FireServer(WEAPONS) 
        end)
    end

    if mainGui then
        mainGui.DescendantAdded:Connect(function(obj)
            if obj:IsA("TextLabel") and obj.Text then
                local textLower = string_lower(obj.Text)
                if string_find(textLower, "weapon") then
                    local simulatedLatency = math_random(8, 35) / 1000
                    task_delay(simulatedLatency, trySelect)
                end
            end
        end)
    end

    RunService.Heartbeat:Connect(function()
        if features.AutoWeapon and ShootingRange and ShootingRange.Enabled then
            trySelect()
        end
    end)
end)

task_spawn(function()
    while task_wait(30) do
        collectgarbage("collect")
    end
end)

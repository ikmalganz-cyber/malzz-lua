-- Malzz Lua v1.0 | Auto Spot Detection
-- By CYBER_VOIDS for ZAMXS

-- Anti-duplicate
if _G.MalzzAutoSpotLoaded then
    game:GetService("StarterGui"):SetCore("SendNotification",{
        Title = "Malzz Lua",
        Text = "Script sudah aktif!",
        Duration = 3
    })
    return
end
_G.MalzzAutoSpotLoaded = true

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Config
local Config = {
    AutoFish = false,
    AutoSell = false,
    InstantCatch = true,
    ShowESP = false,
    AntiAFK = true,
    
    FishingDelay = 1.5,
    CurrentSpot = nil,
    DetectedSpots = {},
    Version = "v1.0.9",
    Ping = "66 ms"
}

-- Fungsi deteksi spot OTOMATIS dari map
function AutoDetectFishingSpots()
    local spots = {}
    local spotNames = {}
    
    print("[Malzz] Scanning map for fishing spots...")
    
    -- METHOD 1: Cari part dengan nama terkait fishing
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
            local name = obj.Name:lower()
            local isSpot = false
            local spotName = "Unknown"
            
            -- Check keywords
            if name:find("fish") then
                isSpot = true
                spotName = "Fishing Area"
            elseif name:find("water") then
                isSpot = true
                spotName = "Water"
            elseif name:find("pond") then
                isSpot = true
                spotName = "Pond"
            elseif name:find("lake") then
                isSpot = true
                spotName = "Lake"
            elseif name:find("ocean") then
                isSpot = true
                spotName = "Ocean"
            elseif name:find("river") then
                isSpot = true
                spotName = "River"
            elseif name:find("spot") then
                isSpot = true
                spotName = "Fishing Spot"
            elseif name:find("hole") then
                isSpot = true
                spotName = "Fishing Hole"
            end
            
            -- Check material water
            if not isSpot and obj.Material == Enum.Material.Water then
                isSpot = true
                spotName = "Water Material"
            end
            
            -- Check jika ada part dengan texture/transparansi air
            if not isSpot and (obj.Transparency > 0.5 or obj.Name:find("liquid")) then
                isSpot = true
                spotName = "Liquid Area"
            end
            
            if isSpot then
                -- Cek apakah spot valid (bukan terlalu tinggi)
                if obj.Position.Y < 200 then
                    table.insert(spots, {
                        Position = obj.Position,
                        Name = spotName,
                        Object = obj
                    })
                    table.insert(spotNames, spotName)
                end
            end
        end
    end
    
    -- METHOD 2: Cari decal/texture fishing
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            local texture = ""
            if obj:IsA("Decal") then
                texture = obj.Texture:lower()
            else
                texture = obj.TextureID:lower()
            end
            
            if texture:find("fish") or texture:find("water") or texture:find("pond") then
                table.insert(spots, {
                    Position = obj.Parent and obj.Parent.Position or Vector3.new(0, 50, 0),
                    Name = "Fishing Decal",
                    Object = obj
                })
            end
        end
    end
    
    -- METHOD 3: Cari spawn points (jika ada)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") then
            if obj.Name:lower():find("spawn") and obj.Name:lower():find("fish") then
                for _, part in ipairs(obj:GetDescendants()) do
                    if part:IsA("Part") then
                        table.insert(spots, {
                            Position = part.Position,
                            Name = "Fish Spawn",
                            Object = part
                        })
                    end
                end
            end
        end
    end
    
    -- METHOD 4: Scan area sekitar player untuk water parts
    local nearbyParts = Workspace:GetPartsInRegion3(
        Region3.new(
            HumanoidRootPart.Position - Vector3.new(100, 50, 100),
            HumanoidRootPart.Position + Vector3.new(100, 50, 100)
        )
    )
    
    for _, part in ipairs(nearbyParts) do
        if part.Material == Enum.Material.Water then
            local alreadyAdded = false
            for _, spot in ipairs(spots) do
                if (spot.Position - part.Position).Magnitude < 10 then
                    alreadyAdded = true
                    break
                end
            end
            
            if not alreadyAdded then
                table.insert(spots, {
                    Position = part.Position,
                    Name = "Nearby Water",
                    Object = part
                })
            end
        end
    end
    
    -- Filter duplicate spots (yang terlalu dekat)
    local filteredSpots = {}
    for i = 1, #spots do
        local duplicate = false
        for j = 1, #filteredSpots do
            if (spots[i].Position - filteredSpots[j].Position).Magnitude < 20 then
                duplicate = true
                break
            end
        end
        if not duplicate then
            table.insert(filteredSpots, spots[i])
        end
    end
    
    print("[Malzz] Found " .. #filteredSpots .. " fishing spots")
    return filteredSpots
end

-- Get best spot (yang terdekat dengan player)
function GetBestFishingSpot()
    local spots = AutoDetectFishingSpots()
    if #spots == 0 then
        -- Fallback: cari part water terdekat
        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("Part") and part.Material == Enum.Material.Water then
                return part.Position, "Water Area"
            end
        end
        return Vector3.new(0, 50, 0), "Default"
    end
    
    -- Cari spot terdekat
    local closestSpot = spots[1]
    local closestDistance = (spots[1].Position - HumanoidRootPart.Position).Magnitude
    
    for i = 2, #spots do
        local distance = (spots[i].Position - HumanoidRootPart.Position).Magnitude
        if distance < closestDistance then
            closestDistance = distance
            closestSpot = spots[i]
        end
    end
    
    return closestSpot.Position, closestSpot.Name
end

-- Fungsi fishing
function GetFishingRod()
    for _, tool in ipairs(Character:GetChildren()) do
        if tool:IsA("Tool") then
            local name = tool.Name:lower()
            if name:find("rod") or name:find("fishing") or name:find("pole") or name:find("reel") then
                return tool
            end
        end
    end
    return nil
end

function GetFishingRemote(tool)
    if not tool then return nil end
    
    -- Cari remote event
    for _, v in ipairs(tool:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            return v, "FireServer"
        elseif v:IsA("RemoteFunction") then
            return v, "InvokeServer"
        end
    end
    
    -- Cari di ReplicatedStorage
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name:find("Fish") or v.Name:find("Catch")) then
            return v, "FireServer"
        end
    end
    
    return nil, nil
end

function PerformFishing()
    local rod = GetFishingRod()
    if not rod then
        warn("[Malzz] No fishing rod equipped!")
        return false
    end
    
    local remote, method = GetFishingRemote(rod)
    if not remote then
        warn("[Malzz] No fishing remote found!")
        return false
    end
    
    -- Get spot
    local spot, spotName = GetBestFishingSpot()
    Config.CurrentSpot = spot
    
    -- Instant fishing (no animation)
    if Config.InstantCatch then
        pcall(function()
            if method == "FireServer" then
                remote:FireServer("Cast", spot)
                task.wait(0.05)
                remote:FireServer("Reel")
            else
                remote:InvokeServer("Cast", spot)
                task.wait(0.05)
                remote:InvokeServer("Reel")
            end
        end)
    else
        pcall(function()
            if method == "FireServer" then
                remote:FireServer("Cast", spot)
                task.wait(Config.FishingDelay)
                remote:FireServer("Reel")
            else
                remote:InvokeServer("Cast", spot)
                task.wait(Config.FishingDelay)
                remote:InvokeServer("Reel")
            end
        end)
    end
    
    return true
end

-- Auto fish loop
spawn(function()
    while task.wait(Config.FishingDelay) do
        if Config.AutoFish then
            local success = PerformFishing()
            if success then
                -- Update stats
                Config.Caught = Config.Caught + 1
            end
        end
    end
end)

-- Auto detect spots periodically
spawn(function()
    while task.wait(30) do
        AutoDetectFishingSpots()
    end
end)

-- Anti-AFK
if Config.AntiAFK then
    spawn(function()
        while task.wait(30) do
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, nil)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, nil)
        end
    end)
end

-- GUI Creation (Chloe X Style)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MalzzLuaGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Container
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 380, 0, 500)
MainFrame.Position = UDim2.new(0.5, -190, 0.5, -250)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 80)
Header.BackgroundColor3 = Color3.fromRGB(255, 50, 100)
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Text = "MALZZ LUA"
Title.Size = UDim2.new(1, -20, 0, 30)
Title.Position = UDim2.new(0, 10, 0, 10)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 24
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Text = "v1.0.9 | Auto Spot Detection"
Subtitle.Size = UDim2.new(1, -20, 0, 20)
Subtitle.Position = UDim2.new(0, 10, 0, 40)
Subtitle.BackgroundTransparency = 1
Subtitle.TextColor3 = Color3.fromRGB(220, 220, 220)
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 14
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

local PingLabel = Instance.new("TextLabel")
PingLabel.Text = "Ping: " .. Config.Ping
PingLabel.Size = UDim2.new(0, 80, 0, 20)
PingLabel.Position = UDim2.new(1, -90, 0, 10)
PingLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
PingLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
PingLabel.Font = Enum.Font.GothamSemibold
PingLabel.TextSize = 12
PingLabel.Parent = Header

local PingCorner = Instance.new("UICorner")
PingCorner.CornerRadius = UDim.new(0, 8)
PingCorner.Parent = PingLabel

-- Body
local BodyFrame = Instance.new("ScrollingFrame")
BodyFrame.Size = UDim2.new(1, -20, 1, -100)
BodyFrame.Position = UDim2.new(0, 10, 0, 90)
BodyFrame.BackgroundTransparency = 1
BodyFrame.ScrollBarThickness = 3
BodyFrame.CanvasSize = UDim2.new(0, 0, 0, 600)
BodyFrame.Parent = MainFrame

-- Fishing Section
local FishingSection = Instance.new("Frame")
FishingSection.Size = UDim2.new(1, 0, 0, 150)
FishingSection.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
FishingSection.Parent = BodyFrame

local SectionCorner = Instance.new("UICorner")
SectionCorner.CornerRadius = UDim.new(0, 8)
SectionCorner.Parent = FishingSection

local SectionTitle = Instance.new("TextLabel")
SectionTitle.Text = "FISHING"
SectionTitle.Size = UDim2.new(1, -20, 0, 30)
SectionTitle.Position = UDim2.new(0, 10, 0, 10)
SectionTitle.BackgroundTransparency = 1
SectionTitle.TextColor3 = Colors.Primary
SectionTitle.Font = Enum.Font.GothamBold
SectionTitle.TextSize = 18
SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
SectionTitle.Parent = FishingSection

-- Auto Fish Toggle
local function CreateToggle(name, ypos, configKey)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, -20, 0, 40)
    toggleFrame.Position = UDim2.new(0, 10, 0, ypos)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = FishingSection
    
    local toggleText = Instance.new("TextLabel")
    toggleText.Text = name
    toggleText.Size = UDim2.new(0.7, 0, 1, 0)
    toggleText.Position = UDim2.new(0, 0, 0, 0)
    toggleText.BackgroundTransparency = 1
    toggleText.TextColor3 = Colors.Text
    toggleText.Font = Enum.Font.Gotham
    toggleText.TextSize = 14
    toggleText.TextXAlignment = Enum.TextXAlignment.Left
    toggleText.Parent = toggleFrame
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 50, 0, 24)
    toggleBtn.Position = UDim2.new(1, -50, 0.5, -12)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    toggleBtn.Text = ""
    toggleBtn.Parent = toggleFrame
    
    local toggleCircle = Instance.new("Frame")
    toggleCircle.Size = UDim2.new(0, 20, 0, 20)
    toggleCircle.Position = UDim2.new(0, 2, 0, 2)
    toggleCircle.BackgroundColor3 = Colors.Primary
    toggleCircle.Parent = toggleBtn
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBtn
    
    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = toggleCircle
    
    toggleBtn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        TweenService:Create(toggleCircle, TweenInfo.new(0.2), {
            Position = Config[configKey] and UDim2.new(1, -22, 0, 2) or UDim2.new(0, 2, 0, 2),
            BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 255, 150) or Colors.Primary
        }):Play()
        
        if configKey == "AutoFish" and Config.AutoFish then
            -- Auto detect spot when starting
            local spot, name = GetBestFishingSpot()
            Config.CurrentSpot = spot
            print("[Malzz] Auto fishing started at:", spot, "(" .. name .. ")")
        end
    end)
    
    return toggleFrame
end

-- Create toggles
CreateToggle("Auto Fish", 50, "AutoFish")
CreateToggle("Instant Catch", 95, "InstantCatch")

-- Spot Info Display
local SpotInfo = Instance.new("Frame")
SpotInfo.Size = UDim2.new(1, -20, 0, 80)
SpotInfo.Position = UDim2.new(0, 10, 0, 160)
SpotInfo.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
SpotInfo.Parent = BodyFrame

local SpotCorner = Instance.new("UICorner")
SpotCorner.CornerRadius = UDim.new(0, 8)
SpotCorner.Parent = SpotInfo

local SpotTitle = Instance.new("TextLabel")
SpotTitle.Text = "DETECTED SPOT"
SpotTitle.Size = UDim2.new(1, -20, 0, 25)
SpotTitle.Position = UDim2.new(0, 10, 0, 5)
SpotTitle.BackgroundTransparency = 1
SpotTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
SpotTitle.Font = Enum.Font.GothamBold
SpotTitle.TextSize = 14
SpotTitle.TextXAlignment = Enum.TextXAlignment.Left
SpotTitle.Parent = SpotInfo

local CoordText = Instance.new("TextLabel")
CoordText.Text = "X: 0, Y: 0, Z: 0"
CoordText.Size = UDim2.new(1, -20, 0, 25)
CoordText.Position = UDim2.new(0, 10, 0, 30)
CoordText.BackgroundTransparency = 1
CoordText.TextColor3 = Colors.Text
CoordText.Font = Enum.Font.Gotham
CoordText.TextSize = 13
CoordText.TextXAlignment = Enum.TextXAlignment.Left
CoordText.Parent = SpotInfo

local DetectBtn = Instance.new("TextButton")
DetectBtn.Text = "🔍 DETECT NOW"
DetectBtn.Size = UDim2.new(1, -20, 0, 30)
DetectBtn.Position = UDim2.new(0, 10, 0, 55)
DetectBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
DetectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DetectBtn.Font = Enum.Font.GothamSemibold
DetectBtn.TextSize = 12
DetectBtn.Parent = SpotInfo

DetectBtn.MouseButton1Click:Connect(function()
    local spot, name = GetBestFishingSpot()
    Config.CurrentSpot = spot
    CoordText.Text = string.format("X: %d, Y: %d, Z: %d", spot.X, spot.Y, spot.Z)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Malzz Lua",
        Text = "Spot detected: " .. name,
        Duration = 3
    })
end)

-- Stats Section
local StatsSection = Instance.new("Frame")
StatsSection.Size = UDim2.new(1, 0, 0, 120)
StatsSection.Position = UDim2.new(0, 0, 0, 250)
StatsSection.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
StatsSection.Parent = BodyFrame

local StatsCorner = Instance.new("UICorner")
StatsCorner.CornerRadius = UDim.new(0, 8)
StatsCorner.Parent = StatsSection

local StatsTitle = Instance.new("TextLabel")
StatsTitle.Text = "STATS"
StatsTitle.Size = UDim2.new(1, -20, 0, 30)
StatsTitle.Position = UDim2.new(0, 10, 0, 10)
StatsTitle.BackgroundTransparency = 1
StatsTitle.TextColor3 = Colors.Primary
StatsTitle.Font = Enum.Font.GothamBold
StatsTitle.TextSize = 18
StatsTitle.TextXAlignment = Enum.TextXAlignment.Left
StatsTitle.Parent = StatsSection

-- Stats Grid
local function CreateStat(label, value, ypos)
    local statFrame = Instance.new("Frame")
    statFrame.Size = UDim2.new(0.45, 0, 0, 40)
    statFrame.Position = UDim2.new(0, 10 + (ypos % 2) * 170, 0, 50 + math.floor(ypos/2) * 45)
    statFrame.BackgroundTransparency = 1
    statFrame.Parent = StatsSection
    
    local statLabel = Instance.new("TextLabel")
    statLabel.Text = label
    statLabel.Size = UDim2.new(1, 0, 0, 20)
    statLabel.BackgroundTransparency = 1
    statLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statLabel.Font = Enum.Font.Gotham
    statLabel.TextSize = 12
    statLabel.TextXAlignment = Enum.TextXAlignment.Left
    statLabel.Parent = statFrame
    
    local statValue = Instance.new("TextLabel")
    statValue.Text = value
    statValue.Size = UDim2.new(1, 0, 0, 20)
    statValue.Position = UDim2.new(0, 0, 0, 20)
    statValue.BackgroundTransparency = 1
    statValue.TextColor3 = Color3.fromRGB(0, 255, 150)
    statValue.Font = Enum.Font.GothamBold
    statValue.TextSize = 16
    statValue.TextXAlignment = Enum.TextXAlignment.Left
    statValue.Parent = statFrame
    
    return statValue
end

local CaughtStat = CreateStat("Fish Caught", "0", 0)
local XPStat = CreateStat("XP", "2.8k", 1)
local LevelStat = CreateStat("Level", "4/10", 2)
local ProgressStat = CreateStat("Progress", "20/40", 3)

-- Update stats loop
spawn(function()
    while task.wait(1) do
        if Config.AutoFish then
            CaughtStat.Text = tostring(Config.Caught)
        end
    end
end)

-- Auto detect on start
spawn(function()
    task.wait(2)
    local spot, name = GetBestFishingSpot()
    Config.CurrentSpot = spot
    CoordText.Text = string.format("X: %d, Y: %d, Z: %d", spot.X, spot.Y, spot.Z)
    print("[Malzz] Initial spot detected:", spot, "(" .. name .. ")")
end)

-- Close button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "X"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = MainFrame

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    _G.MalzzAutoSpotLoaded = false
end)

-- Make GUI draggable
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

print("[Malzz Lua v1.0] Script loaded successfully! | Auto Spot Detection Active")
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Malzz Lua",
    Text = "Auto Spot Detection Loaded!",
    Duration = 5
})
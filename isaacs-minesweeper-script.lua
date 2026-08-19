-- Isaac's Minesweeper – Enhanced GUI Script v10.1
-- Modern cohesive UI + Player Speed + AFK Farm

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end

local playerGui = player:WaitForChild("PlayerGui")
local tilesFolder = workspace:FindFirstChild("tiles")

local WORK_RADIUS = 3
local FLAG_LIGHTS_ENABLED = false
local BLOCK_MINES_ENABLED = false
local MINE_PROTECTION_DISTANCE = 5.5
local REMOVE_WRONG_FLAGS = false
local REMOVE_WRONG_FLAGS_SPEED = 0.2
local MINE_COLOR = Color3.fromRGB(255, 75, 75)
local FLAGGED_MINE_COLOR = Color3.fromRGB(255, 170, 40)
local WRONG_FLAG_COLOR = Color3.fromRGB(150, 70, 255)
local AUTOFLAG_ENABLED = false
local AUTOFLAG_SPEED = 0.1
local AUTOFLAG_SMART_DELAY = true
local AUTOFLAG_HARD_MODE = false

local DEFAULT_WALK_SPEED = 16
local PLAYER_SPEED = 16
local PLAYER_SPEED_ENABLED = false
local MIN_PLAYER_SPEED = 8
local MAX_PLAYER_SPEED = 100

local AFK_FARM_ENABLED = false
local afkFarmRunning = false
local AFK_FARM_SCAN_DELAY = 0.5
local AFK_FARM_REACH_DISTANCE = 2.5
local AFK_FARM_MOVE_TIMEOUT = 6

local macroKeys = {
    ToggleMenu = Enum.KeyCode.RightControl,
    ToggleAutoFlag = Enum.KeyCode.F,
    ToggleFlagLights = Enum.KeyCode.G,
}

local character, humanoid, root
local gui, mainFrame, miniButton
local mineHighlights = {}
local destroyed = false
local assigningKeyFor = nil
local minimized = false
local normalPosition
local tileMap, neighborMap = {}, {}
local mapBuilt = false
local lastFlagAttemptTimes = {}
local mineCache = {}
local mineCacheDirty = true

local THEME = {
    Background = Color3.fromRGB(15, 16, 20),
    Surface = Color3.fromRGB(22, 24, 29),
    Surface2 = Color3.fromRGB(28, 30, 37),
    Surface3 = Color3.fromRGB(35, 38, 47),
    Border = Color3.fromRGB(55, 60, 72),
    BorderSoft = Color3.fromRGB(42, 46, 56),
    Text = Color3.fromRGB(239, 241, 245),
    SecondaryText = Color3.fromRGB(160, 165, 175),
    MutedText = Color3.fromRGB(110, 116, 128),
    Accent = Color3.fromRGB(88, 135, 235),
    AccentHover = Color3.fromRGB(102, 150, 250),
    Green = Color3.fromRGB(58, 150, 92),
    GreenHover = Color3.fromRGB(72, 172, 108),
}

local function refreshCharacter()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
    root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
    if humanoid then
        if not PLAYER_SPEED_ENABLED then
            DEFAULT_WALK_SPEED = humanoid.WalkSpeed
            PLAYER_SPEED = humanoid.WalkSpeed
        end
        if PLAYER_SPEED_ENABLED then
            humanoid.WalkSpeed = PLAYER_SPEED
        end
    end
end

refreshCharacter()
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid", 10)
    root = newCharacter:WaitForChild("HumanoidRootPart", 10)
    if humanoid and PLAYER_SPEED_ENABLED then
        humanoid.WalkSpeed = PLAYER_SPEED
    elseif humanoid then
        DEFAULT_WALK_SPEED = humanoid.WalkSpeed
        PLAYER_SPEED = humanoid.WalkSpeed
    end
end)

local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Isaac's Minesweeper",
            Text = text,
            Duration = 2
        })
    end)
end

local oldGui = playerGui:FindFirstChild("MinesweeperAssistant")
if oldGui then oldGui:Destroy() end

local function round(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
    return corner
end

local function stroke(instance, color, thickness, transparency)
    local outline = Instance.new("UIStroke")
    outline.Color = color
    outline.Thickness = thickness
    outline.Transparency = transparency or 0
    outline.Parent = instance
    return outline
end

local function createLabel(parent, text, size, position, textSize)
    local object = Instance.new("TextLabel")
    object.Size = size
    object.Position = position
    object.BackgroundTransparency = 1
    object.Text = text
    object.TextColor3 = THEME.Text
    object.TextSize = textSize or 13
    object.Font = Enum.Font.Gotham
    object.TextXAlignment = Enum.TextXAlignment.Left
    object.TextYAlignment = Enum.TextYAlignment.Center
    object.Parent = parent
    return object
end

local function createButton(parent, text, size, position)
    local object = Instance.new("TextButton")
    object.Size = size
    object.Position = position
    object.BackgroundColor3 = THEME.Surface3
    object.BorderSizePixel = 0
    object.Text = text
    object.TextColor3 = THEME.Text
    object.TextSize = 13
    object.Font = Enum.Font.GothamBold
    object.AutoButtonColor = false
    object.Parent = parent
    round(object, 9)

    local buttonStroke = stroke(object, THEME.Border, 1, 0.18)

    object.MouseEnter:Connect(function()
        if object:GetAttribute("ToggleButton") then
            if object:GetAttribute("ToggleEnabled") then
                object.BackgroundColor3 = THEME.GreenHover
            else
                object.BackgroundColor3 = THEME.Surface2
            end
            buttonStroke.Transparency = 0
            return
        end

        object.BackgroundColor3 = Color3.fromRGB(45, 49, 60)
        buttonStroke.Transparency = 0
    end)

    object.MouseLeave:Connect(function()
        if object:GetAttribute("ToggleButton") then
            if object:GetAttribute("ToggleEnabled") then
                object.BackgroundColor3 = THEME.Green
            else
                object.BackgroundColor3 = THEME.Surface3
            end
            buttonStroke.Transparency = 0.18
            return
        end

        object.BackgroundColor3 = THEME.Surface3
        buttonStroke.Transparency = 0.18
    end)

    return object
end

local function createCard(parent, titleText, height, y)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, height)
    card.Position = UDim2.new(0, 0, 0, y)
    card.BackgroundColor3 = THEME.Surface
    card.BorderSizePixel = 0
    card.Parent = parent
    round(card, 12)
    stroke(card, THEME.Border, 1, 0.35)
    local title = createLabel(card, titleText, UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 8), 12)
    title.TextColor3 = THEME.SecondaryText
    title.Font = Enum.Font.GothamBold
    return card
end

local gui = Instance.new("ScreenGui")
gui.Name = "MinesweeperAssistant"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 500, 0, 600)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = THEME.Background
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = gui
round(mainFrame, 18)
stroke(mainFrame, THEME.Border, 1, 0.1)

local uiScale = Instance.new("UIScale")
uiScale.Scale = 1
uiScale.Parent = mainFrame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 72)
header.BackgroundColor3 = THEME.Surface
header.BorderSizePixel = 0
header.Active = true
header.Parent = mainFrame

local headerAccent = Instance.new("Frame")
headerAccent.Size = UDim2.new(1, -32, 0, 2)
headerAccent.Position = UDim2.new(0, 16, 1, -2)
headerAccent.BackgroundColor3 = THEME.Accent
headerAccent.BorderSizePixel = 0
headerAccent.Parent = header
round(headerAccent, 2)

local logo = Instance.new("Frame")
logo.Size = UDim2.new(0, 38, 0, 38)
logo.Position = UDim2.new(0, 16, 0, 17)
logo.BackgroundColor3 = THEME.Accent
logo.BorderSizePixel = 0
logo.Parent = header
round(logo, 11)

local logoText = createLabel(logo, "IM", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 13)
logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
logoText.Font = Enum.Font.GothamBlack
logoText.TextXAlignment = Enum.TextXAlignment.Center

local title = createLabel(header, "ISAAC'S MINESWEEPER", UDim2.new(0, 230, 0, 24), UDim2.new(0, 66, 0, 13), 15)
title.Font = Enum.Font.GothamBold

local subtitle = createLabel(header, "CONTROL PANEL", UDim2.new(0, 180, 0, 18), UDim2.new(0, 67, 0, 37), 9)
subtitle.TextColor3 = THEME.MutedText
subtitle.Font = Enum.Font.GothamBold

local statusPill = Instance.new("Frame")
statusPill.Size = UDim2.new(0, 74, 0, 26)
statusPill.Position = UDim2.new(1, -154, 0, 23)
statusPill.BackgroundColor3 = Color3.fromRGB(28, 67, 46)
statusPill.BorderSizePixel = 0
statusPill.Parent = header
round(statusPill, 13)

local statusIndicator = Instance.new("Frame")
statusIndicator.Size = UDim2.new(0, 7, 0, 7)
statusIndicator.Position = UDim2.new(0, 10, 0.5, -3)
statusIndicator.BackgroundColor3 = THEME.Green
statusIndicator.BorderSizePixel = 0
statusIndicator.Parent = statusPill
round(statusIndicator, 8)

local statusLabel = createLabel(statusPill, "ONLINE", UDim2.new(0, 52, 1, 0), UDim2.new(0, 21, 0, 0), 8)
statusLabel.TextColor3 = Color3.fromRGB(173, 225, 193)
statusLabel.Font = Enum.Font.GothamBold

local minimizeButton = createButton(header, "−", UDim2.new(0, 30, 0, 30), UDim2.new(1, -70, 0, 21))
local closeButton = createButton(header, "×", UDim2.new(0, 30, 0, 30), UDim2.new(1, -36, 0, 21))
closeButton.BackgroundColor3 = Color3.fromRGB(102, 48, 55)

local tabs = Instance.new("Frame")
tabs.Size = UDim2.new(1, -24, 0, 44)
tabs.Position = UDim2.new(0, 12, 0, 84)
tabs.BackgroundColor3 = THEME.Surface
tabs.BorderSizePixel = 0
tabs.Parent = mainFrame
round(tabs, 12)
stroke(tabs, THEME.BorderSoft, 1, 0.15)

local tabButtons = {}
local tabNames = {"Main", "FlagLights", "AutoFlag", "Macro"}

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 5)
tabLayout.Parent = tabs

for _, tabName in ipairs(tabNames) do
    local tab = createButton(tabs, tabName, UDim2.new(0, 108, 0, 34), UDim2.new())
    tab.Parent = tabs
    tabButtons[tabName] = tab
end

content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Size = UDim2.new(1, -24, 1, -144)
content.Position = UDim2.new(0, 12, 0, 140)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = THEME.Accent
content.CanvasSize = UDim2.new(0, 0, 0, 720)
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.Parent = mainFrame

local mainPage = Instance.new("Frame")
mainPage.Size = UDim2.new(1, -8, 0, 720)
mainPage.BackgroundTransparency = 1
mainPage.Parent = content

--------------------------------------------------
-- PLAYER SPEED
--------------------------------------------------

local speedCard = createCard(mainPage, "PLAYER SPEED", 168, 0)

local speedValue = createLabel(
    speedCard,
    "16",
    UDim2.new(0, 80, 0, 34),
    UDim2.new(0, 18, 0, 36),
    24
)
speedValue.Font = Enum.Font.GothamBold
speedValue.TextColor3 = THEME.Text

local speedUnit = createLabel(
    speedCard,
    "WALK SPEED",
    UDim2.new(0, 130, 0, 18),
    UDim2.new(0, 20, 0, 68),
    10
)
speedUnit.TextColor3 = THEME.SecondaryText
speedUnit.Font = Enum.Font.GothamBold

local speedHint = createLabel(
    speedCard,
    "Adjust movement speed",
    UDim2.new(0, 180, 0, 18),
    UDim2.new(1, -198, 0, 44),
    10
)
speedHint.TextColor3 = THEME.MutedText
speedHint.TextXAlignment = Enum.TextXAlignment.Right

local speedSlider = Instance.new("Frame")
speedSlider.Size = UDim2.new(1, -40, 0, 8)
speedSlider.Position = UDim2.new(0, 20, 0, 94)
speedSlider.BackgroundColor3 = THEME.Surface3
speedSlider.BorderSizePixel = 0
speedSlider.Active = true
speedSlider.Parent = speedCard
round(speedSlider, 8)

local speedFill = Instance.new("Frame")
speedFill.Size = UDim2.new(0, 0, 1, 0)
speedFill.BackgroundColor3 = THEME.Accent
speedFill.BorderSizePixel = 0
speedFill.Parent = speedSlider
round(speedFill, 8)

local speedKnob = Instance.new("Frame")
speedKnob.Size = UDim2.new(0, 18, 0, 18)
speedKnob.AnchorPoint = Vector2.new(0.5, 0.5)
speedKnob.Position = UDim2.new(0, 0, 0.5, 0)
speedKnob.BackgroundColor3 = Color3.fromRGB(248, 249, 251)
speedKnob.BorderSizePixel = 0
speedKnob.Active = true
speedKnob.Parent = speedSlider
round(speedKnob, 10)
stroke(speedKnob, THEME.Accent, 1)

local speedToggle = createButton(
    speedCard,
    "Custom speed: OFF",
    UDim2.new(0, 170, 0, 30),
    UDim2.new(0, 18, 0, 122)
)

local speedReset = createButton(
    speedCard,
    "Reset",
    UDim2.new(0, 90, 0, 30),
    UDim2.new(1, -108, 0, 122)
)

--------------------------------------------------
-- AFK FARM
--------------------------------------------------

local afkCard = createCard(mainPage, "AFK FARM", 104, 182)

local afkDescription = createLabel(
    afkCard,
    "Move to the nearest unopened safe cell",
    UDim2.new(0, 250, 0, 18),
    UDim2.new(0, 18, 0, 40),
    10
)
afkDescription.TextColor3 = THEME.SecondaryText

local afkFarmButton = createButton(
    afkCard,
    "OFF",
    UDim2.new(0, 120, 0, 34),
    UDim2.new(1, -138, 0, 34)
)

--------------------------------------------------
-- WORK RADIUS
--------------------------------------------------

local radiusCard = createCard(mainPage, "WORK RADIUS", 112, 298)

local radiusValue = createLabel(
    radiusCard,
    "7 × 7",
    UDim2.new(0, 92, 0, 26),
    UDim2.new(0, 18, 0, 47),
    14
)
radiusValue.Font = Enum.Font.GothamBold

local radiusHint = createLabel(
    radiusCard,
    "Area",
    UDim2.new(0, 92, 0, 16),
    UDim2.new(0, 18, 0, 68),
    9
)
radiusHint.TextColor3 = THEME.MutedText

local radiusSlider = Instance.new("Frame")
radiusSlider.Size = UDim2.new(1, -150, 0, 8)
radiusSlider.Position = UDim2.new(0, 118, 0, 55)
radiusSlider.BackgroundColor3 = THEME.Surface3
radiusSlider.BorderSizePixel = 0
radiusSlider.Active = true
radiusSlider.Parent = radiusCard
round(radiusSlider, 8)

local radiusFill = Instance.new("Frame")
radiusFill.Size = UDim2.new(0, 0, 1, 0)
radiusFill.BackgroundColor3 = THEME.Accent
radiusFill.BorderSizePixel = 0
radiusFill.Parent = radiusSlider
round(radiusFill, 8)

local radiusKnob = Instance.new("Frame")
radiusKnob.Size = UDim2.new(0, 16, 0, 16)
radiusKnob.AnchorPoint = Vector2.new(0.5, 0.5)
radiusKnob.Position = UDim2.new(0, 0, 0.5, 0)
radiusKnob.BackgroundColor3 = Color3.fromRGB(248, 249, 251)
radiusKnob.BorderSizePixel = 0
radiusKnob.Active = true
radiusKnob.Parent = radiusSlider
round(radiusKnob, 9)

--------------------------------------------------
-- SAFETY
--------------------------------------------------

local safetyCard = createCard(mainPage, "SAFETY", 208, 422)

local mineProtectionButton = createButton(
    safetyCard,
    "OFF",
    UDim2.new(0, 108, 0, 30),
    UDim2.new(1, -126, 0, 38)
)

local mineProtectionLabel = createLabel(
    safetyCard,
    "Mine protection",
    UDim2.new(0, 170, 0, 20),
    UDim2.new(0, 18, 0, 43),
    12
)
mineProtectionLabel.Font = Enum.Font.GothamBold

local wrongFlagsButton = createButton(
    safetyCard,
    "OFF",
    UDim2.new(0, 108, 0, 30),
    UDim2.new(1, -126, 0, 82)
)

local wrongFlagsLabel = createLabel(
    safetyCard,
    "Remove wrong flags",
    UDim2.new(0, 190, 0, 20),
    UDim2.new(0, 18, 0, 87),
    12
)
wrongFlagsLabel.Font = Enum.Font.GothamBold

local protectionDistanceLabel = createLabel(
    safetyCard,
    "Distance",
    UDim2.new(0, 110, 0, 18),
    UDim2.new(0, 18, 0, 130),
    10
)
protectionDistanceLabel.TextColor3 = THEME.SecondaryText

local protectionDistanceValue = createLabel(
    safetyCard,
    "5.5",
    UDim2.new(0, 70, 0, 20),
    UDim2.new(1, -92, 0, 128),
    11
)
protectionDistanceValue.Font = Enum.Font.GothamBold
protectionDistanceValue.TextXAlignment = Enum.TextXAlignment.Right

local protectionDistanceSlider = Instance.new("Frame")
protectionDistanceSlider.Size = UDim2.new(1, -36, 0, 8)
protectionDistanceSlider.Position = UDim2.new(0, 18, 0, 158)
protectionDistanceSlider.BackgroundColor3 = THEME.Surface3
protectionDistanceSlider.BorderSizePixel = 0
protectionDistanceSlider.Active = true
protectionDistanceSlider.Parent = safetyCard
round(protectionDistanceSlider, 8)

local protectionDistanceFill = Instance.new("Frame")
protectionDistanceFill.Size = UDim2.new(0, 0, 1, 0)
protectionDistanceFill.BackgroundColor3 = THEME.Accent
protectionDistanceFill.BorderSizePixel = 0
protectionDistanceFill.Parent = protectionDistanceSlider
round(protectionDistanceFill, 8)

local protectionDistanceKnob = Instance.new("Frame")
protectionDistanceKnob.Size = UDim2.new(0, 16, 0, 16)
protectionDistanceKnob.AnchorPoint = Vector2.new(0.5, 0.5)
protectionDistanceKnob.Position = UDim2.new(0, 0, 0.5, 0)
protectionDistanceKnob.BackgroundColor3 = Color3.fromRGB(248, 249, 251)
protectionDistanceKnob.BorderSizePixel = 0
protectionDistanceKnob.Active = true
protectionDistanceKnob.Parent = protectionDistanceSlider
round(protectionDistanceKnob, 9)

local flagLightsPage = Instance.new("Frame")
flagLightsPage.Size = UDim2.new(1, -8, 0, 700)
flagLightsPage.BackgroundTransparency = 1
flagLightsPage.Visible = false
flagLightsPage.Parent = content

local flagLightsCard = createCard(flagLightsPage, "FLAG LIGHTS", 300, 0)
local lightsToggle = createButton(flagLightsCard, "Enabled: NO", UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 42))
local lightsKeyLabel = createLabel(flagLightsCard, "Toggle key: F", UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 0, 82), 12)
lightsKeyLabel.TextColor3 = THEME.SecondaryText
local mineColorButton = createButton(flagLightsCard, "Mine color", UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 116))
local flaggedMineColorButton = createButton(flagLightsCard, "Flagged mine color", UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 158))
local wrongFlagColorButton = createButton(flagLightsCard, "Wrong flag color", UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 200))

local autoFlagPage = Instance.new("Frame")
autoFlagPage.Size = UDim2.new(1, -8, 0, 700)
autoFlagPage.BackgroundTransparency = 1
autoFlagPage.Visible = false
autoFlagPage.Parent = content

local autoFlagCard = createCard(autoFlagPage, "AUTOFLAG", 280, 0)
local autoFlagToggle = createButton(autoFlagCard, "Enabled: OFF", UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 42))
local autoFlagSpeedLabel = createLabel(autoFlagCard, "Speed: 0.10s", UDim2.new(0, 150, 0, 25), UDim2.new(0, 12, 0, 90), 12)

local autoFlagSpeedSlider = Instance.new("Frame")
autoFlagSpeedSlider.Size = UDim2.new(0, 200, 0, 8)
autoFlagSpeedSlider.Position = UDim2.new(0, 180, 0, 98)
autoFlagSpeedSlider.BackgroundColor3 = THEME.Surface3
autoFlagSpeedSlider.BorderSizePixel = 0
autoFlagSpeedSlider.Active = true
autoFlagSpeedSlider.Parent = autoFlagCard
round(autoFlagSpeedSlider, 8)

local autoFlagSpeedFill = Instance.new("Frame")
autoFlagSpeedFill.Size = UDim2.new(0, 0, 1, 0)
autoFlagSpeedFill.BackgroundColor3 = THEME.Accent
autoFlagSpeedFill.BorderSizePixel = 0
autoFlagSpeedFill.Parent = autoFlagSpeedSlider
round(autoFlagSpeedFill, 8)

local autoFlagSpeedKnob = Instance.new("Frame")
autoFlagSpeedKnob.Size = UDim2.new(0, 16, 0, 16)
autoFlagSpeedKnob.AnchorPoint = Vector2.new(0.5, 0.5)
autoFlagSpeedKnob.Position = UDim2.new(0, 0, 0.5, 0)
autoFlagSpeedKnob.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
autoFlagSpeedKnob.BorderSizePixel = 0
autoFlagSpeedKnob.Active = true
autoFlagSpeedKnob.Parent = autoFlagSpeedSlider
round(autoFlagSpeedKnob, 9)

local smartDelayButton = createButton(autoFlagCard, "Smart delay: ON", UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 130))
local hardModeButton = createButton(autoFlagCard, "Hard mode: OFF", UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 172))

local macroPage = Instance.new("Frame")
macroPage.Size = UDim2.new(1, -8, 0, 700)
macroPage.BackgroundTransparency = 1
macroPage.Visible = false
macroPage.Parent = content

local macroCard = createCard(macroPage, "MACROS", 260, 0)
local macroInfo = createLabel(macroCard, "Click a button and press a key", UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 0, 40), 11)
macroInfo.TextColor3 = THEME.MutedText
local macroKeyButtons = {}
local macroActions = {"ToggleMenu", "ToggleAutoFlag", "ToggleFlagLights"}
local macroLabels = {"Main menu", "AutoFlag", "FlagLights"}
for i, action in ipairs(macroActions) do
    local keyButton = createButton(macroCard, macroLabels[i] .. ": " .. tostring(macroKeys[action]), UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 72 + (i - 1) * 44))
    macroKeyButtons[action] = keyButton
end

local function setToggle(buttonObject, enabled, prefix)
    buttonObject:SetAttribute("ToggleButton", true)
    buttonObject:SetAttribute("ToggleEnabled", enabled)

    local text = prefix or ""

    if buttonObject == afkFarmButton then
        buttonObject.Text = enabled and "ON" or "OFF"
    elseif buttonObject == mineProtectionButton then
        buttonObject.Text = enabled and "ON" or "OFF"
    elseif buttonObject == wrongFlagsButton then
        buttonObject.Text = enabled and "ON" or "OFF"
    else
        buttonObject.Text = text .. (enabled and "ON" or "OFF")
    end

    buttonObject.BackgroundColor3 = enabled and THEME.Green or THEME.Surface3
end

local function showTab(name)
    mainPage.Visible = name == "Main"
    flagLightsPage.Visible = name == "FlagLights"
    autoFlagPage.Visible = name == "AutoFlag"
    macroPage.Visible = name == "Macro"
    for tabName, tab in pairs(tabButtons) do
        tab.BackgroundColor3 = tabName == name and THEME.Accent or THEME.Surface3
    end
end

for name, tab in pairs(tabButtons) do
    tab.MouseButton1Click:Connect(function()
        showTab(name)
    end)
end
showTab("Main")

local dragging = false
local dragStart
local dragPosition
header.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    dragging = true
    dragStart = input.Position
    dragPosition = mainFrame.Position
    local connection
    connection = input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false
            if connection then connection:Disconnect() end
        end
    end)
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(dragPosition.X.Scale, dragPosition.X.Offset + delta.X, dragPosition.Y.Scale, dragPosition.Y.Offset + delta.Y)
end)

local speedDragging = false
local function applyPlayerSpeed()
    if humanoid and humanoid.Parent then
        humanoid.WalkSpeed = PLAYER_SPEED
    end
end

local function updateSpeedVisual()
    local percent = (PLAYER_SPEED - MIN_PLAYER_SPEED) / (MAX_PLAYER_SPEED - MIN_PLAYER_SPEED)
    percent = math.clamp(percent, 0, 1)
    speedFill.Size = UDim2.new(percent, 0, 1, 0)
    speedKnob.Position = UDim2.new(percent, 0, 0.5, 0)
    speedValue.Text = tostring(math.round(PLAYER_SPEED))
end

local function setSpeedFromMouse(x)
    local startX = speedSlider.AbsolutePosition.X
    local width = speedSlider.AbsoluteSize.X
    if width <= 0 then return end
    local percent = math.clamp((x - startX) / width, 0, 1)
    PLAYER_SPEED = math.round(MIN_PLAYER_SPEED + percent * (MAX_PLAYER_SPEED - MIN_PLAYER_SPEED))
    PLAYER_SPEED_ENABLED = true
    applyPlayerSpeed()
    updateSpeedVisual()
    setToggle(speedToggle, true, "Custom speed: ")
end

speedSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        speedDragging = true
        setSpeedFromMouse(input.Position.X)
    end
end)
speedKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        speedDragging = true
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if speedDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        setSpeedFromMouse(input.Position.X)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        speedDragging = false
    end
end)

speedToggle.MouseButton1Click:Connect(function()
    PLAYER_SPEED_ENABLED = not PLAYER_SPEED_ENABLED
    if PLAYER_SPEED_ENABLED then
        applyPlayerSpeed()
        setToggle(speedToggle, true, "Custom speed: ")
        notify("Player speed enabled: " .. tostring(math.round(PLAYER_SPEED)))
    else
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = DEFAULT_WALK_SPEED
        end
        setToggle(speedToggle, false, "Custom speed: ")
        notify("Player speed reset")
    end
end)

speedReset.MouseButton1Click:Connect(function()
    PLAYER_SPEED = DEFAULT_WALK_SPEED
    PLAYER_SPEED_ENABLED = false
    if humanoid and humanoid.Parent then humanoid.WalkSpeed = DEFAULT_WALK_SPEED end
    updateSpeedVisual()
    setToggle(speedToggle, false, "Custom speed: ")
    notify("Speed reset to " .. tostring(math.round(DEFAULT_WALK_SPEED)))
end)

local radiusDragging = false
local function updateRadiusVisual()
    local percent = (WORK_RADIUS - 1) / 19
    radiusFill.Size = UDim2.new(percent, 0, 1, 0)
    radiusKnob.Position = UDim2.new(percent, 0, 0.5, 0)
    radiusValue.Text = string.format("%d × %d", WORK_RADIUS * 2 + 1, WORK_RADIUS * 2 + 1)
end
local function setRadiusFromMouse(x)
    local startX = radiusSlider.AbsolutePosition.X
    local width = radiusSlider.AbsoluteSize.X
    if width <= 0 then return end
    local percent = math.clamp((x - startX) / width, 0, 1)
    WORK_RADIUS = math.round(1 + percent * 19)
    updateRadiusVisual()
end
radiusSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then radiusDragging = true; setRadiusFromMouse(input.Position.X) end
end)
radiusKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then radiusDragging = true end
end)
UserInputService.InputChanged:Connect(function(input)
    if radiusDragging and input.UserInputType == Enum.UserInputType.MouseMovement then setRadiusFromMouse(input.Position.X) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then radiusDragging = false end
end)

local protectionDistanceDragging = false
local function updateProtectionDistanceVisual()
    local percent = (MINE_PROTECTION_DISTANCE - 3) / 7
    protectionDistanceFill.Size = UDim2.new(percent, 0, 1, 0)
    protectionDistanceKnob.Position = UDim2.new(percent, 0, 0.5, 0)
    protectionDistanceValue.Text = string.format("%.1f", MINE_PROTECTION_DISTANCE)
end
local function setProtectionDistanceFromMouse(x)
    local startX = protectionDistanceSlider.AbsolutePosition.X
    local width = protectionDistanceSlider.AbsoluteSize.X
    if width <= 0 then return end
    local percent = math.clamp((x - startX) / width, 0, 1)
    MINE_PROTECTION_DISTANCE = 3 + percent * 7
    updateProtectionDistanceVisual()
end
protectionDistanceSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then protectionDistanceDragging = true; setProtectionDistanceFromMouse(input.Position.X) end
end)
protectionDistanceKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then protectionDistanceDragging = true end
end)
UserInputService.InputChanged:Connect(function(input)
    if protectionDistanceDragging and input.UserInputType == Enum.UserInputType.MouseMovement then setProtectionDistanceFromMouse(input.Position.X) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then protectionDistanceDragging = false end
end)

local autoFlagSpeedDragging = false
local function updateAutoFlagSpeedVisual()
    local percent = (AUTOFLAG_SPEED - 0.05) / 0.95
    autoFlagSpeedFill.Size = UDim2.new(percent, 0, 1, 0)
    autoFlagSpeedKnob.Position = UDim2.new(percent, 0, 0.5, 0)
    autoFlagSpeedLabel.Text = string.format("Speed: %.2fs", AUTOFLAG_SPEED)
end
local function setAutoFlagSpeedFromMouse(x)
    local startX = autoFlagSpeedSlider.AbsolutePosition.X
    local width = autoFlagSpeedSlider.AbsoluteSize.X
    if width <= 0 then return end
    local percent = math.clamp((x - startX) / width, 0, 1)
    AUTOFLAG_SPEED = 0.05 + percent * 0.95
    updateAutoFlagSpeedVisual()
end

autoFlagSpeedSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then autoFlagSpeedDragging = true; setAutoFlagSpeedFromMouse(input.Position.X) end
end)
autoFlagSpeedKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then autoFlagSpeedDragging = true end
end)
UserInputService.InputChanged:Connect(function(input)
    if autoFlagSpeedDragging and input.UserInputType == Enum.UserInputType.MouseMovement then setAutoFlagSpeedFromMouse(input.Position.X) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then autoFlagSpeedDragging = false end
end)

local remotesFolder = ReplicatedStorage:FindFirstChild("remotes")
local flagRemote = remotesFolder and remotesFolder:FindFirstChild("flag")

local function attemptFlag(tile)
    if not flagRemote or not tile then return false end
    local success = pcall(function()
        flagRemote:FireServer(tile, true)
    end)
    if success then
        task.wait(0.15)
        return tile:GetAttribute("flagged") == true
    end
    return false
end

local function attemptFlagFast(tile)
    if not flagRemote or not tile then return false end
    local success = pcall(function()
        flagRemote:FireServer(tile, true)
    end)
    if not success then return false end

    task.wait(0.03)
    return tile:GetAttribute("flagged") == true
end

local function attemptUnflag(tile)
    if not flagRemote or not tile then return false end
    local success = pcall(function() flagRemote:FireServer(tile, false) end)
    if success then
        task.wait(0.15)
        return tile:GetAttribute("flagged") ~= true
    end
    return false
end

local function runMineProtection()
    if not BLOCK_MINES_ENABLED or not root or not tilesFolder then return end
    local playerPos = root.Position
    for _, tile in ipairs(tilesFolder:GetChildren()) do
        if tile:IsA("BasePart") and tile:GetAttribute("mine") == true then
            local dx = playerPos.X - tile.Position.X
            local dz = playerPos.Z - tile.Position.Z
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist <= MINE_PROTECTION_DISTANCE then
                local lastTime = lastFlagAttemptTimes[tile]
                local now = os.clock()
                if not lastTime or (now - lastTime) > 3 then
                    if tile:GetAttribute("flagged") ~= true then
                        if attemptFlag(tile) then notify("Flag placed on nearby mine") end
                        lastFlagAttemptTimes[tile] = now
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while not destroyed and gui.Parent do
        if BLOCK_MINES_ENABLED then runMineProtection() end
        task.wait(0.2)
    end
end)

mineProtectionButton.MouseButton1Click:Connect(function()
    BLOCK_MINES_ENABLED = not BLOCK_MINES_ENABLED
    setToggle(mineProtectionButton, BLOCK_MINES_ENABLED, "Mine protection: ")
    notify(BLOCK_MINES_ENABLED and "Mine protection enabled" or "Mine protection disabled")
end)

local function isWrongFlag(tile)
    local attributes = tile:GetAttributes()
    return attributes.flagged == true and attributes.mine ~= true
end
local function removeWrongFlags()
    if not REMOVE_WRONG_FLAGS or not tilesFolder then return end
    for _, tile in ipairs(tilesFolder:GetChildren()) do
        if tile:IsA("BasePart") and isWrongFlag(tile) then
            if attemptUnflag(tile) then task.wait(REMOVE_WRONG_FLAGS_SPEED) end
        end
    end
end
wrongFlagsButton.MouseButton1Click:Connect(function()
    REMOVE_WRONG_FLAGS = not REMOVE_WRONG_FLAGS
    setToggle(wrongFlagsButton, REMOVE_WRONG_FLAGS, "Remove wrong flags: ")
    notify(REMOVE_WRONG_FLAGS and "Wrong flag removal enabled" or "Wrong flag removal disabled")
end)

local function clearMineHighlights()
    for _, hl in pairs(mineHighlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    table.clear(mineHighlights)
end
local function createTopHighlight(tile, color)
    local highlight = Instance.new("Part")
    highlight.Name = "TopHighlight"
    highlight.Size = Vector3.new(tile.Size.X, 0.1, tile.Size.Z)
    highlight.Position = tile.Position + Vector3.new(0, tile.Size.Y / 2 + 0.05, 0)
    highlight.Anchored = true
    highlight.CanCollide = false
    highlight.CanQuery = false
    highlight.CanTouch = false
    highlight.CastShadow = false
    highlight.Transparency = 0.4
    highlight.Color = color
    highlight.Material = Enum.Material.SmoothPlastic
    highlight.Parent = workspace
    table.insert(mineHighlights, highlight)
end
local function updateFlagLights()
    clearMineHighlights()
    if not FLAG_LIGHTS_ENABLED or not root or not tilesFolder then return end
    local position = root.Position
    local side = WORK_RADIUS * 5
    for _, tile in ipairs(tilesFolder:GetChildren()) do
        if tile:IsA("BasePart") then
            local attributes = tile:GetAttributes()
            local dx = tile.Position.X - position.X
            local dz = tile.Position.Z - position.Z
            if math.abs(dx) <= side and math.abs(dz) <= side then
                local isMine = attributes.mine == true
                local isFlagged = attributes.flagged == true
                if isMine and isFlagged then
                    createTopHighlight(tile, FLAGGED_MINE_COLOR)
                elseif isMine then
                    createTopHighlight(tile, MINE_COLOR)
                elseif isFlagged then
                    createTopHighlight(tile, WRONG_FLAG_COLOR)
                end
            end
        end
    end
end
lightsToggle.MouseButton1Click:Connect(function()
    FLAG_LIGHTS_ENABLED = not FLAG_LIGHTS_ENABLED
    setToggle(lightsToggle, FLAG_LIGHTS_ENABLED, "Enabled: ")
    updateFlagLights()
    notify(FLAG_LIGHTS_ENABLED and "Flag lights enabled" or "Flag lights disabled")
end)
local function updateLightsKeyLabel()
    lightsKeyLabel.Text = "Toggle key: " .. tostring(macroKeys.ToggleFlagLights)
end

local function cycleColor(current)
    local palette = {
        Color3.fromRGB(255, 75, 75),
        Color3.fromRGB(255, 70, 70),
        Color3.fromRGB(255, 210, 60),
        Color3.fromRGB(150, 70, 255),
        Color3.fromRGB(70, 150, 255),
    }
    for i, c in ipairs(palette) do
        if c == current then return palette[i % #palette + 1] end
    end
    return palette[1]
end
mineColorButton.MouseButton1Click:Connect(function()
    MINE_COLOR = cycleColor(MINE_COLOR)
    mineColorButton.BackgroundColor3 = MINE_COLOR
    updateFlagLights()
end)
flaggedMineColorButton.MouseButton1Click:Connect(function()
    FLAGGED_MINE_COLOR = cycleColor(FLAGGED_MINE_COLOR)
    flaggedMineColorButton.BackgroundColor3 = FLAGGED_MINE_COLOR
    updateFlagLights()
end)
wrongFlagColorButton.MouseButton1Click:Connect(function()
    WRONG_FLAG_COLOR = cycleColor(WRONG_FLAG_COLOR)
    wrongFlagColorButton.BackgroundColor3 = WRONG_FLAG_COLOR
    updateFlagLights()
end)
mineColorButton.BackgroundColor3 = MINE_COLOR
flaggedMineColorButton.BackgroundColor3 = FLAGGED_MINE_COLOR
wrongFlagColorButton.BackgroundColor3 = WRONG_FLAG_COLOR

local function rebuildMineCache()
    if not tilesFolder then return end

    table.clear(mineCache)

    for _, tile in ipairs(tilesFolder:GetChildren()) do
        if tile:IsA("BasePart") and tile:GetAttribute("mine") == true then
            mineCache[#mineCache + 1] = tile
        end
    end

    mineCacheDirty = false
end

local function buildMaps()
    if not tilesFolder then return end

    tileMap = {}
    neighborMap = {}
    local allTiles = {}

    for _, tile in ipairs(tilesFolder:GetChildren()) do
        if tile:IsA("BasePart") then
            local key = tile.Position.X .. ":" .. tile.Position.Z
            tileMap[key] = tile
            allTiles[#allTiles + 1] = tile
        end
    end

    local offsets = {
        Vector3.new(5,0,0), Vector3.new(-5,0,0), Vector3.new(0,0,5), Vector3.new(0,0,-5),
        Vector3.new(5,0,5), Vector3.new(5,0,-5), Vector3.new(-5,0,5), Vector3.new(-5,0,-5),
    }

    for _, tile in ipairs(allTiles) do
        local neighbors = {}

        for _, off in ipairs(offsets) do
            local key = (tile.Position.X + off.X) .. ":" .. (tile.Position.Z + off.Z)
            local neighbor = tileMap[key]
            if neighbor then
                neighbors[#neighbors + 1] = neighbor
            end
        end

        neighborMap[tile] = neighbors
    end

    mapBuilt = true
end

if tilesFolder then
    tilesFolder.ChildAdded:Connect(function(tile)
        mapBuilt = false
        mineCacheDirty = true

        if tile:IsA("BasePart") then
            tile:GetAttributeChangedSignal("mine"):Connect(function()
                mineCacheDirty = true
            end)
        end
    end)

    tilesFolder.ChildRemoved:Connect(function()
        mapBuilt = false
        mineCacheDirty = true
    end)

    for _, tile in ipairs(tilesFolder:GetChildren()) do
        if tile:IsA("BasePart") then
            tile:GetAttributeChangedSignal("mine"):Connect(function()
                mineCacheDirty = true
            end)
        end
    end
end
local function getCachedNeighbors(tile) return neighborMap[tile] or {} end

local function autoFlagStep()
    if not AUTOFLAG_ENABLED or not root or not tilesFolder then return false end

    local flagsPlaced = 0

    if AUTOFLAG_HARD_MODE then
        if mineCacheDirty then
            rebuildMineCache()
        end

        local playerPos = root.Position
        local side = WORK_RADIUS * 5
        local bestTile = nil
        local bestDistanceSq = math.huge

        for i = 1, #mineCache do
            local tile = mineCache[i]

            if tile.Parent and tile:GetAttribute("mine") == true and tile:GetAttribute("flagged") ~= true then
                local dx = tile.Position.X - playerPos.X
                local dz = tile.Position.Z - playerPos.Z

                if math.abs(dx) <= side and math.abs(dz) <= side then
                    local distanceSq = dx * dx + dz * dz
                    if distanceSq < bestDistanceSq then
                        bestDistanceSq = distanceSq
                        bestTile = tile
                    end
                end
            end
        end

        if bestTile and attemptFlagFast(bestTile) then
            flagsPlaced = 1
        end

        return flagsPlaced > 0
    end

    if not mapBuilt then buildMaps() end
    local tiles = tilesFolder:GetChildren()

    if not AUTOFLAG_HARD_MODE then
        for _, tile in ipairs(tiles) do
            if tile:IsA("BasePart") then
                local attrs = tile:GetAttributes()
                if attrs.cleared == true then
                    local minesNumber = tonumber(attrs.mines) or 0
                    if minesNumber > 0 then
                        local neighbors = getCachedNeighbors(tile)
                        local closedNeighbors = {}
                        local flaggedCount = 0
                        for _, neighbor in ipairs(neighbors) do
                            local nattrs = neighbor:GetAttributes()
                            if nattrs.flagged == true then
                                flaggedCount += 1
                            elseif nattrs.cleared ~= true then
                                table.insert(closedNeighbors, neighbor)
                            end
                        end
                        local remaining = minesNumber - flaggedCount
                        if remaining > 0 and #closedNeighbors == remaining then
                            for _, closedNeighbor in ipairs(closedNeighbors) do
                                if attemptFlag(closedNeighbor) then
                                    flagsPlaced += 1
                                    task.wait(AUTOFLAG_SPEED + (AUTOFLAG_SMART_DELAY and 0.05 or 0))
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if flagsPlaced > 0 then break end
        end
    end
    return flagsPlaced > 0
end

local autoFlagLoopRunning = false
local function autoFlagLoop()
    if autoFlagLoopRunning then return end
    autoFlagLoopRunning = true
    local lastRebuild = 0
    while AUTOFLAG_ENABLED and not destroyed do
        if AUTOFLAG_HARD_MODE then
            if mineCacheDirty then
                rebuildMineCache()
            end
        else
            if not mapBuilt or os.clock() - lastRebuild > 3 then
                buildMaps()
                lastRebuild = os.clock()
            end
        end

        local placed = autoFlagStep()

        if placed then
            task.wait(math.max(0.02, AUTOFLAG_SPEED))
        else
            task.wait(math.min(0.08, math.max(0.02, AUTOFLAG_SPEED)))
        end
    end
    autoFlagLoopRunning = false
end
local function toggleAutoFlag()
    AUTOFLAG_ENABLED = not AUTOFLAG_ENABLED
    setToggle(autoFlagToggle, AUTOFLAG_ENABLED, "Enabled: ")
    if AUTOFLAG_ENABLED then task.spawn(autoFlagLoop); notify("AutoFlag enabled") else notify("AutoFlag disabled") end
end
autoFlagToggle.MouseButton1Click:Connect(toggleAutoFlag)
smartDelayButton.MouseButton1Click:Connect(function()
    AUTOFLAG_SMART_DELAY = not AUTOFLAG_SMART_DELAY
    setToggle(smartDelayButton, AUTOFLAG_SMART_DELAY, "Smart delay: ")
end)
hardModeButton.MouseButton1Click:Connect(function()
    AUTOFLAG_HARD_MODE = not AUTOFLAG_HARD_MODE
    setToggle(hardModeButton, AUTOFLAG_HARD_MODE, "Hard mode: ")
    notify(AUTOFLAG_HARD_MODE and "Hard mode enabled" or "Hard mode disabled")
end)

local function isUsableUnopenedTile(tile)
    if not tile or not tile:IsA("BasePart") then
        return false
    end

    local attributes = tile:GetAttributes()

    if attributes.cleared == true then
        return false
    end

    if attributes.flagged == true then
        return false
    end

    if attributes.mine == true then
        return false
    end

    return true
end


local function getNearestUnopenedTile()
    if not root or not root.Parent or not tilesFolder then
        return nil
    end

    local nearestTile = nil
    local nearestDistanceSquared = math.huge
    local playerPosition = root.Position

    for _, tile in ipairs(tilesFolder:GetChildren()) do
        if isUsableUnopenedTile(tile) then
            local dx = tile.Position.X - playerPosition.X
            local dz = tile.Position.Z - playerPosition.Z
            local distanceSquared = dx * dx + dz * dz

            if distanceSquared < nearestDistanceSquared then
                nearestDistanceSquared = distanceSquared
                nearestTile = tile
            end
        end
    end

    return nearestTile
end


local function stopAFKMovement()
    if humanoid and humanoid.Parent then
        humanoid:Move(Vector3.zero, false)
        humanoid:MoveTo(root and root.Position or character:GetPivot().Position)
    end
end


local function moveDirectlyToTile(tile)
    if not tile or not tile.Parent then
        return false
    end

    if not humanoid or not humanoid.Parent then
        return false
    end

    if not root or not root.Parent then
        return false
    end

    if tile:GetAttribute("cleared") == true
        or tile:GetAttribute("flagged") == true
        or tile:GetAttribute("mine") == true
    then
        return false
    end

    local target = tile.Position
    local startTime = os.clock()

    humanoid:MoveTo(target)

    while AFK_FARM_ENABLED
        and not destroyed
        and humanoid.Parent
        and root.Parent
        and tile.Parent
    do
        if tile:GetAttribute("cleared") == true then
            stopAFKMovement()
            return true
        end

        if tile:GetAttribute("mine") == true
            or tile:GetAttribute("flagged") == true
        then
            stopAFKMovement()
            return false
        end

        local dx = root.Position.X - target.X
        local dz = root.Position.Z - target.Z
        local distanceSquared = dx * dx + dz * dz

        if distanceSquared <= AFK_FARM_REACH_DISTANCE * AFK_FARM_REACH_DISTANCE then
            stopAFKMovement()
            return true
        end

        if os.clock() - startTime >= AFK_FARM_MOVE_TIMEOUT then
            stopAFKMovement()
            return false
        end

        task.wait(0.05)
    end

    stopAFKMovement()
    return false
end


local function afkFarmLoop()
    if afkFarmRunning then
        return
    end

    afkFarmRunning = true

    while AFK_FARM_ENABLED and not destroyed do
        if not character
            or not character.Parent
            or not humanoid
            or not humanoid.Parent
            or not root
            or not root.Parent
        then
            task.wait(0.5)
            continue
        end

        local targetTile = getNearestUnopenedTile()

        if targetTile then
            moveDirectlyToTile(targetTile)
        else
            stopAFKMovement()
            task.wait(AFK_FARM_SCAN_DELAY)
        end

        task.wait(0.03)
    end

    stopAFKMovement()
    afkFarmRunning = false
end


local function toggleAFKFarm()
    AFK_FARM_ENABLED = not AFK_FARM_ENABLED
    setToggle(afkFarmButton, AFK_FARM_ENABLED, "AFK Farm: ")
    if AFK_FARM_ENABLED then
        task.spawn(afkFarmLoop)
        notify("AFK Farm enabled")
    else
        stopAFKMovement()
        notify("AFK Farm disabled")
    end
end
afkFarmButton.MouseButton1Click:Connect(toggleAFKFarm)

local function startKeyAssignment(action)
    assigningKeyFor = action
    notify("Press a key for " .. action)
    macroKeyButtons[action].Text = "Press key..."
end
for action, keyButton in pairs(macroKeyButtons) do
    keyButton.MouseButton1Click:Connect(function() startKeyAssignment(action) end)
end
UserInputService.InputBegan:Connect(function(input, processed)
    if assigningKeyFor then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local key = input.KeyCode
            if key ~= Enum.KeyCode.Unknown then
                macroKeys[assigningKeyFor] = key
                local labelText = assigningKeyFor == "ToggleMenu" and "Main menu" or assigningKeyFor == "ToggleAutoFlag" and "AutoFlag" or "FlagLights"
                macroKeyButtons[assigningKeyFor].Text = labelText .. ": " .. tostring(key)
                assigningKeyFor = nil
                updateLightsKeyLabel()
                notify("Key set to " .. tostring(key))
            end
        end
        return
    end
    if processed then return end
    if input.KeyCode == macroKeys.ToggleFlagLights then
        FLAG_LIGHTS_ENABLED = not FLAG_LIGHTS_ENABLED
        setToggle(lightsToggle, FLAG_LIGHTS_ENABLED, "Enabled: ")
        updateFlagLights()
    elseif input.KeyCode == macroKeys.ToggleAutoFlag then
        toggleAutoFlag()
    elseif input.KeyCode == macroKeys.ToggleMenu then
        minimized = not minimized
        mainFrame.Visible = not minimized
        if miniButton then miniButton.Visible = minimized end
    end
end)

normalPosition = mainFrame.Position
miniButton = Instance.new("TextButton")
miniButton.Name = "MiniButton"
miniButton.Size = UDim2.new(0, 62, 0, 62)
miniButton.AnchorPoint = Vector2.new(1, 1)
miniButton.Position = UDim2.new(1, -22, 1, -22)
miniButton.BackgroundColor3 = THEME.Accent
miniButton.BorderSizePixel = 0
miniButton.Text = "IM"
miniButton.TextColor3 = Color3.fromRGB(255, 255, 255)
miniButton.TextSize = 15
miniButton.Font = Enum.Font.GothamBold
miniButton.Visible = false
miniButton.Parent = gui
round(miniButton, 31)
stroke(miniButton, THEME.AccentHover, 1)

local miniDragging = false
local miniDragStart
local miniStartPosition
local miniClickSuppressed = false
miniButton.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    miniDragging = true
    miniClickSuppressed = false
    miniDragStart = input.Position
    miniStartPosition = miniButton.Position
    local connection
    connection = input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            miniDragging = false
            if connection then connection:Disconnect() end
        end
    end)
end)
UserInputService.InputChanged:Connect(function(input)
    if not miniDragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local delta = input.Position - miniDragStart
    if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then miniClickSuppressed = true end
    miniButton.Position = UDim2.new(miniStartPosition.X.Scale, miniStartPosition.X.Offset + delta.X, miniStartPosition.Y.Scale, miniStartPosition.Y.Offset + delta.Y)
end)
miniButton.MouseButton1Click:Connect(function()
    if miniClickSuppressed then miniClickSuppressed = false; return end
    minimized = false
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    normalPosition = mainFrame.Position
    mainFrame.Visible = true
    miniButton.Visible = false
end)
minimizeButton.MouseButton1Click:Connect(function()
    minimized = true
    normalPosition = mainFrame.Position
    mainFrame.Visible = false
    miniButton.Visible = true
end)

closeButton.MouseButton1Click:Connect(function()
    destroyed = true
    AUTOFLAG_ENABLED = false
    AFK_FARM_ENABLED = false
    clearMineHighlights()
    if humanoid and humanoid.Parent and not PLAYER_SPEED_ENABLED then humanoid.WalkSpeed = DEFAULT_WALK_SPEED end
    if gui then gui:Destroy() end
end)

setToggle(mineProtectionButton, false, "Mine protection: ")
setToggle(wrongFlagsButton, false, "Remove wrong flags: ")
setToggle(lightsToggle, false, "Enabled: ")
setToggle(autoFlagToggle, false, "Enabled: ")
setToggle(smartDelayButton, true, "Smart delay: ")
setToggle(hardModeButton, false, "Hard mode: ")
setToggle(speedToggle, PLAYER_SPEED_ENABLED, "Custom speed: ")
setToggle(afkFarmButton, false, "AFK Farm: ")

updateRadiusVisual()
updateAutoFlagSpeedVisual()
updateProtectionDistanceVisual()
updateLightsKeyLabel()
updateSpeedVisual()


task.spawn(function()
    while not destroyed and gui.Parent do
        updateFlagLights()
        if REMOVE_WRONG_FLAGS then removeWrongFlags() end
        task.wait(0.5)
    end
end)

notify("Minesweeper assistant loaded")

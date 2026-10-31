--[[
    MK AIM v2
    Port đầy đủ từ Exunys/Aimbot-V2 + ESP + Mini GUI tùy chỉnh phím
    Thuần Roblox API — paste vào LocalScript trong StarterCharacterScripts
    Bấm RightShift để mở/đóng GUI
]]

-- ═══════════════════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local StarterGui       = game:GetService("StarterGui")
local Workspace        = workspace

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════════════
--  SETTINGS (copy từ V2, thêm ESP)
-- ═══════════════════════════════════════════════════════════════

local Settings = {
    Enabled              = true,
    TeamCheck            = false,
    AliveCheck           = true,
    WallCheck            = false,
    Sensitivity          = 0,        -- 0 = instant, >0 = tween giây
    TriggerKey           = "MouseButton2",
    Toggle               = false,
    LockPart             = "Head",
}

local FOVSettings = {
    Enabled      = true,
    Visible      = true,
    Amount       = 120,
    Color        = Color3.fromRGB(255, 255, 255),
    LockedColor  = Color3.fromRGB(255, 70,  70),
    Transparency = 0.1,
}

local ESPSettings = {
    Enabled     = true,
    BoxColor    = Color3.fromRGB(255, 60, 60),
    NameColor   = Color3.fromRGB(255, 255, 255),
    TracerColor = Color3.fromRGB(255, 60, 60),
    ShowBox     = true,
    ShowName    = true,
    ShowTracer  = false,
    ShowHealth  = true,
    TeamCheck   = false,
}

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════

local Running          = false
local Locked           = nil
local Animation        = nil
local Typing           = false
local RequiredDistance = Settings.FOVSettings and FOVSettings.Amount or 2000
local ServiceConns     = {}
local Listening        = false   -- đang chờ nhận phím mới

-- ═══════════════════════════════════════════════════════════════
--  COLORS / UTIL
-- ═══════════════════════════════════════════════════════════════

local function Tween(obj, t, props, style)
    TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function CancelAnim()
    if Animation then pcall(function() Animation:Cancel() end) Animation = nil end
end

local function Notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "MK Aim v2", Text = msg, Duration = 3 })
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  GUI SETUP
-- ═══════════════════════════════════════════════════════════════

local SG = Instance.new("ScreenGui")
SG.Name           = "MKAimV2"
SG.ResetOnSpawn   = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = true
SG.Parent         = LocalPlayer.PlayerGui

-- ── FOV Circle ──────────────────────────────────────────────────
local FOVFrame = Instance.new("Frame")
FOVFrame.Name                   = "FOVCircle"
FOVFrame.AnchorPoint            = Vector2.new(0.5, 0.5)
FOVFrame.Size                   = UDim2.fromOffset(FOVSettings.Amount*2, FOVSettings.Amount*2)
FOVFrame.BackgroundTransparency = 1
FOVFrame.BorderSizePixel        = 0
FOVFrame.ZIndex                 = 900
FOVFrame.Visible                = FOVSettings.Enabled and FOVSettings.Visible
FOVFrame.Parent                 = SG
Instance.new("UICorner", FOVFrame).CornerRadius = UDim.new(1,0)
local FOVStroke = Instance.new("UIStroke", FOVFrame)
FOVStroke.Color       = FOVSettings.Color
FOVStroke.Thickness   = 1.5
FOVStroke.Transparency = FOVSettings.Transparency

-- ── Mini GUI ────────────────────────────────────────────────────
local C = {
    Bg     = Color3.fromRGB(15, 15, 20),
    Panel  = Color3.fromRGB(22, 22, 30),
    Accent = Color3.fromRGB(140, 60, 255),
    AccentLock = Color3.fromRGB(255, 60, 60),
    Text   = Color3.fromRGB(220, 220, 230),
    Sub    = Color3.fromRGB(130, 130, 150),
    Toggle = Color3.fromRGB(50, 200, 100),
    Off    = Color3.fromRGB(80, 80, 100),
}

local function Corner(p, r) local c=Instance.new("UICorner",p) c.CornerRadius=UDim.new(0,r or 6) end
local function Stroke(p, col, t) local s=Instance.new("UIStroke",p) s.Color=col s.Thickness=t or 1 return s end

local GUI = Instance.new("Frame")
GUI.Name                   = "MKAimMenu"
GUI.Size                   = UDim2.fromOffset(280, 370)
GUI.Position               = UDim2.new(0, 20, 0.5, -185)
GUI.BackgroundColor3       = C.Bg
GUI.BorderSizePixel        = 0
GUI.Visible                = false
GUI.ZIndex                 = 999
GUI.Active                 = true
GUI.Parent                 = SG
Corner(GUI, 10)
Stroke(GUI, C.Accent, 1.5)

-- drag
local dragging, dragStart, startPos
GUI.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = i.Position
        startPos  = GUI.Position
    end
end)
GUI.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseDelta then
        GUI.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + i.Position.X,
            startPos.Y.Scale, startPos.Y.Offset + i.Position.Y
        )
    end
end)

-- title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1,0,0,36)
TitleBar.BackgroundColor3 = C.Panel
TitleBar.BorderSizePixel  = 0
TitleBar.ZIndex           = 1000
TitleBar.Parent           = GUI
Corner(TitleBar, 10)

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size              = UDim2.new(1,-12,1,0)
TitleLbl.Position          = UDim2.fromOffset(12,0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text              = "⬡  MK AIM  v2"
TitleLbl.TextColor3        = C.Text
TitleLbl.Font              = Enum.Font.GothamBold
TitleLbl.TextSize          = 14
TitleLbl.TextXAlignment    = Enum.TextXAlignment.Left
TitleLbl.ZIndex            = 1001
TitleLbl.Parent            = TitleBar

local SubLbl = Instance.new("TextLabel")
SubLbl.Size              = UDim2.new(1,-12,1,0)
SubLbl.Position          = UDim2.fromOffset(0,0)
SubLbl.BackgroundTransparency = 1
SubLbl.Text              = "RightShift = mở/đóng"
SubLbl.TextColor3        = C.Sub
SubLbl.Font              = Enum.Font.Gotham
SubLbl.TextSize          = 11
SubLbl.TextXAlignment    = Enum.TextXAlignment.Right
SubLbl.ZIndex            = 1001
SubLbl.Parent            = TitleBar

-- scroll container
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size                    = UDim2.new(1,-8,1,-44)
Scroll.Position                = UDim2.fromOffset(4,40)
Scroll.BackgroundTransparency  = 1
Scroll.BorderSizePixel         = 0
Scroll.ScrollBarThickness      = 3
Scroll.ScrollBarImageColor3    = C.Accent
Scroll.CanvasSize              = UDim2.fromOffset(0,0)
Scroll.AutomaticCanvasSize     = Enum.AutomaticSize.Y
Scroll.ZIndex                  = 1000
Scroll.Parent                  = GUI

local List = Instance.new("UIListLayout", Scroll)
List.SortOrder    = Enum.SortOrder.LayoutOrder
List.Padding      = UDim.new(0,5)

local Pad = Instance.new("UIPadding", Scroll)
Pad.PaddingLeft   = UDim.new(0,6)
Pad.PaddingRight  = UDim.new(0,6)
Pad.PaddingTop    = UDim.new(0,4)

-- ── Row builders ────────────────────────────────────────────────

local function SectionLabel(text, order)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1,0,0,22)
    f.BackgroundTransparency = 1
    f.LayoutOrder      = order
    f.Parent           = Scroll
    local l = Instance.new("TextLabel",f)
    l.Size             = UDim2.fromScale(1,1)
    l.BackgroundTransparency = 1
    l.Text             = "— "..text.." —"
    l.TextColor3       = C.Accent
    l.Font             = Enum.Font.GothamBold
    l.TextSize         = 11
    l.TextXAlignment   = Enum.TextXAlignment.Left
    l.ZIndex           = 1001
end

local function ToggleRow(label, value, order, onChange)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,32)
    row.BackgroundColor3 = C.Panel
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.Parent           = Scroll
    Corner(row, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size             = UDim2.new(1,-52,1,0)
    lbl.Position         = UDim2.fromOffset(10,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = C.Text
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 13
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 1002

    local pill = Instance.new("Frame", row)
    pill.Size            = UDim2.fromOffset(38, 20)
    pill.Position        = UDim2.new(1,-46,0.5,-10)
    pill.BackgroundColor3 = value and C.Toggle or C.Off
    pill.BorderSizePixel = 0
    pill.ZIndex          = 1002
    Corner(pill, 10)

    local dot = Instance.new("Frame", pill)
    dot.Size             = UDim2.fromOffset(16,16)
    dot.Position         = value and UDim2.fromOffset(20,2) or UDim2.fromOffset(2,2)
    dot.BackgroundColor3 = Color3.fromRGB(255,255,255)
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 1003
    Corner(dot, 8)

    local state = value
    local btn = Instance.new("TextButton", row)
    btn.Size             = UDim2.fromScale(1,1)
    btn.BackgroundTransparency = 1
    btn.Text             = ""
    btn.ZIndex           = 1004
    btn.MouseButton1Click:Connect(function()
        state = not state
        Tween(pill, 0.15, { BackgroundColor3 = state and C.Toggle or C.Off })
        Tween(dot,  0.15, { Position = state and UDim2.fromOffset(20,2) or UDim2.fromOffset(2,2) })
        onChange(state)
    end)

    return row
end

local function SliderRow(label, val, min, max, order, onChange)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,46)
    row.BackgroundColor3 = C.Panel
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.Parent           = Scroll
    Corner(row, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size             = UDim2.new(1,-60,0,20)
    lbl.Position         = UDim2.fromOffset(10,4)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = C.Text
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 13
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 1002

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size          = UDim2.fromOffset(50,20)
    valLbl.Position      = UDim2.new(1,-58,0,4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text          = tostring(val)
    valLbl.TextColor3    = C.Accent
    valLbl.Font          = Enum.Font.GothamBold
    valLbl.TextSize      = 13
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.ZIndex        = 1002

    local track = Instance.new("Frame", row)
    track.Size           = UDim2.new(1,-20,0,6)
    track.Position       = UDim2.fromOffset(10,30)
    track.BackgroundColor3 = C.Off
    track.BorderSizePixel = 0
    track.ZIndex         = 1002
    Corner(track, 3)

    local fill = Instance.new("Frame", track)
    fill.Size            = UDim2.fromScale((val-min)/(max-min),1)
    fill.BackgroundColor3 = C.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex          = 1003
    Corner(fill, 3)

    local sliding = false
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then
            local abs   = track.AbsolutePosition
            local sz    = track.AbsoluteSize
            local pct   = math.clamp((i.Position.X - abs.X) / sz.X, 0, 1)
            local newV  = math.floor(min + (max-min)*pct)
            fill.Size   = UDim2.fromScale(pct, 1)
            valLbl.Text = tostring(newV)
            onChange(newV)
        end
    end)

    return row
end

local function KeybindRow(label, currentKey, order, onChange)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,32)
    row.BackgroundColor3 = C.Panel
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.Parent           = Scroll
    Corner(row, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size             = UDim2.new(1,-100,1,0)
    lbl.Position         = UDim2.fromOffset(10,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = C.Text
    lbl.Font             = Enum.Font.Gotham
    lbl.TextSize         = 13
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 1002

    local keyBtn = Instance.new("TextButton", row)
    keyBtn.Size          = UDim2.fromOffset(84,22)
    keyBtn.Position      = UDim2.new(1,-92,0.5,-11)
    keyBtn.BackgroundColor3 = C.Bg
    keyBtn.Text          = currentKey
    keyBtn.TextColor3    = C.Accent
    keyBtn.Font          = Enum.Font.GothamBold
    keyBtn.TextSize      = 12
    keyBtn.BorderSizePixel = 0
    keyBtn.ZIndex        = 1003
    Corner(keyBtn, 5)
    Stroke(keyBtn, C.Accent, 1)

    local listening = false

    keyBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        Listening = true
        keyBtn.Text      = "[ ... ]"
        keyBtn.TextColor3 = C.Sub

        local conn
        conn = UserInputService.InputBegan:Connect(function(i, gpe)
            if gpe then return end
            -- detect key or mouse button
            local keyName
            if i.UserInputType ~= Enum.UserInputType.None
                and i.UserInputType ~= Enum.UserInputType.Keyboard then
                keyName = i.UserInputType.Name
            elseif i.KeyCode ~= Enum.KeyCode.Unknown then
                keyName = i.KeyCode.Name
            end
            if not keyName then return end

            conn:Disconnect()
            listening = false
            Listening = false
            Settings.TriggerKey = keyName
            keyBtn.Text       = keyName
            keyBtn.TextColor3 = C.Accent
            onChange(keyName)
        end)
    end)

    return row
end

-- ═══════════════════════════════════════════════════════════════
--  BUILD GUI ROWS
-- ═══════════════════════════════════════════════════════════════

SectionLabel("AIMBOT", 1)

ToggleRow("Aimbot On/Off", Settings.Enabled, 2, function(v)
    Settings.Enabled = v
end)

ToggleRow("Team Check", Settings.TeamCheck, 3, function(v)
    Settings.TeamCheck = v
end)

ToggleRow("Alive Check", Settings.AliveCheck, 4, function(v)
    Settings.AliveCheck = v
end)

ToggleRow("Wall Check", Settings.WallCheck, 5, function(v)
    Settings.WallCheck = v
end)

ToggleRow("Toggle Mode", Settings.Toggle, 6, function(v)
    Settings.Toggle = v
end)

SliderRow("FOV Radius", FOVSettings.Amount, 30, 400, 7, function(v)
    FOVSettings.Amount = v
end)

SliderRow("Sensitivity (x10)", math.floor(Settings.Sensitivity*10), 0, 30, 8, function(v)
    Settings.Sensitivity = v / 10
end)

KeybindRow("Aim Key", Settings.TriggerKey, 9, function(v)
    Settings.TriggerKey = v
end)

SectionLabel("ESP", 10)

ToggleRow("ESP On/Off", ESPSettings.Enabled, 11, function(v)
    ESPSettings.Enabled = v
end)

ToggleRow("Box", ESPSettings.ShowBox, 12, function(v)
    ESPSettings.ShowBox = v
end)

ToggleRow("Name", ESPSettings.ShowName, 13, function(v)
    ESPSettings.ShowName = v
end)

ToggleRow("Tracer", ESPSettings.ShowTracer, 14, function(v)
    ESPSettings.ShowTracer = v
end)

ToggleRow("Health Bar", ESPSettings.ShowHealth, 15, function(v)
    ESPSettings.ShowHealth = v
end)

ToggleRow("Team Check (ESP)", ESPSettings.TeamCheck, 16, function(v)
    ESPSettings.TeamCheck = v
end)

SectionLabel("FOV CIRCLE", 17)

ToggleRow("FOV Visible", FOVSettings.Visible, 18, function(v)
    FOVSettings.Visible = v
end)

-- ═══════════════════════════════════════════════════════════════
--  ESP SYSTEM
-- ═══════════════════════════════════════════════════════════════

local ESPObjects = {}   -- [player] = { box, name, healthBg, healthFill, tracer }

local function NewESPLabel(text, size, color, parent)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text        = text
    l.TextColor3  = color
    l.TextStrokeTransparency = 0.6
    l.Font        = Enum.Font.GothamBold
    l.TextSize    = size
    l.ZIndex      = 850
    l.Parent      = parent
    return l
end

local function CreateESP(pl)
    if ESPObjects[pl] then return end
    local t = {}

    -- box
    t.box = Instance.new("Frame")
    t.box.BackgroundTransparency = 1
    t.box.BorderSizePixel        = 0
    t.box.ZIndex                 = 851
    t.box.Visible                = false
    t.box.Parent                 = SG
    Stroke(t.box, ESPSettings.BoxColor, 1.5)

    -- name
    t.name = NewESPLabel("", 12, ESPSettings.NameColor, SG)
    t.name.AnchorPoint = Vector2.new(0.5, 1)
    t.name.Size        = UDim2.fromOffset(160, 16)
    t.name.Visible     = false

    -- health bg
    t.hbg = Instance.new("Frame")
    t.hbg.BackgroundColor3  = Color3.fromRGB(30,30,30)
    t.hbg.BorderSizePixel   = 0
    t.hbg.ZIndex            = 852
    t.hbg.Visible           = false
    t.hbg.Parent            = SG

    -- health fill
    t.hfill = Instance.new("Frame")
    t.hfill.BackgroundColor3 = Color3.fromRGB(80,220,80)
    t.hfill.BorderSizePixel  = 0
    t.hfill.ZIndex           = 853
    t.hfill.Parent           = t.hbg

    -- tracer
    t.tracer = Instance.new("Frame")
    t.tracer.AnchorPoint           = Vector2.new(0, 0.5)
    t.tracer.BackgroundColor3      = ESPSettings.TracerColor
    t.tracer.BackgroundTransparency = 0.4
    t.tracer.BorderSizePixel       = 0
    t.tracer.Size                  = UDim2.fromOffset(0, 1.5)
    t.tracer.ZIndex                = 850
    t.tracer.Visible               = false
    t.tracer.Parent                = SG

    ESPObjects[pl] = t
end

local function RemoveESP(pl)
    local t = ESPObjects[pl]
    if not t then return end
    for _, v in pairs(t) do pcall(function() v:Destroy() end) end
    ESPObjects[pl] = nil
end

local function UpdateESP()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl == LocalPlayer then continue end

        local char = pl.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")

        if not ESPSettings.Enabled or not char or not hrp or not head or not hum
            or (ESPSettings.TeamCheck and pl.Team == LocalPlayer.Team)
        then
            local t = ESPObjects[pl]
            if t then
                for _, v in pairs(t) do pcall(function() v.Visible = false end) end
            end
            continue
        end

        CreateESP(pl)
        local t = ESPObjects[pl]

        -- world → screen corners
        local topPos    = head.Position + Vector3.new(0, 1.2, 0)
        local botPos    = hrp.Position  - Vector3.new(0, 3.2, 0)
        local topScreen, topOn  = Camera:WorldToViewportPoint(topPos)
        local botScreen, botOn  = Camera:WorldToViewportPoint(botPos)

        local visible = topOn or botOn

        -- box
        if ESPSettings.ShowBox and visible then
            local w = math.max(20, math.abs(topScreen.X - botScreen.X) * 1.4 + 20)
            local h = math.abs(topScreen.Y - botScreen.Y)
            local cx = (topScreen.X + botScreen.X) / 2
            local ty = math.min(topScreen.Y, botScreen.Y)
            t.box.Position = UDim2.fromOffset(cx - w/2, ty)
            t.box.Size     = UDim2.fromOffset(w, h)
            t.box.Visible  = true
        else
            t.box.Visible = false
        end

        -- name
        if ESPSettings.ShowName and visible then
            t.name.Text     = pl.DisplayName
            t.name.Position = UDim2.fromOffset(topScreen.X, topScreen.Y - 2)
            t.name.Visible  = true
        else
            t.name.Visible = false
        end

        -- health bar
        if ESPSettings.ShowHealth and visible then
            local hp     = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local w      = math.max(20, math.abs(topScreen.X - botScreen.X) * 1.4 + 20)
            local h      = math.abs(topScreen.Y - botScreen.Y)
            local cx     = (topScreen.X + botScreen.X) / 2
            local ty     = math.min(topScreen.Y, botScreen.Y)
            t.hbg.Position  = UDim2.fromOffset(cx - w/2 - 6, ty)
            t.hbg.Size      = UDim2.fromOffset(4, h)
            t.hfill.Size    = UDim2.fromScale(1, hp)
            t.hfill.Position = UDim2.fromScale(0, 1-hp)
            t.hfill.BackgroundColor3 = Color3.fromRGB(
                math.floor(255*(1-hp)), math.floor(200*hp), 0
            )
            t.hbg.Visible  = true
        else
            t.hbg.Visible = false
        end

        -- tracer
        if ESPSettings.ShowTracer and visible then
            local vp  = Camera.ViewportSize
            local fx, fy = vp.X/2, vp.Y
            local tx, ty2 = botScreen.X, botScreen.Y
            local dx  = tx - fx
            local dy  = ty2 - fy
            local len = math.sqrt(dx*dx + dy*dy)
            t.tracer.Position = UDim2.fromOffset(fx, fy)
            t.tracer.Size     = UDim2.fromOffset(len, 1.5)
            t.tracer.Rotation = math.deg(math.atan2(dy, dx))
            t.tracer.Visible  = true
        else
            t.tracer.Visible = false
        end
    end
end

-- cleanup khi player rời
Players.PlayerRemoving:Connect(function(pl)
    RemoveESP(pl)
end)

-- ═══════════════════════════════════════════════════════════════
--  AIMBOT CORE (copy logic V2)
-- ═══════════════════════════════════════════════════════════════

local function GetClosestPlayer()
    if not Locked then
        -- tìm target mới
        RequiredDistance = FOVSettings.Enabled and FOVSettings.Amount or 2000

        for _, v in next, Players:GetPlayers() do
            if v == LocalPlayer then continue end
            local char = v.Character
            if not char then continue end
            local part = char:FindFirstChild(Settings.LockPart)
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not part or not hum then continue end
            if Settings.TeamCheck and v.Team == LocalPlayer.Team then continue end
            if Settings.AliveCheck and hum.Health <= 0 then continue end
            if Settings.WallCheck and #Camera:GetPartsObscuringTarget({part.Position}, char:GetDescendants()) > 0 then continue end

            local vec, onScreen = Camera:WorldToViewportPoint(part.Position)
            if not onScreen then continue end
            local mouse = UserInputService:GetMouseLocation()
            local dist  = (Vector2.new(vec.X, vec.Y) - mouse).Magnitude

            if dist < RequiredDistance then
                RequiredDistance = dist
                Locked = v
            end
        end
    else
        -- cek target cũ còn trong FOV không
        local char = Locked.Character
        local part = char and char:FindFirstChild(Settings.LockPart)
        if not part then Locked = nil CancelAnim() FOVStroke.Color = FOVSettings.Color return end

        local vec = Camera:WorldToViewportPoint(part.Position)
        local mouse = UserInputService:GetMouseLocation()
        local dist = (Vector2.new(vec.X, vec.Y) - mouse).Magnitude

        if dist > (FOVSettings.Enabled and FOVSettings.Amount or 2000) then
            Locked = nil
            CancelAnim()
            FOVStroke.Color = FOVSettings.Color
        end
    end
end

local function IsKey(input)
    local key = Settings.TriggerKey
    local ok1 = pcall(function()
        return input.KeyCode == Enum.KeyCode[key]
    end)
    local ok2 = pcall(function()
        return input.UserInputType == Enum.UserInputType[key]
    end)
    local match = false
    pcall(function() if input.KeyCode == Enum.KeyCode[key] then match = true end end)
    pcall(function() if input.UserInputType == Enum.UserInputType[key] then match = true end end)
    return match
end

-- ═══════════════════════════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════════════════════════

RunService:BindToRenderStep("MKAimV2", Enum.RenderPriority.Camera.Value + 1, function()
    -- FOV circle
    if FOVSettings.Enabled and FOVSettings.Visible then
        local m = UserInputService:GetMouseLocation()
        FOVFrame.Position = UDim2.fromOffset(m.X, m.Y)
        FOVFrame.Size     = UDim2.fromOffset(FOVSettings.Amount*2, FOVSettings.Amount*2)
        FOVStroke.Transparency = FOVSettings.Transparency
        FOVFrame.Visible  = true
    else
        FOVFrame.Visible = false
    end

    -- ESP
    UpdateESP()

    -- aim
    if Running and Settings.Enabled then
        GetClosestPlayer()

        if Locked then
            local char = Locked.Character
            local part = char and char:FindFirstChild(Settings.LockPart)
            if part then
                FOVStroke.Color = FOVSettings.LockedColor
                local goal = CFrame.new(Camera.CFrame.Position, part.Position)
                if Settings.Sensitivity > 0 then
                    CancelAnim()
                    Animation = TweenService:Create(
                        Camera,
                        TweenInfo.new(Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                        { CFrame = goal }
                    )
                    Animation:Play()
                else
                    Camera.CFrame = goal
                end
            end
        end
    end

    if not Running then
        FOVStroke.Color = FOVSettings.Color
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  INPUT
-- ═══════════════════════════════════════════════════════════════

UserInputService.TextBoxFocused:Connect(function()        Typing = true  end)
UserInputService.TextBoxFocusReleased:Connect(function()  Typing = false end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- toggle GUI
    if input.KeyCode == Enum.KeyCode.RightShift then
        GUI.Visible = not GUI.Visible
        return
    end

    if Typing or Listening then return end
    if not IsKey(input) then return end

    if Settings.Toggle then
        Running = not Running
        if not Running then
            Locked = nil
            CancelAnim()
            FOVStroke.Color = FOVSettings.Color
        end
    else
        Running = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if Typing or Listening or Settings.Toggle then return end
    if not IsKey(input) then return end
    Running = false
    Locked  = nil
    CancelAnim()
    FOVStroke.Color = FOVSettings.Color
end)

LocalPlayer.CharacterRemoving:Connect(function()
    Running = false
    Locked  = nil
    CancelAnim()
    FOVStroke.Color = FOVSettings.Color
end)

Notify("MK Aim v2 loaded — RightShift mở menu")
Notify("MK Yeu Em") 

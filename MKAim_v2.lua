--[[
    MK AIM v2 — FINAL (Synapse X compatible)
    Aimbot + ESP + Mini GUI + Anime Notify
    RightShift = mở/đóng menu
]]

-- ═══════════════════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local Workspace        = workspace

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════════════
--  SETTINGS
-- ═══════════════════════════════════════════════════════════════

local Settings = {
    Enabled     = true,
    TeamCheck   = false,
    AliveCheck  = true,
    WallCheck   = false,
    Sensitivity = 0,
    TriggerKey  = "MouseButton2",
    Toggle      = false,
    LockPart    = "Head",
}

local FOVSettings = {
    Enabled      = true,
    Visible      = true,
    Amount       = 120,
    Color        = Color3.fromRGB(255, 255, 255),
    LockedColor  = Color3.fromRGB(255, 70, 70),
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
local Listening        = false
local RequiredDistance = FOVSettings.Amount
local Alive            = true   -- flag để dừng tất cả loop khi script unload

-- ═══════════════════════════════════════════════════════════════
--  SCREEN GUI — Synapse safe
-- ═══════════════════════════════════════════════════════════════

-- cleanup cũ trước khi tạo mới
pcall(function()
    local old = CoreGui:FindFirstChild("MKAimV2")
    if old then old:Destroy() end
end)
pcall(function()
    local old = LocalPlayer.PlayerGui:FindFirstChild("MKAimV2")
    if old then old:Destroy() end
end)
task.wait() -- 1 frame để Roblox xử lý destroy

local SG = Instance.new("ScreenGui")
SG.Name            = "MKAimV2"
SG.ResetOnSpawn    = false
SG.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset  = true
SG.DisplayOrder    = 999

-- Synapse X: thử CoreGui trước, fallback PlayerGui
local ok = pcall(function() SG.Parent = CoreGui end)
if not ok or not SG.Parent then
    SG.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- notify sound
local NotifySfx = Instance.new("Sound")
NotifySfx.SoundId = "rbxassetid://6026984224"
NotifySfx.Volume  = 1
NotifySfx.Parent  = SG

-- ═══════════════════════════════════════════════════════════════
--  ANIME NOTIFY
-- ═══════════════════════════════════════════════════════════════

local NC = {
    Dark   = Color3.fromRGB(10, 8, 22),
    Purple = Color3.fromRGB(170, 70, 255),
    Pink   = Color3.fromRGB(255, 80, 200),
    Green  = Color3.fromRGB(90, 255, 170),
    White  = Color3.fromRGB(240, 235, 255),
}

local NotifyQueue = {}
local NotifyBusy  = false
local NotifyDead  = false

local function RainbowColor(t)
    return Color3.fromHSV(t % 1, 0.8, 1)
end

local function SpawnStar(parent, x, y)
    if not parent or not parent.Parent then return end
    local star = Instance.new("TextLabel")
    star.Size                  = UDim2.fromOffset(14, 14)
    star.Position              = UDim2.fromOffset(x, y)
    star.BackgroundTransparency = 1
    star.Text                  = "✦"
    star.TextColor3            = NC.Pink
    star.TextSize              = 14
    star.Font                  = Enum.Font.GothamBold
    star.ZIndex                = 1100
    star.TextTransparency      = 0
    star.Parent                = parent
    local dx = math.random(-40, 40)
    local dy = math.random(-40, 40)
    local mv = TweenService:Create(star,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.fromOffset(x+dx, y+dy), TextTransparency = 1 }
    )
    mv:Play()
    mv.Completed:Connect(function() pcall(function() star:Destroy() end) end)
end

local function BurstStars(frame)
    if not frame or not frame.Parent then return end
    local w = math.max(1, math.floor(frame.AbsoluteSize.X))
    local h = math.max(1, math.floor(frame.AbsoluteSize.Y))
    for _ = 1, 10 do
        task.spawn(SpawnStar, frame, math.random(0, w), math.random(0, h))
    end
end

local function GlowPulse(stroke)
    task.spawn(function()
        while stroke and stroke.Parent and not NotifyDead do
            pcall(function()
                TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {Transparency = 0.1}):Play()
            end)
            task.wait(0.8)
            pcall(function()
                TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {Transparency = 0.6}):Play()
            end)
            task.wait(0.8)
        end
    end)
end

local function CreateNotify(title, message)
    if NotifyDead or not SG or not SG.Parent then return end

    local Halo = Instance.new("Frame", SG)
    Halo.Size                   = UDim2.fromOffset(350, 140)
    Halo.Position               = UDim2.new(1, 380, 0, 30)
    Halo.BackgroundColor3       = NC.Purple
    Halo.BackgroundTransparency = 0.82
    Halo.BorderSizePixel        = 0
    Halo.ZIndex                 = 1050
    Instance.new("UICorner", Halo).CornerRadius = UDim.new(0, 16)

    local Frame = Instance.new("Frame", Halo)
    Frame.Size             = UDim2.fromOffset(334, 128)
    Frame.Position         = UDim2.fromOffset(8, 6)
    Frame.BackgroundColor3 = NC.Dark
    Frame.BorderSizePixel  = 0
    Frame.ZIndex           = 1051
    Frame.ClipsDescendants = true
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 12)

    local OuterStroke = Instance.new("UIStroke", Frame)
    OuterStroke.Color       = NC.Purple
    OuterStroke.Thickness   = 1.8
    OuterStroke.Transparency = 0.1

    -- gradient
    local Grad = Instance.new("Frame", Frame)
    Grad.Size                   = UDim2.fromScale(1, 0.4)
    Grad.BackgroundColor3       = NC.Purple
    Grad.BackgroundTransparency = 0.88
    Grad.BorderSizePixel        = 0
    Grad.ZIndex                 = 1052
    Instance.new("UICorner", Grad).CornerRadius = UDim.new(0, 12)
    local gg = Instance.new("UIGradient", Grad)
    gg.Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, NC.Purple), ColorSequenceKeypoint.new(1, NC.Pink) })
    gg.Rotation = 90

    -- accent bar
    local AccentBar = Instance.new("Frame", Frame)
    AccentBar.Size             = UDim2.fromOffset(3, 0)
    AccentBar.BackgroundColor3 = NC.Purple
    AccentBar.BorderSizePixel  = 0
    AccentBar.ZIndex           = 1053
    local ag = Instance.new("UIGradient", AccentBar)
    ag.Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0, NC.Purple), ColorSequenceKeypoint.new(1, NC.Pink) })
    ag.Rotation = 90

    -- icon circle
    local IconCircle = Instance.new("Frame", Frame)
    IconCircle.Size                   = UDim2.fromOffset(36, 36)
    IconCircle.Position               = UDim2.fromOffset(12, 10)
    IconCircle.BackgroundColor3       = NC.Purple
    IconCircle.BackgroundTransparency = 0.3
    IconCircle.BorderSizePixel        = 0
    IconCircle.ZIndex                 = 1054
    Instance.new("UICorner", IconCircle).CornerRadius = UDim.new(1, 0)
    local is2 = Instance.new("UIStroke", IconCircle)
    is2.Color = NC.Pink is2.Thickness = 1 is2.Transparency = 0.2

    local IconImg = Instance.new("ImageLabel", IconCircle)
    IconImg.Size                   = UDim2.fromOffset(28, 28)
    IconImg.Position               = UDim2.fromOffset(4, 4)
    IconImg.BackgroundTransparency = 1
    IconImg.Image                  = "rbxassetid://122052941282436"
    IconImg.ScaleType              = Enum.ScaleType.Fit
    IconImg.ZIndex                 = 1055

    -- title
    local TitleN = Instance.new("TextLabel", Frame)
    TitleN.Size             = UDim2.new(1,-70,0,20)
    TitleN.Position         = UDim2.fromOffset(56, 10)
    TitleN.BackgroundTransparency = 1
    TitleN.Text             = title
    TitleN.TextColor3       = NC.White
    TitleN.TextSize         = 14
    TitleN.Font             = Enum.Font.GothamBold
    TitleN.TextXAlignment   = Enum.TextXAlignment.Left
    TitleN.ZIndex           = 1054

    -- sub
    local SubN = Instance.new("TextLabel", Frame)
    SubN.Size             = UDim2.new(1,-70,0,14)
    SubN.Position         = UDim2.fromOffset(56, 30)
    SubN.BackgroundTransparency = 1
    SubN.Text             = "✦ MK AIM SYSTEM"
    SubN.TextColor3       = NC.Pink
    SubN.TextSize         = 10
    SubN.Font             = Enum.Font.GothamBold
    SubN.TextXAlignment   = Enum.TextXAlignment.Left
    SubN.ZIndex           = 1054

    -- divider
    local Div = Instance.new("Frame", Frame)
    Div.Size             = UDim2.new(1,-20,0,1)
    Div.Position         = UDim2.fromOffset(10, 52)
    Div.BackgroundColor3 = NC.Purple
    Div.BackgroundTransparency = 0.6
    Div.BorderSizePixel  = 0
    Div.ZIndex           = 1054

    -- terminal
    local Terminal = Instance.new("TextLabel", Frame)
    Terminal.Size             = UDim2.new(1,-28,0,38)
    Terminal.Position         = UDim2.fromOffset(14, 58)
    Terminal.BackgroundTransparency = 1
    Terminal.Text             = "> _"
    Terminal.TextColor3       = NC.Green
    Terminal.TextSize         = 13
    Terminal.Font             = Enum.Font.Code
    Terminal.TextWrapped      = true
    Terminal.TextXAlignment   = Enum.TextXAlignment.Left
    Terminal.TextYAlignment   = Enum.TextYAlignment.Top
    Terminal.ZIndex           = 1054

    -- progress bar
    local BarBG = Instance.new("Frame", Frame)
    BarBG.Size             = UDim2.new(1,-20,0,3)
    BarBG.Position         = UDim2.new(0,10,1,-8)
    BarBG.BackgroundColor3 = Color3.fromRGB(35,25,55)
    BarBG.BorderSizePixel  = 0
    BarBG.ZIndex           = 1054
    Instance.new("UICorner", BarBG).CornerRadius = UDim.new(1, 0)

    local Bar = Instance.new("Frame", BarBG)
    Bar.Size             = UDim2.fromScale(1,1)
    Bar.BackgroundColor3 = NC.Purple
    Bar.BorderSizePixel  = 0
    Bar.ZIndex           = 1055
    Instance.new("UICorner", Bar).CornerRadius = UDim.new(1, 0)
    local brg = Instance.new("UIGradient", Bar)
    brg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, NC.Purple), ColorSequenceKeypoint.new(1, NC.Pink) })

    -- slide in
    local slideIn = TweenService:Create(Halo,
        TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(1,-358,0,30) }
    )
    slideIn:Play()

    TweenService:Create(AccentBar,
        TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.fromOffset(3, 128) }
    ):Play()

    -- icon rainbow
    task.spawn(function()
        local t0 = tick()
        while IconCircle and IconCircle.Parent do
            if tick()-t0 > 1.5 then break end
            pcall(function()
                IconCircle.BackgroundColor3 = RainbowColor((tick()-t0)*0.5)
            end)
            task.wait()
        end
        pcall(function()
            if IconCircle and IconCircle.Parent then
                IconCircle.BackgroundColor3 = NC.Purple
            end
        end)
    end)

    slideIn.Completed:Wait()
    pcall(BurstStars, Frame)
    GlowPulse(OuterStroke)
    pcall(function() NotifySfx:Stop() NotifySfx.TimePosition=0 NotifySfx:Play() end)

    -- typing
    local msg = tostring(message)
    for i = 1, #msg do
        if NotifyDead or not Frame.Parent then return end
        pcall(function()
            Terminal.Text = "> " .. msg:sub(1,i) .. (i < #msg and "_" or "")
        end)
        task.wait(0.03)
    end

    -- bar drain
    task.spawn(function()
        local t0  = tick()
        local dur = 4
        while Bar and Bar.Parent and not NotifyDead do
            local e = tick()-t0
            if e >= dur then break end
            pcall(function() Bar.Size = UDim2.fromScale(1-(e/dur), 1) end)
            task.wait()
        end
    end)

    task.wait(4)

    if Halo and Halo.Parent then
        local exit = TweenService:Create(Halo,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(1,380,0,30) }
        )
        exit:Play()
        exit.Completed:Wait()
        pcall(function() Halo:Destroy() end)
    end
end

local function Notify(title, message)
    if NotifyDead then return end
    table.insert(NotifyQueue, { T = title or "MK AIM", M = message or "" })
    if NotifyBusy then return end
    NotifyBusy = true
    task.spawn(function()
        while #NotifyQueue > 0 and not NotifyDead do
            local d = table.remove(NotifyQueue, 1)
            pcall(CreateNotify, d.T, d.M)
        end
        NotifyBusy = false
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  GUI HELPERS
-- ═══════════════════════════════════════════════════════════════

local C = {
    Bg     = Color3.fromRGB(15, 15, 20),
    Panel  = Color3.fromRGB(22, 22, 30),
    Accent = Color3.fromRGB(140, 60, 255),
    Text   = Color3.fromRGB(220, 220, 230),
    Sub    = Color3.fromRGB(130, 130, 150),
    Toggle = Color3.fromRGB(50, 200, 100),
    Off    = Color3.fromRGB(80, 80, 100),
}

local function Corner(p, r)
    Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 6)
end

local function Stroke(p, col, t)
    local s = Instance.new("UIStroke", p)
    s.Color = col s.Thickness = t or 1
    return s
end

local function TW(obj, t, props)
    TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ═══════════════════════════════════════════════════════════════
--  MINI GUI
-- ═══════════════════════════════════════════════════════════════

local GUI = Instance.new("Frame", SG)
GUI.Name             = "MKAimMenu"
GUI.Size             = UDim2.fromOffset(280, 370)
GUI.Position         = UDim2.new(0, 20, 0.5, -185)
GUI.BackgroundColor3 = C.Bg
GUI.BorderSizePixel  = 0
GUI.Visible          = false
GUI.ZIndex           = 999
GUI.Active           = true
Corner(GUI, 10)
Stroke(GUI, C.Accent, 1.5)

-- drag
local dragging, dragStart, startPos
GUI.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true dragStart = i.Position startPos = GUI.Position
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
local TitleBar = Instance.new("Frame", GUI)
TitleBar.Size             = UDim2.new(1,0,0,36)
TitleBar.BackgroundColor3 = C.Panel
TitleBar.BorderSizePixel  = 0
TitleBar.ZIndex           = 1000
Corner(TitleBar, 10)

local TitleLbl = Instance.new("TextLabel", TitleBar)
TitleLbl.Size             = UDim2.new(1,-12,1,0)
TitleLbl.Position         = UDim2.fromOffset(12,0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text             = "⬡  MK AIM  v2"
TitleLbl.TextColor3       = C.Text
TitleLbl.Font             = Enum.Font.GothamBold
TitleLbl.TextSize         = 14
TitleLbl.TextXAlignment   = Enum.TextXAlignment.Left
TitleLbl.ZIndex           = 1001

local SubLbl = Instance.new("TextLabel", TitleBar)
SubLbl.Size             = UDim2.new(1,-12,1,0)
SubLbl.BackgroundTransparency = 1
SubLbl.Text             = "RightShift = mở/đóng"
SubLbl.TextColor3       = C.Sub
SubLbl.Font             = Enum.Font.Gotham
SubLbl.TextSize         = 11
SubLbl.TextXAlignment   = Enum.TextXAlignment.Right
SubLbl.ZIndex           = 1001

-- scroll
local Scroll = Instance.new("ScrollingFrame", GUI)
Scroll.Size                   = UDim2.new(1,-8,1,-44)
Scroll.Position               = UDim2.fromOffset(4,40)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel        = 0
Scroll.ScrollBarThickness     = 3
Scroll.ScrollBarImageColor3   = C.Accent
Scroll.CanvasSize             = UDim2.fromOffset(0,0)
Scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
Scroll.ZIndex                 = 1000

Instance.new("UIListLayout", Scroll).Padding = UDim.new(0,5)
local Pad = Instance.new("UIPadding", Scroll)
Pad.PaddingLeft  = UDim.new(0,6)
Pad.PaddingRight = UDim.new(0,6)
Pad.PaddingTop   = UDim.new(0,4)

-- row builders
local function SectionLabel(text, order)
    local f = Instance.new("Frame", Scroll)
    f.Size = UDim2.new(1,0,0,22) f.BackgroundTransparency=1 f.LayoutOrder=order
    local l = Instance.new("TextLabel", f)
    l.Size=UDim2.fromScale(1,1) l.BackgroundTransparency=1
    l.Text="— "..text.." —" l.TextColor3=C.Accent
    l.Font=Enum.Font.GothamBold l.TextSize=11
    l.TextXAlignment=Enum.TextXAlignment.Left l.ZIndex=1001
end

local function ToggleRow(label, value, order, onChange)
    local row = Instance.new("Frame", Scroll)
    row.Size=UDim2.new(1,0,0,32) row.BackgroundColor3=C.Panel
    row.BorderSizePixel=0 row.LayoutOrder=order
    Corner(row,6)
    local lbl = Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(1,-52,1,0) lbl.Position=UDim2.fromOffset(10,0)
    lbl.BackgroundTransparency=1 lbl.Text=label lbl.TextColor3=C.Text
    lbl.Font=Enum.Font.Gotham lbl.TextSize=13
    lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.ZIndex=1002
    local pill = Instance.new("Frame",row)
    pill.Size=UDim2.fromOffset(38,20) pill.Position=UDim2.new(1,-46,0.5,-10)
    pill.BackgroundColor3=value and C.Toggle or C.Off
    pill.BorderSizePixel=0 pill.ZIndex=1002
    Corner(pill,10)
    local dot = Instance.new("Frame",pill)
    dot.Size=UDim2.fromOffset(16,16)
    dot.Position=value and UDim2.fromOffset(20,2) or UDim2.fromOffset(2,2)
    dot.BackgroundColor3=Color3.fromRGB(255,255,255) dot.BorderSizePixel=0 dot.ZIndex=1003
    Corner(dot,8)
    local state=value
    local btn = Instance.new("TextButton",row)
    btn.Size=UDim2.fromScale(1,1) btn.BackgroundTransparency=1 btn.Text="" btn.ZIndex=1004
    btn.MouseButton1Click:Connect(function()
        state=not state
        TW(pill,0.15,{BackgroundColor3=state and C.Toggle or C.Off})
        TW(dot,0.15,{Position=state and UDim2.fromOffset(20,2) or UDim2.fromOffset(2,2)})
        onChange(state)
    end)
end

local function SliderRow(label, val, mn, mx, order, onChange)
    local row = Instance.new("Frame",Scroll)
    row.Size=UDim2.new(1,0,0,46) row.BackgroundColor3=C.Panel
    row.BorderSizePixel=0 row.LayoutOrder=order
    Corner(row,6)
    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(1,-60,0,20) lbl.Position=UDim2.fromOffset(10,4)
    lbl.BackgroundTransparency=1 lbl.Text=label lbl.TextColor3=C.Text
    lbl.Font=Enum.Font.Gotham lbl.TextSize=13
    lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.ZIndex=1002
    local valLbl=Instance.new("TextLabel",row)
    valLbl.Size=UDim2.fromOffset(50,20) valLbl.Position=UDim2.new(1,-58,0,4)
    valLbl.BackgroundTransparency=1 valLbl.Text=tostring(val) valLbl.TextColor3=C.Accent
    valLbl.Font=Enum.Font.GothamBold valLbl.TextSize=13
    valLbl.TextXAlignment=Enum.TextXAlignment.Right valLbl.ZIndex=1002
    local track=Instance.new("Frame",row)
    track.Size=UDim2.new(1,-20,0,6) track.Position=UDim2.fromOffset(10,30)
    track.BackgroundColor3=C.Off track.BorderSizePixel=0 track.ZIndex=1002
    Corner(track,3)
    local fill=Instance.new("Frame",track)
    fill.Size=UDim2.fromScale((val-mn)/(mx-mn),1)
    fill.BackgroundColor3=C.Accent fill.BorderSizePixel=0 fill.ZIndex=1003
    Corner(fill,3)
    local sliding=false
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=true end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not sliding or i.UserInputType~=Enum.UserInputType.MouseMovement then return end
        local abs=track.AbsolutePosition local sz=track.AbsoluteSize
        if sz.X <= 0 then return end
        local pct=math.clamp((i.Position.X-abs.X)/sz.X,0,1)
        local newV=math.floor(mn+(mx-mn)*pct)
        fill.Size=UDim2.fromScale(pct,1) valLbl.Text=tostring(newV)
        onChange(newV)
    end)
end

local function KeybindRow(label, currentKey, order, onChange)
    local row=Instance.new("Frame",Scroll)
    row.Size=UDim2.new(1,0,0,32) row.BackgroundColor3=C.Panel
    row.BorderSizePixel=0 row.LayoutOrder=order
    Corner(row,6)
    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(1,-100,1,0) lbl.Position=UDim2.fromOffset(10,0)
    lbl.BackgroundTransparency=1 lbl.Text=label lbl.TextColor3=C.Text
    lbl.Font=Enum.Font.Gotham lbl.TextSize=13
    lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.ZIndex=1002
    local keyBtn=Instance.new("TextButton",row)
    keyBtn.Size=UDim2.fromOffset(84,22) keyBtn.Position=UDim2.new(1,-92,0.5,-11)
    keyBtn.BackgroundColor3=C.Bg keyBtn.Text=currentKey keyBtn.TextColor3=C.Accent
    keyBtn.Font=Enum.Font.GothamBold keyBtn.TextSize=12
    keyBtn.BorderSizePixel=0 keyBtn.ZIndex=1003
    Corner(keyBtn,5) Stroke(keyBtn,C.Accent,1)
    local lstn=false
    keyBtn.MouseButton1Click:Connect(function()
        if lstn then return end
        lstn=true Listening=true
        keyBtn.Text="[ ... ]" keyBtn.TextColor3=C.Sub
        local conn
        conn=UserInputService.InputBegan:Connect(function(i,gpe)
            if gpe then return end
            local kn
            if i.UserInputType~=Enum.UserInputType.None and i.UserInputType~=Enum.UserInputType.Keyboard then
                kn=i.UserInputType.Name
            elseif i.KeyCode~=Enum.KeyCode.Unknown then
                kn=i.KeyCode.Name
            end
            if not kn then return end
            conn:Disconnect() lstn=false Listening=false
            Settings.TriggerKey=kn
            keyBtn.Text=kn keyBtn.TextColor3=C.Accent
            onChange(kn)
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  BUILD ROWS
-- ═══════════════════════════════════════════════════════════════

SectionLabel("AIMBOT", 1)
ToggleRow("Aimbot On/Off",   Settings.Enabled,     2,  function(v) Settings.Enabled=v end)
ToggleRow("Team Check",      Settings.TeamCheck,    3,  function(v) Settings.TeamCheck=v end)
ToggleRow("Alive Check",     Settings.AliveCheck,   4,  function(v) Settings.AliveCheck=v end)
ToggleRow("Wall Check",      Settings.WallCheck,    5,  function(v) Settings.WallCheck=v end)
ToggleRow("Toggle Mode",     Settings.Toggle,       6,  function(v) Settings.Toggle=v end)
SliderRow("FOV Radius",      FOVSettings.Amount,    30, 400, 7, function(v) FOVSettings.Amount=v end)
SliderRow("Sensitivity x10", math.floor(Settings.Sensitivity*10), 0, 30, 8, function(v) Settings.Sensitivity=v/10 end)
KeybindRow("Aim Key",        Settings.TriggerKey,   9,  function(v) Settings.TriggerKey=v end)

SectionLabel("ESP", 10)
ToggleRow("ESP On/Off",      ESPSettings.Enabled,   11, function(v) ESPSettings.Enabled=v end)
ToggleRow("Box",             ESPSettings.ShowBox,   12, function(v) ESPSettings.ShowBox=v end)
ToggleRow("Name",            ESPSettings.ShowName,  13, function(v) ESPSettings.ShowName=v end)
ToggleRow("Tracer",          ESPSettings.ShowTracer,14, function(v) ESPSettings.ShowTracer=v end)
ToggleRow("Health Bar",      ESPSettings.ShowHealth,15, function(v) ESPSettings.ShowHealth=v end)
ToggleRow("Team Check(ESP)", ESPSettings.TeamCheck, 16, function(v) ESPSettings.TeamCheck=v end)

SectionLabel("FOV CIRCLE", 17)
ToggleRow("FOV Visible", FOVSettings.Visible, 18, function(v) FOVSettings.Visible=v end)

-- ═══════════════════════════════════════════════════════════════
--  FOV CIRCLE
-- ═══════════════════════════════════════════════════════════════

local FOVFrame = Instance.new("Frame", SG)
FOVFrame.Name                   = "FOVCircle"
FOVFrame.AnchorPoint            = Vector2.new(0.5, 0.5)
FOVFrame.Size                   = UDim2.fromOffset(FOVSettings.Amount*2, FOVSettings.Amount*2)
FOVFrame.BackgroundTransparency = 1
FOVFrame.BorderSizePixel        = 0
FOVFrame.ZIndex                 = 900
FOVFrame.Visible                = false
Instance.new("UICorner", FOVFrame).CornerRadius = UDim.new(1, 0)
local FOVStroke = Instance.new("UIStroke", FOVFrame)
FOVStroke.Color        = FOVSettings.Color
FOVStroke.Thickness    = 1.5
FOVStroke.Transparency = FOVSettings.Transparency

-- ═══════════════════════════════════════════════════════════════
--  ESP
-- ═══════════════════════════════════════════════════════════════

local ESPObjects = {}

local function CreateESP(pl)
    if ESPObjects[pl] then return end
    local t = {}
    t.box = Instance.new("Frame", SG)
    t.box.BackgroundTransparency=1 t.box.BorderSizePixel=0 t.box.ZIndex=851 t.box.Visible=false
    Stroke(t.box, ESPSettings.BoxColor, 1.5)

    t.name = Instance.new("TextLabel", SG)
    t.name.BackgroundTransparency=1 t.name.Text=""
    t.name.TextColor3=ESPSettings.NameColor t.name.TextStrokeTransparency=0.6
    t.name.Font=Enum.Font.GothamBold t.name.TextSize=12 t.name.ZIndex=850
    t.name.AnchorPoint=Vector2.new(0.5,1) t.name.Size=UDim2.fromOffset(160,16) t.name.Visible=false

    t.hbg = Instance.new("Frame", SG)
    t.hbg.BackgroundColor3=Color3.fromRGB(30,30,30) t.hbg.BorderSizePixel=0 t.hbg.ZIndex=852 t.hbg.Visible=false

    t.hfill = Instance.new("Frame", t.hbg)
    t.hfill.BackgroundColor3=Color3.fromRGB(80,220,80) t.hfill.BorderSizePixel=0 t.hfill.ZIndex=853

    t.tracer = Instance.new("Frame", SG)
    t.tracer.AnchorPoint=Vector2.new(0,0.5) t.tracer.BackgroundColor3=ESPSettings.TracerColor
    t.tracer.BackgroundTransparency=0.4 t.tracer.BorderSizePixel=0
    t.tracer.Size=UDim2.fromOffset(0,1.5) t.tracer.ZIndex=850 t.tracer.Visible=false

    ESPObjects[pl] = t
end

local function RemoveESP(pl)
    local t = ESPObjects[pl]
    if not t then return end
    for _,v in pairs(t) do pcall(function() v:Destroy() end) end
    ESPObjects[pl] = nil
end

local function UpdateESP()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl == LocalPlayer then continue end
        local char = pl.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        local isDead = not hum or hum.Health<=0 or hum:GetState()==Enum.HumanoidStateType.Dead

        if not ESPSettings.Enabled or not char or not hrp or not head or isDead
            or (ESPSettings.TeamCheck and pl.Team==LocalPlayer.Team)
        then
            local t=ESPObjects[pl]
            if t then for _,v in pairs(t) do pcall(function() v.Visible=false end) end end
            continue
        end

        CreateESP(pl)
        local t = ESPObjects[pl]
        local topS, topOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,1.2,0))
        local botS, botOn = Camera:WorldToViewportPoint(hrp.Position  - Vector3.new(0,3.2,0))
        local vis = topOn or botOn

        if ESPSettings.ShowBox and vis then
            local w=math.max(20, math.abs(topS.X-botS.X)*1.4+20)
            local h=math.abs(topS.Y-botS.Y)
            local cx=(topS.X+botS.X)/2
            t.box.Position=UDim2.fromOffset(cx-w/2, math.min(topS.Y,botS.Y))
            t.box.Size=UDim2.fromOffset(w,h) t.box.Visible=true
        else t.box.Visible=false end

        if ESPSettings.ShowName and vis then
            t.name.Text=pl.DisplayName
            t.name.Position=UDim2.fromOffset(topS.X, topS.Y-2) t.name.Visible=true
        else t.name.Visible=false end

        if ESPSettings.ShowHealth and vis then
            local hp=math.clamp(hum.Health/hum.MaxHealth,0,1)
            local w=math.max(20, math.abs(topS.X-botS.X)*1.4+20)
            local h=math.abs(topS.Y-botS.Y)
            local cx=(topS.X+botS.X)/2
            t.hbg.Position=UDim2.fromOffset(cx-w/2-6, math.min(topS.Y,botS.Y))
            t.hbg.Size=UDim2.fromOffset(4,h)
            t.hfill.Size=UDim2.fromScale(1,hp) t.hfill.Position=UDim2.fromScale(0,1-hp)
            t.hfill.BackgroundColor3=Color3.fromRGB(math.floor(255*(1-hp)),math.floor(200*hp),0)
            t.hbg.Visible=true
        else t.hbg.Visible=false end

        if ESPSettings.ShowTracer and vis then
            local vp=Camera.ViewportSize
            local dx=botS.X-vp.X/2 local dy=botS.Y-vp.Y
            t.tracer.Position=UDim2.fromOffset(vp.X/2, vp.Y)
            t.tracer.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),1.5)
            t.tracer.Rotation=math.deg(math.atan2(dy,dx)) t.tracer.Visible=true
        else t.tracer.Visible=false end
    end
end

Players.PlayerRemoving:Connect(RemoveESP)

-- ═══════════════════════════════════════════════════════════════
--  AIMBOT CORE
-- ═══════════════════════════════════════════════════════════════

local function CancelAnim()
    if Animation then pcall(function() Animation:Cancel() end) Animation=nil end
end

local function IsKey(input)
    local k=Settings.TriggerKey
    local match=false
    pcall(function() if input.KeyCode==Enum.KeyCode[k] then match=true end end)
    pcall(function() if input.UserInputType==Enum.UserInputType[k] then match=true end end)
    return match
end

local function ResetLock()
    Locked=nil CancelAnim()
    pcall(function() FOVStroke.Color=FOVSettings.Color end)
end

local function GetClosestPlayer()
    if not Locked then
        RequiredDistance = FOVSettings.Enabled and FOVSettings.Amount or 2000
        local mouse = UserInputService:GetMouseLocation()
        for _,v in next, Players:GetPlayers() do
            if v==LocalPlayer then continue end
            local char=v.Character if not char then continue end
            local part=char:FindFirstChild(Settings.LockPart)
            local hum=char:FindFirstChildOfClass("Humanoid")
            if not part or not hum then continue end
            if Settings.TeamCheck and v.Team==LocalPlayer.Team then continue end
            if Settings.AliveCheck and hum.Health<=0 then continue end
            if Settings.WallCheck then
                local ok,bl=pcall(function()
                    return Camera:GetPartsObscuringTarget({part.Position},char:GetDescendants())
                end)
                if ok and #bl>0 then continue end
            end
            local vec,onScreen=Camera:WorldToViewportPoint(part.Position)
            if not onScreen then continue end
            local dist=(Vector2.new(vec.X,vec.Y)-mouse).Magnitude
            if dist<RequiredDistance then RequiredDistance=dist Locked=v end
        end
    else
        local char=Locked.Character
        local part=char and char:FindFirstChild(Settings.LockPart)
        if not part then ResetLock() return end
        local vec=Camera:WorldToViewportPoint(part.Position)
        local mouse=UserInputService:GetMouseLocation()
        local dist=(Vector2.new(vec.X,vec.Y)-mouse).Magnitude
        if dist>(FOVSettings.Enabled and FOVSettings.Amount or 2000) then ResetLock() end
    end
end

-- ═══════════════════════════════════════════════════════════════
--  LOOPS — tách hoàn toàn để Synapse không bị overload
-- ═══════════════════════════════════════════════════════════════

-- ESP: 10fps riêng
task.spawn(function()
    while Alive do
        task.wait(0.1)
        pcall(UpdateESP)
    end
end)

-- Aim: BindToRenderStep nhưng wrap pcall toàn bộ
RunService:BindToRenderStep("MKAimV2", Enum.RenderPriority.Camera.Value+1, function()
    pcall(function()
        -- FOV circle
        if FOVSettings.Enabled and FOVSettings.Visible then
            local m = UserInputService:GetMouseLocation()
            FOVFrame.Position    = UDim2.fromOffset(m.X, m.Y)
            FOVFrame.Size        = UDim2.fromOffset(FOVSettings.Amount*2, FOVSettings.Amount*2)
            FOVStroke.Transparency = FOVSettings.Transparency
            FOVFrame.Visible     = true
        else
            FOVFrame.Visible = false
        end

        if not Running or not Settings.Enabled then
            FOVStroke.Color = FOVSettings.Color
            return
        end

        GetClosestPlayer()

        if not Locked then
            FOVStroke.Color = FOVSettings.Color
            return
        end

        local char = Locked.Character
        local part = char and char:FindFirstChild(Settings.LockPart)
        if not part then ResetLock() return end

        FOVStroke.Color = FOVSettings.LockedColor
        local goal = CFrame.new(Camera.CFrame.Position, part.Position)

        if Settings.Sensitivity > 0 then
            CancelAnim()
            Animation = TweenService:Create(Camera,
                TweenInfo.new(Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {CFrame = goal})
            Animation:Play()
        else
            Camera.CFrame = goal
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════
--  INPUT
-- ═══════════════════════════════════════════════════════════════

UserInputService.TextBoxFocused:Connect(function()       Typing=true  end)
UserInputService.TextBoxFocusReleased:Connect(function() Typing=false end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode==Enum.KeyCode.RightShift then
        GUI.Visible=not GUI.Visible return
    end
    if Typing or Listening then return end
    if not IsKey(input) then return end
    if Settings.Toggle then
        Running=not Running
        if not Running then ResetLock() end
    else
        Running=true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if Typing or Listening or Settings.Toggle then return end
    if not IsKey(input) then return end
    Running=false ResetLock()
end)

LocalPlayer.CharacterRemoving:Connect(function()
    Running=false ResetLock()
end)

-- ═══════════════════════════════════════════════════════════════
--  NOTIFY
-- ═══════════════════════════════════════════════════════════════

Notify("MK AIM v2", "Loaded — RightShift mở menu 💜")

task.delay(6, function()
    Notify("MKDz ND", "MK Yeu Em 💜")
end)

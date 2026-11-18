--[[
    KENNEX HUB v45  |  K / ROXO
    Jogo: Volleyball Legends
    ------------------------------------------------------------
    Base do v39: hitbox, ESP, indicadores, mira, ataque.
    Sem sistema de carga.
    ------------------------------------------------------------
    Tecla de UI: RightShift   |   Panico: End
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local genv = (getgenv and getgenv()) or _G
if type(genv.__KNX) == "function" then pcall(genv.__KNX) end

local G = { conns = {}, insts = {}, alive = true }

local Players = game:GetService("Players")
local RS      = game:GetService("RunService")
local UIS     = game:GetService("UserInputService")
local VIM     = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local TS      = game:GetService("TweenService")
local HS      = game:GetService("HttpService")
local LP      = Players.LocalPlayer
local cam     = workspace.CurrentCamera

-- ============================================================
-- ESTADO
-- ============================================================
local S = {
    autoSpike = false, spikeDist = 18,
    autoBump  = false, bumpDist  = 10,

    hitbox = false, hitboxSize = 2.2, hitMode = "HOOK", hitShow = true,

    aim = false, aimLock = true, aimFov = 140, aimSmooth = 0.35,

    superSpike = false, ssPower = 60, ssTime = 0.15,

    esp = false, espBox = true, espFill = true, espHp = true,
    espName = true, espDist = true, espBall = true,

    hud = true,

    remoteServe = false, remoteSpike = false, remoteInf = false,

    autoAbility = false, abilityDelay = 1.4, abilityKey = Enum.KeyCode.Q,
    tilt = false, tiltAngle = 12,

    walkspeed = 32, jumppower = 55, autorot = false,

    uiKey = Enum.KeyCode.RightShift, panicKey = Enum.KeyCode.End,
    open = true, mini = false,

    lastSpike = nil, lastServe = nil, lastInf = nil,
    lastAtk = 0, fps = 60,
}

-- paleta
local ACC   = Color3.fromRGB(167, 139, 250)
local ACC2  = Color3.fromRGB(124, 82, 240)
local GOOD  = Color3.fromRGB(120, 225, 165)
local WARN  = Color3.fromRGB(255, 178, 84)
local BG    = Color3.fromRGB(11, 9, 18)
local PANEL = Color3.fromRGB(22, 18, 33)
local ROW   = Color3.fromRGB(31, 26, 45)
local TXT   = Color3.fromRGB(235, 231, 245)
local DIM   = Color3.fromRGB(139, 130, 160)

-- ============================================================
-- UTIL
-- ============================================================
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    table.insert(G.insts, o)
    return o
end

local function conn(sig, fn)
    local c = sig:Connect(fn)
    table.insert(G.conns, c)
    return c
end

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = o
    return c
end

local function stroke(o, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or Color3.fromRGB(56, 46, 78)
    s.Thickness = th or 1
    s.Parent = o
    return s
end

local function grad(o, a, b, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(a, b)
    g.Rotation = rot or 90
    g.Parent = o
    return g
end

local function tween(o, props, t)
    TS:Create(o, TweenInfo.new(t or 0.12), props):Play()
end

local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c = LP.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
end

local ballCache, ballAt = nil, 0
local function getBall()
    if ballCache and ballCache.Parent and tick() - ballAt < 1 then return ballCache end
    ballAt = tick()
    ballCache = nil
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Name:lower():find("ball") then
            ballCache = v
            break
        end
    end
    return ballCache
end

-- ============================================================
-- INPUT
-- ============================================================
local function firePress()
    local vp = cam.ViewportSize
    pcall(function()
        VIM:SendMouseMoveEvent(Vector2.new(vp.X / 2, vp.Y / 2), game, 0)
        VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 0)
    end)
    task.wait(0.045)
    pcall(function()
        VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 0)
    end)
end

function doAttack()
    if tick() - S.lastAtk < 0.1 then return end
    S.lastAtk = tick()
    firePress()
end

-- ============================================================
-- HITBOX
-- ============================================================
local sizeStore = {}
local hitMark = nil

local function restoreSizes()
    for part, sz in pairs(sizeStore) do
        if part and part.Parent then pcall(function() part.Size = sz end) end
    end
    sizeStore = {}
end

local function clearMark()
    if hitMark then pcall(function() hitMark:Destroy() end); hitMark = nil end
end

local function markBall(ball)
    if not S.hitShow then return end
    if hitMark and hitMark.Adornee == ball then return end
    clearMark()
    if not ball then return end
    local ok, sb = pcall(function()
        local b = Instance.new("SelectionBox")
        b.Adornee = ball
        b.Color3 = ACC
        b.LineThickness = 0.05
        b.SurfaceTransparency = 1
        b.Parent = ball
        return b
    end)
    if ok then hitMark = sb end
end

local function applySizeMode()
    local ball = getBall()
    if not ball then return end
    markBall(ball)
    local orig = sizeStore[ball] or ball.Size
    sizeStore[ball] = orig
    local want = orig * S.hitboxSize
    if (ball.Size - want).Magnitude > 0.01 then
        pcall(function() ball.Size = want end)
    end
end

local function stopHitbox()
    restoreSizes()
    clearMark()
end

-- ============================================================
-- HOOK
-- ============================================================
local mt, oldNamecall
local hooked = false

local function installHook()
    local ok, m = pcall(getrawmetatable, game)
    if not ok or not m then return end
    local nc = newcclosure or function(f) return f end
    mt, oldNamecall = m, m.__namecall
    pcall(setreadonly, m, false)
    m.__namecall = nc(function(self, ...)
        local method = getnamecallmethod()

        if S.hitbox and S.hitMode == "HOOK" then
            if method == "GetPartBoundsInBox" then
                local cf, sz, prm = ...
                if typeof(sz) == "Vector3" then
                    return oldNamecall(self, cf, sz * S.hitboxSize, prm)
                end
            elseif method == "GetPartBoundsInRadius" then
                local pos, rad, prm = ...
                if typeof(rad) == "number" then
                    return oldNamecall(self, pos, rad * S.hitboxSize, prm)
                end
            elseif method == "GetPartsInPart" then
                local part, prm = ...
                if typeof(part) == "Instance" and part:IsA("BasePart") then
                    local okc, res = pcall(function()
                        return self.GetPartBoundsInBox(self, part.CFrame, part.Size * S.hitboxSize, prm)
                    end)
                    if okc then return res end
                end
            end
        end

        if method == "InvokeServer" and typeof(self) == "Instance" then
            local n = self.Name:lower()
            local args = { ... }
            if n:find("spike") then S.lastSpike = args
            elseif n:find("serve") then S.lastServe = args
            elseif n:find("inf") then S.lastInf = args end
        end

        return oldNamecall(self, ...)
    end)
    pcall(setreadonly, m, true)
    hooked = true
end

local function unhook()
    if mt and oldNamecall then
        pcall(setreadonly, mt, false)
        mt.__namecall = oldNamecall
        pcall(setreadonly, mt, true)
    end
    hooked = false
end

local function findRF(pattern)
    for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if v:IsA("RemoteFunction") and v.Name:lower():find(pattern) then return v end
    end
end

local function fireRemote(pattern, args)
    local rf = findRF(pattern)
    if not rf then return end
    pcall(function()
        if args and #args > 0 then rf:InvokeServer(table.unpack(args))
        else rf:InvokeServer() end
    end)
end

-- ============================================================
-- SUPER SPIKE / AIM
-- ============================================================
local function superSpike()
    local hum, root = getHum(), getRoot()
    if not hum or not root then return end
    local ball = getBall()
    local dir = ball and (ball.Position - root.Position).Unit or Vector3.new(0, 0, -1)
    root.AssemblyLinearVelocity = Vector3.new(dir.X * S.ssPower, 42, dir.Z * S.ssPower)
    task.wait(S.ssTime)
    doAttack()
end

local function applyAim()
    if not S.aim then return end
    local ball = getBall()
    if not ball then return end
    local vp = cam.ViewportSize
    local p, on = cam:WorldToViewportPoint(ball.Position)
    if not on then return end
    local c = Vector2.new(vp.X / 2, vp.Y / 2)
    if (Vector2.new(p.X, p.Y) - c).Magnitude > S.aimFov then return end
    cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, ball.Position), math.clamp(S.aimSmooth, 0.05, 1))
end

-- ============================================================
-- ESP (BillboardGui)
-- ============================================================
local espSet = {}

local function killESP(plr)
    local e = espSet[plr]
    if not e then return end
    for _, v in pairs(e) do pcall(function() v:Destroy() end) end
    espSet[plr] = nil
end

local function buildESP(plr)
    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "KNX_ESP"
    bb.Size = UDim2.fromScale(4.2, 5.4)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 400
    bb.Adornee = root
    bb.Parent = root

    local box = Instance.new("Frame")
    box.Size = UDim2.fromScale(1, 1)
    box.BackgroundColor3 = ACC
    box.BackgroundTransparency = 0.9
    box.BorderSizePixel = 0
    box.Parent = bb
    local st = Instance.new("UIStroke")
    st.Color = ACC
    st.Thickness = 1.4
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    st.Parent = box

    local hpBg = Instance.new("Frame")
    hpBg.Size = UDim2.new(0.09, 0, 1, 0)
    hpBg.Position = UDim2.new(-0.16, 0, 0, 0)
    hpBg.BackgroundColor3 = Color3.fromRGB(18, 15, 26)
    hpBg.BorderSizePixel = 0
    hpBg.Parent = bb

    local hp = Instance.new("Frame")
    hp.Size = UDim2.fromScale(1, 1)
    hp.Position = UDim2.fromScale(0, 0)
    hp.BackgroundColor3 = GOOD
    hp.BorderSizePixel = 0
    hp.Parent = hpBg

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1.6, 0, 0.2, 0)
    nameL.Position = UDim2.new(-0.3, 0, -0.24, 0)
    nameL.BackgroundTransparency = 1
    nameL.Font = Enum.Font.GothamBold
    nameL.TextScaled = true
    nameL.TextColor3 = ACC
    nameL.TextStrokeTransparency = 0.3
    nameL.Text = plr.Name
    nameL.Parent = bb

    local distL = Instance.new("TextLabel")
    distL.Size = UDim2.new(1.6, 0, 0.16, 0)
    distL.Position = UDim2.new(-0.3, 0, -0.04, 0)
    distL.BackgroundTransparency = 1
    distL.Font = Enum.Font.Code
    distL.TextScaled = true
    distL.TextColor3 = DIM
    distL.TextStrokeTransparency = 0.4
    distL.Text = ""
    distL.Parent = bb

    espSet[plr] = { bb = bb, box = box, st = st, hpBg = hpBg, hp = hp, nameL = nameL, distL = distL }
end

local function syncESP()
    if not S.esp then
        for plr in pairs(espSet) do killESP(plr) end
        return
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local e = espSet[plr]
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if not (root and hum) then
                killESP(plr)
            else
                if not e or not e.bb.Parent then
                    killESP(plr)
                    buildESP(plr)
                    e = espSet[plr]
                end
                if e then
                    local alive = hum.Health > 0
                    local col = alive and ACC or Color3.fromRGB(150, 145, 165)
                    e.st.Color = col
                    e.box.BackgroundColor3 = col
                    e.box.BackgroundTransparency = S.espFill and 0.9 or 1
                    e.box.Visible = S.espBox
                    e.hpBg.Visible = S.espHp
                    e.nameL.Visible = S.espName
                    e.distL.Visible = S.espDist

                    local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    e.hp.Size = UDim2.fromScale(1, pct)
                    e.hp.Position = UDim2.fromScale(0, 1 - pct)
                    e.hp.BackgroundColor3 = pct > 0.5 and GOOD or (pct > 0.22 and WARN or Color3.fromRGB(240, 96, 110))

                    local d = (cam.CFrame.Position - root.Position).Magnitude
                    e.distL.Text = math.floor(d) .. "m"
                    e.nameL.Text = plr.Name
                end
            end
        end
    end
end

-- marcador da bola
local ballMark
local function syncBallESP()
    if not S.espBall then
        if ballMark then pcall(function() ballMark:Destroy() end); ballMark = nil end
        return
    end
    local ball = getBall()
    if not ball then return end
    if ballMark and ballMark.Parent == ball then return end
    if ballMark then pcall(function() ballMark:Destroy() end) end
    local ok, bb = pcall(function()
        local b = Instance.new("BillboardGui")
        b.Size = UDim2.fromScale(1.6, 1.6)
        b.AlwaysOnTop = true
        b.LightInfluence = 0
        b.Adornee = ball
        b.Parent = ball
        local t = Instance.new("TextLabel")
        t.Size = UDim2.fromScale(1, 1)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.GothamBold
        t.TextScaled = true
        t.TextColor3 = Color3.fromRGB(255, 255, 255)
        t.TextStrokeTransparency = 0.2
        t.Text = "+"
        t.Parent = b
        return b
    end)
    if ok then ballMark = bb end
end

-- ============================================================
-- UI
-- ============================================================
local gui = new("ScreenGui", {
    Name = "Kennex", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local okGui = pcall(function() gui.Parent = CoreGui end)
if not okGui then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = new("Frame", {
    Size = UDim2.fromOffset(452, 328),
    Position = UDim2.new(0, 40, 0, 90),
    BackgroundColor3 = BG, BorderSizePixel = 0,
}, gui)
corner(main, 14); stroke(main, Color3.fromRGB(66, 52, 96), 1)

local head = new("Frame", {
    Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = PANEL, BorderSizePixel = 0,
}, main)
corner(head, 14)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = ACC2, BorderSizePixel = 0,
}, head)
grad(head, Color3.fromRGB(58, 38, 104), PANEL, 90)

-- logo K
local badge = new("Frame", {
    Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(12, 9),
    BackgroundColor3 = ACC2, BorderSizePixel = 0,
}, head)
corner(badge, 7)
grad(badge, ACC, ACC2, 45)
new("Frame", {
    Size = UDim2.fromOffset(3, 16), Position = UDim2.fromOffset(7, 5),
    BackgroundColor3 = Color3.fromRGB(246, 243, 255), BorderSizePixel = 0,
}, badge)
local d1 = new("Frame", {
    Size = UDim2.fromOffset(3, 11), Position = UDim2.fromOffset(13, 3),
    BackgroundColor3 = Color3.fromRGB(246, 243, 255), BorderSizePixel = 0,
}, badge)
d1.Rotation = 38
local d2 = new("Frame", {
    Size = UDim2.fromOffset(3, 11), Position = UDim2.fromOffset(13, 12),
    BackgroundColor3 = Color3.fromRGB(246, 243, 255), BorderSizePixel = 0,
}, badge)
d2.Rotation = -38

new("TextLabel", {
    Size = UDim2.fromOffset(120, 18), Position = UDim2.fromOffset(46, 6),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
    TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = "KENNEX",
}, head)
new("TextLabel", {
    Size = UDim2.fromOffset(120, 12), Position = UDim2.fromOffset(46, 24),
    BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 9,
    TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = "v45 · volleyball",
}, head)

local function hdrBtn(txt, x, col, bg)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(24, 22), Position = UDim2.new(1, x, 0, 11),
        BackgroundColor3 = bg, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = col,
        Text = txt, AutoButtonColor = false,
    }, head)
    corner(b, 5)
    return b
end

local closeBtn = hdrBtn("x", -32, Color3.fromRGB(255, 140, 150), Color3.fromRGB(52, 30, 40))
local miniBtn  = hdrBtn("-", -60, ACC, Color3.fromRGB(44, 34, 66))

closeBtn.MouseButton1Click:Connect(function() S.open = false; main.Visible = false end)
miniBtn.MouseButton1Click:Connect(function()
    S.mini = not S.mini
    main.Size = S.mini and UDim2.fromOffset(452, 44) or UDim2.fromOffset(452, 328)
end)

local dragging, dragStart, startPos
conn(head.InputBegan, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = i.Position; startPos = main.Position
    end
end)
conn(UIS.InputChanged, function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
conn(UIS.InputEnded, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local tabBar = new("Frame", {
    Size = UDim2.new(1, -18, 0, 24), Position = UDim2.fromOffset(9, 50),
    BackgroundTransparency = 1,
}, main)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, tabBar)

local content = new("Frame", {
    Size = UDim2.new(1, -18, 1, -82), Position = UDim2.fromOffset(9, 80),
    BackgroundTransparency = 1, ClipsDescendants = true,
}, main)

local pages, tabBtns = {}, {}
local ORDER = { "COMBATE", "VISUAL", "MOVER", "ACAO", "MOVIM", "UI" }

for i, name in ipairs(ORDER) do
    local b = new("TextButton", {
        Size = UDim2.fromOffset(66, 24), BackgroundColor3 = ROW, BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = DIM,
        Text = name, AutoButtonColor = false, LayoutOrder = i,
    }, tabBar)
    corner(b, 6)
    tabBtns[name] = b

    local p = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(74, 62, 100),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, content)
    new("UIListLayout", { Padding = UDim.new(0, 6) }, p)
    pages[name] = p
end

local function selectTab(name)
    for n, b in pairs(tabBtns) do
        b.BackgroundColor3 = (n == name) and ACC2 or ROW
        b.TextColor3 = (n == name) and Color3.fromRGB(248, 245, 255) or DIM
    end
    for n, p in pairs(pages) do p.Visible = (n == name) end
end

for name, b in pairs(tabBtns) do
    b.MouseButton1Click:Connect(function() selectTab(name) end)
end

local function card(page, title, accent)
    local c = new("Frame", {
        Size = UDim2.new(1, -8, 0, 0), BackgroundColor3 = PANEL,
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y,
    }, page)
    corner(c, 9); stroke(c, Color3.fromRGB(52, 42, 76), 1)
    new("UIListLayout", { Padding = UDim.new(0, 5) }, c)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7),
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    }, c)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = accent or ACC, Text = title,
    }, c)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(44, 36, 64), BorderSizePixel = 0,
    }, c)
    local body = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
    }, c)
    new("UIListLayout", { Padding = UDim.new(0, 5) }, body)
    return body
end

local function row(parent, h)
    local r = new("Frame", {
        Size = UDim2.new(1, 0, 0, h or 23), BackgroundColor3 = ROW, BorderSizePixel = 0,
    }, parent)
    corner(r, 6)
    return r
end

local function toggle(parent, label, key, onChange)
    local r = row(parent)
    new("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11.5,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, r)
    local sw = new("Frame", {
        Size = UDim2.fromOffset(32, 15), Position = UDim2.new(1, -41, 0.5, -7.5),
        BackgroundColor3 = Color3.fromRGB(48, 40, 66), BorderSizePixel = 0,
    }, r)
    corner(sw, 8)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(11, 11), Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(180, 172, 200), BorderSizePixel = 0,
    }, sw)
    corner(knob, 6)

    local function paint()
        local on = S[key]
        sw.BackgroundColor3 = on and ACC2 or Color3.fromRGB(48, 40, 66)
        knob.Position = on and UDim2.fromOffset(19, 2) or UDim2.fromOffset(2, 2)
        knob.BackgroundColor3 = on and Color3.fromRGB(250, 248, 255) or Color3.fromRGB(180, 172, 200)
    end

    local btn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, r)
    btn.MouseButton1Click:Connect(function()
        S[key] = not S[key]
        paint()
        if onChange then pcall(onChange, S[key]) end
    end)
    paint()
    return r
end

local function slider(parent, label, key, min, max, step, fmt)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = ROW, BorderSizePixel = 0,
    }, parent)
    corner(holder, 6)

    new("TextLabel", {
        Size = UDim2.new(1, -60, 0, 15), Position = UDim2.fromOffset(8, 3),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10.5,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, holder)
    local val = new("TextLabel", {
        Size = UDim2.fromOffset(52, 15), Position = UDim2.new(1, -60, 0, 3),
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 10.5,
        TextColor3 = ACC, TextXAlignment = Enum.TextXAlignment.Right, Text = tostring(S[key]),
    }, holder)

    local track = new("Frame", {
        Size = UDim2.new(1, -16, 0, 4), Position = UDim2.fromOffset(8, 25),
        BackgroundColor3 = Color3.fromRGB(46, 38, 64), BorderSizePixel = 0,
    }, holder)
    corner(track, 2)
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = ACC2, BorderSizePixel = 0,
    }, track)
    corner(fill, 2)

    local function paint()
        fill.Size = UDim2.new(math.clamp((S[key] - min) / (max - min), 0, 1), 0, 1, 0)
        val.Text = fmt and fmt(S[key]) or tostring(S[key])
    end

    local grabbing = false
    local function set(input)
        local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = math.floor((min + rel * (max - min)) / step + 0.5) * step
        S[key] = math.clamp(v, min, max)
        paint()
    end

    local grab = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, holder)
    grab.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            grabbing = true; set(i)
        end
    end)
    conn(UIS.InputChanged, function(i)
        if grabbing and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            set(i)
        end
    end)
    conn(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            grabbing = false
        end
    end)

    paint()
    return holder
end

local function button(parent, label, fn)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = ACC2,
        BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 10.5,
        TextColor3 = Color3.fromRGB(248, 245, 255), Text = label, AutoButtonColor = false,
    }, parent)
    corner(b, 6)
    b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = ACC }) end)
    b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = ACC2 }) end)
    b.MouseButton1Click:Connect(function() pcall(fn) end)
    return b
end

local function info(parent, text)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
        Font = Enum.Font.Code, TextSize = 9.5, TextColor3 = DIM,
        TextXAlignment = Enum.TextXAlignment.Left, Text = text, TextWrapped = true,
    }, parent)
end

local function modeRow(parent, label, key, opts)
    local r = row(parent, 26)
    new("TextLabel", {
        Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10.5,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, r)
    local btns = {}
    local function paint()
        for v, b in pairs(btns) do
            b.BackgroundColor3 = (S[key] == v) and ACC2 or Color3.fromRGB(44, 36, 62)
            b.TextColor3 = (S[key] == v) and Color3.fromRGB(250, 248, 255) or DIM
        end
    end
    for i, v in ipairs(opts) do
        local b = new("TextButton", {
            Size = UDim2.fromOffset(48, 18), Position = UDim2.new(1, -52 * (3 - i) - 2, 0.5, -9),
            BackgroundColor3 = Color3.fromRGB(44, 36, 62), BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = DIM,
            Text = v, AutoButtonColor = false,
        }, r)
        corner(b, 4)
        btns[v] = b
        b.MouseButton1Click:Connect(function()
            S[key] = v
            paint()
            if key == "hitMode" and v == "HOOK" then restoreSizes() end
        end)
    end
    paint()
    return r
end

-- ============================================================
-- HUD
-- ============================================================
local hud = new("Frame", {
    Size = UDim2.fromOffset(172, 112), Position = UDim2.new(0, 40, 0, 434),
    BackgroundColor3 = Color3.fromRGB(10, 8, 16), BorderSizePixel = 0,
    BackgroundTransparency = 0.15,
}, gui)
corner(hud, 10); stroke(hud, Color3.fromRGB(58, 46, 84), 1)
new("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = ACC2, BorderSizePixel = 0 }, hud)
new("TextLabel", {
    Size = UDim2.new(1, -12, 0, 13), Position = UDim2.fromOffset(8, 4),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 8.5,
    TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = "INDICADORES",
}, hud)

local function hudRow(y, label)
    new("TextLabel", {
        Size = UDim2.fromOffset(68, 12), Position = UDim2.fromOffset(8, y),
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 9.5,
        TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, hud)
    return new("TextLabel", {
        Size = UDim2.fromOffset(76, 12), Position = UDim2.fromOffset(78, y),
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 9.5,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Right, Text = "--",
    }, hud)
end

local hDist  = hudRow(20, "distancia")
local hSpeed = hudRow(33, "velocidade")
local hAlt   = hudRow(46, "altura")
local hFps   = hudRow(59, "fps")

local chipRow = new("Frame", {
    Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(8, 78),
    BackgroundTransparency = 1,
}, hud)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, chipRow)

local function chip(label)
    local f = new("Frame", {
        Size = UDim2.fromOffset(0, 16), BackgroundColor3 = Color3.fromRGB(30, 25, 44),
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X,
    }, chipRow)
    corner(f, 4)
    new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, f)
    local l = new("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = Color3.fromRGB(96, 88, 118), Text = label,
    }, f)
    return f, l
end

local cAimF, cAimL = chip("AIM")
local cHitF, cHitL = chip("HIT")
local cSpkF, cSpkL = chip("SPK")
local cLckF, cLckL = chip("LOCK")

local function paintChip(f, l, on)
    f.BackgroundColor3 = on and Color3.fromRGB(52, 38, 84) or Color3.fromRGB(30, 25, 44)
    l.TextColor3 = on and ACC or Color3.fromRGB(96, 88, 118)
end

local hDrag, hStart, hPos
conn(hud.InputBegan, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        hDrag = true; hStart = i.Position; hPos = hud.Position
    end
end)
conn(UIS.InputChanged, function(i)
    if hDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - hStart
        hud.Position = UDim2.new(hPos.X.Scale, hPos.X.Offset + d.X, hPos.Y.Scale, hPos.Y.Offset + d.Y)
    end
end)
conn(UIS.InputEnded, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        hDrag = false
    end
end)

-- toasts
local toasts = new("Frame", {
    Size = UDim2.fromOffset(210, 190), Position = UDim2.new(0, 40, 1, -210),
    BackgroundTransparency = 1,
}, gui)
new("UIListLayout", {
    VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 4),
}, toasts)

local function notify(text, col)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(22, 18, 33),
        BorderSizePixel = 0,
    }, toasts)
    corner(f, 6); stroke(f, col or ACC, 1)
    new("Frame", { Size = UDim2.fromOffset(2, 22), BackgroundColor3 = col or ACC, BorderSizePixel = 0 }, f)
    new("TextLabel", {
        Size = UDim2.new(1, -14, 1, 0), Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10.5,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = text,
    }, f)
    task.delay(2.1, function()
        pcall(function() tween(f, { BackgroundTransparency = 1 }, 0.25) end)
        task.delay(0.3, function() pcall(function() f:Destroy() end) end)
    end)
end

-- ============================================================
-- PÁGINAS
-- ============================================================
local pg = pages.COMBATE
local c1 = card(pg, "ATAQUE")
toggle(c1, "AUTO SPIKE", "autoSpike")
slider(c1, "distância", "spikeDist", 6, 45, 1)
toggle(c1, "AUTO BUMP", "autoBump")
slider(c1, "distância (bump)", "bumpDist", 4, 30, 1)

local c2 = card(pg, "HITBOX")
toggle(c2, "HITBOX", "hitbox", function(v)
    if not v then stopHitbox() end
    notify(v and "hitbox ON" or "hitbox OFF", v and GOOD or DIM)
end)
slider(c2, "multiplicador", "hitboxSize", 1, 6, 0.1, function(v) return string.format("%.1fx", v) end)
modeRow(c2, "modo", "hitMode", { "HOOK", "TAMANHO" })
toggle(c2, "CONTORNO NA BOLA", "hitShow", function(v)
    if not v then clearMark() end
end)

local c3 = card(pg, "MIRA")
toggle(c3, "AIM ASSIST", "aim")
toggle(c3, "MARCAR ALVO", "aimLock")
slider(c3, "campo", "aimFov", 40, 420, 5)
slider(c3, "suavidade", "aimSmooth", 0.05, 1, 0.05, function(v) return string.format("%.2f", v) end)

local c4 = card(pg, "SUPER SPIKE", WARN)
toggle(c4, "SUPER SPIKE", "superSpike")
slider(c4, "força", "ssPower", 20, 140, 2)
button(c4, "EXECUTAR", function() superSpike(); notify("super spike", WARN) end)
button(c4, "ATACAR AGORA", doAttack)

local v1 = card(pages.VISUAL, "ESP")
toggle(v1, "ESP", "esp", function(v) notify(v and "esp ON" or "esp OFF", v and GOOD or DIM) end)
toggle(v1, "CAIXA", "espBox")
toggle(v1, "PREENCHIMENTO", "espFill")
toggle(v1, "VIDA", "espHp")
toggle(v1, "NOME", "espName")
toggle(v1, "DISTANCIA", "espDist")
toggle(v1, "BOLA", "espBall")

local v2 = card(pages.VISUAL, "HUD")
toggle(v2, "MOSTRAR HUD", "hud", function(v) hud.Visible = v end)

local m1 = card(pages.MOVER, "REMOTES")
toggle(m1, "SERVE REMOTO", "remoteServe")
toggle(m1, "SPIKE REMOTO", "remoteSpike")
toggle(m1, "INF", "remoteInf")
button(m1, "DISPARAR SPIKE", function() fireRemote("spike", S.lastSpike) end)
button(m1, "DISPARAR SERVE", function() fireRemote("serve", S.lastServe) end)

local a1 = card(pages.ACAO, "AUTO HABILIDADE")
toggle(a1, "AUTO HABILIDADE", "autoAbility")
slider(a1, "intervalo", "abilityDelay", 0.3, 5, 0.1, function(v) return string.format("%.1fs", v) end)

local a2 = card(pages.ACAO, "TILT")
toggle(a2, "TILT", "tilt")
slider(a2, "angulo", "tiltAngle", -30, 30, 1)

local mv = card(pages.MOVIM, "MOVIMENTO")
slider(mv, "WALKSPEED", "walkspeed", 16, 120, 1)
slider(mv, "JUMPPOWER", "jumppower", 30, 200, 1)
toggle(mv, "AUTO ROTATE", "autorot")
button(mv, "APLICAR", applyLive)

-- UI / binds / diagnóstico
local u1 = card(pages.UI, "BINDS")
local function bindRow(label, key, col)
    local r = row(u1)
    new("TextLabel", {
        Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, r)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(74, 17), Position = UDim2.new(1, -82, 0.5, -8.5),
        BackgroundColor3 = Color3.fromRGB(40, 33, 58), BorderSizePixel = 0,
        Font = Enum.Font.Code, TextSize = 9.5, TextColor3 = col,
        Text = S[key].Name, AutoButtonColor = false,
    }, r)
    corner(b, 4)
    return b
end

local keyBtn = bindRow("tecla da UI", "uiKey", ACC)
local panicBtn = bindRow("panico", "panicKey", WARN)

local listening, listeningPanic = false, false
keyBtn.MouseButton1Click:Connect(function() listening = true; keyBtn.Text = "..." end)
panicBtn.MouseButton1Click:Connect(function() listeningPanic = true; panicBtn.Text = "..." end)

local u2 = card(pages.UI, "DIAGNOSTICO")
local dgExec = info(u2, "executor: --")
local dgHook = info(u2, "hook: --")
local dgBall = info(u2, "bola: --")
local dgEsp  = info(u2, "esp: --")

conn(UIS.InputBegan, function(i, gpe)
    if gpe then return end
    if listening then
        listening = false; S.uiKey = i.KeyCode; keyBtn.Text = i.KeyCode.Name; return
    end
    if listeningPanic then
        listeningPanic = false; S.panicKey = i.KeyCode; panicBtn.Text = i.KeyCode.Name; return
    end
    if i.KeyCode == S.uiKey then
        S.open = not S.open; main.Visible = S.open
    elseif i.KeyCode == S.panicKey then
        pcall(genv.__KNX)
    end
end)

local u3 = card(pages.UI, "CONFIG")
local CFG = {
    "autoSpike","spikeDist","autoBump","bumpDist","hitbox","hitboxSize","hitMode","hitShow",
    "aim","aimLock","aimFov","aimSmooth","superSpike","ssPower",
    "esp","espBox","espFill","espHp","espName","espDist","espBall","hud",
    "remoteServe","remoteSpike","remoteInf","autoAbility","abilityDelay",
    "tilt","tiltAngle","walkspeed","jumppower","autorot",
}

button(u3, "SALVAR", function()
    if not writefile then notify("sem writefile", WARN); return end
    local out = {}
    for _, k in ipairs(CFG) do out[k] = S[k] end
    writefile("kennex_v45.json", HS:JSONEncode(out))
    notify("salvo", GOOD)
end)

button(u3, "CARREGAR", function()
    if not (readfile and isfile and isfile("kennex_v45.json")) then notify("nada salvo", WARN); return end
    local d = HS:JSONDecode(readfile("kennex_v45.json"))
    for k, v in pairs(d) do
        if S[k] ~= nil and type(v) == type(S[k]) then S[k] = v end
    end
    notify("carregado", GOOD)
end)

selectTab("COMBATE")

-- ============================================================
-- MOVIM
-- ============================================================
function applyLive()
    local hum = getHum()
    if not hum then return end
    pcall(function()
        hum.WalkSpeed = S.walkspeed
        hum.JumpPower = S.jumppower
        hum.UseJumpPower = true
        hum.AutoRotate = S.autorot
    end)
end

conn(LP.CharacterAdded, function()
    task.wait(1)
    applyLive()
end)

task.spawn(function()
    while S.alive do
        applyLive()
        task.wait(0.7)
    end
end)

-- ============================================================
-- LOOPS
-- ============================================================
conn(RS.Heartbeat, function()
    if not S.alive or tick() - S.lastAtk < 0.35 then return end
    local ball, root = getBall(), getRoot()
    if not ball or not root then return end
    local rel = ball.Position - root.Position
    local d = rel.Magnitude
    if S.autoSpike and d <= S.spikeDist and rel.Y > -1 then doAttack(); return end
    if S.autoBump and d <= S.bumpDist and rel.Y <= 1 then doAttack() end
end)

task.spawn(function()
    while S.alive do
        if S.autoAbility then
            pcall(function()
                VIM:SendKeyEvent(true, S.abilityKey, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, S.abilityKey, false, game)
            end)
            task.wait(S.abilityDelay)
        else
            task.wait(0.1)
        end
    end
end)

local frames, fpsAt = 0, tick()
conn(RS.RenderStepped, function() frames += 1 end)

task.spawn(function()
    while S.alive do
        pcall(function()
            if tick() - fpsAt >= 1 then S.fps = frames; frames = 0; fpsAt = tick() end
        end)
        task.wait(0.25)
    end
end)

-- HUD + hitbox tamanho + diagnóstico
task.spawn(function()
    while S.alive do
        pcall(function()
            local ball, root = getBall(), getRoot()
            if ball and root then
                local d = (ball.Position - root.Position).Magnitude
                hDist.Text = string.format("%.1fm", d)
                hDist.TextColor3 = d <= S.spikeDist and GOOD or TXT
                hSpeed.Text = string.format("%.0f", ball.AssemblyLinearVelocity.Magnitude)
                hAlt.Text = string.format("%.1f", ball.Position.Y)
            else
                hDist.Text = "--"; hSpeed.Text = "--"; hAlt.Text = "--"
            end
            hFps.Text = tostring(S.fps)
            hFps.TextColor3 = S.fps >= 45 and GOOD or WARN

            paintChip(cAimF, cAimL, S.aim)
            paintChip(cHitF, cHitL, S.hitbox)
            paintChip(cSpkF, cSpkL, S.autoSpike)
            paintChip(cLckF, cLckL, S.aim and S.aimLock)

            hud.Visible = S.hud

            if S.hitbox and S.hitMode == "TAMANHO" then applySizeMode()
            elseif not S.hitbox then restoreSizes() end

            if S.hitbox and S.hitShow then markBall(ball) else if not S.hitbox then clearMark() end end

            dgExec.Text = "executor: " .. ((getrawmetatable and "raw-mt ok") or "raw-mt ausente")
            dgExec.TextColor3 = getrawmetatable and GOOD or WARN
            dgHook.Text = "hook: " .. (hooked and "ativo" or "inativo")
            dgHook.TextColor3 = hooked and GOOD or WARN
            dgBall.Text = "bola: " .. (ball and "ok" or "nao achada")
            dgBall.TextColor3 = ball and GOOD or WARN
            dgEsp.Text = "esp: " .. (S.esp and (#Players:GetPlayers() - 1) .. " alvos" or "off")
            dgEsp.TextColor3 = S.esp and GOOD or DIM
        end)
        task.wait(0.2)
    end
end)

conn(RS.RenderStepped, function()
    if not S.alive then return end
    pcall(applyAim)
    if S.tilt then cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(S.tiltAngle)) end
    pcall(syncESP)
    pcall(syncBallESP)
end)

conn(Players.PlayerRemoving, function(p) killESP(p) end)

-- ============================================================
-- CLEANUP
-- ============================================================
genv.__KNX = function()
    G.alive = false
    for _, c in ipairs(G.conns) do pcall(function() c:Disconnect() end) end
    for _, i in ipairs(G.insts) do pcall(function() i:Destroy() end) end
    for plr in pairs(espSet) do killESP(plr) end
    pcall(stopHitbox)
    if ballMark then pcall(function() ballMark:Destroy() end) end
    pcall(unhook)
    pcall(function() if gui then gui:Destroy() end end)
    genv.__KNX = nil
end

installHook()
notify("kennex v45 carregado", GOOD)
print("[KENNEX v45] ok · hook:", hooked)

--[[
    KENNEX HUB v44  |  QUALITY OF LIFE + VISUAL
    Jogo: Volleyball Legends
    ------------------------------------------------------------
    Sem sistema de carga. O ataque e um clique puro.
    Foco: hitbox, ESP, indicadores, mira e acabamento de UI.
    ------------------------------------------------------------
    Tecla de UI: RightShift (editavel no card INTERFACE)
    Desligar: reexecutar ou tecla de panico
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local genv = (getgenv and getgenv()) or _G
if type(genv.__KNX) == "function" then pcall(genv.__KNX) end

local G = { conns = {}, insts = {}, draws = {}, alive = true }

local Players  = game:GetService("Players")
local RS       = game:GetService("RunService")
local UIS      = game:GetService("UserInputService")
local VIM      = game:GetService("VirtualInputManager")
local CoreGui  = game:GetService("CoreGui")
local TS       = game:GetService("TweenService")
local HS       = game:GetService("HttpService")
local LP       = Players.LocalPlayer
local cam      = workspace.CurrentCamera

-- ============================================================
-- ESTADO
-- ============================================================
local S = {
    -- COMBATE
    autoSpike   = false, spikeDist = 18,
    autoBump    = false, bumpDist  = 10,
    hitbox      = false, hitboxSize = 2.2,
    aim         = false, aimFov = 140, aimSmooth = 0.35,
    aimLock     = true,
    superSpike  = false, ssPower = 60, ssTime = 0.15,

    -- VISUAL
    esp         = false,
    espBox      = true, espFill = true, espHp = true,
    espName     = true, espDist = true, espTracer = false,
    espBall     = true, espGlow = true,
    hud         = true,

    -- MOVER
    remoteServe = false, remoteSpike = false, remoteInf = false,

    -- ACAO
    autoAbility = false, abilityDelay = 1.4, abilityKey = Enum.KeyCode.Q,
    tilt        = false, tiltAngle = 12,

    -- MOVIM
    walkspeed   = 32, jumppower = 55, autorot = false,

    -- UI
    uiKey       = Enum.KeyCode.RightShift,
    panicKey    = Enum.KeyCode.End,
    open        = true, mini = false,

    -- interno
    lastSpike   = nil, lastServe = nil, lastInf = nil,
    lastAtk     = 0, fps = 60,
}

local COL_LIVE = Color3.fromRGB(110, 225, 255)
local COL_DEAD = Color3.fromRGB(150, 152, 160)
local ACCENT   = Color3.fromRGB(96, 178, 255)
local GOOD     = Color3.fromRGB(110, 220, 160)
local WARN     = Color3.fromRGB(255, 176, 74)
local BG       = Color3.fromRGB(13, 15, 19)
local PANEL    = Color3.fromRGB(21, 24, 30)
local ROW      = Color3.fromRGB(29, 33, 40)
local ROW_HI   = Color3.fromRGB(38, 43, 52)
local TXT      = Color3.fromRGB(230, 234, 242)
local DIM      = Color3.fromRGB(124, 133, 148)

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
    s.Color = col or Color3.fromRGB(48, 52, 62)
    s.Thickness = th or 1
    s.Parent = o
    return s
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

local function flatLook()
    local lv = cam.CFrame.LookVector
    local d = Vector3.new(lv.X, 0, lv.Z)
    if d.Magnitude < 0.01 then return Vector3.new(0, 0, -1) end
    return d.Unit
end

-- ============================================================
-- INPUT
-- ============================================================
local function pressDown()
    local vp = cam.ViewportSize
    pcall(function()
        VIM:SendMouseMoveEvent(Vector2.new(vp.X / 2, vp.Y / 2), game, 0)
        VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 0)
    end)
end

local function pressUp()
    local vp = cam.ViewportSize
    pcall(function()
        VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 0)
    end)
end

local function firePress()
    pressDown()
    task.wait(0.045)
    pressUp()
end

function doAttack()
    if tick() - S.lastAtk < 0.1 then return end
    S.lastAtk = tick()
    firePress()
end

-- ============================================================
-- HOOK
-- ============================================================
local mt, oldNamecall
local function installHook()
    local ok, m = pcall(getrawmetatable, game)
    if not ok or not m then return end
    mt, oldNamecall = m, m.__namecall
    pcall(setreadonly, m, false)
    m.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "GetPartBoundsInBox" and S.hitbox then
            local a, b, c = ...
            if typeof(b) == "Vector3" then
                return oldNamecall(self, a, b * S.hitboxSize, c)
            end
        elseif method == "InvokeServer" and typeof(self) == "Instance" then
            local n = self.Name:lower()
            local args = { ... }
            if n:find("spike") then S.lastSpike = args
            elseif n:find("serve") then S.lastServe = args
            elseif n:find("inf") then S.lastInf = args end
        end
        return oldNamecall(self, ...)
    end)
    pcall(setreadonly, m, true)
end

local function unhook()
    if mt and oldNamecall then
        pcall(setreadonly, mt, false)
        mt.__namecall = oldNamecall
        pcall(setreadonly, mt, true)
    end
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
-- SUPER SPIKE
-- ============================================================
local function superSpike()
    local hum, root = getHum(), getRoot()
    if not hum or not root then return end
    local ball = getBall()
    local dir = ball and (ball.Position - root.Position).Unit or flatLook()
    root.AssemblyLinearVelocity = Vector3.new(dir.X * S.ssPower, 42, dir.Z * S.ssPower)
    task.wait(S.ssTime)
    doAttack()
end

-- ============================================================
-- AIM
-- ============================================================
local function applyAim()
    if not S.aim then return end
    local ball = getBall()
    if not ball then return end
    local vp = cam.ViewportSize
    local p, on = cam:WorldToViewportPoint(ball.Position)
    if not on then return end
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    if (Vector2.new(p.X, p.Y) - center).Magnitude > S.aimFov then return end
    local goal = CFrame.lookAt(cam.CFrame.Position, ball.Position)
    cam.CFrame = cam.CFrame:Lerp(goal, math.clamp(S.aimSmooth, 0.05, 1))
end

local function applyTilt()
    if not S.tilt then return end
    cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(S.tiltAngle))
end

-- ============================================================
-- DRAW POOL
-- ============================================================
local function mkDraw(kind)
    if not Drawing then return nil end
    local ok, d = pcall(function() return Drawing.new(kind) end)
    if not ok or not d then return nil end
    table.insert(G.draws, d)
    return d
end

-- ============================================================
-- ESP
-- ============================================================
local espCache = {}

local function espFor(plr)
    if espCache[plr] then return espCache[plr] end
    local e = {
        fill = mkDraw("Square"),
        edge = {},
        cornerL = {},
        hpBg = mkDraw("Square"),
        hp = mkDraw("Square"),
        name = mkDraw("Text"),
        dist = mkDraw("Text"),
        tracer = mkDraw("Line"),
        dot = mkDraw("Circle"),
    }
    for i = 1, 4 do
        e.edge[i] = mkDraw("Line")
        e.cornerL[i] = mkDraw("Line")
    end
    espCache[plr] = e
    return e
end

local function hideESP(e)
    if not e then return end
    for _, d in pairs(e) do
        if type(d) == "table" then
            for _, v in pairs(d) do pcall(function() v.Visible = false end) end
        elseif d then
            pcall(function() d.Visible = false end)
        end
    end
end

local function setLine(l, a, b, col, th)
    l.Visible = true
    l.Color = col
    l.Thickness = th or 1
    l.From = a
    l.To = b
end

local function updateESP()
    if not Drawing then return end
    if not S.esp then
        for _, e in pairs(espCache) do hideESP(e) end
        return
    end

    local vp = cam.ViewportSize
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local e = espFor(plr)
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if root and hum and e.fill then
                local pos, on = cam:WorldToViewportPoint(root.Position)
                local d = (cam.CFrame.Position - root.Position).Magnitude
                local h = math.clamp(2400 / math.max(d, 1), 18, 340)
                local w = h * 0.56
                local col = (hum.Health > 0) and COL_LIVE or COL_DEAD

                local x0, y0 = pos.X - w / 2, pos.Y - h / 2
                local x1, y1 = pos.X + w / 2, pos.Y + h / 2

                if on then
                    if S.espFill then
                        e.fill.Visible = true
                        e.fill.Color = col
                        e.fill.Filled = true
                        e.fill.Thickness = 0
                        e.fill.Transparency = S.espGlow and 0.88 or 1
                        e.fill.Size = Vector2.new(w, h)
                        e.fill.Position = Vector2.new(x0, y0)
                    else
                        e.fill.Visible = false
                    end

                    if S.espBox then
                        setLine(e.edge[1], Vector2.new(x0, y0), Vector2.new(x1, y0), col, 1)
                        setLine(e.edge[2], Vector2.new(x1, y0), Vector2.new(x1, y1), col, 1)
                        setLine(e.edge[3], Vector2.new(x1, y1), Vector2.new(x0, y1), col, 1)
                        setLine(e.edge[4], Vector2.new(x0, y1), Vector2.new(x0, y0), col, 1)

                        local cw = w * 0.22
                        local ch = h * 0.16
                        setLine(e.cornerL[1], Vector2.new(x0, y0), Vector2.new(x0 + cw, y0), col, 2)
                        setLine(e.cornerL[2], Vector2.new(x1, y0), Vector2.new(x1 - cw, y0), col, 2)
                        setLine(e.cornerL[3], Vector2.new(x0, y1), Vector2.new(x0 + cw, y1), col, 2)
                        setLine(e.cornerL[4], Vector2.new(x1, y1), Vector2.new(x1 - cw, y1), col, 2)
                    else
                        for i = 1, 4 do
                            e.edge[i].Visible = false
                            e.cornerL[i].Visible = false
                        end
                    end

                    if S.espHp then
                        local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        e.hpBg.Visible = true
                        e.hpBg.Color = Color3.fromRGB(20, 22, 28)
                        e.hpBg.Filled = true
                        e.hpBg.Thickness = 0
                        e.hpBg.Size = Vector2.new(3, h)
                        e.hpBg.Position = Vector2.new(x0 - 6, y0)

                        e.hp.Visible = true
                        e.hp.Color = pct > 0.5 and GOOD or (pct > 0.22 and WARN or Color3.fromRGB(240, 96, 96))
                        e.hp.Filled = true
                        e.hp.Thickness = 0
                        e.hp.Size = Vector2.new(3, h * pct)
                        e.hp.Position = Vector2.new(x0 - 6, y0 + h * (1 - pct))
                    else
                        e.hpBg.Visible = false
                        e.hp.Visible = false
                    end

                    if S.espName and e.name then
                        e.name.Visible = true
                        e.name.Color = col
                        e.name.Size = 13
                        e.name.Center = true
                        e.name.Outline = true
                        e.name.Text = plr.Name
                        e.name.Position = Vector2.new(pos.X, y0 - 32)
                    elseif e.name then
                        e.name.Visible = false
                    end

                    if S.espDist and e.dist then
                        e.dist.Visible = true
                        e.dist.Color = DIM
                        e.dist.Size = 11
                        e.dist.Center = true
                        e.dist.Outline = true
                        e.dist.Text = math.floor(d) .. "m"
                        e.dist.Position = Vector2.new(pos.X, y0 - 18)
                    elseif e.dist then
                        e.dist.Visible = false
                    end

                    if S.espTracer then
                        setLine(e.tracer, Vector2.new(vp.X / 2, vp.Y), Vector2.new(pos.X, y1), col, 1)
                    else
                        e.tracer.Visible = false
                    end

                    if e.dot then
                        e.dot.Visible = true
                        e.dot.Color = col
                        e.dot.Thickness = 1
                        e.dot.Filled = true
                        e.dot.Radius = 2
                        e.dot.Position = Vector2.new(pos.X, pos.Y)
                    end
                else
                    hideESP(e)
                end
            else
                hideESP(e)
            end
        end
    end
end

conn(Players.PlayerRemoving, function(p)
    local e = espCache[p]
    if e then
        hideESP(e)
        for _, d in pairs(e) do
            if type(d) == "table" then
                for _, v in pairs(d) do pcall(function() v:Remove() end) end
            elseif d then
                pcall(function() d:Remove() end)
            end
        end
        espCache[p] = nil
    end
end)

-- ============================================================
-- MIRA: anel, crosshair, trava
-- ============================================================
local aimRing = mkDraw("Circle")
local crossH, crossV = mkDraw("Line"), mkDraw("Line")
local lockBox, lockLine = mkDraw("Square"), mkDraw("Line")

local function updateAimGfx()
    local vp = cam.ViewportSize
    local c = Vector2.new(vp.X / 2, vp.Y / 2)

    if crossH then
        crossH.Visible = S.aim
        crossH.Color = Color3.fromRGB(255, 255, 255)
        crossH.Thickness = 1
        crossH.From = Vector2.new(c.X - 6, c.Y)
        crossH.To = Vector2.new(c.X + 6, c.Y)
    end
    if crossV then
        crossV.Visible = S.aim
        crossV.Color = Color3.fromRGB(255, 255, 255)
        crossV.Thickness = 1
        crossV.From = Vector2.new(c.X, c.Y - 6)
        crossV.To = Vector2.new(c.X, c.Y + 6)
    end
    if aimRing then
        aimRing.Visible = S.aim
        aimRing.Color = Color3.fromRGB(96, 178, 255)
        aimRing.Thickness = 1
        aimRing.Filled = false
        aimRing.NumSides = 64
        aimRing.Radius = S.aimFov
        aimRing.Position = c
    end

    if not (S.aim and S.aimLock) then
        if lockBox then lockBox.Visible = false end
        if lockLine then lockLine.Visible = false end
        return
    end

    local best, bestD = nil, S.aimFov
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local h = plr.Character:FindFirstChild("Head")
            if h then
                local p, on = cam:WorldToViewportPoint(h.Position)
                if on then
                    local d = (Vector2.new(p.X, p.Y) - c).Magnitude
                    if d < bestD then best, bestD = p, d end
                end
            end
        end
    end

    if best and lockBox then
        lockBox.Visible = true
        lockBox.Color = Color3.fromRGB(255, 176, 74)
        lockBox.Thickness = 1
        lockBox.Filled = false
        lockBox.Size = Vector2.new(26, 26)
        lockBox.Position = Vector2.new(best.X - 13, best.Y - 13)

        lockLine.Visible = true
        lockLine.Color = Color3.fromRGB(255, 176, 74)
        lockLine.Thickness = 1
        lockLine.From = c
        lockLine.To = Vector2.new(best.X, best.Y)
    else
        lockBox.Visible = false
        lockLine.Visible = false
    end
end

-- ============================================================
-- UI
-- ============================================================
local gui = new("ScreenGui", {
    Name = "KennexHub", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local okGui = pcall(function() gui.Parent = CoreGui end)
if not okGui then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = new("Frame", {
    Size = UDim2.fromOffset(486, 340),
    Position = UDim2.new(0, 40, 0, 90),
    BackgroundColor3 = BG, BorderSizePixel = 0,
}, gui)
corner(main, 12); stroke(main, Color3.fromRGB(52, 57, 68), 1)

local bar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = PANEL, BorderSizePixel = 0,
}, main)
corner(bar, 12)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = ACCENT, BorderSizePixel = 0,
}, bar)

new("TextLabel", {
    Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
    TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "KENNEX  v44",
}, bar)
new("TextLabel", {
    Size = UDim2.fromOffset(64, 16), Position = UDim2.new(0, 96, 0, 10),
    BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 10,
    TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = "QoL/VISUAL",
}, bar)

local function hdrBtn(txt, x, col, bg)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(26, 22), Position = UDim2.new(1, x, 0, 7),
        BackgroundColor3 = bg, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = col,
        Text = txt, AutoButtonColor = false,
    }, bar)
    corner(b, 5)
    return b
end

local closeBtn = hdrBtn("X", -34, Color3.fromRGB(255, 132, 132), Color3.fromRGB(48, 30, 34))
local miniBtn  = hdrBtn("-", -64, Color3.fromRGB(170, 200, 235), Color3.fromRGB(32, 38, 46))

closeBtn.MouseButton1Click:Connect(function()
    S.open = false; main.Visible = false
end)
miniBtn.MouseButton1Click:Connect(function()
    S.mini = not S.mini
    main.Size = S.mini and UDim2.fromOffset(486, 36) or UDim2.fromOffset(486, 340)
end)

-- arrastar
local dragging, dragStart, startPos
conn(bar.InputBegan, function(i)
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

-- abas
local tabBar = new("Frame", {
    Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 44),
    BackgroundTransparency = 1,
}, main)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local content = new("Frame", {
    Size = UDim2.new(1, -20, 1, -80), Position = UDim2.fromOffset(10, 78),
    BackgroundTransparency = 1, ClipsDescendants = true,
}, main)

local pages, tabBtns = {}, {}
local ORDER = { "COMBATE", "VISUAL", "MOVER", "ACAO", "MOVIM", "UI" }

for i, name in ipairs(ORDER) do
    local b = new("TextButton", {
        Size = UDim2.fromOffset(70, 26), BackgroundColor3 = ROW, BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = DIM,
        Text = name, AutoButtonColor = false, LayoutOrder = i,
    }, tabBar)
    corner(b, 6)
    tabBtns[name] = b

    local p = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(68, 74, 88),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, content)
    new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, p)
    pages[name] = p
end

local function selectTab(name)
    for n, b in pairs(tabBtns) do
        b.BackgroundColor3 = (n == name) and ACCENT or ROW
        b.TextColor3 = (n == name) and Color3.fromRGB(10, 14, 20) or DIM
    end
    for n, p in pairs(pages) do p.Visible = (n == name) end
end

for name, b in pairs(tabBtns) do
    b.MouseButton1Click:Connect(function() selectTab(name) end)
end

-- construtores
local function card(page, title, accent)
    local c = new("Frame", {
        Size = UDim2.new(1, -8, 0, 0), BackgroundColor3 = PANEL,
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y,
    }, page)
    corner(c, 9); stroke(c, Color3.fromRGB(46, 51, 62), 1)
    new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, c)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9),
    }, c)

    local head = new("Frame", {
        Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = 0,
    }, c)
    new("TextLabel", {
        Size = UDim2.new(1, -8, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 10.5, TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = accent or ACCENT, Text = title,
    }, head)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 4),
        BackgroundColor3 = Color3.fromRGB(40, 44, 54), BorderSizePixel = 0,
    }, c)

    local body = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1,
    }, c)
    new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    return body
end

local function row(parent, h)
    local r = new("Frame", {
        Size = UDim2.new(1, 0, 0, h or 24), BackgroundColor3 = ROW, BorderSizePixel = 0,
    }, parent)
    corner(r, 6)
    return r
end

local function toggle(parent, label, key, accent, onChange)
    local r = row(parent)
    new("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, r)
    local sw = new("Frame", {
        Size = UDim2.fromOffset(34, 16), Position = UDim2.new(1, -43, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(50, 55, 65), BorderSizePixel = 0,
    }, r)
    corner(sw, 8)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(188, 194, 205), BorderSizePixel = 0,
    }, sw)
    corner(knob, 6)

    local function paint()
        local on = S[key]
        sw.BackgroundColor3 = on and (accent or ACCENT) or Color3.fromRGB(50, 55, 65)
        knob.Position = on and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
        knob.BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(188, 194, 205)
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

local function slider(parent, label, key, min, max, step, accent, fmt)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = ROW, BorderSizePixel = 0,
    }, parent)
    corner(holder, 6)

    new("TextLabel", {
        Size = UDim2.new(1, -62, 0, 16), Position = UDim2.fromOffset(9, 4),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, holder)
    local val = new("TextLabel", {
        Size = UDim2.fromOffset(54, 16), Position = UDim2.new(1, -62, 0, 4),
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = accent or ACCENT, TextXAlignment = Enum.TextXAlignment.Right,
        Text = tostring(S[key]),
    }, holder)

    local track = new("Frame", {
        Size = UDim2.new(1, -18, 0, 5), Position = UDim2.fromOffset(9, 26),
        BackgroundColor3 = Color3.fromRGB(46, 50, 60), BorderSizePixel = 0,
    }, holder)
    corner(track, 3)
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = accent or ACCENT, BorderSizePixel = 0,
    }, track)
    corner(fill, 3)

    local function paint()
        local a = (S[key] - min) / (max - min)
        fill.Size = UDim2.new(math.clamp(a, 0, 1), 0, 1, 0)
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

local function button(parent, label, fn, accent)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = accent or ACCENT,
        BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = Color3.fromRGB(10, 14, 20), Text = label, AutoButtonColor = false,
    }, parent)
    corner(b, 6)
    b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = Color3.fromRGB(150, 205, 255) }) end)
    b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = accent or ACCENT }) end)
    b.MouseButton1Click:Connect(function() pcall(fn) end)
    return b
end

local function info(parent, text, color)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1,
        Font = Enum.Font.Code, TextSize = 10, TextColor3 = color or DIM,
        TextXAlignment = Enum.TextXAlignment.Left, Text = text, TextWrapped = true,
    }, parent)
end

local function chips(parent)
    local f = new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 }, parent)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
    }, f)
    return f
end

local function chip(parent, label)
    local f = new("Frame", {
        Size = UDim2.fromOffset(0, 18), BackgroundColor3 = Color3.fromRGB(34, 38, 46),
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X,
    }, parent)
    corner(f, 4)
    new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, f)
    local l = new("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, TextSize = 9.5, TextColor3 = DIM, Text = label,
    }, f)
    return f, l
end

-- ============================================================
-- HUD DE INDICADORES
-- ============================================================
local hud = new("Frame", {
    Size = UDim2.fromOffset(178, 116), Position = UDim2.new(0, 40, 0, 448),
    BackgroundColor3 = Color3.fromRGB(11, 13, 17), BorderSizePixel = 0,
    BackgroundTransparency = 0.12,
}, gui)
corner(hud, 9); stroke(hud, Color3.fromRGB(44, 49, 60), 1)

new("Frame", {
    Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = ACCENT, BorderSizePixel = 0,
}, hud)

new("TextLabel", {
    Size = UDim2.new(1, -12, 0, 14), Position = UDim2.fromOffset(8, 5),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 9,
    TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = "INDICADORES",
}, hud)

local function hudRow(y, label)
    new("TextLabel", {
        Size = UDim2.fromOffset(70, 13), Position = UDim2.fromOffset(8, y),
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 10,
        TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, hud)
    return new("TextLabel", {
        Size = UDim2.fromOffset(78, 13), Position = UDim2.fromOffset(80, y),
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 10,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Right, Text = "--",
    }, hud)
end

local hDist  = hudRow(22, "distancia")
local hSpeed = hudRow(36, "velocidade")
local hAlt   = hudRow(50, "altura")
local hFps   = hudRow(64, "fps")

local chipRow = new("Frame", {
    Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(8, 84),
    BackgroundTransparency = 1,
}, hud)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, chipRow)
local cAim = chip(chipRow, "AIM")
local cHit = chip(chipRow, "HIT")
local cSpk = chip(chipRow, "SPK")
local cLock = chip(chipRow, "LOCK")

local function paintChip(f, l, on)
    f.BackgroundColor3 = on and Color3.fromRGB(32, 60, 78) or Color3.fromRGB(30, 34, 41)
    l.TextColor3 = on and ACCENT or Color3.fromRGB(96, 103, 116)
end

-- arrastar hud
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

-- ============================================================
-- TOASTS
-- ============================================================
local toastHolder = new("Frame", {
    Size = UDim2.fromOffset(220, 200), Position = UDim2.new(0, 40, 1, -220),
    BackgroundTransparency = 1,
}, gui)
new("UIListLayout", {
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder,
}, toastHolder)

local function notify(text, col)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.fromRGB(20, 23, 29),
        BorderSizePixel = 0, BackgroundTransparency = 0.05,
    }, toastHolder)
    corner(f, 6); stroke(f, col or ACCENT, 1)
    new("Frame", { Size = UDim2.fromOffset(2, 24), BackgroundColor3 = col or ACCENT, BorderSizePixel = 0 }, f)
    new("TextLabel", {
        Size = UDim2.new(1, -14, 1, 0), Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = text,
    }, f)
    task.delay(2.2, function()
        pcall(function() tween(f, { BackgroundTransparency = 1 }, 0.25) end)
        task.delay(0.3, function() pcall(function() f:Destroy() end) end)
    end)
end

-- ============================================================
-- PÁGINAS
-- ============================================================
-- COMBATE
local pg = pages.COMBATE
local c1 = card(pg, "ATAQUE AUTOMÁTICO")
toggle(c1, "AUTO SPIKE", "autoSpike")
slider(c1, "distância", "spikeDist", 6, 45, 1)
toggle(c1, "AUTO BUMP", "autoBump")
slider(c1, "distância (bump)", "bumpDist", 4, 30, 1)
info(c1, "spike acima de -1Y · bump abaixo")

local c2 = card(pg, "HITBOX")
toggle(c2, "HITBOX EXPANDIDA", "hitbox", nil, function(v)
    notify(v and "hitbox ON" or "hitbox OFF", v and GOOD or DIM)
end)
slider(c2, "multiplicador", "hitboxSize", 1, 6, 0.1, nil, function(v) return string.format("%.1fx", v) end)
info(c2, "hook em GetPartBoundsInBox")

local c3 = card(pg, "MIRA")
toggle(c3, "AIM ASSIST", "aim")
toggle(c3, "MARCAR ALVO", "aimLock")
slider(c3, "campo (px)", "aimFov", 40, 420, 5)
slider(c3, "suavidade", "aimSmooth", 0.05, 1, 0.05, nil, function(v) return string.format("%.2f", v) end)

local c4 = card(pg, "SUPER SPIKE", WARN)
toggle(c4, "SUPER SPIKE", "superSpike")
slider(c4, "força", "ssPower", 20, 140, 2, WARN)
button(c4, "EXECUTAR SUPER SPIKE", function()
    superSpike(); notify("super spike", WARN)
end, WARN)
button(c4, "ATACAR AGORA", doAttack)

-- VISUAL
local v1 = card(pages.VISUAL, "ESP")
toggle(v1, "ESP ATIVO", "esp")
toggle(v1, "CAIXA + CANTOS", "espBox")
toggle(v1, "PREENCHIMENTO", "espFill")
toggle(v1, "BRILHO", "espGlow")
toggle(v1, "BARRA DE VIDA", "espHp")
toggle(v1, "NOME", "espName")
toggle(v1, "DISTÂNCIA", "espDist")
toggle(v1, "TRACER", "espTracer")
toggle(v1, "BOLA", "espBall")
info(v1, "requer Drawing API")

local v2 = card(pages.VISUAL, "HUD")
toggle(v2, "MOSTRAR HUD", "hud", nil, function(v) hud.Visible = v end)
info(v2, "painel arrastável, canto superior esquerdo")

-- MOVER
local m1 = card(pages.MOVER, "REMOTES")
toggle(m1, "SERVE REMOTO", "remoteServe")
toggle(m1, "SPIKE REMOTO", "remoteSpike")
toggle(m1, "INFINITE (INF)", "remoteInf")
button(m1, "DISPARAR SPIKE", function()
    fireRemote("spike", S.lastSpike); notify("spike remoto", ACCENT)
end)
button(m1, "DISPARAR SERVE", function()
    fireRemote("serve", S.lastServe); notify("serve remoto", ACCENT)
end)
info(m1, "args capturados via InvokeServer")

-- ACAO
local a1 = card(pages.ACAO, "AUTO HABILIDADE")
toggle(a1, "AUTO HABILIDADE", "autoAbility")
slider(a1, "intervalo", "abilityDelay", 0.3, 5, 0.1, nil, function(v) return string.format("%.1fs", v) end)

local a2 = card(pages.ACAO, "TILT")
toggle(a2, "TILT DE CÂMERA", "tilt")
slider(a2, "ângulo", "tiltAngle", -30, 30, 1)
info(a2, "inclinação estilo cinematico")

-- MOVIM
local mv = card(pages.MOVIM, "MOVIMENTO")
slider(mv, "WALKSPEED", "walkspeed", 16, 120, 1)
slider(mv, "JUMPPOWER", "jumppower", 30, 200, 1)
toggle(mv, "AUTO ROTATE", "autorot")
button(mv, "APLICAR AGORA", applyLive)

-- UI
local u1 = card(pages.UI, "INTERFACE")
local keyRow = row(u1)
new("TextLabel", {
    Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(9, 0),
    BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
    TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = "tecla da UI",
}, keyRow)
local keyLbl = new("TextButton", {
    Size = UDim2.fromOffset(78, 18), Position = UDim2.new(1, -88, 0.5, -9),
    BackgroundColor3 = Color3.fromRGB(40, 45, 55), BorderSizePixel = 0,
    Font = Enum.Font.Code, TextSize = 10, TextColor3 = ACCENT,
    Text = S.uiKey.Name, AutoButtonColor = false,
}, keyRow)
corner(keyLbl, 4)

local listening = false
keyLbl.MouseButton1Click:Connect(function()
    listening = true
    keyLbl.Text = "..."
end)

local pRow = row(u1)
new("TextLabel", {
    Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(9, 0),
    BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
    TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = "tecla de panico",
}, pRow)
local pLbl = new("TextButton", {
    Size = UDim2.fromOffset(78, 18), Position = UDim2.new(1, -88, 0.5, -9),
    BackgroundColor3 = Color3.fromRGB(40, 45, 55), BorderSizePixel = 0,
    Font = Enum.Font.Code, TextSize = 10, TextColor3 = WARN,
    Text = S.panicKey.Name, AutoButtonColor = false,
}, pRow)
corner(pLbl, 4)

local listeningPanic = false
pLbl.MouseButton1Click:Connect(function()
    listeningPanic = true
    pLbl.Text = "..."
end)

conn(UIS.InputBegan, function(i, gpe)
    if gpe then return end
    if listening then
        listening = false
        S.uiKey = i.KeyCode
        keyLbl.Text = i.KeyCode.Name
        notify("bind: " .. i.KeyCode.Name, ACCENT)
        return
    end
    if listeningPanic then
        listeningPanic = false
        S.panicKey = i.KeyCode
        pLbl.Text = i.KeyCode.Name
        notify("panico: " .. i.KeyCode.Name, WARN)
        return
    end
    if i.KeyCode == S.uiKey then
        S.open = not S.open
        main.Visible = S.open
    elseif i.KeyCode == S.panicKey then
        pcall(genv.__KNX)
    end
end)

local u2 = card(pages.UI, "CONFIG")
local CFG_KEYS = {
    "autoSpike","spikeDist","autoBump","bumpDist","hitbox","hitboxSize",
    "aim","aimLock","aimFov","aimSmooth","superSpike","ssPower","ssTime",
    "esp","espBox","espFill","espGlow","espHp","espName","espDist","espTracer","espBall",
    "hud","remoteServe","remoteSpike","remoteInf","autoAbility","abilityDelay",
    "tilt","tiltAngle","walkspeed","jumppower","autorot",
}

button(u2, "SALVAR CONFIG", function()
    if not writefile then notify("sem writefile", WARN) return end
    local out = {}
    for _, k in ipairs(CFG_KEYS) do out[k] = S[k] end
    writefile("kennex_v44.json", HS:JSONEncode(out))
    notify("config salva", GOOD)
end, GOOD)

button(u2, "CARREGAR CONFIG", function()
    if not (readfile and isfile and isfile("kennex_v44.json")) then
        notify("nenhum config salvo", WARN)
        return
    end
    local data = HS:JSONDecode(readfile("kennex_v44.json"))
    for k, v in pairs(data) do
        if S[k] ~= nil and type(v) == type(S[k]) then S[k] = v end
    end
    notify("config carregada (reabra a UI)", GOOD)
end)

info(u2, "salva apenas valores, nao binds")

selectTab("COMBATE")
if Drawing == nil then notify("Drawing ausente: ESP off", WARN) end

-- ============================================================
-- APLICAÇÃO DE MOVIM
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
        task.wait(0.6)
    end
end)

-- ============================================================
-- LOOP DE COMBATE
-- ============================================================
conn(RS.Heartbeat, function()
    if not S.alive or tick() - S.lastAtk < 0.35 then return end
    local ball, root = getBall(), getRoot()
    if not ball or not root then return end
    local rel = ball.Position - root.Position
    local d = rel.Magnitude

    if S.autoSpike and d <= S.spikeDist and rel.Y > -1 then
        doAttack(); return
    end
    if S.autoBump and d <= S.bumpDist and rel.Y <= 1 then
        doAttack()
    end
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

-- ============================================================
-- HUD UPDATE
-- ============================================================
local frames, fpsAt = 0, tick()
conn(RS.RenderStepped, function()
    frames += 1
    if tick() - fpsAt >= 1 then
        S.fps = frames
        frames = 0
        fpsAt = tick()
    end
end)

task.spawn(function()
    while S.alive do
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

        paintChip(cAim, select(2, cAim:GetChildren()), S.aim)
        paintChip(cHit, select(2, cHit:GetChildren()), S.hitbox)
        paintChip(cSpk, select(2, cSpk:GetChildren()), S.autoSpike)
        paintChip(cLock, select(2, cLock:GetChildren()), S.aim and S.aimLock)
        task.wait(0.2)
    end
end)

-- ============================================================
-- RENDER
-- ============================================================
conn(RS.RenderStepped, function()
    if not S.alive then return end
    applyAim()
    applyTilt()
    updateESP()
    updateAimGfx()
end)

-- ============================================================
-- CLEANUP
-- ============================================================
genv.__KNX = function()
    G.alive = false
    for _, c in ipairs(G.conns) do pcall(function() c:Disconnect() end) end
    for _, d in pairs(G.draws) do pcall(function() d:Remove() end) end
    for _, i in ipairs(G.insts) do pcall(function() i:Destroy() end) end
    pcall(unhook)
    pcall(function() if gui then gui:Destroy() end end)
    pcall(function()
        local hum = getHum()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.AutoRotate = true
        end
    end)
    genv.__KNX = nil
end

installHook()
notify("kennex v44 carregado", GOOD)
print("[KENNEX v44] ok")

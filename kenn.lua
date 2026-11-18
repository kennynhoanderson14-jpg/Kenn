--[[
    KENNEX HUB v43  |  CHARGE FORCADO
    Jogo: Volleyball Legends
    ------------------------------------------------------------
    A carga do TSH vem de MOVIMENTO. Este hub simula um passo
    curtissimo (lunge) imediatamente antes do golpe para o jogo
    contabilizar deslocamento e marcar o toque como CHARGE,
    sem voce precisar andar e sem travar o personagem.
    ------------------------------------------------------------
    Tecla de UI: RightShift   |   Desligar: apagar/reexecutar
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local genv = (getgenv and getgenv()) or _G
if type(genv.__KNX) == "function" then pcall(genv.__KNX) end

local G = { conns = {}, insts = {}, draws = {}, alive = true }

local Players    = game:GetService("Players")
local RS         = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local VIM        = game:GetService("VirtualInputManager")
local CoreGui    = game:GetService("CoreGui")
local LP         = Players.LocalPlayer
local cam        = workspace.CurrentCamera

-- ============================================================
-- ESTADO
-- ============================================================
local S = {
    -- COMBATE
    autoSpike   = false, spikeDist = 18,
    autoBump    = false, bumpDist  = 10,
    hitbox      = false, hitboxSize = 2.2,
    aim         = false, aimFov = 120, aimSmooth = 0.35,
    superSpike  = false, ssPower = 60, ssTime = 0.15,

    -- VISUAL
    esp         = false, espBox = true, espName = true,
    espTracer   = false, espBall = true,

    -- MOVER (remotes)
    remoteServe = false, remoteSpike = false, remoteInf = false,

    -- ACAO
    lunge       = true,
    lungeTime   = 0.12,
    lungeSpeed  = 26,
    holdCharge  = false,
    chargeHold  = 0.35,
    barLock     = false,
    pinPct      = 72,
    autoAbility = false,
    abilityDelay = 1.4,
    abilityKey  = Enum.KeyCode.Q,
    tilt        = false,
    tiltAngle   = 12,

    -- MOVIM
    walkspeed   = 32, jumppower = 55, autorot = false,

    -- interno
    lungeActive = false,
    lastSpike   = nil,
    lastServe   = nil,
    lastInf     = nil,
    lastAtk     = 0,
}

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

local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c = LP.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
end

local function flatLook()
    local lv = cam.CFrame.LookVector
    local d = Vector3.new(lv.X, 0, lv.Z)
    if d.Magnitude < 0.01 then return Vector3.new(0, 0, -1) end
    return d.Unit
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

local function dist(a, b)
    return (a.Position - b.Position).Magnitude
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

-- ============================================================
-- CHARGE FORCADO
-- ============================================================
local function lunge(hum, root)
    if not S.lunge or not hum or not root then return end
    if S.lungeActive then return end
    S.lungeActive = true

    local dir = flatLook()
    pcall(function() hum:Move(dir, false) end)
    root.AssemblyLinearVelocity =
        Vector3.new(dir.X * S.lungeSpeed, root.AssemblyLinearVelocity.Y, dir.Z * S.lungeSpeed)

    task.delay(S.lungeTime, function()
        if not S.alive then return end
        S.lungeActive = false
        local h, r = getHum(), getRoot()
        if not h or not r then return end
        pcall(function() h:Move(Vector3.zero, false) end)
        local v = r.AssemblyLinearVelocity
        r.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
    end)
end

local function holdTime()
    if S.barLock then
        return math.clamp((S.pinPct / 100) * 0.9, 0.05, 0.9)
    end
    return S.chargeHold
end

function doAttack()
    local hum, root = getHum(), getRoot()
    if not hum or not root then return end

    local moving = hum.MoveDirection.Magnitude > 0.15
    local pre = 0
    if S.lunge and not moving then
        lunge(hum, root)
        pre = S.lungeTime * 0.55
    end

    if S.holdCharge or S.barLock then
        local t = holdTime()
        task.delay(pre, function()
            pressDown()
            task.wait(t)
            pressUp()
        end)
    else
        task.delay(pre, firePress)
    end
    S.lastAtk = tick()
end

-- ============================================================
-- HOOK (hitbox / captura de remotes)
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
-- AIM / TILT
-- ============================================================
local function applyAim()
    if not S.aim then return end
    local ball = getBall()
    if not ball then return end
    local vp = cam.ViewportSize
    local p, on = cam:WorldToViewportPoint(ball.Position)
    if not on then return end
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local d = (Vector2.new(p.X, p.Y) - center).Magnitude
    if d > S.aimFov then return end
    local goal = CFrame.lookAt(cam.CFrame.Position, ball.Position)
    cam.CFrame = cam.CFrame:Lerp(goal, math.clamp(S.aimSmooth, 0.05, 1))
end

local function applyTilt()
    if not S.tilt then return end
    cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(S.tiltAngle))
end

-- ============================================================
-- ESP
-- ============================================================
local espCache = {}

local function mkDraw(kind)
    local ok, d = pcall(function() return Drawing.new(kind) end)
    if not ok or not d then return nil end
    table.insert(G.draws, d)
    return d
end

local function espFor(plr)
    if espCache[plr] then return espCache[plr] end
    local e = {
        box = mkDraw("Square"),
        name = mkDraw("Text"),
        tracer = mkDraw("Line"),
    }
    espCache[plr] = e
    return e
end

local function hideESP(e)
    if not e then return end
    if e.box then e.box.Visible = false end
    if e.name then e.name.Visible = false end
    if e.tracer then e.tracer.Visible = false end
end

local COL = Color3.fromRGB(120, 220, 255)

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
            local head = char and char:FindFirstChild("Head")

            if root and head and e.box then
                local pos, on = cam:WorldToViewportPoint(root.Position)
                local d = (cam.CFrame.Position - root.Position).Magnitude
                local h = math.clamp(2200 / math.max(d, 1), 16, 320)
                local w = h * 0.55

                if on and S.espBox then
                    e.box.Visible = true
                    e.box.Color = COL
                    e.box.Thickness = 1
                    e.box.Size = Vector2.new(w, h)
                    e.box.Position = Vector2.new(pos.X - w / 2, pos.Y - h / 2)
                elseif e.box then
                    e.box.Visible = false
                end

                if on and S.espName and e.name then
                    e.name.Visible = true
                    e.name.Color = COL
                    e.name.Size = 13
                    e.name.Center = true
                    e.name.Outline = true
                    e.name.Text = plr.Name .. "  [" .. math.floor(d) .. "]"
                    e.name.Position = Vector2.new(pos.X, pos.Y - h / 2 - 16)
                elseif e.name then
                    e.name.Visible = false
                end

                if on and S.espTracer and e.tracer then
                    e.tracer.Visible = true
                    e.tracer.Color = COL
                    e.tracer.Thickness = 1
                    e.tracer.From = Vector2.new(vp.X / 2, vp.Y)
                    e.tracer.To = Vector2.new(pos.X, pos.Y + h / 2)
                elseif e.tracer then
                    e.tracer.Visible = false
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
        for _, d in pairs(e) do pcall(function() d:Remove() end) end
        espCache[p] = nil
    end
end)

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
-- UI
-- ============================================================
local function mk(class, props, parent) return new(class, props, parent) end

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = o
    return c
end

local function stroke(o, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or Color3.fromRGB(50, 52, 62)
    s.Thickness = th or 1
    s.Parent = o
    return s
end

local ACCENT = Color3.fromRGB(96, 178, 255)
local AMBER  = Color3.fromRGB(255, 176, 74)
local BG     = Color3.fromRGB(16, 17, 21)
local PANEL  = Color3.fromRGB(24, 26, 32)
local ROW    = Color3.fromRGB(30, 33, 40)
local TXT    = Color3.fromRGB(228, 232, 240)
local DIM    = Color3.fromRGB(132, 140, 155)

local gui = mk("ScreenGui", {
    Name = "KennexHub", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local okGui = pcall(function() gui.Parent = CoreGui end)
if not okGui then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = mk("Frame", {
    Size = UDim2.fromOffset(468, 322),
    Position = UDim2.new(0, 40, 0, 90),
    BackgroundColor3 = BG, BorderSizePixel = 0,
}, gui)
corner(main, 10); stroke(main, Color3.fromRGB(58, 62, 74), 1)

local bar = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = PANEL, BorderSizePixel = 0,
}, main)
corner(bar, 10)

mk("TextLabel", {
    Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(12, 0),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
    TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left,
    Text = "KENNEX  v43   ·   CHARGE FORÇADO",
}, bar)

local closeBtn = mk("TextButton", {
    Size = UDim2.fromOffset(26, 22), Position = UDim2.new(1, -34, 0, 6),
    BackgroundColor3 = Color3.fromRGB(52, 30, 34), BorderSizePixel = 0,
    Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(255, 130, 130),
    Text = "X", AutoButtonColor = false,
}, bar)
corner(closeBtn, 5)
closeBtn.MouseButton1Click:Connect(function()
    S.open = false
    main.Visible = false
end)

-- arrastar
local dragging, dragStart, startPos
conn(bar.InputBegan, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = i.Position
        startPos = main.Position
    end
end)
conn(UIS.InputChanged, function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)
conn(UIS.InputEnded, function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

conn(UIS.InputBegan, function(i, gpe)
    if gpe then return end
    if i.KeyCode == S.uiKey then
        S.open = not S.open
        main.Visible = S.open
    end
end)

-- abas
local tabBar = mk("Frame", {
    Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 40),
    BackgroundTransparency = 1,
}, main)
mk("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local content = mk("Frame", {
    Size = UDim2.new(1, -16, 1, -74), Position = UDim2.fromOffset(8, 72),
    BackgroundTransparency = 1, ClipsDescendants = true,
}, main)

local pages, tabBtns = {}, {}
local order = { "COMBATE", "VISUAL", "MOVER", "ACAO", "MOVIM" }

for i, name in ipairs(order) do
    local b = mk("TextButton", {
        Size = UDim2.fromOffset(84, 26), BackgroundColor3 = ROW, BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = DIM,
        Text = name, AutoButtonColor = false, LayoutOrder = i,
    }, tabBar)
    corner(b, 6)
    tabBtns[name] = b

    local p = mk("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(70, 74, 88),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, content)
    mk("UIListLayout", {
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
    }, p)
    pages[name] = p
end

local function selectTab(name)
    for n, b in pairs(tabBtns) do
        b.BackgroundColor3 = (n == name) and ACCENT or ROW
        b.TextColor3 = (n == name) and Color3.fromRGB(12, 16, 22) or DIM
    end
    for n, p in pairs(pages) do p.Visible = (n == name) end
end

for name, b in pairs(tabBtns) do
    b.MouseButton1Click:Connect(function() selectTab(name) end)
end

-- construtores
local function card(page, title, accent)
    local c = mk("Frame", {
        Size = UDim2.new(1, -6, 0, 0), BackgroundColor3 = PANEL,
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y,
    }, page)
    corner(c, 8); stroke(c, Color3.fromRGB(48, 52, 62), 1)
    mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, c)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    }, c)
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = accent or ACCENT, Text = title, LayoutOrder = 0,
    }, c)
    local body = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1,
    }, c)
    mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    return body
end

local function row(parent, h)
    local r = mk("Frame", {
        Size = UDim2.new(1, 0, 0, h or 22), BackgroundColor3 = ROW, BorderSizePixel = 0,
    }, parent)
    corner(r, 5)
    return r
end

local function toggle(parent, label, key, accent)
    local r = row(parent)
    mk("TextLabel", {
        Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, r)
    local sw = mk("Frame", {
        Size = UDim2.fromOffset(34, 16), Position = UDim2.new(1, -42, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(52, 56, 66), BorderSizePixel = 0,
    }, r)
    corner(sw, 8)
    local knob = mk("Frame", {
        Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(190, 195, 205), BorderSizePixel = 0,
    }, sw)
    corner(knob, 6)

    local function paint()
        local on = S[key]
        sw.BackgroundColor3 = on and (accent or ACCENT) or Color3.fromRGB(52, 56, 66)
        knob.Position = on and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
        knob.BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(190, 195, 205)
    end

    local btn = mk("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
    }, r)
    btn.MouseButton1Click:Connect(function()
        S[key] = not S[key]
        paint()
    end)
    paint()
    return r
end

local function slider(parent, label, key, min, max, step, accent, fmt)
    local holder = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = ROW, BorderSizePixel = 0,
    }, parent)
    corner(holder, 5)

    local lbl = mk("TextLabel", {
        Size = UDim2.new(1, -60, 0, 16), Position = UDim2.fromOffset(8, 3),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, holder)

    local val = mk("TextLabel", {
        Size = UDim2.fromOffset(52, 16), Position = UDim2.new(1, -60, 0, 3),
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = accent or ACCENT, TextXAlignment = Enum.TextXAlignment.Right,
        Text = tostring(S[key]),
    }, holder)

    local track = mk("Frame", {
        Size = UDim2.new(1, -16, 0, 5), Position = UDim2.fromOffset(8, 24),
        BackgroundColor3 = Color3.fromRGB(48, 52, 62), BorderSizePixel = 0,
    }, holder)
    corner(track, 3)

    local fill = mk("Frame", {
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
        local v = min + rel * (max - min)
        v = math.floor(v / step + 0.5) * step
        S[key] = math.clamp(v, min, max)
        paint()
    end

    local grab = mk("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
    }, holder)
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
    local b = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = accent or ACCENT,
        BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = Color3.fromRGB(12, 16, 22), Text = label, AutoButtonColor = false,
    }, parent)
    corner(b, 5)
    b.MouseButton1Click:Connect(function() pcall(fn) end)
    return b
end

local function info(parent, text, color)
    local l = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1,
        Font = Enum.Font.Code, TextSize = 10, TextColor3 = color or DIM,
        TextXAlignment = Enum.TextXAlignment.Left, Text = text, TextWrapped = true,
    }, parent)
    return l
end

-- ---------------- COMBATE ----------------
local pg = pages.COMBATE
local c1 = card(pg, "ATAQUE AUTOMÁTICO")
toggle(c1, "AUTO SPIKE", "autoSpike")
slider(c1, "distância", "spikeDist", 6, 45, 1)
toggle(c1, "AUTO BUMP", "autoBump")
slider(c1, "distância (bump)", "bumpDist", 4, 30, 1)

local c2 = card(pg, "HITBOX")
toggle(c2, "HITBOX EXPANDIDA", "hitbox")
slider(c2, "multiplicador", "hitboxSize", 1, 6, 0.1, nil, function(v) return string.format("%.1fx", v) end)

local c3 = card(pg, "MIRA")
toggle(c3, "AIM ASSIST", "aim")
slider(c3, "campo (px)", "aimFov", 40, 400, 5)
slider(c3, "suavidade", "aimSmooth", 0.05, 1, 0.05, nil, function(v) return string.format("%.2f", v) end)

local c4 = card(pg, "SUPER SPIKE")
toggle(c4, "SUPER SPIKE", "superSpike")
slider(c4, "força", "ssPower", 20, 140, 2)
button(c4, "EXECUTAR SUPER SPIKE", superSpike, AMBER)

-- ---------------- VISUAL ----------------
local v1 = card(pages.VISUAL, "ESP")
toggle(v1, "ESP ATIVO", "esp")
toggle(v1, "CAIXA", "espBox")
toggle(v1, "NOME + DISTÂNCIA", "espName")
toggle(v1, "TRACER", "espTracer")
toggle(v1, "BOLA", "espBall")
info(v1, "Drawing API necessária para o ESP.")

-- ---------------- MOVER ----------------
local m1 = card(pages.MOVER, "REMOTES")
toggle(m1, "SERVE REMOTO", "remoteServe")
toggle(m1, "SPIKE REMOTO", "remoteSpike")
toggle(m1, "INFINITE (INF)", "remoteInf")
button(m1, "DISPARAR SPIKE REMOTO", function()
    fireRemote("spike", S.lastSpike)
end)
button(m1, "DISPARAR SERVE REMOTO", function()
    fireRemote("serve", S.lastServe)
end)
info(m1, "Remotes capturados pelo hook de InvokeServer.")

-- ---------------- ACAO ----------------
local a1 = card(pages.ACAO, "CHARGE FORÇADO", AMBER)
toggle(a1, "CHARGE EM TODO ATAQUE", "lunge", AMBER)
slider(a1, "tempo do passo", "lungeTime", 0.04, 0.35, 0.01, AMBER, function(v) return string.format("%.2fs", v) end)
slider(a1, "velocidade do passo", "lungeSpeed", 8, 60, 1, AMBER)
local ncNote = info(a1, "status: aguardando", DIM)

local a2 = card(pages.ACAO, "CARGA MANUAL")
toggle(a2, "SEGURAR ATAQUE", "holdCharge")
slider(a2, "tempo segurando", "chargeHold", 0.05, 0.9, 0.05, nil, function(v) return string.format("%.2fs", v) end)
toggle(a2, "BARRA TRAVADA", "barLock")
slider(a2, "alvo da barra (%)", "pinPct", 10, 100, 1)

local a3 = card(pages.ACAO, "AUTO HABILIDADE")
toggle(a3, "AUTO HABILIDADE", "autoAbility")
slider(a3, "intervalo", "abilityDelay", 0.3, 5, 0.1, nil, function(v) return string.format("%.1fs", v) end)

local a4 = card(pages.ACAO, "TILT")
toggle(a4, "TILT DE CÂMERA", "tilt")
slider(a4, "ângulo", "tiltAngle", -30, 30, 1)

button(pages.ACAO, "ATACAR AGORA (charge)", doAttack, AMBER)

-- ---------------- MOVIM ----------------
local mv = card(pages.MOVIM, "MOVIMENTO")
slider(mv, "WALKSPEED", "walkspeed", 16, 120, 1)
slider(mv, "JUMPPOWER", "jumppower", 30, 200, 1)
toggle(mv, "AUTO ROTATE", "autorot")

selectTab("COMBATE")

-- ============================================================
-- APLICAÇÃO DE MOVIM
-- ============================================================
local function applyLive()
    local hum = getHum()
    if not hum then return end
    pcall(function()
        hum.WalkSpeed = S.walkspeed
        hum.JumpPower = S.jumppower
        hum.UseJumpPower = true
        hum.AutoRotate = S.autorot
    end)
end

conn(LP.CharacterAdded or LP.CharacterAdded, function()
    task.wait(1)
    applyLive()
end)

task.spawn(function()
    while S.alive do
        applyLive()
        task.wait(0.5)
    end
end)

-- ============================================================
-- LOOPS DE COMBATE
-- ============================================================
local function ballValid(ball, maxD)
    local root = getRoot()
    if not ball or not root then return false end
    if dist(root, ball) > maxD then return false end
    return true
end

conn(RS.Heartbeat, function()
    if not S.alive then return end
    if tick() - S.lastAtk < 0.35 then return end

    local ball = getBall()
    if not ball then return end
    local root = getRoot()
    if not root then return end

    if S.autoSpike and ballValid(ball, S.spikeDist) then
        local rel = ball.Position - root.Position
        if rel.Y > -1 then
            doAttack()
            return
        end
    end

    if S.autoBump and ballValid(ball, S.bumpDist) then
        local rel = ball.Position - root.Position
        if rel.Y <= 1 then
            doAttack()
        end
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
-- RENDER
-- ============================================================
conn(RS.RenderStepped, function()
    if not S.alive then return end
    applyAim()
    applyTilt()
    updateESP()
end)

-- nota do card de charge
task.spawn(function()
    while S.alive do
        local hum = getHum()
        if not hum then
            ncNote.Text = "status: sem personagem"
            ncNote.TextColor3 = DIM
        elseif not S.lunge then
            ncNote.Text = "status: desligado"
            ncNote.TextColor3 = DIM
        elseif hum.MoveDirection.Magnitude > 0.15 then
            ncNote.Text = "status: andando (lunge em espera)"
            ncNote.TextColor3 = DIM
        elseif S.lungeActive then
            ncNote.Text = "status: IMPULSO ATIVO"
            ncNote.TextColor3 = AMBER
        else
            ncNote.Text = "status: pronto (parado)"
            ncNote.TextColor3 = Color3.fromRGB(120, 220, 160)
        end
        task.wait(0.12)
    end
end)

installHook()

pcall(function()
    local n = Instance.new("TextLabel")
    n:Destroy()
end)

print("[KENNEX v43] carregado - charge forcado ativo")

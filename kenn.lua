--[[ KENNEX HUB v31 · Volleyball Legends
     · abas: COMBATE / VISUAL / MOVER / ACAO / MOVIM
     · v31: cartoes com AutomaticSize + build por pagina isolado
     · v31: movimento corrigido (rot no ar, cooldown de pulo, restore de ws/jp)
     · hitbox = esfera cliente na bola · releaseAll por hide()
]]
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local VIM        = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Tween      = game:GetService("TweenService")
local RS         = game:GetService("ReplicatedStorage")

local genv = getgenv()
local function out(...)
    local t = { ... }
    for i = 1, #t do t[i] = tostring(t[i]) end
    print("[KNX] " .. table.concat(t, " "))
end

local LP = Players.LocalPlayer
if not LP then
    local t = os.clock() + 8
    repeat task.wait(0.1) LP = Players.LocalPlayer until LP or os.clock() > t
end
if not LP then out("sem LocalPlayer") return end
if genv.__KNX then pcall(genv.__KNX) end

local PLACES = {
    [73956553001240] = true, [74691681039273] = true, [85395484560711] = true,
    [86789627188240] = true, [96802054849934] = true, [102580589030177] = true,
    [103521881639626] = true, [109684591839194] = true, [117134837736236] = true,
    [134314141048307] = true,
}
local GAMES = { [6931042565] = true }

local CFG = { cd = 0.09, lead = 0.14, pad = 0.5, scan = 0.3,
    maxModelMag = 30, maxModelParts = 60, maxCand = 40, radCap = 6,
    maxHBmag = 12, maxOut = 24, minHBmag = 0.1, eps = 0.02, jumpCd = 0.4 }

local S = {
    alive = true, ball = nil, box = nil, prev = nil, vel = Vector3.zero,
    balls = {}, tier = {}, baseRad = {}, charRad = 2, charT = 0, live = {},
    hits = 0, lastPress = 0, pick = false, manual = nil, btn = nil, btnT = 0,
    uiT = 0, scanT = 0, hbT = 0, forced = nil, conns = {}, hbMode = "off",
    gravBase = workspace.Gravity, supported = false, camActive = false, camBase = nil,
    abilBtn = nil, abilT = 0, abilScanT = 0, chgT = 0, chgKey = nil, chgHost = nil,
    tiltHold = 0, netCache = nil, netT = 0, abilFail = 0,
    jumpT = 0, wsBase = nil, jpBase = nil, rotBase = nil,
}

local function bind(c) S.conns[#S.conns + 1] = c; return c end

local State = {
    hbOn = true, hbMult = 3, hbClient = true, hbReal = true, hbQuery = true,
    ring = true, tracer = true, traj = true, esp = true, hp = true, hideMate = false,
    useDraw = false,
    aim = true, fovRing = true, aimFov = 55, aimSpeed = 9, aimRange = 90, camFov = 0,
    autoRecv = false, autoSpike = false, jump = false, autoRot = false,
    reach = 9, spikeH = 6, spikeR = 8, hold = 0.03, mode = 1,
    gravOn = false, gravPct = 100, wsOn = false, ws = 16, jpOn = false, jp = 50,
    sSpike = 1, sBump = 1, sSet = 1, sBlock = 1, sDive = 1, sSpeed = 1,
    sJump = 1, sTilt = 1, sServe = 1,
    autoAbility = false, abilDelay = 0.35, forceCharge = false, chargePct = 100,
    tiltMode = 1,
}
local MODES = { "CLIQUE NA BOLA", "BOTAO", "MANUAL" }
local TILTS = { "OFF", "RETA", "DIAGONAL", "INVERTIDO", "REDE" }

local C = {
    bg = Color3.fromRGB(10, 7, 18), surface = Color3.fromRGB(19, 13, 30),
    card = Color3.fromRGB(23, 16, 36), inset = Color3.fromRGB(14, 10, 22),
    line = Color3.fromRGB(46, 32, 70), accent = Color3.fromRGB(139, 92, 246),
    accent2 = Color3.fromRGB(196, 162, 255), text = Color3.fromRGB(243, 240, 252),
    dim = Color3.fromRGB(130, 122, 152), green = Color3.fromRGB(74, 222, 128),
    red = Color3.fromRGB(248, 113, 113), amber = Color3.fromRGB(251, 191, 36),
}
local D3 = {
    ring = Color3.fromRGB(0, 235, 255), tracer = Color3.fromRGB(178, 122, 255),
    land = Color3.fromRGB(251, 191, 36), traj = Color3.fromRGB(251, 191, 36),
    enemy = Color3.fromRGB(248, 113, 113), mate = Color3.fromRGB(96, 165, 250),
    solo = Color3.fromRGB(74, 222, 128), fov = Color3.fromRGB(139, 92, 246),
}

local DRAW = nil
pcall(function() local t = Drawing.new("Circle"); t:Remove(); DRAW = Drawing end)

local gpar
if type(gethui) == "function" then local ok, h = pcall(gethui); if ok and h then gpar = h end end
if not gpar then
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then
        local ok2 = pcall(function() local f = Instance.new("Frame"); f.Parent = cg; f:Destroy() end)
        if ok2 then gpar = cg end
    end
end
if not gpar then gpar = LP:WaitForChild("PlayerGui") end

local function mk(cls, props, par)
    local o = Instance.new(cls)
    local p = par
    if props then
        for k, v in pairs(props) do
            if k == "Parent" then p = v else pcall(function() o[k] = v end) end
        end
    end
    if p then o.Parent = p end
    return o
end
local function safe(f) local ok, e = pcall(f); if not ok then out("ERRO", e) end return ok end

local UI = {}

--// ===================== DESENHO =====================
local pool = { ring = {}, dot = {}, tracer = {}, land = {}, traj = {} }

local function makeCircle(col, thick, trans, filled)
    if DRAW and State.useDraw then
        local c = DRAW.new("Circle")
        c.Color = col; c.Thickness = thick or 1.5; c.NumSides = 72
        c.Filled = filled or false; c.Transparency = trans or 0.1; c.Visible = false
        return { set = function(x, y, r, cc, v)
            c.Position = Vector2.new(x, y); c.Radius = r
            if cc then c.Color = cc end; c.Visible = v end,
            hide = function() c.Visible = false end,
            rm = function() pcall(function() c:Remove() end) end }
    end
    local f = mk("Frame", { BackgroundTransparency = filled and 0.15 or 1,
        BackgroundColor3 = col, BorderSizePixel = 0, Visible = false }, UI.gui)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
    local st
    if not filled then st = mk("UIStroke", { Color = col, Thickness = thick or 1.5 }, f) end
    return { set = function(x, y, r, cc, v)
        f.Size = UDim2.fromOffset(r * 2, r * 2); f.Position = UDim2.fromOffset(x - r, y - r)
        if cc then
            if st then st.Color = cc else f.BackgroundColor3 = cc end
        end
        f.Visible = v end,
        hide = function() f.Visible = false end,
        rm = function() pcall(function() f:Destroy() end) end }
end

local function makeLine(col)
    if DRAW and State.useDraw then
        local l = DRAW.new("Line")
        l.Color = col; l.Thickness = 1.3; l.Transparency = 0.35; l.Visible = false
        return { set = function(a, b, cc, v)
            l.From = a; l.To = b; if cc then l.Color = cc end; l.Visible = v end,
            hide = function() l.Visible = false end,
            rm = function() pcall(function() l:Remove() end) end }
    end
    local f = mk("Frame", { BackgroundColor3 = col, BorderSizePixel = 0,
        BackgroundTransparency = 0.35, Visible = false }, UI.gui)
    return { set = function(a, b, cc, v)
        local dv = b - a
        f.Position = UDim2.fromOffset(a.X, a.Y); f.Size = UDim2.fromOffset(dv.Magnitude, 1)
        f.Rotation = math.deg(math.atan2(dv.Y, dv.X))
        if cc then f.BackgroundColor3 = cc end; f.Visible = v end,
        hide = function() f.Visible = false end,
        rm = function() pcall(function() f:Destroy() end) end }
end

local function makeText(col, sz)
    if DRAW and State.useDraw then
        local t = DRAW.new("Text")
        t.Color = col; t.Size = sz or 10; t.Center = true; t.Outline = true
        t.OutlineColor = Color3.new(0, 0, 0); t.Visible = false
        return { set = function(x, y, s, cc, v)
            t.Position = Vector2.new(x, y); t.Text = tostring(s)
            if cc then t.Color = cc end; t.Visible = v end,
            hide = function() t.Visible = false end,
            rm = function() pcall(function() t:Remove() end) end }
    end
    local l = mk("TextLabel", { Size = UDim2.fromOffset(170, 14), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = sz or 10, TextColor3 = col,
        TextStrokeTransparency = 0.3, Visible = false }, UI.gui)
    return { set = function(x, y, s, cc, v)
        l.Position = UDim2.fromOffset(x - 85, y); l.Text = tostring(s)
        if cc then l.TextColor3 = cc end; l.Visible = v end,
        hide = function() l.Visible = false end,
        rm = function() pcall(function() l:Destroy() end) end }
end

local function grab(list, maker, arg)
    for _, o in ipairs(list) do if not o.busy then o.busy = true return o end end
    local o = maker(arg); o.busy = true; list[#list + 1] = o; return o
end
local function releaseAll(list)
    for _, o in ipairs(list) do
        if o.busy then o.busy = false; pcall(o.hide) end
    end
end

--// ===================== DASHBOARD =====================
local pages, pillOf = {}, {}
local activeTab = 0
local cardH, cardPg = {}, {}

local function setStatus(txt, col)
    if not UI.stLbl then return end
    UI.stLbl.Text = txt
    if col then UI.stLbl.TextColor3 = col end
end

local function showTab(i)
    if activeTab == i then return end
    activeTab = i
    for k, p in pairs(pages) do p.page.Visible = (k == i) end
    for k, b in pairs(pillOf) do
        local on = k == i
        Tween:Create(b, TweenInfo.new(0.12),
            { BackgroundColor3 = on and C.accent or C.card }):Play()
        b.TextColor3 = on and C.text or C.dim
    end
end

local function bump() end
local function addRow() end

local function card(pg, order, label)
    local c = mk("Frame", { Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.card,
        BorderSizePixel = 0, LayoutOrder = order }, pg.list)
    mk("UICorner", { CornerRadius = UDim.new(0, 12) }, c)
    mk("UIStroke", { Color = C.line, Thickness = 1, Transparency = 0.35 }, c)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, c)
    mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, c)
    if label then
        mk("TextLabel", { Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1,
            Text = "  " .. label, Font = Enum.Font.GothamBold, TextSize = 8,
            TextColor3 = C.accent2, TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 0 }, c)
    end
    return c
end

local function switch(c, label, key, order, cb)
    local row = mk("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.surface,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = order }, c)
    mk("UICorner", { CornerRadius = UDim.new(0, 9) }, row)
    mk("UIStroke", { Color = C.line, Thickness = 1, Transparency = 0.55 }, row)
    mk("TextLabel", { Size = UDim2.new(1, -54, 1, 0), Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1, Text = label, Font = Enum.Font.GothamMedium,
        TextSize = 10, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
    local track = mk("Frame", { Size = UDim2.fromOffset(34, 17), Position = UDim2.new(1, -44, 0.5, -8),
        BackgroundColor3 = C.inset, BorderSizePixel = 0 }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    local knob = mk("Frame", { Size = UDim2.fromOffset(13, 13), Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = C.dim, BorderSizePixel = 0 }, track)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
    local function paint()
        local on = State[key]
        Tween:Create(track, TweenInfo.new(0.13), { BackgroundColor3 = on and C.accent or C.inset }):Play()
        Tween:Create(knob, TweenInfo.new(0.13),
            { Position = on and UDim2.fromOffset(19, 2) or UDim2.fromOffset(2, 2),
              BackgroundColor3 = on and C.text or C.dim }):Play()
    end
    row.Activated:Connect(function()
        State[key] = not State[key]
        paint()
        if cb then safe(function() cb(State[key]) end) end
    end)
    paint()
end

local function slider(c, label, key, order, min, max, fmt, step, cb)
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 37), BackgroundColor3 = C.surface,
        BorderSizePixel = 0, LayoutOrder = order }, c)
    mk("UICorner", { CornerRadius = UDim.new(0, 9) }, row)
    mk("UIStroke", { Color = C.line, Thickness = 1, Transparency = 0.55 }, row)
    mk("TextLabel", { Size = UDim2.new(1, -58, 0, 14), Position = UDim2.fromOffset(10, 4),
        BackgroundTransparency = 1, Text = label, Font = Enum.Font.GothamMedium,
        TextSize = 10, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
    local val = mk("TextLabel", { Size = UDim2.fromOffset(44, 13), Position = UDim2.new(1, -52, 0, 4),
        BackgroundColor3 = C.inset, BorderSizePixel = 0, Text = tostring(State[key]),
        Font = Enum.Font.Code, TextSize = 9, TextColor3 = C.accent2 }, row)
    mk("UICorner", { CornerRadius = UDim.new(0, 5) }, val)
    local track = mk("Frame", { Size = UDim2.new(1, -20, 0, 5), Position = UDim2.fromOffset(10, 25),
        BackgroundColor3 = C.inset, BorderSizePixel = 0 }, row)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    local fill = mk("Frame", { Size = UDim2.fromScale(0.3, 1), BackgroundColor3 = C.accent,
        BorderSizePixel = 0 }, track)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    local grip = mk("Frame", { Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.3, 0, 0.5, 0), BackgroundColor3 = C.text, BorderSizePixel = 0 }, track)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, grip)
    local hit = mk("TextButton", { Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, 19),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, row)

    local function setVal(v)
        v = math.clamp(v, min, max)
        if step then v = math.floor(v / step + 0.5) * step end
        v = math.floor(v * 100 + 0.5) / 100
        State[key] = v
        local a = (v - min) / (max - min)
        fill.Size = UDim2.fromScale(a, 1)
        grip.Position = UDim2.new(a, 0, 0.5, 0)
        val.Text = fmt and fmt(v) or tostring(v)
        if cb then safe(function() cb(v) end) end
    end
    setVal(State[key])

    local function fromX(x)
        local ap, as = track.AbsolutePosition, track.AbsoluteSize
        if as.X <= 0 then return end
        setVal(min + (max - min) * math.clamp((x - ap.X) / as.X, 0, 1))
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            fromX(i.Position.X)
        end
    end)
    hit.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
            or i.UserInputType == Enum.UserInputType.MouseMovement then fromX(i.Position.X) end
    end)
end

local function button(c, txt, order, cb, col)
    local b = mk("TextButton", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.surface,
        BorderSizePixel = 0, Text = txt, Font = Enum.Font.GothamBold, TextSize = 9,
        TextColor3 = col or C.text, AutoButtonColor = false, LayoutOrder = order }, c)
    mk("UICorner", { CornerRadius = UDim.new(0, 9) }, b)
    mk("UIStroke", { Color = C.line, Thickness = 1, Transparency = 0.55 }, b)
    b.Activated:Connect(function() safe(cb) end)
    return b
end

local function note(c, txt, order, col)
    local l = mk("TextLabel", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
        Text = txt, Font = Enum.Font.Gotham, TextSize = 8, TextColor3 = col or C.dim,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order }, c)
    return l
end

local function makePage(i)
    local page = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Visible = false }, UI.content)
    local scroll = mk("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y }, page)
    local list = mk("Frame", { Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, scroll)
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, list)
    pages[i] = { page = page, scroll = scroll, list = list, h = 16 }
end

local ballRoot, pressPoint, press, restoreAll, rebuildDraw, servePath

local function buildUI()
    local vs = Vector2.new(800, 450)
    local c0 = workspace.CurrentCamera
    if c0 then vs = c0.ViewportSize end

    local W = math.clamp(math.floor(vs.X * 0.66), 250, 310)
    local H = math.clamp(math.floor(vs.Y * 0.68), 280, 420)
    local px = 12
    local py = math.max(10, math.floor(vs.Y * 0.10))

    local gui = mk("ScreenGui", { Name = "KennexHub", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 9999 }, gpar)
    UI.gui = gui

    local win = mk("Frame", { Size = UDim2.fromOffset(W, H), Position = UDim2.fromOffset(px, py),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true, ClipsDescendants = true }, gui)
    UI.win = win
    mk("UICorner", { CornerRadius = UDim.new(0, 16) }, win)
    mk("UIStroke", { Color = C.accent, Thickness = 1, Transparency = 0.45 }, win)

    local head = mk("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.surface,
        BorderSizePixel = 0, ZIndex = 3, Active = true }, win)
    UI.head = head
    mk("UICorner", { CornerRadius = UDim.new(0, 16) }, head)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = C.surface, BorderSizePixel = 0 }, head)
    mk("UIGradient", { Color = ColorSequence.new(C.accent2, C.accent), Rotation = 90,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.78),
            NumberSequenceKeypoint.new(1, 1) }) }, head)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, BackgroundTransparency = 0.3 }, head)

    local logo = mk("TextLabel", { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(12, 11),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = "K",
        Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = C.text, ZIndex = 6 }, head)
    mk("UICorner", { CornerRadius = UDim.new(0, 7) }, logo)
    mk("UIGradient", { Color = ColorSequence.new(C.accent2, C.accent), Rotation = 45 }, logo)

    local title = mk("TextLabel", { Size = UDim2.fromOffset(140, 16), Position = UDim2.fromOffset(42, 8),
        BackgroundTransparency = 1, Text = "KENNEX", Font = Enum.Font.GothamBlack,
        TextSize = 15, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 }, head)
    mk("UIGradient", { Color = ColorSequence.new(C.accent2, C.accent), Rotation = 25 }, title)
    mk("TextLabel", { Size = UDim2.fromOffset(160, 10), Position = UDim2.fromOffset(42, 24),
        BackgroundTransparency = 1, Text = "one hub · multiple plays", Font = Enum.Font.Gotham,
        TextSize = 8, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 }, head)
    local pill = mk("TextLabel", { Size = UDim2.fromOffset(28, 12), Position = UDim2.fromOffset(12, 31),
        BackgroundColor3 = C.inset, BorderSizePixel = 0, Text = "V31",
        Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = C.accent2, ZIndex = 6 }, head)
    mk("UICorner", { CornerRadius = UDim.new(0, 4) }, pill)
    local dot = mk("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(45, 34),
        BackgroundColor3 = C.red, BorderSizePixel = 0, ZIndex = 6 }, head)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
    UI.dot = dot

    local dragBar = mk("TextButton", { Size = UDim2.new(1, -74, 0, 46), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, Active = true, ZIndex = 4 }, head)
    UI.dragBar = dragBar

    local function headBtn(txt, xoff, col, size)
        local b = mk("TextButton", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, xoff, 0, 10),
            BackgroundColor3 = C.inset, BorderSizePixel = 0, Text = txt, Font = Enum.Font.GothamBold,
            TextSize = size or 14, TextColor3 = col or C.dim, AutoButtonColor = false, ZIndex = 7 }, head)
        mk("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
        mk("UIStroke", { Color = C.line, Thickness = 1, Transparency = 0.4 }, b)
        return b
    end
    local offBtn = headBtn("OFF", -92, C.red, 8)
    local minBtn = headBtn("×", -60, C.text, 16)

    local TABS = { "COMBATE", "VISUAL", "MOVER", "ACAO", "MOVIM" }
    local tabRow = mk("Frame", { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 52),
        BackgroundTransparency = 1, ZIndex = 2 }, win)
    mk("UIListLayout", { Padding = UDim.new(0, 4), FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }, tabRow)

    local content = mk("Frame", { Size = UDim2.new(1, -20, 1, -134), Position = UDim2.fromOffset(10, 82),
        BackgroundTransparency = 1, ClipsDescendants = true }, win)
    UI.content = content

    local foot = mk("Frame", { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 1, -50),
        BackgroundColor3 = C.inset, BorderSizePixel = 0 }, win)
    mk("UICorner", { CornerRadius = UDim.new(0, 10) }, foot)
    mk("UIStroke", { Color = C.line, Thickness = 1, Transparency = 0.5 }, foot)
    local stLbl = mk("TextLabel", { Size = UDim2.new(1, -104, 1, -8), Position = UDim2.fromOffset(7, 4),
        BackgroundTransparency = 1, Text = "procurando bola", Font = Enum.Font.Code, TextSize = 8,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true }, foot)
    UI.stLbl = stLbl

    local function footBtn(txt, xoff, w, col, cb)
        local b = mk("TextButton", { Size = UDim2.fromOffset(w, 24), Position = UDim2.new(1, xoff, 0.5, -12),
            BackgroundColor3 = C.surface, BorderSizePixel = 0, Text = txt,
            Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = col or C.dim,
            AutoButtonColor = false }, foot)
        mk("UICorner", { CornerRadius = UDim.new(0, 7) }, b)
        mk("UIStroke", { Color = C.line, Thickness = 1, Transparency = 0.5 }, b)
        b.Activated:Connect(function() safe(cb) end)
        return b
    end
    local modeBtn = footBtn("MODO 1", -94, 46, C.text, function()
        State.mode = (State.mode % #MODES) + 1
        modeBtn.Text = "MODO " .. State.mode
        setStatus("modo: " .. MODES[State.mode])
    end)
    footBtn("BOLA", -44, 38, C.accent2, function()
        S.pick = true
        setStatus("TOQUE NA BOLA", C.accent2)
    end)

    local icon = mk("TextButton", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(px, py),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = "K", Font = Enum.Font.GothamBlack,
        TextSize = 18, TextColor3 = C.text, AutoButtonColor = false, Active = true,
        Visible = false }, gui)
    UI.icon = icon
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, icon)
    mk("UIStroke", { Color = C.accent2, Thickness = 1, Transparency = 0.3 }, icon)
    mk("UIGradient", { Color = ColorSequence.new(C.accent2, C.accent), Rotation = 45 }, icon)

    local minimized = false
    local function setMin(v)
        minimized = v
        if v then
            icon.Position = win.Position
            icon.Visible = true
            win.Visible = false
        else
            win.Position = icon.Position
            icon.Visible = false
            win.Visible = true
        end
    end
    UI.setMin = setMin
    minBtn.Activated:Connect(function() setMin(true) end)
    icon.Activated:Connect(function() if minimized then setMin(false) end end)
    offBtn.Activated:Connect(function() if genv.__KNX then genv.__KNX() end end)

    for i, name in ipairs(TABS) do
        local b = mk("TextButton", { Size = UDim2.new(0.2, -4, 1, 0), BackgroundColor3 = C.card,
            BorderSizePixel = 0, Text = name, Font = Enum.Font.GothamBold, TextSize = 8,
            TextColor3 = C.dim, AutoButtonColor = false, LayoutOrder = i }, tabRow)
        mk("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
        mk("UIStroke", { Color = C.line, Thickness = 1, Transparency = 0.5 }, b)
        b.Activated:Connect(function() showTab(i) end)
        pillOf[i] = b
        makePage(i)
    end

    local drag, st, off, target = false, nil, nil, nil
    local function start(obj, x, y)
        drag = true
        target = obj
        st = Vector2.new(x, y)
        off = Vector2.new(obj.Position.X.Offset, obj.Position.Y.Offset)
    end
    local function move(x, y)
        if not drag or not target then return end
        local d = Vector2.new(x, y) - st
        target.Position = UDim2.fromOffset(off.X + d.X, off.Y + d.Y)
    end
    local function stop()
        drag = false
        if minimized and icon then win.Position = icon.Position end
    end
    local function hook(obj, getter)
        obj.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.Touch
                and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            start(getter(), i.Position.X, i.Position.Y)
        end)
        obj.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch
                or i.UserInputType == Enum.UserInputType.MouseMovement then move(i.Position.X, i.Position.Y) end
        end)
        obj.InputEnded:Connect(stop)
    end
    hook(dragBar, function() return win end)
    hook(icon, function() return icon end)

    return true
end

--// ===================== CONTEUDO =====================
local function buildPages()
    local function pg(i) return pages[i] end

    local function block(name, fn)
        local ok, e = pcall(fn)
        if not ok then
            out("FALHA CARD", name, tostring(e))
            local p = pages[1]
            if p then
                local c = card(p, 90, name)
                note(c, "erro: " .. tostring(e), 1, C.red)
            end
        end
    end

    block("COMBATE", function()
        local p = pg(1)
        local c1 = card(p, 1, "HITBOX")
        switch(c1, "HITBOX LIGADA", "hbOn", 1, function(on)
            if not on and restoreAll then restoreAll() end
        end)
        slider(c1, "MULTIPLICADOR", "hbMult", 2, 1, 12, function(v) return v .. "x" end, 0.1)
        switch(c1, "ESFERA NA BOLA", "hbClient", 3)
        switch(c1, "REFORCO SERVIDOR", "hbReal", 4)
        switch(c1, "CANQUERY", "hbQuery", 5)
        note(c1, "esfera = volume na bola · reforco = template do servidor", 6)

        local c2 = card(p, 2, "MIRA")
        switch(c2, "MIRA", "aim", 1)
        switch(c2, "ANEL FOV", "fovRing", 2)
        slider(c2, "CONE FOV", "aimFov", 3, 5, 180, function(v) return v .. "°" end, 1)
        slider(c2, "SUAVIZACAO", "aimSpeed", 4, 1, 30, function(v) return v .. "" end, 0.5)
        slider(c2, "ALCANCE", "aimRange", 5, 10, 300, function(v) return v .. "st" end, 1)
        slider(c2, "CAMERA FOV", "camFov", 6, 0, 120, function(v) return v == 0 and "off" or (v .. "°") end, 1)

        local c3 = card(p, 3, "PODER")
        local function attr(key, label, maxv, stepv, order, cr)
            slider(cr, label, key, order, 0, maxv, function(v) return v .. "x" end, stepv,
                function(v) safe(function() LP:SetAttribute(key, v) end) end)
        end
        attr("GameSpikePowerMultiplier", "FORCA SPIKE", 50, 0.1, 1, c3)
        attr("GameServePowerMultiplier", "FORCA SAQUE", 50, 0.1, 2, c3)
        attr("GameBumpPowerMultiplier", "FORCA BUMP", 50, 0.1, 3, c3)
        attr("GameSetPowerMultiplier", "FORCA SET", 50, 0.1, 4, c3)
        attr("GameBlockPowerMultiplier", "FORCA BLOQUEIO", 50, 0.1, 5, c3)
        attr("GameTiltPowerMultiplier", "FORCA TILT", 50, 0.1, 6, c3)
        attr("GameSpeedMultiplier", "VELOCIDADE", 1.5, 0.05, 7, c3)
        attr("GameJumpPowerMultiplier", "FORCA PULO", 5, 0.1, 8, c3)
        attr("GameDiveSpeedMultiplier", "VELOCIDADE DIVE", 5, 0.1, 9, c3)
    end)

    block("VISUAL", function()
        local p = pg(2)
        local c1 = card(p, 1, "LEITURA DA BOLA")
        switch(c1, "ANEL", "ring", 1)
        switch(c1, "TRACER", "tracer", 2)
        switch(c1, "TRAJETORIA", "traj", 3)
        local c2 = card(p, 2, "JOGADORES")
        switch(c2, "ESP", "esp", 1)
        switch(c2, "VIDA NO ESP", "hp", 2)
        switch(c2, "ESCONDER ALIADO", "hideMate", 3)
        local c3 = card(p, 3, "RENDER")
        switch(c3, "USAR DRAWING", "useDraw", 1, function() if rebuildDraw then rebuildDraw() end end)
        note(c3, "drawing costuma ser mais leve que frame", 2)
    end)

    block("MOVER", function()
        local p = pg(3)
        local c1 = card(p, 1, "AEREOS")
        switch(c1, "GIRAR NO AR", "autoRot", 1)
        switch(c1, "AUTO PULO", "jump", 2)
        note(c1, "girar no ar forca o corpo a acompanhar a camera durante o salto", 3)
        local c2 = card(p, 2, "GRAVIDADE")
        switch(c2, "GRAVIDADE", "gravOn", 1)
        slider(c2, "GRAVIDADE %", "gravPct", 2, 1, 100, function(v) return v .. "%" end, 1)
        note(c2, "afeta a bola tambem, nao so voce", 3)
        local c3 = card(p, 3, "CORPO")
        switch(c3, "WALKSPEED", "wsOn", 1)
        slider(c3, "WALKSPEED", "ws", 2, 1, 100, function(v) return v .. "" end, 1)
        switch(c3, "JUMPPOWER", "jpOn", 3)
        slider(c3, "JUMPPOWER", "jp", 4, 1, 200, function(v) return v .. "" end, 1)
        note(c3, "desligar devolve o valor original do jogo", 5)
    end)

    block("ACAO", function()
        local p = pg(4)
        local c1 = card(p, 1, "AUTOMACAO")
        switch(c1, "AUTO RECEPCAO", "autoRecv", 1)
        switch(c1, "AUTO SPIKE", "autoSpike", 2)
        local c2 = card(p, 2, "LEITURA DE QUEDA")
        slider(c2, "RAIO DE QUEDA", "reach", 1, 2, 25, function(v) return v .. "st" end)
        slider(c2, "ALTURA SPIKE", "spikeH", 2, 2, 20, function(v) return v .. "st" end)
        slider(c2, "RAIO SPIKE", "spikeR", 3, 2, 25, function(v) return v .. "st" end)
        note(c2, "o clique sai quando a bola cai dentro do raio", 4)
    end)

    block("MOVIM", function()
        local p = pg(5)
        local c1 = card(p, 1, "HABILIDADE")
        switch(c1, "AUTO HABILIDADE", "autoAbility", 1)
        slider(c1, "INTERVALO", "abilDelay", 2, 0.15, 5, function(v) return ("%.2fs"):format(v) end, 0.05)
        UI.abilNote = note(c1, "aciona a habilidade do estilo (Sanju, TSH, Kijo...)", 3)
        local c2 = card(p, 2, "CARGA")
        switch(c2, "CARGA FORCADA", "forceCharge", 1)
        slider(c2, "CARGA %", "chargePct", 2, 10, 100, function(v) return v .. "%" end, 1)
        UI.chgNote = note(c2, "atributo: procurando", 3)
        note(c2, "mantem a carga cheia · so funciona com estilo que carrega", 4)
        local c3 = card(p, 3, "TILT / DIRECAO")
        local tiltBtn = button(c3, "TILT: " .. TILTS[State.tiltMode], 1, function()
            State.tiltMode = (State.tiltMode % #TILTS) + 1
            tiltBtn.Text = "TILT: " .. TILTS[State.tiltMode]
            S.tiltHold = os.clock() + 0.4
        end)
        note(c3, "RETA = pela lateral · DIAGONAL = cruzado · INVERTIDO = troca o lado · REDE = toque na rede", 2)
    end)

    showTab(1)
end

--// ===================== HELPERS =====================
local function cam() return workspace.CurrentCamera end
ballRoot = function(b)
    if not b then return nil end
    if b:IsA("BasePart") then return b end
    if b:IsA("Model") then
        local p = b.PrimaryPart
        if p then return p end
        for _, d in ipairs(b:GetChildren()) do
            if d:IsA("BasePart") and not string.find(string.lower(d.Name), "knx", 1, true) then return d end
        end
        return b:FindFirstChildWhichIsA("BasePart", true)
    end
end
local function myRoot()
    local ch = LP.Character
    if not ch then return nil end
    return ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChildWhichIsA("BasePart")
end
local function isBallPart(p)
    local n = string.lower(p.Name)
    return not (string.find(n, "knx", 1, true) or string.find(n, "trail", 1, true)
        or string.find(n, "beam", 1, true))
end

local function computeRadius(b)
    local parts = b:IsA("BasePart") and { b } or {}
    if not b:IsA("BasePart") then
        for _, d in ipairs(b:GetDescendants()) do
            if d:IsA("BasePart") and isBallPart(d) then parts[#parts + 1] = d end
        end
    end
    if #parts == 0 then return 1 end
    local mn, mx
    for i = 1, math.min(#parts, 40) do
        local p = parts[i]
        local half = p.Size * 0.5
        local lo, hi = p.Position - half, p.Position + half
        if not mn then
            mn, mx = lo, hi
        else
            mn = Vector3.new(math.min(mn.X, lo.X), math.min(mn.Y, lo.Y), math.min(mn.Z, lo.Z))
            mx = Vector3.new(math.max(mx.X, hi.X), math.max(mx.Y, hi.Y), math.max(mx.Z, hi.Z))
        end
    end
    return math.clamp((mx - mn).Magnitude * 0.5, 0.4, CFG.radCap)
end

local function ballRadius(b)
    if not b then return 1 end
    local cached = S.baseRad[b]
    if cached then return cached end
    local r = computeRadius(b)
    S.baseRad[b] = r
    return r
end

local function charRad()
    if os.clock() - S.charT < 1 then return S.charRad end
    S.charT = os.clock()
    local ch = LP.Character
    if ch then
        local ok, _, sz = pcall(function() return ch:GetBoundingBox() end)
        if ok and sz then S.charRad = math.max(sz.X, sz.Z) * 0.5 end
    end
    return S.charRad
end

servePath = function()
    local p = RS:FindFirstChild("Packages")
    local idx = p and p:FindFirstChild("_Index")
    local knit = idx and idx:FindFirstChild("sleitnick_knit@1.7.0")
    local k = knit and knit:FindFirstChild("knit")
    local sv = k and k:FindFirstChild("Services")
    local g = sv and sv:FindFirstChild("GameService")
    local rf = g and g:FindFirstChild("RF")
    local s = rf and rf:FindFirstChild("Serve")
    return s
end

--// ===================== GRUPOS DE GOLPE =====================
local MOVES = {
    { "jumpset", "set" }, { "jump set", "set" }, { "spike", "spike" },
    { "block", "block" }, { "bloq", "block" }, { "bump", "def" }, { "dive", "def" },
    { "defesa", "def" }, { "set", "set" }, { "serve", "set" }, { "saque", "set" },
}

local function groupOf(name)
    local n = string.lower(name)
    for _, pair in ipairs(MOVES) do
        if string.find(n, pair[1], 1, true) then return pair[2] end
    end
end

local function moveOf(inst)
    local g = groupOf(inst.Name)
    if g then return g end
    local p = inst.Parent
    for _ = 1, 3 do
        if not p or p == workspace then break end
        g = groupOf(p.Name)
        if g then return g end
        p = p.Parent
    end
end

local function inChar(inst)
    local p = inst
    for _ = 1, 5 do
        p = p.Parent
        if not p or p == workspace then return false end
        if Players:GetPlayerFromCharacter(p) then return true end
    end
    return false
end

local BODY = { "head", "torso", "hand", "foot", "leg", "arm", "humanoidrootpart",
    "upper", "lower", "handle", "neck", "waist", "shoulder", "hip" }

local function bodyPart(name)
    local n = string.lower(name)
    for _, k in ipairs(BODY) do
        if string.find(n, k, 1, true) then return true end
    end
    return false
end

local MAPWORD = { "wall", "floor", "ceiling", "prop", "decor", "terrain", "sign",
    "glass", "window", "roof", "ground", "crate", "rock", "tree", "fence", "net",
    "post", "stand", "crowd", "banner", "light" }

local function mapWord(name)
    local n = string.lower(name)
    for _, k in ipairs(MAPWORD) do
        if string.find(n, k, 1, true) then return true end
    end
    return false
end

--// ===================== TEMPLATES =====================
local HB = nil
local hbBase = {}
local hbRetry = 0

local function folderOk(f)
    local n, small = 0, 0
    for _, d in ipairs(f:GetDescendants()) do
        if d:IsA("BasePart") then
            n += 1
            if d.Size.Magnitude <= CFG.maxHBmag then small += 1 end
            if n > 250 then break end
        end
    end
    return n > 0 and (small / n) >= 0.6
end

local function resolveHB()
    if HB and HB.Parent then return HB end
    if os.clock() < hbRetry then return HB end
    hbRetry = os.clock() + 3
    local a = RS:FindFirstChild("Assets")
    local cand = {}
    if a then
        cand[#cand + 1] = a:FindFirstChild("Hitboxes")
        cand[#cand + 1] = a:FindFirstChild("Hitbox")
    end
    cand[#cand + 1] = RS:FindFirstChild("Hitboxes")
    cand[#cand + 1] = RS:FindFirstChild("Hitbox")
    for _, c in ipairs(cand) do
        if c and c:IsA("Folder") and folderOk(c) then HB = c return HB end
    end
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("Folder") and string.find(string.lower(d.Name), "hitbox", 1, true)
            and folderOk(d) then HB = d return HB end
    end
    return nil
end

local function hbParts()
    local list = {}
    local f = resolveHB()
    if not f then return list end
    for _, d in ipairs(f:GetDescendants()) do
        if d:IsA("BasePart") then list[#list + 1] = d end
    end
    return list
end

local function templateFor(g)
    for _, p in ipairs(hbParts()) do
        local gg = groupOf(p.Name) or groupOf(p.Parent and p.Parent.Name or "")
        if gg == g and hbBase[p] then return p end
    end
end

local function cacheBase()
    for _, p in ipairs(hbParts()) do
        local m = p.Size.Magnitude
        if not hbBase[p] and m >= CFG.minHBmag and m <= CFG.maxHBmag then
            hbBase[p] = p.Size
        end
    end
end

local function applyTpl()
    for p, sz in pairs(hbBase) do
        if p.Parent and sz.Magnitude <= CFG.maxHBmag then
            local want = (State.hbOn and State.hbReal) and (sz * State.hbMult) or sz
            local mag = want.Magnitude
            if mag > CFG.maxOut then want = want * (CFG.maxOut / mag) end
            if (p.Size - want).Magnitude > CFG.eps then safe(function() p.Size = want end) end
        end
    end
end

--// ===================== HITBOX VIVA =====================
local function watchPart(part)
    if not part:IsA("BasePart") then return end
    if part.Name == "KNXBox" then return end
    if S.live[part] then return end
    local mine = inChar(part)
    local folder = resolveHB()
    local inHB = folder ~= nil and part:IsDescendantOf(folder)
    if not mine and not inHB then
        if not (groupOf(part.Name) and bodyPart(part.Name)) then return end
        if mapWord(part.Name) then return end
    end
    local g = moveOf(part)
    if not g then return end
    if part.Size.Magnitude > (mine and 40 or CFG.maxHBmag) then return end
    local tpl = templateFor(g)
    local base = (tpl and hbBase[tpl]) or part.Size
    if base.Magnitude < CFG.minHBmag then return end
    S.live[part] = { base = base, group = g, applied = part.Size,
        touch = part.CanTouch, query = part.CanQuery }
end

local function applyLive()
    if not (State.hbOn and State.hbReal) then return end
    for part, rec in pairs(S.live) do
        if not part.Parent then
            S.live[part] = nil
        else
            if rec.applied and (part.Size - rec.applied).Magnitude > 0.05
                and (part.Size - rec.base).Magnitude > 0.05 then
                rec.base = part.Size
            end
            local want = rec.base * State.hbMult
            local mag = want.Magnitude
            if mag > CFG.maxOut then want = want * (CFG.maxOut / mag) end
            if (part.Size - want).Magnitude > CFG.eps then
                safe(function() part.Size = want end)
                rec.applied = want
            else
                rec.applied = part.Size
            end
            part.CanTouch = true
            if State.hbQuery then part.CanQuery = true end
        end
    end
end

local function restoreLive()
    for p, rec in pairs(S.live) do
        if p.Parent then
            safe(function() p.Size = rec.base end)
            pcall(function() p.CanTouch = rec.touch end)
            pcall(function() p.CanQuery = rec.query end)
        end
    end
end

local function restoreTpl()
    for p, sz in pairs(hbBase) do
        if p.Parent then safe(function() p.Size = sz end) end
    end
end

restoreAll = function()
    restoreLive()
    restoreTpl()
end

local function sweepLive()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and (bodyPart(d.Name) or groupOf(d.Name)) then
            watchPart(d)
        end
    end
end

bind(workspace.DescendantAdded:Connect(function(d)
    if d:IsA("BasePart") and (bodyPart(d.Name) or groupOf(d.Name)) then watchPart(d) end
end))

--// ===================== ESFERA NA BOLA =====================
local function killBox()
    if S.box then safe(function() S.box:Destroy() end) S.box = nil end
end

local function applyBox(ball, root)
    if not (State.hbOn and State.hbClient) then killBox() return end
    local base = S.baseRad[ball]
    if not base then killBox() return end
    local d = base * State.hbMult * 2
    if not S.box or S.box.Parent ~= ball then
        killBox()
        S.box = mk("Part", { Name = "KNXBox", Shape = Enum.PartType.Ball,
            Size = Vector3.new(d, d, d), Transparency = 1, CanCollide = false,
            Anchored = true, Massless = true, CastShadow = false, CFrame = root.CFrame,
            Parent = ball, CanTouch = true, CanQuery = State.hbQuery })
    else
        S.box.CanQuery = State.hbQuery
        if math.abs(S.box.Size.X - d) > 0.05 then
            safe(function() S.box.Size = Vector3.new(d, d, d) end)
        end
        S.box.CFrame = root.CFrame
    end
end

--// ===================== BOLAS =====================
local function ballTier(b)
    local n = string.lower(b.Name)
    if string.find(n, "client_ball", 1, true) then return 3 end
    if not (string.find(n, "ball", 1, true) or string.find(n, "bola", 1, true)) then return 0 end
    if b:IsA("BasePart") then return b.CanCollide and 1 or 2 end
    for _, d in ipairs(b:GetDescendants()) do
        if d:IsA("BasePart") then
            local dn = string.lower(d.Name)
            if string.find(dn, "sphere", 1, true) or string.find(dn, "cube", 1, true)
                or string.find(dn, "ball", 1, true) then return 2 end
        end
    end
    return 1
end

local function modelOk(b)
    local n, mag, soft = 0, 0, false
    if b:IsA("BasePart") then
        mag = b.Size.Magnitude
        soft = not b.CanCollide
    else
        local piv = b:GetPivot().Position
        for _, d in ipairs(b:GetDescendants()) do
            if d:IsA("BasePart") and isBallPart(d) then
                n += 1
                if not d.CanCollide then soft = true end
                mag = math.max(mag, (d.Position - piv).Magnitude + d.Size.Magnitude)
                if n > CFG.maxModelParts then return false end
            end
        end
    end
    return soft and mag <= CFG.maxModelMag and n <= CFG.maxModelParts
end

local function register(b)
    if not b or not b.Parent or S.balls[b] then return end
    if not (b:IsA("Model") or b:IsA("BasePart")) then return end
    if not modelOk(b) then return end
    if not ballRoot(b) then return end
    if not S.baseRad[b] then S.baseRad[b] = computeRadius(b) end
    S.tier[b] = ballTier(b)
    S.balls[b] = os.clock()
end

local function scan()
    local containers = { workspace }
    local map = workspace:FindFirstChild("Map")
    if map then containers[#containers + 1] = map end
    local bc = workspace:FindFirstChild("BallNoCollide")
    if bc then containers[#containers + 1] = bc end
    local found, best = {}, 0
    for _, cont in ipairs(containers) do
        for _, o in ipairs(cont:GetChildren()) do
            if o:IsA("Model") or o:IsA("BasePart") then
                local t = ballTier(o)
                if t > 0 and modelOk(o) then
                    found[#found + 1] = { o, t }
                    if t > best then best = t end
                end
            end
        end
    end
    local cut = math.min(best, 2)
    for _, e in ipairs(found) do
        if e[2] >= cut then register(e[1]) end
    end
    local now = os.clock()
    for b in pairs(S.balls) do
        if not b.Parent or now - S.balls[b] > 20 then
            S.balls[b] = nil
            S.tier[b] = nil
            if S.ball ~= b then S.baseRad[b] = nil end
        end
    end
end

local function pickBall()
    local r = myRoot()
    if not r then return nil end
    local best, bs, count = nil, -1e9, 0
    for b in pairs(S.balls) do
        if count < CFG.maxCand then
            count += 1
            local root = ballRoot(b)
            if root then
                local d = (root.Position - r.Position).Magnitude
                if d < 400 then
                    local s = 1000 - d * 1.4 + (S.tier[b] or 0) * 200
                    if b:IsA("Model") then s += 40 end
                    if s > bs then best, bs = b, s end
                end
            end
        end
    end
    return best
end

local function setBall(b)
    if S.ball == b then return end
    killBox()
    S.ball, S.prev, S.vel, S.hits = b, nil, Vector3.zero, 0
    if b and not S.baseRad[b] then S.baseRad[b] = computeRadius(b) end
end

local function pickAt(x, y)
    local c = cam()
    if not c then return end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local f = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then f[#f + 1] = p.Character end
    end
    rp.FilterDescendantsInstances = f
    local ray = c:ViewportPointToRay(x, y)
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, rp)
    if hit and hit.Instance then
        local target = hit.Instance
        local m = target:FindFirstAncestorOfClass("Model")
        if m and not Players:GetPlayerFromCharacter(m) then target = m end
        register(target)
        S.forced = target
        setBall(target)
    end
end

local function inPanel(x, y)
    if not UI.win or not UI.win.Visible then return false end
    local ap, as = UI.win.AbsolutePosition, UI.win.AbsoluteSize
    return x >= ap.X and x <= ap.X + as.X and y >= ap.Y and y <= ap.Y + as.Y
end

bind(UIS.InputBegan:Connect(function(i)
    if i.UserInputType ~= Enum.UserInputType.Touch and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local x, y = i.Position.X, i.Position.Y
    if inPanel(x, y) then return end
    if UI.icon and UI.icon.Visible then
        local ia, isz = UI.icon.AbsolutePosition, UI.icon.AbsoluteSize
        if x >= ia.X and x <= ia.X + isz.X and y >= ia.Y and y <= ia.Y + isz.Y then return end
    end
    if S.pick then
        S.pick = false
        safe(function() pickAt(x, y) end)
        return
    end
    if State.mode == 3 then S.manual = Vector2.new(x, y) end
end))

--// ===================== HABILIDADE / CARGA / TILT =====================
local ABILWORD = { "habil", "abilit", "skill", "poder", "power", "special", "ult", "estilo" }

local function findAbilBtn()
    if os.clock() - S.abilScanT < 1 then return S.abilBtn end
    S.abilScanT = os.clock()
    S.abilBtn = nil
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    for _, b in ipairs(pg:GetDescendants()) do
        if b:IsA("GuiButton") and b.Visible and not b:IsDescendantOf(UI.gui) then
            local n = string.lower(b.Name)
            for _, w in ipairs(ABILWORD) do
                if string.find(n, w, 1, true) then
                    local as = b.AbsoluteSize
                    if as.X > 22 and as.Y > 22 then
                        S.abilBtn = b
                        return b
                    end
                    break
                end
            end
        end
    end
    return nil
end

local function pressAbility()
    local now = os.clock()
    if now - S.abilT < State.abilDelay then return end
    S.abilT = now
    local b = findAbilBtn()
    if b and b.Parent and b.Visible then
        local ap, as = b.AbsolutePosition, b.AbsoluteSize
        local ins = GuiService:GetGuiInset()
        press(ap.X + as.X * 0.5 + ins.X, ap.Y + as.Y * 0.5 + ins.Y)
    else
        safe(function() VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, game) end)
        task.delay(0.05, function()
            safe(function() VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game) end)
        end)
    end
end

local function chargeTarget()
    if S.chgKey and S.chgHost and S.chgHost.Parent then return S.chgHost, S.chgKey end
    S.chgKey, S.chgHost = nil, nil
    local hosts = { LP, LP.Character }
    for _, h in ipairs(hosts) do
        if h then
            for key, v in pairs(h:GetAttributes()) do
                local n = string.lower(key)
                if type(v) == "number" and (string.find(n, "charge", 1, true)
                    or string.find(n, "carga", 1, true)) then
                    S.chgKey, S.chgHost = key, h
                    return h, key
                end
            end
        end
    end
end

local function applyCharge()
    if not State.forceCharge then return end
    if os.clock() - S.chgT < 0.1 then return end
    S.chgT = os.clock()
    local host, key = chargeTarget()
    if not host then return end
    local cur = host:GetAttribute(key)
    local v = State.chargePct
    if type(cur) == "number" and cur <= 1.5 then v = v / 100 end
    safe(function() host:SetAttribute(key, v) end)
end

local function netPart()
    if S.netCache and S.netCache.Parent then return S.netCache end
    if os.clock() - S.netT < 5 then return S.netCache end
    S.netT = os.clock()
    S.netCache = nil
    local cont = workspace:FindFirstChild("Map") or workspace
    for _, d in ipairs(cont:GetDescendants()) do
        local n = string.lower(d.Name)
        if d:IsA("BasePart") and (string.find(n, "net", 1, true) or string.find(n, "rede", 1, true)) then
            S.netCache = d
            return d
        end
    end
    return nil
end

local function applyTilt()
    if State.tiltMode == 1 then return end
    local c = cam()
    local r = myRoot()
    local net = netPart()
    if not c or not r then return end
    local dir
    if net then
        local to = r.Position - net.Position
        local along = net.CFrame.RightVector
        local across = net.CFrame.LookVector
        local sA = (to:Dot(across) >= 0) and 1 or -1
        local sS = (to:Dot(along) >= 0) and 1 or -1
        local base = across * sA
        local side = along * sS
        if State.tiltMode == 2 then dir = base + side * 0.55
        elseif State.tiltMode == 3 then dir = base - side * 0.8
        elseif State.tiltMode == 4 then dir = base - side * 0.55
        else dir = base * 0.4 end
        dir = Vector3.new(dir.X, 0, dir.Z)
        if dir.Magnitude < 0.01 then return end
        local look = r.Position + dir.Unit * 45 + Vector3.new(0, 7, 0)
        c.CFrame = CFrame.new(c.CFrame.Position, look)
        S.tiltHold = os.clock() + 0.18
    else
        local base = c.CFrame.LookVector
        local side = c.CFrame.RightVector
        if State.tiltMode == 2 then dir = base + side * 0.4
        elseif State.tiltMode == 3 then dir = base - side * 0.6
        elseif State.tiltMode == 4 then dir = base - side * 0.4
        else dir = base end
        local look = r.Position + dir.Unit * 45 + Vector3.new(0, 7, 0)
        c.CFrame = CFrame.new(c.CFrame.Position, look)
        S.tiltHold = os.clock() + 0.18
    end
end

--// ===================== INPUT =====================
press = function(x, y)
    local c = cam()
    local vs = c and c.ViewportSize or Vector2.new(720, 1280)
    x = math.clamp(x, 2, vs.X - 2)
    y = math.clamp(y, 2, vs.Y - 2)
    safe(function() VIM:SendMouseMoveEvent(x, y, game) end)
    safe(function() VIM:SendMouseButtonEvent(x, y, 0, true, game, 0) end)
    task.delay(math.max(State.hold, 0.012), function()
        safe(function() VIM:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
    end)
end

local BTNH = { "colis", "atac", "hit", "spike", "bump", "cortar", "remate",
    "defin", "mergulho", "dive", "bloque" }

local function findBtn()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    local c = cam()
    if not pg or not c then return nil end
    local vs = c.ViewportSize
    local best, bs = nil, 0
    for _, b in ipairs(pg:GetDescendants()) do
        if b:IsA("GuiButton") and b.Visible and not b:IsDescendantOf(UI.gui) then
            local as = b.AbsoluteSize
            if as.X > 24 and as.Y > 24 then
                local ap = b.AbsolutePosition
                local cx, cy = ap.X + as.X * 0.5, ap.Y + as.Y * 0.5
                if cx > 1 and cy > 1 and cx < vs.X - 1 and cy < vs.Y - 1 then
                    local nm = string.lower(b.Name)
                    local s = 0
                    for _, h in ipairs(BTNH) do
                        if string.find(nm, h, 1, true) then s += 100 end
                    end
                    if s > 0 then
                        if cy > vs.Y * 0.55 then s += 30 end
                        if cx > vs.X * 0.55 and cy > vs.Y * 0.55 then s += 40 end
                    end
                    if s > bs then best, bs = b, s end
                end
            end
        end
    end
    return best
end

local function btnPoint()
    if os.clock() - S.btnT > 1.5 then
        S.btnT = os.clock()
        S.btn = findBtn()
    end
    local btn = S.btn
    if not btn or not btn.Parent then return nil end
    local ap, as = btn.AbsolutePosition, btn.AbsoluteSize
    local ins = GuiService:GetGuiInset()
    return Vector2.new(ap.X + as.X * 0.5 + ins.X, ap.Y + as.Y * 0.5 + ins.Y)
end

pressPoint = function()
    local b = S.ball
    local c = cam()
    if not b or not c then return nil end
    local r = ballRoot(b)
    if not r then return nil end
    if State.mode == 1 then
        local v = c:WorldToViewportPoint(r.Position)
        if v.Z > 0 then return Vector2.new(v.X, v.Y) end
        return btnPoint() or S.manual
    elseif State.mode == 2 then
        return btnPoint() or S.manual
    end
    return S.manual
end

local function doAttack()
    local now = os.clock()
    if now - S.lastPress < CFG.cd then return end
    local pos = pressPoint()
    if not pos then return end
    S.lastPress = now
    S.hits += 1
    if State.tiltMode > 1 then safe(applyTilt) end
    press(pos.X, pos.Y)
end

local function doJump()
    local now = os.clock()
    if now - S.jumpT < CFG.jumpCd then return end
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall then return end
    if st == Enum.HumanoidStateType.Seated or st == Enum.HumanoidStateType.Dead then return end
    S.jumpT = now
    safe(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
end

local function landPoint(pos, vel)
    local g = workspace.Gravity
    if g <= 0 then return nil end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local f = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then f[#f + 1] = p.Character end
    end
    if S.box then f[#f + 1] = S.box end
    local br = S.ball and ballRoot(S.ball)
    if br then f[#f + 1] = br end
    rp.FilterDescendantsInstances = f
    local fh = workspace:Raycast(pos, Vector3.new(0, -400, 0), rp)
    if not fh then return nil end
    local gy = fh.Position.Y
    local a, b, c0 = -0.5 * g, vel.Y, pos.Y - gy
    local disc = b * b - 4 * a * c0
    if disc < 0 then return nil end
    local sq = math.sqrt(disc)
    local t = math.max((-b + sq) / (2 * a), (-b - sq) / (2 * a))
    if t <= 0 or t > 6 then return nil end
    local h = pos + Vector3.new(vel.X, 0, vel.Z) * t
    return Vector3.new(h.X, gy + 0.4, h.Z), t
end

--// ===================== ESP =====================
local espObj = {}
local function espFor(pl)
    if not espObj[pl] then
        espObj[pl] = { txt = makeText(D3.solo, 10), hp = makeText(D3.solo, 9), line = makeLine(D3.solo) }
    end
    return espObj[pl]
end
bind(Players.PlayerRemoving:Connect(function(pl)
    local e = espObj[pl]
    if e then
        pcall(function() e.txt.rm() end); pcall(function() e.hp.rm() end); pcall(function() e.line.rm() end)
        espObj[pl] = nil
    end
end))
local function colorOf(pl)
    if pl.Team and LP.Team then
        return pl.Team == LP.Team and D3.mate or D3.enemy
    end
    return D3.solo
end
local function hideEsp(e)
    if not e then return end
    pcall(e.txt.hide); pcall(e.hp.hide); pcall(e.line.hide)
end

--// ===================== FOV =====================
local fovCircle, fovTxt

local function fovPixel(c, vs)
    local a = math.rad(math.min(State.aimFov, 88))
    return math.tan(a) * (vs.Y * 0.5) / math.tan(math.rad(c.FieldOfView * 0.5))
end

rebuildDraw = function()
    for _, list in pairs(pool) do
        for _, o in ipairs(list) do pcall(function() o.rm() end) end
        for i = #list, 1, -1 do list[i] = nil end
    end
    for pl, e in pairs(espObj) do
        pcall(function() e.txt.rm() end); pcall(function() e.hp.rm() end); pcall(function() e.line.rm() end)
        espObj[pl] = nil
    end
    if fovCircle then pcall(function() fovCircle.rm() end) end
    if fovTxt then pcall(function() fovTxt.rm() end) end
    fovCircle = makeCircle(D3.fov, 1.2, 0.55)
    fovTxt = makeText(D3.fov, 9)
end

local function stepAim(dt)
    local c = cam()
    if not c then return end
    local b = S.ball
    local root = b and ballRoot(b)
    local show = State.fovRing and State.aim and root ~= nil
    if not show then
        pcall(fovCircle.hide)
        pcall(fovTxt.hide)
    end
    if State.camFov > 0 then
        if not S.camActive then S.camActive = true; S.camBase = c.FieldOfView end
        local a = 1 - math.exp(-10 * dt)
        c.FieldOfView = c.FieldOfView + (State.camFov - c.FieldOfView) * a
    elseif S.camActive then
        local base = S.camBase or 70
        c.FieldOfView = c.FieldOfView + (base - c.FieldOfView) * (1 - math.exp(-10 * dt))
        if math.abs(c.FieldOfView - base) < 0.2 then S.camActive = false end
    end
    if not root then return end
    local vs = c.ViewportSize
    if show then
        local r = math.clamp(fovPixel(c, vs), 20, vs.Y)
        fovCircle.set(vs.X * 0.5, vs.Y * 0.5, r, D3.fov, true)
        fovTxt.set(vs.X * 0.5, vs.Y * 0.5 - r - 13, ("%.0f°"):format(State.aimFov), D3.fov, true)
    end
    if not State.aim then return end
    if os.clock() < S.tiltHold then return end
    local to = root.Position - c.CFrame.Position
    local dist = to.Magnitude
    if dist < 0.4 then return end
    local ang = math.deg(math.acos(math.clamp(c.CFrame.LookVector:Dot(to.Unit), -1, 1)))
    if dist <= State.aimRange and ang <= State.aimFov then
        local want = CFrame.new(c.CFrame.Position, root.Position)
        local a = 1 - math.exp(-State.aimSpeed * dt)
        if ang < 1.2 then a = a * 0.45 end
        c.CFrame = c.CFrame:Lerp(want, math.clamp(a, 0, 1))
    end
end

--// ===================== LOOP =====================
local function stepDraw(dt)
    if not S.alive then return end
    local c = cam()
    local r = myRoot()
    if not c or not r then return end
    local vs = c.ViewportSize

    releaseAll(pool.ring) releaseAll(pool.dot) releaseAll(pool.tracer)
    releaseAll(pool.land) releaseAll(pool.traj)

    if os.clock() - S.hbT > 0.8 then
        S.hbT = os.clock()
        safe(cacheBase)
        safe(applyTpl)
    end
    safe(applyLive)
    safe(applyCharge)
    if State.autoAbility then safe(pressAbility) end

    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum then
        if State.wsOn then
            if not S.wsBase then S.wsBase = hum.WalkSpeed end
            if math.abs(hum.WalkSpeed - State.ws) > 0.1 then hum.WalkSpeed = State.ws end
        elseif S.wsBase then
            if math.abs(hum.WalkSpeed - S.wsBase) > 0.1 then hum.WalkSpeed = S.wsBase end
            S.wsBase = nil
        end
        if State.jpOn then
            if not S.jpBase then
                S.jpBase = hum.UseJumpPower and hum.JumpPower or hum.JumpHeight
            end
            if hum.UseJumpPower then
                if math.abs(hum.JumpPower - State.jp) > 0.1 then hum.JumpPower = State.jp end
            else
                local v = State.jp / 5
                if math.abs(hum.JumpHeight - v) > 0.1 then hum.JumpHeight = v end
            end
        elseif S.jpBase then
            if hum.UseJumpPower then hum.JumpPower = S.jpBase else hum.JumpHeight = S.jpBase end
            S.jpBase = nil
        end
        local st = hum:GetState()
        local air = st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
        if State.autoRot then
            if S.rotBase == nil then S.rotBase = hum.AutoRotate end
            if air and not hum.AutoRotate then hum.AutoRotate = true end
        elseif S.rotBase ~= nil then
            if hum.AutoRotate ~= S.rotBase then hum.AutoRotate = S.rotBase end
            S.rotBase = nil
        end
    end
    if State.gravOn then
        local g = S.gravBase * (State.gravPct / 100)
        if math.abs(workspace.Gravity - g) > 0.1 then workspace.Gravity = g end
    elseif math.abs(workspace.Gravity - S.gravBase) > 0.1 then
        workspace.Gravity = S.gravBase
    end

    if os.clock() - S.scanT > CFG.scan then
        S.scanT = os.clock()
        scan()
        if S.forced and not S.forced.Parent then S.forced = nil end
        if not S.forced then setBall(pickBall()) end
    end

    local ball = S.ball
    if ball and (not ball.Parent or not ballRoot(ball)) then
        S.balls[ball] = nil
        S.tier[ball] = nil
        S.baseRad[ball] = nil
        setBall(nil)
        ball = nil
    end
    if UI.dot then UI.dot.BackgroundColor3 = ball and C.green or C.red end

    if ball then
        local root = ballRoot(ball)
        if root then
            applyBox(ball, root)
            if S.prev then
                local raw = (root.Position - S.prev) / math.max(dt, 1 / 240)
                if raw.Magnitude > 800 then raw = raw.Unit * 800 end
                S.vel = S.vel:Lerp(raw, 1 - math.exp(-22 * dt))
                if S.vel.Magnitude < 0.6 then S.vel = Vector3.zero end
            end
            S.prev = root.Position

            local rad = ballRadius(ball)
            local dist = (root.Position - r.Position).Magnitude
            local trig = rad + charRad() + CFG.pad
            local fut = dist
            if S.vel.Magnitude > 3 then
                fut = ((root.Position + S.vel * CFG.lead) - r.Position).Magnitude
            end
            local inside = fut <= trig

            local pos, on = c:WorldToViewportPoint(root.Position)
            local visible = on and pos.Z > 0
                and pos.X > -80 and pos.X < vs.X + 80 and pos.Y > -80 and pos.Y < vs.Y + 80

            if State.ring and visible then
                local edge = c:WorldToViewportPoint(root.Position + c.CFrame.RightVector * rad)
                local pr = math.abs(edge.X - pos.X)
                if pr == pr and pr > 0 and pr < 900 then
                    local col = inside and D3.green or D3.ring
                    grab(pool.ring, function() return makeCircle(col, 1.5, 0.1) end).set(
                        pos.X, pos.Y, math.max(pr, 9), col, true)
                    grab(pool.dot, function() return makeCircle(col, 1, 0, true) end).set(
                        pos.X, pos.Y, 2.5, col, true)
                    grab(pool.land, makeText, D3.ring).set(pos.X,
                        pos.Y + math.max(pr, 16) + 4, ("%.1f"):format(dist), col, true)
                end
            end

            if State.tracer and visible then
                grab(pool.tracer, makeLine, D3.tracer).set(
                    Vector2.new(vs.X * 0.5, vs.Y - 4), Vector2.new(pos.X, pos.Y), D3.tracer, true)
            end

            local lp, ltime
            if S.vel.Magnitude > 6 then
                lp, ltime = landPoint(root.Position, S.vel)
            end

            if State.traj and lp and S.vel.Magnitude > 6 then
                local p, v, g = root.Position, S.vel, workspace.Gravity
                for i = 1, 12 do
                    local t = (ltime or 1) * (i / 12)
                    local sp = p + v * t + Vector3.new(0, -0.5 * g * t * t, 0)
                    local sps, son = c:WorldToViewportPoint(sp)
                    if son and sps.Z > 0 then
                        grab(pool.traj, function() return makeCircle(D3.traj, 1, 0, true) end).set(
                            sps.X, sps.Y, 2, D3.traj, true)
                    end
                end
            end

            if lp and State.traj then
                local lpos, lon = c:WorldToViewportPoint(lp)
                if lon and lpos.Z > 0 then
                    local edge = c:WorldToViewportPoint(lp + c.CFrame.RightVector * 3)
                    local pr = math.clamp(math.abs(edge.X - lpos.X), 6, 300)
                    grab(pool.land, makeCircle, D3.land).set(lpos.X, lpos.Y, pr, D3.land, true)
                    if ltime then
                        grab(pool.land, makeText, D3.land).set(lpos.X, lpos.Y - pr - 12,
                            ("%.1fs"):format(ltime), D3.land, true)
                    end
                end
            end

            local nearLand = lp and (lp - r.Position).Magnitude <= State.reach
            local high = (root.Position.Y - r.Position.Y) >= State.spikeH and dist <= State.spikeR

            if State.jump and (high or (nearLand and S.vel.Y > 2)) then doJump() end
            if (State.autoRecv and nearLand) or (State.autoSpike and high) then doAttack() end
        end
    end

    if State.esp then
        local drawn = 0
        for _, pl in ipairs(Players:GetPlayers()) do
            if drawn < 12 and pl ~= LP and pl.Character then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                local h2 = pl.Character:FindFirstChildOfClass("Humanoid")
                local mate = pl.Team and LP.Team and pl.Team == LP.Team
                if hrp and h2 and h2.Health > 0 and not (mate and State.hideMate) then
                    local d = (hrp.Position - r.Position).Magnitude
                    if d < 220 then
                        local pos, on = c:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                        local e = espFor(pl)
                        local col = colorOf(pl)
                        if on and pos.Z > 0 then
                            drawn += 1
                            e.txt.set(pos.X, pos.Y - 12, ("%s · %d"):format(pl.Name, math.floor(d)), col, true)
                            if State.hp then
                                e.hp.set(pos.X, pos.Y - 24,
                                    ("%d"):format(math.floor(h2.Health / h2.MaxHealth * 100)), col, true)
                            else
                                pcall(e.hp.hide)
                            end
                            e.line.set(Vector2.new(vs.X * 0.5, vs.Y - 4),
                                Vector2.new(pos.X, pos.Y), col, true)
                        else
                            hideEsp(e)
                        end
                    else
                        hideEsp(espObj[pl])
                    end
                else
                    hideEsp(espObj[pl])
                end
            end
        end
    else
        for _, e in pairs(espObj) do hideEsp(e) end
    end

    if os.clock() - S.uiT > 0.25 and UI.stLbl then
        S.uiT = os.clock()
        if UI.chgNote then
            UI.chgNote.Text = S.chgKey and ("atributo: " .. S.chgKey) or "atributo nao encontrado"
        end
        if UI.abilNote then
            UI.abilNote.Text = S.abilBtn and ("botao: " .. S.abilBtn.Name) or "sem botao · usa tecla Q"
        end
        local live = 0
        for p in pairs(S.live) do if p.Parent then live += 1 end end
        local hbmode
        if not State.hbOn then
            hbmode = "off"
        elseif S.box or live > 0 then
            hbmode = State.hbClient and "esfera" or "servidor"
        elseif State.hbReal then
            hbmode = "sem golpe"
        else
            hbmode = "off"
        end
        S.hbMode = hbmode
        local rd = ball and ballRoot(ball)
        local aviso = S.supported and "" or " · FORA DO JOGO"
        if rd then
            UI.stLbl.Text = ("%s · %.1f st · v %.0f\nhits %d · hb %s %dx · tilt %s%s"):format(
                ball.Name, (rd.Position - r.Position).Magnitude, S.vel.Magnitude, S.hits,
                hbmode, State.hbMult, TILTS[State.tiltMode], aviso)
            UI.stLbl.TextColor3 = C.text
        else
            UI.stLbl.Text = ("sem bola · hb %s %dx%s\nentre em partida"):format(hbmode, State.hbMult, aviso)
            UI.stLbl.TextColor3 = S.supported and C.red or C.amber
        end
    end
end

local function step(dt)
    safe(function() stepAim(dt) end)
    safe(function() stepDraw(dt) end)
end

--// ===================== CLEANUP =====================
genv.__KNX = function()
    S.alive = false
    pcall(function() RunService:UnbindFromRenderStep("KNX") end)
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    S.conns = {}
    restoreLive()
    restoreTpl()
    S.live = {}
    S.tier = {}
    hbBase = {}
    killBox()
    if math.abs(workspace.Gravity - S.gravBase) > 0.1 then workspace.Gravity = S.gravBase end
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum then
        if S.wsBase then pcall(function() hum.WalkSpeed = S.wsBase end) end
        if S.jpBase then
            pcall(function()
                if hum.UseJumpPower then hum.JumpPower = S.jpBase else hum.JumpHeight = S.jpBase end
            end)
        end
        if S.rotBase ~= nil then pcall(function() hum.AutoRotate = S.rotBase end) end
    end
    for _, list in pairs(pool) do
        for _, o in ipairs(list) do pcall(function() o.rm() end) end
    end
    for _, e in pairs(espObj) do
        pcall(function() e.txt.rm() end)
        pcall(function() e.hp.rm() end)
        pcall(function() e.line.rm() end)
    end
    pcall(function() fovCircle.rm() end)
    pcall(function() fovTxt.rm() end)
    if UI.gui then safe(function() UI.gui:Destroy() end) end
    genv.__KNX = nil
    out("off")
end

--// ===================== BOOT =====================
task.spawn(function()
    S.supported = (PLACES[game.PlaceId] or GAMES[game.GameID]) and true or false
    if not S.supported then out("AVISO: place", game.PlaceId, "fora da lista") end

    local ok, err = pcall(buildUI)
    if not ok then out("FALHA NA UI:", err) return end
    local ok2, err2 = pcall(buildPages)
    if not ok2 then out("FALHA NAS PAGINAS:", err2) end

    rebuildDraw()
    RunService:BindToRenderStep("KNX", Enum.RenderPriority.Camera.Value + 1, step)

    resolveHB()
    cacheBase()
    sweepLive()
    out("v31 pronto · place suportado:", S.supported)
end)

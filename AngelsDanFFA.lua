local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local mouse = lp:GetMouse()

local cfg = {
    silentAim = true,
    useKeybind = true,
    silentAimKey = Enum.KeyCode.V,
    uiToggleKey = Enum.KeyCode.RightControl,
    silentAimHitChance = 100,
    silentAimFOV = 150,
    silentAimFOVShow = false,
    silentAimFOVFilled = false,
    silentAimFOVOpacity = 0.2,
    silentAimFOVColor = Color3.fromRGB(255, 182, 215),

    silentAimPart = "Head",
    silentAimClosestPart = false,

    silentAimTeamCheck = false,
    silentAimWallCheck = false,
    knockCheck = false, -- ignore knocked / downed players
    triggerBot = false,
    triggerBotKey = Enum.KeyCode.T,
    triggerBotDelay = 0.08, -- seconds between auto clicks
    camlock = false,
    camlockKey = Enum.KeyCode.V,
    camlockSmooth = 0.25,
    espBoxes = false,
    espNames = false,
    espHealth = false,
    espColor = Color3.fromRGB(255, 112, 196),
    silentAimMaxDist = 1000,

    silentAimPredX = 0,
    silentAimPredY = 0,

    bypassRevolver = false,
    device = "pc",
}

local whitelist = {} -- [UserId] = true

------------------------------------------------
-- FOG
-- Presets copied 1:1 from pwd.MAIN: same names, same colors, same densities,
-- Atmosphere Haze = 4, Lighting.FogStart = 30, Lighting.FogEnd = 200.
------------------------------------------------
local Lighting = game:GetService("Lighting")

local FogPresets = {
    { name = "Red",           Color = Color3.fromRGB(255, 60, 60),   Density = 0.45 },
    { name = "Light Red",     Color = Color3.fromRGB(255, 120, 120), Density = 0.44 },
    { name = "Dark Red",      Color = Color3.fromRGB(180, 20, 20),   Density = 0.48 },
    { name = "Orange",        Color = Color3.fromRGB(255, 140, 0),   Density = 0.43 },
    { name = "Light Orange",  Color = Color3.fromRGB(255, 190, 80),  Density = 0.42 },
    { name = "Dark Orange",   Color = Color3.fromRGB(200, 90, 0),    Density = 0.46 },
    { name = "Yellow",        Color = Color3.fromRGB(255, 240, 60),  Density = 0.41 },
    { name = "Lime",          Color = Color3.fromRGB(140, 255, 60),  Density = 0.45 },
    { name = "Green",         Color = Color3.fromRGB(50, 255, 50),   Density = 0.49 },
    { name = "Cyan",          Color = Color3.fromRGB(60, 255, 220),  Density = 0.47 },
    { name = "Electric Blue", Color = Color3.fromRGB(0, 255, 255),   Density = 0.51 },
    { name = "Blue",          Color = Color3.fromRGB(60, 140, 255),  Density = 0.50 },
    { name = "Purple",        Color = Color3.fromRGB(180, 60, 255),  Density = 0.52 },
    { name = "Violet",        Color = Color3.fromRGB(138, 43, 226),  Density = 0.56 },
    { name = "Pink",          Color = Color3.fromRGB(255, 100, 200), Density = 0.48 },
    { name = "Hot Pink",      Color = Color3.fromRGB(255, 20, 147),  Density = 0.49 },
}

-- what the game had before we touched anything (used by "reset fog")
local OrigLighting = {
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    FogColor = Lighting.FogColor,
}

local stashedAtmospheres = {} -- the game's own Atmosphere objects, parked while a fog preset is on

local function applyFog(preset)
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") then
            if v.Name == "AngelsFog" then
                v:Destroy()
            else
                stashedAtmospheres[#stashedAtmospheres + 1] = v
                v.Parent = nil
            end
        end
    end
    local atm = Instance.new("Atmosphere", Lighting)
    atm.Name = "AngelsFog"
    atm.Color = preset.Color
    atm.Density = preset.Density
    atm.Haze = 4
    Lighting.FogStart = 30
    Lighting.FogEnd = 200
end

local function resetFog()
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") and v.Name == "AngelsFog" then
            v:Destroy()
        end
    end
    for _, v in ipairs(stashedAtmospheres) do
        pcall(function() v.Parent = Lighting end)
    end
    stashedAtmospheres = {}
    Lighting.FogStart = OrigLighting.FogStart
    Lighting.FogEnd = OrigLighting.FogEnd
    Lighting.FogColor = OrigLighting.FogColor
end

local bodyPartsList = {
    "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg",
    "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"
}

local fovCircle
pcall(function()
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5
    fovCircle.NumSides = 64
    fovCircle.Radius = cfg.silentAimFOV
    fovCircle.Color = cfg.silentAimFOVColor
    fovCircle.Filled = cfg.silentAimFOVFilled
    fovCircle.Visible = false
    fovCircle.Transparency = 1
end)

local fovGuiCircle
local function updateFovCircle(mousePos, show)
    local radius = math.max(10, cfg.silentAimFOV)
    if fovCircle then
        fovCircle.Position = mousePos
        fovCircle.Radius = radius
        fovCircle.Color = cfg.silentAimFOVColor
        fovCircle.Visible = show
        fovCircle.Transparency = 1
    end
    if fovGuiCircle then
        fovGuiCircle.Visible = show
        fovGuiCircle.Size = UDim2.fromOffset(radius * 2, radius * 2)
        fovGuiCircle.Position = UDim2.fromOffset(mousePos.X - radius, mousePos.Y - radius)
        local stroke = fovGuiCircle:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = cfg.silentAimFOVColor
        end
    end
end

local silentAimCachedPart = nil
local camlockPart = nil
local lastTriggerClick = 0
local triggerUi = nil
local camlockUi = nil
local espObjects = {}
local espParent = nil

local function clickMouse()
    if typeof(mouse1click) == "function" then
        mouse1click()
        return true
    end
    local ok = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local pos
        if cfg.device == "mob" then
            local vs = cam.ViewportSize
            pos = Vector2.new(vs.X / 2, vs.Y / 2)
        else
            pos = UIS:GetMouseLocation()
        end
        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
        task.delay(0.02, function()
            vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
        end)
    end)
    return ok
end

local function isHoldingRevolver()
    if not cfg.bypassRevolver then return false end
    local char = lp.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local toolName = string.lower(tool.Name)
        if string.find(toolName, "revolver") or string.find(toolName, "rev") then
            return true
        end
    end
    return false
end

local function getAimPos()
    if cfg.device == "mob" then
        local vs = cam.ViewportSize
        return Vector2.new(vs.X / 2, vs.Y / 2)
    end
    return UIS:GetMouseLocation()
end

local function getHum(p)
    local c = p and p.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getHRP(p)
    local c = p and p.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isAlive(p)
    local h = getHum(p)
    return h and h.Health > 0
end

local function isWhitelisted(p)
    return p and whitelist[p.UserId] == true
end

local function sameTeam(p)
    return lp.Team and p.Team and lp.Team == p.Team
end

-- True when the player is knocked / downed and should be ignored.
-- Covers common FFA layouts: BodyEffects.K.O, Knocked bools, and a Knocked attribute.
local function isKnocked(p)
    local c = p and p.Character
    if not c then return false end

    if c:GetAttribute("Knocked") == true or c:GetAttribute("K.O") == true then
        return true
    end

    local be = c:FindFirstChild("BodyEffects")
    if be then
        for _, name in ipairs({ "K.O", "KO", "Knocked", "Downed" }) do
            local v = be:FindFirstChild(name)
            if v and v:IsA("BoolValue") and v.Value == true then
                return true
            end
        end
    end

    for _, name in ipairs({ "K.O", "KO", "Knocked", "Downed" }) do
        local v = c:FindFirstChild(name)
        if v and v:IsA("BoolValue") and v.Value == true then
            return true
        end
    end

    return false
end

local function wallBetween(pos)
    if not cfg.silentAimWallCheck then return false end
    local ro = cam.CFrame.Position
    local rd = pos - ro
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { lp.Character }
    params.FilterType = Enum.RaycastFilterType.Exclude
    local hit = workspace:Raycast(ro, rd, params)
    if not hit then return false end
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and hit.Instance:IsDescendantOf(p.Character) then return false end
    end
    return true
end

local function safeWorldToViewportPoint(pos)
    local sp, on = Vector3.new(), false
    pcall(function()
        sp, on = cam:WorldToViewportPoint(pos)
    end)
    return sp, on
end

local function getClosestBodyPart(char)
    local closestPart, shortestDist = nil, math.huge
    local mousePos = getAimPos()
    for _, pName in ipairs(bodyPartsList) do
        local part = char:FindFirstChild(pName)
        if part then
            local screenPos, onScreen = safeWorldToViewportPoint(part.Position)
            local dist = onScreen and (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude or math.huge
            if dist < shortestDist then
                shortestDist = dist
                closestPart = part
            end
        end
    end
    return closestPart or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getTargetPart(char)
    if not char then return nil end
    if cfg.silentAimClosestPart then
        return getClosestBodyPart(char)
    end
    return char:FindFirstChild(cfg.silentAimPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getClosestPlayerToCursor()
    if isHoldingRevolver() then return nil end

    local closestPlayer = nil
    local shortestDist = cfg.silentAimFOV
    local mousePos = getAimPos()

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp and isAlive(p) then
            if cfg.silentAimTeamCheck and sameTeam(p) then continue end
            if isWhitelisted(p) then continue end
            if cfg.knockCheck and isKnocked(p) then continue end
            local hrp = getHRP(p)
            if hrp then
                local dist3D = (hrp.Position - cam.CFrame.Position).Magnitude
                if dist3D <= cfg.silentAimMaxDist then
                    local sp, onScreen = safeWorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local dist2D = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                        if dist2D < shortestDist then
                            local part = getTargetPart(p.Character)
                            if part and not wallBetween(part.Position) then
                                shortestDist = dist2D
                                closestPlayer = part
                            end
                        end
                    end
                end
            end
        end
    end
    return closestPlayer
end

local function clearEsp(p)
    local pack = espObjects[p]
    if not pack then return end
    if pack.highlight then pack.highlight:Destroy() end
    if pack.bill then pack.bill:Destroy() end
    espObjects[p] = nil
end

local function updateEsp()
    if not (cfg.espBoxes or cfg.espNames or cfg.espHealth) then
        for p in pairs(espObjects) do
            clearEsp(p)
        end
        return
    end
    local seen = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and not isWhitelisted(p) and p.Character then
            local char = p.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                seen[p] = true
                local pack = espObjects[p]
                if not pack or pack.char ~= char then
                    clearEsp(p)
                    pack = { char = char }
                    espObjects[p] = pack
                end
                if cfg.espBoxes then
                    if not pack.highlight then
                        local h = Instance.new("Highlight")
                        h.Name = "CuteEsp"
                        h.Adornee = char
                        h.FillTransparency = 0.72
                        h.OutlineTransparency = 0
                        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        h.Parent = espParent or CoreGui
                        pack.highlight = h
                    end
                    pack.highlight.Enabled = true
                    pack.highlight.FillColor = cfg.espColor
                    pack.highlight.OutlineColor = cfg.espColor
                elseif pack.highlight then
                    pack.highlight.Enabled = false
                end
                if cfg.espNames or cfg.espHealth then
                    if not pack.bill then
                        local bb = Instance.new("BillboardGui")
                        bb.Name = "CuteEspBill"
                        bb.AlwaysOnTop = true
                        bb.Size = UDim2.fromOffset(140, 40)
                        bb.StudsOffset = Vector3.new(0, 3.4, 0)
                        bb.Adornee = hrp
                        bb.Parent = espParent or CoreGui
                        local name = Instance.new("TextLabel", bb)
                        name.BackgroundTransparency = 1
                        name.Size = UDim2.new(1, 0, 0, 18)
                        name.Font = Enum.Font.FredokaOne
                        name.TextSize = 14
                        name.TextStrokeTransparency = 0.55
                        name.TextStrokeColor3 = Color3.fromRGB(255, 228, 240)
                        local barBg = Instance.new("Frame", bb)
                        barBg.BackgroundColor3 = Color3.fromRGB(255, 228, 240)
                        barBg.Position = UDim2.new(0.18, 0, 0, 22)
                        barBg.Size = UDim2.new(0.64, 0, 0, 7)
                        barBg.BorderSizePixel = 0
                        Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
                        local fill = Instance.new("Frame", barBg)
                        fill.Size = UDim2.new(1, 0, 1, 0)
                        fill.BorderSizePixel = 0
                        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
                        pack.bill = bb
                        pack.name = name
                        pack.bar = barBg
                        pack.fill = fill
                    end
                    pack.bill.Enabled = true
                    pack.bill.Adornee = hrp
                    pack.name.Visible = cfg.espNames
                    pack.name.Text = "♡ " .. p.DisplayName
                    pack.name.TextColor3 = cfg.espColor
                    pack.bar.Visible = cfg.espHealth
                    local ratio = hum.MaxHealth > 0 and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
                    pack.fill.Size = UDim2.new(ratio, 0, 1, 0)
                    pack.fill.BackgroundColor3 = cfg.espColor
                elseif pack.bill then
                    pack.bill.Enabled = false
                end
            end
        end
    end
    for p in pairs(espObjects) do
        if not seen[p] then
            clearEsp(p)
        end
    end
end

Players.PlayerRemoving:Connect(function(p)
    clearEsp(p)
end)

-- HOOK
local _grm = getrawmetatable(game)
local _oldIndex = _grm.__index
setreadonly(_grm, false)

_grm.__index = function(self, key)
    if not checkcaller() and self == mouse and cfg.silentAim and not isHoldingRevolver() then
        if (key == "Hit" or key == "Target" or key == "UnitRay") and silentAimCachedPart then
            if math.random(1, 100) <= cfg.silentAimHitChance then
                local origin = cam.CFrame.Position
                local hitPos = silentAimCachedPart.Position + Vector3.new(
                    silentAimCachedPart.AssemblyLinearVelocity.X * cfg.silentAimPredX,
                    silentAimCachedPart.AssemblyLinearVelocity.Y * cfg.silentAimPredY,
                    silentAimCachedPart.AssemblyLinearVelocity.Z * cfg.silentAimPredX
                )
                if key == "UnitRay" then
                    return Ray.new(origin, (hitPos - origin).Unit)
                elseif key == "Hit" then
                    return CFrame.new(hitPos)
                elseif key == "Target" then
                    return silentAimCachedPart
                end
            end
        end
    end
    return _oldIndex(self, key)
end
setreadonly(_grm, true)

RunService.RenderStepped:Connect(function()
    local mousePos = getAimPos()
    updateFovCircle(mousePos, cfg.silentAimFOVShow and not isHoldingRevolver())

    if cfg.silentAim or cfg.triggerBot or cfg.camlock then
        silentAimCachedPart = getClosestPlayerToCursor()
    else
        silentAimCachedPart = nil
    end

    if cfg.camlock and not isHoldingRevolver() then
        local lockedOk = camlockPart and camlockPart.Parent and camlockPart:IsDescendantOf(workspace)
        if not lockedOk then
            camlockPart = silentAimCachedPart
        end
        if camlockPart then
            local goal = CFrame.lookAt(cam.CFrame.Position, camlockPart.Position)
            local alpha = math.clamp(cfg.camlockSmooth, 0.01, 1)
            cam.CFrame = cam.CFrame:Lerp(goal, alpha)
        end
    else
        camlockPart = nil
    end

    if cfg.triggerBot and silentAimCachedPart and not isHoldingRevolver() then
        local now = os.clock()
        if now - lastTriggerClick >= cfg.triggerBotDelay then
            lastTriggerClick = now
            clickMouse()
        end
    end
end)

------------------------------------------------
-- UI
------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AngelsDanFFA"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true

local success = pcall(function()
    ScreenGui.Parent = CoreGui
end)

if not success or not ScreenGui.Parent then
    ScreenGui.Parent = lp:WaitForChild("PlayerGui")
end
espParent = ScreenGui
RunService.RenderStepped:Connect(updateEsp)

fovGuiCircle = Instance.new("Frame")
fovGuiCircle.Name = "FovCircle"
fovGuiCircle.AnchorPoint = Vector2.new(0, 0)
fovGuiCircle.BackgroundTransparency = 1
fovGuiCircle.BorderSizePixel = 0
fovGuiCircle.Active = false
fovGuiCircle.Visible = cfg.silentAimFOVShow
fovGuiCircle.ZIndex = 20
fovGuiCircle.Parent = ScreenGui
Instance.new("UICorner", fovGuiCircle).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke", fovGuiCircle)
fovStroke.Color = cfg.silentAimFOVColor
fovStroke.Thickness = 2
fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.ClipsDescendants = true
Main.Size = UDim2.new(0, 480, 0, 575)
Main.Position = UDim2.new(0.5, -240, 0.5, -287)
Main.BackgroundColor3 = Color3.fromRGB(255, 240, 250)
Main.BorderSizePixel = 0
Main.Active = true
Main.Visible = false
Main.Parent = ScreenGui

-- Dragging
local dragging, dragInput, dragStart, startPos
local Header

-- drag is bound for every panel at the end of the script (see makeDraggable)

-- Layout helpers (declared this early so pickDevice below can use them).
-- math.clamp() THROWS when max < min. That happens whenever a window is bigger than the
-- screen (always on phones, and on small PC windows). clampSafe() never throws.
local function viewportSize()
    local c = workspace.CurrentCamera
    local vs = c and c.ViewportSize
    if vs and vs.X > 0 and vs.Y > 0 then
        return vs
    end
    return ScreenGui.AbsoluteSize
end

local function clampSafe(v, lo, hi)
    if hi < lo then hi = lo end
    return math.clamp(v, lo, hi)
end

local function frameSize(f)
    local s = f.AbsoluteSize
    if s.X <= 0 or s.Y <= 0 then
        return Vector2.new(f.Size.X.Offset, f.Size.Y.Offset)
    end
    return s
end

-- Default size for the chosen device, shrunk to fit the screen, and centred.
-- (A 300x420 menu used to hang off the top/bottom of a short phone screen.)
local function fitMain()
    local mob = cfg.device == "mob"
    local vs = viewportSize()
    local w = math.max(200, math.min(mob and 300 or 480, vs.X - 16))
    local h = math.max(200, math.min(mob and 420 or 575, vs.Y - 16))
    Main.Size = UDim2.fromOffset(w, h)
    Main.Position = UDim2.fromOffset(math.max(0, (vs.X - w) / 2), math.max(0, (vs.Y - h) / 2))
end

local UICorner = Instance.new("UICorner", Main)
UICorner.CornerRadius = UDim.new(0, 22)

local UIStroke = Instance.new("UIStroke", Main)
UIStroke.Color = Color3.fromRGB(255, 170, 220)
UIStroke.Thickness = 2.5

-- Header
Header = Instance.new("Frame", Main)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 18, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "♡ angels dan ffa ♡"
Title.TextColor3 = Color3.fromRGB(220, 90, 160)
Title.TextSize = 18
Title.Font = Enum.Font.FredokaOne
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextYAlignment = Enum.TextYAlignment.Center
Title.TextStrokeTransparency = 0.75
Title.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)

local Subtitle = Instance.new("TextLabel", Header)
Subtitle.Size = UDim2.new(1, -60, 0, 16)
Subtitle.Position = UDim2.new(0, 20, 1, -18)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "⋆ ˚｡⋆ little melody menu ⋆ ˚｡⋆"
Subtitle.TextColor3 = Color3.fromRGB(200, 140, 180)
Subtitle.Font = Enum.Font.FredokaOne
Subtitle.TextSize = 11
Subtitle.TextXAlignment = Enum.TextXAlignment.Left

local Device = Instance.new("Frame")
Device.Name = "DevicePick"
Device.Size = UDim2.new(0, 340, 0, 250)
Device.Position = UDim2.new(0.5, -170, 0.5, -125)
Device.BackgroundColor3 = Color3.fromRGB(255, 240, 250)
Device.BorderSizePixel = 0
Device.Active = true
Device.Parent = ScreenGui
Instance.new("UICorner", Device).CornerRadius = UDim.new(0, 22)
local deviceStroke = Instance.new("UIStroke", Device)
deviceStroke.Color = Color3.fromRGB(255, 170, 220)
deviceStroke.Thickness = 2.5

local dTitle = Instance.new("TextLabel", Device)
dTitle.Size = UDim2.new(1, -24, 0, 32)
dTitle.Position = UDim2.new(0, 16, 0, 16)
dTitle.BackgroundTransparency = 1
dTitle.Text = "♡ choose device ♡"
dTitle.TextColor3 = Color3.fromRGB(220, 90, 160)
dTitle.Font = Enum.Font.FredokaOne
dTitle.TextSize = 22
dTitle.TextXAlignment = Enum.TextXAlignment.Left

local dSub = Instance.new("TextLabel", Device)
dSub.Size = UDim2.new(1, -24, 0, 18)
dSub.Position = UDim2.new(0, 16, 0, 48)
dSub.BackgroundTransparency = 1
dSub.Text = "⋆ pick pc or mob ⋆"
dSub.TextColor3 = Color3.fromRGB(214, 140, 180)
dSub.Font = Enum.Font.FredokaOne
dSub.TextSize = 13
dSub.TextXAlignment = Enum.TextXAlignment.Left

local function makeDeviceButton(text, sub, y)
    local btn = Instance.new("TextButton", Device)
    btn.Size = UDim2.new(1, -32, 0, 64)
    btn.Position = UDim2.new(0, 16, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(255, 248, 253)
    btn.Text = ""
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 16)
    local s = Instance.new("UIStroke", btn)
    s.Color = Color3.fromRGB(255, 190, 225)
    s.Thickness = 1.4

    local name = Instance.new("TextLabel", btn)
    name.Size = UDim2.new(1, -20, 0, 24)
    name.Position = UDim2.new(0, 14, 0, 8)
    name.BackgroundTransparency = 1
    name.Text = text
    name.TextColor3 = Color3.fromRGB(220, 90, 160)
    name.Font = Enum.Font.FredokaOne
    name.TextSize = 18
    name.TextXAlignment = Enum.TextXAlignment.Left

    local hint = Instance.new("TextLabel", btn)
    hint.Size = UDim2.new(1, -20, 0, 18)
    hint.Position = UDim2.new(0, 14, 0, 34)
    hint.BackgroundTransparency = 1
    hint.Text = sub
    hint.TextColor3 = Color3.fromRGB(214, 140, 180)
    hint.Font = Enum.Font.FredokaOne
    hint.TextSize = 12
    hint.TextXAlignment = Enum.TextXAlignment.Left
    return btn
end

local pcBtn = makeDeviceButton("♡ pc", "⋆ cursor fov + outfit copy ⋆", 82)
local mobBtn = makeDeviceButton("♡ mob", "⋆ fov stays in the middle ⋆", 158)

local function pickDevice(mode)
    cfg.device = mode
    Device.Visible = false
    fitMain()
    if mode == "mob" then
        Title.TextSize = 16
        if White then
            White.Size = UDim2.fromOffset(280, 340)
            White.Position = UDim2.new(0.5, -140, 0.55, -150)
        end
    else
        Title.TextSize = 18
        if White then
            White.Size = UDim2.fromOffset(340, 460)
            White.Position = UDim2.new(0.5, 250, 0.5, -230)
        end
    end
    Main.Visible = true
    Subtitle.Text = mode == "mob" and "⋆ ˚｡⋆ mob · middle fov ⋆ ˚｡⋆" or "⋆ ˚｡⋆ little melody menu ⋆ ˚｡⋆"
end

pcBtn.MouseButton1Click:Connect(function()
    pickDevice("pc")
end)
mobBtn.MouseButton1Click:Connect(function()
    pickDevice("mob")
end)

local MinimizeBtn = Instance.new("TextButton", Header)
MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
MinimizeBtn.Position = UDim2.new(1, -38, 0.5, -14)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 230)
MinimizeBtn.Text = "−"
MinimizeBtn.TextColor3 = Color3.fromRGB(220, 80, 150)
MinimizeBtn.Font = Enum.Font.FredokaOne
MinimizeBtn.TextSize = 18
MinimizeBtn.AutoButtonColor = false

Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 10)

-- Mini Bubble
local MiniBubble = Instance.new("TextButton", ScreenGui)
MiniBubble.Name = "MiniBubble"
MiniBubble.Size = UDim2.new(0, 50, 0, 50)
MiniBubble.Position = UDim2.new(0.5, -25, 0.5, -25)
MiniBubble.BackgroundColor3 = Color3.fromRGB(255, 230, 245)
MiniBubble.Text = "🪽"
MiniBubble.TextSize = 22
MiniBubble.Visible = false
MiniBubble.Active = true
-- keep the bubble above the whitelist / character panels so they can never sit on top of it
-- and swallow the click that is supposed to reopen the menu
MiniBubble.ZIndex = 100

local bDragging, bDragStart, bStartPos
-- bubble drag is included in the shared drag below

Instance.new("UICorner", MiniBubble).CornerRadius = UDim.new(1, 0)

local BubbleStroke = Instance.new("UIStroke", MiniBubble)
BubbleStroke.Color = Color3.fromRGB(255, 160, 210)
BubbleStroke.Thickness = 2.2

-- Scroll
local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Size = UDim2.new(1, -24, 1, -92) -- leaves room for the resize footer at the bottom
Scroll.Position = UDim2.new(0, 12, 0, 52)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 6
Scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 170, 215)
Scroll.ScrollingEnabled = true
Scroll.Active = true
Scroll.ElasticBehavior = Enum.ElasticBehavior.Never
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

Scroll.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseWheel then
        dragging = false
    end
end)

local UIList = Instance.new("UIListLayout", Scroll)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 11)

UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Scroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 12)
end)

-- minimize / restore. (restoreUI used to crash on small screens because of math.clamp,
-- so the menu never came back; it now uses clampSafe and always shows the menu.)
local function minimizeUI()
    pcall(function()
        local vs, ms = viewportSize(), frameSize(Main)
        local x = clampSafe(Main.AbsolutePosition.X + (ms.X / 2) - 25, 0, vs.X - 50)
        local y = clampSafe(Main.AbsolutePosition.Y + (ms.Y / 2) - 25, 0, vs.Y - 50)
        MiniBubble.Position = UDim2.new(0, x, 0, y)
    end)
    Main.Visible = false
    MiniBubble.Visible = true
end

local function restoreUI()
    pcall(function()
        local vs, ms = viewportSize(), frameSize(Main)
        local x = clampSafe(MiniBubble.AbsolutePosition.X - (ms.X / 2) + 25, 0, vs.X - ms.X)
        local y = clampSafe(MiniBubble.AbsolutePosition.Y - (ms.Y / 2) + 25, 0, vs.Y - ms.Y)
        Main.Position = UDim2.new(0, x, 0, y)
    end)
    MiniBubble.Visible = false
    Main.Visible = true
end

-- Hide-menu key. Flips the whole ScreenGui, and when it comes back makes sure something
-- is actually showing (menu or bubble) so it can never reopen as an empty screen.
local function toggleMenu()
    ScreenGui.Enabled = not ScreenGui.Enabled
    if ScreenGui.Enabled and not Device.Visible and not Main.Visible and not MiniBubble.Visible then
        Main.Visible = true
    end
end

-- Window dragging.
-- Only a press on the HANDLE starts a drag (the old handler started one from anywhere inside
-- the menu, so dragging a slider also dragged the whole window and made it jump).
-- Movement is tracked as a delta from the press, so scale positions / the top-bar inset can
-- never make the window jump, and it works with mouse AND touch.
-- Returns a function that says whether the last press turned into a real drag.
local function makeDraggable(handle, frame)
    local dragging, moved = false, false
    local startPointer, startAbs
    handle.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            dragging, moved = true, false
            startPointer = Vector2.new(input.Position.X, input.Position.Y)
            startAbs = frame.AbsolutePosition
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        local t = input.UserInputType
        if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
        local delta = Vector2.new(input.Position.X, input.Position.Y) - startPointer
        if not moved and delta.Magnitude < 6 then return end -- ignore finger / hand jitter
        moved = true
        local vs, size = viewportSize(), frameSize(frame)
        frame.Position = UDim2.fromOffset(
            clampSafe(startAbs.X + delta.X, 0, vs.X - size.X),
            clampSafe(startAbs.Y + delta.Y, 0, vs.Y - size.Y)
        )
    end)
    UIS.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return function() return moved end
end

-- Slider input, shared by every slider. Handles mouse AND touch (the old sliders only knew
-- the mouse, so they never moved on mobile), and freezes the menu's scrolling while a
-- finger is on the slider so the list doesn't scroll away under it.
-- hit = the clickable strip, track = the bar, apply(0..1) = what to do with the position.
local function bindSlider(hit, track, apply)
    local active = false
    local function setFromX(x)
        local w = track.AbsoluteSize.X
        if w > 0 then
            apply(math.clamp((x - track.AbsolutePosition.X) / w, 0, 1))
        end
    end
    hit.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            active = true
            Scroll.ScrollingEnabled = false
            setFromX(input.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not active then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
            setFromX(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and active then
            active = false
            Scroll.ScrollingEnabled = true
        end
    end)
end

local bubbleMoved = makeDraggable(MiniBubble, MiniBubble)

-- Footer: resize handle + reset (works for pc and mob)
do
    local Footer = Instance.new("Frame", Main)
    Footer.Name = "Footer"
    Footer.Size = UDim2.new(1, -28, 0, 28)
    Footer.Position = UDim2.new(0, 14, 1, -36)
    Footer.BackgroundTransparency = 1

    local function pill(text, w)
        local b = Instance.new("TextButton", Footer)
        b.Size = UDim2.fromOffset(w, 26)
        b.BackgroundColor3 = Color3.fromRGB(255, 230, 245)
        b.Text = text
        b.TextColor3 = Color3.fromRGB(196, 72, 138)
        b.Font = Enum.Font.FredokaOne
        b.TextSize = 13
        b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
        local s = Instance.new("UIStroke", b)
        s.Color = Color3.fromRGB(255, 190, 225)
        s.Thickness = 1.2
        return b
    end

    local resetBtn = pill("reset size", 92)
    resetBtn.Position = UDim2.new(0, 0, 0.5, -13)
    resetBtn.MouseButton1Click:Connect(fitMain)

    local resizeBtn = pill("resize", 100)
    resizeBtn.AnchorPoint = Vector2.new(1, 0)
    resizeBtn.Position = UDim2.new(1, 0, 0.5, -13)
    resizeBtn.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UIPadding", resizeBtn).PaddingLeft = UDim.new(0, 12)

    -- little diagonal grip drawn with frames (no font / glyph support needed)
    local icon = Instance.new("Frame", resizeBtn)
    icon.Size = UDim2.fromOffset(14, 14)
    icon.AnchorPoint = Vector2.new(1, 0.5)
    icon.Position = UDim2.new(1, -9, 0.5, 0)
    icon.BackgroundTransparency = 1
    for k = 1, 3 do
        local line = Instance.new("Frame", icon)
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Size = UDim2.fromOffset(4 * k, 2)
        line.Position = UDim2.fromOffset(14 - 3 * k, 14 - 3 * k)
        line.Rotation = -45
        line.BorderSizePixel = 0
        line.BackgroundColor3 = Color3.fromRGB(220, 90, 160)
    end

    -- press the resize pill and drag: the menu's top-left corner stays put, the size follows
    local resizing, rStart, rSize = false, nil, nil
    resizeBtn.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            resizing = true
            rStart = Vector2.new(input.Position.X, input.Position.Y)
            rSize = frameSize(Main)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not resizing then return end
        local t = input.UserInputType
        if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
        local mob = cfg.device == "mob"
        local minW, minH = mob and 230 or 340, mob and 250 or 320
        local vs, pos = viewportSize(), Main.AbsolutePosition
        local d = Vector2.new(input.Position.X, input.Position.Y) - rStart
        Main.Size = UDim2.fromOffset(
            clampSafe(rSize.X + d.X, minW, vs.X - pos.X),
            clampSafe(rSize.Y + d.Y, minH, vs.Y - pos.Y)
        )
    end)
    UIS.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            resizing = false
        end
    end)
end

MinimizeBtn.MouseButton1Click:Connect(minimizeUI)
MiniBubble.MouseButton1Click:Connect(function()
    if bubbleMoved() then return end -- that press was a drag of the bubble, not a tap
    restoreUI()
end)

-- Helpers
local function createCard(height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, height or 42)
    card.BackgroundColor3 = Color3.fromRGB(255, 248, 253)
    card.BorderSizePixel = 0
    card.Parent = Scroll

    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)

    local s = Instance.new("UIStroke", card)
    s.Color = Color3.fromRGB(255, 210, 235)
    s.Thickness = 1.2
    return card
end

local function addToggle(text, default, callback, subtitle)
    local card = createCard(subtitle and 52 or 42)
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0.7, 0, subtitle and 0 or 1, subtitle and 22 or 0)
    lbl.Position = UDim2.new(0, 12, 0, subtitle and 6 or 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 80, 150)
    lbl.Font = Enum.Font.FredokaOne
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    if subtitle then
        local sub = Instance.new("TextLabel", card)
        sub.Size = UDim2.new(0.7, 0, 0, 16)
        sub.Position = UDim2.new(0, 12, 0, 28)
        sub.BackgroundTransparency = 1
        sub.Text = "♡ " .. subtitle
        sub.TextColor3 = Color3.fromRGB(214, 130, 176)
        sub.Font = Enum.Font.FredokaOne
        sub.TextSize = 11
        sub.TextXAlignment = Enum.TextXAlignment.Left
    end

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0, 46, 0, 24)
    btn.Position = UDim2.new(1, -56, 0.5, -12)
    btn.BackgroundColor3 = default and Color3.fromRGB(255, 140, 200) or Color3.fromRGB(250, 230, 245)
    btn.Text = ""
    btn.AutoButtonColor = false

    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame", btn)
    circle.Size = UDim2.new(0, 20, 0, 20)
    circle.Position = default and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(255, 140, 200) or Color3.fromRGB(250, 230, 245)
        circle:TweenPosition(state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        callback(state)
    end)
end

local function addSlider(text, min, max, default, callback)
    local card = createCard(52)

    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0.6, 0, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 80, 150)
    lbl.Font = Enum.Font.FredokaOne
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", card)
    valLbl.Size = UDim2.new(0.3, 0, 0, 20)
    valLbl.Position = UDim2.new(0.7, -10, 0, 5)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default)
    valLbl.TextColor3 = Color3.fromRGB(210, 120, 170)
    valLbl.Font = Enum.Font.SourceSans
    valLbl.TextSize = 14
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local bg = Instance.new("Frame", card)
    bg.Size = UDim2.new(1, -24, 0, 9)
    bg.Position = UDim2.new(0, 12, 0, 32)
    bg.BackgroundColor3 = Color3.fromRGB(255, 225, 240)
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", bg)
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 140, 200)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local function applyPct(pos)
        local val = math.clamp(math.floor(min + (max - min) * pos + 0.5), min, max)
        fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
        valLbl.Text = tostring(val)
        callback(val)
    end

    -- the bar itself is only 9px tall, which is hard to hit with a finger: use a taller
    -- invisible strip over it as the touch target (mouse + touch, see bindSlider)
    local hit = Instance.new("TextButton", card)
    hit.Name = "SliderHit"
    hit.Size = UDim2.new(1, -24, 0, 28)
    hit.Position = UDim2.new(0, 12, 0, 22)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.AutoButtonColor = false
    bindSlider(hit, bg, applyPct)
end

local function addDropdown(text, list, default, callback)
    local card = createCard(42)

    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 80, 150)
    lbl.Font = Enum.Font.FredokaOne
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0.55, 0, 0, 28)
    btn.Position = UDim2.new(0.42, 0, 0.5, -14)
    btn.BackgroundColor3 = Color3.fromRGB(255, 230, 245)
    btn.Text = default
    btn.TextColor3 = Color3.fromRGB(100, 140, 160)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local s = Instance.new("UIStroke", btn)
    s.Color = Color3.fromRGB(255, 190, 225)

    local dropFrame = Instance.new("ScrollingFrame", Scroll)
    dropFrame.Size = UDim2.new(1, -6, 0, 120)
    dropFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dropFrame.Visible = false
    dropFrame.BorderSizePixel = 0
    dropFrame.ScrollBarThickness = 3
    Instance.new("UICorner", dropFrame).CornerRadius = UDim.new(0, 10)

    local dList = Instance.new("UIListLayout", dropFrame)
    dList.SortOrder = Enum.SortOrder.LayoutOrder

    dList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        dropFrame.CanvasSize = UDim2.new(0, 0, 0, dList.AbsoluteContentSize.Y)
    end)

    for _, v in ipairs(list) do
        local item = Instance.new("TextButton", dropFrame)
        item.Size = UDim2.new(1, 0, 0, 26)
        item.BackgroundTransparency = 1
        item.Text = v
        item.TextColor3 = Color3.fromRGB(210, 70, 150)
        item.Font = Enum.Font.SourceSans
        item.TextSize = 13

        item.MouseButton1Click:Connect(function()
            btn.Text = v
            dropFrame.Visible = false
            callback(v)
        end)
    end

    btn.MouseButton1Click:Connect(function()
        dropFrame.Visible = not dropFrame.Visible
    end)
end

local function addKeybind(text, defaultKey, callback)
    local card = createCard(42)
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 80, 150)
    lbl.Font = Enum.Font.FredokaOne
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0, 84, 0, 26)
    btn.Position = UDim2.new(1, -94, 0.5, -13)
    btn.BackgroundColor3 = Color3.fromRGB(255, 230, 245)
    btn.Text = defaultKey.Name
    btn.TextColor3 = Color3.fromRGB(100, 140, 160)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local s = Instance.new("UIStroke", btn)
    s.Color = Color3.fromRGB(255, 190, 225)

    local listening = false
    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
    end)

    UIS.InputBegan:Connect(function(input, gpe)
        if listening and not gpe and input.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            btn.Text = input.KeyCode.Name
            callback(input.KeyCode)
        end
    end)
end

local function addFOVColorPicker()
    local card = createCard(58)

    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1, -20, 0, 22)
    title.Position = UDim2.new(0, 12, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "♡ fov color"
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left

    local colors = {
        Color3.fromRGB(235, 64, 64),
        Color3.fromRGB(255, 149, 48),
        Color3.fromRGB(255, 214, 48),
        Color3.fromRGB(92, 214, 92),
        Color3.fromRGB(48, 214, 214),
        Color3.fromRGB(72, 112, 255),
        Color3.fromRGB(168, 92, 255),
        Color3.fromRGB(255, 112, 196),
        Color3.fromRGB(24, 24, 28),
    }

    local row = Instance.new("Frame", card)
    row.Size = UDim2.new(1, -20, 0, 22)
    row.Position = UDim2.new(0, 10, 0, 28)
    row.BackgroundTransparency = 1

    local layout = Instance.new("UIListLayout", row)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 6)
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local swatches = {}
    local function paintSelection()
        for _, sw in ipairs(swatches) do
            sw.stroke.Enabled = sw.color == cfg.silentAimFOVColor
            sw.stroke.Color = Color3.fromRGB(255, 255, 255)
            sw.stroke.Thickness = 2
        end
    end

    for _, color in ipairs(colors) do
        local sw = Instance.new("TextButton", row)
        sw.Size = UDim2.new(0, 18, 0, 18)
        sw.BackgroundColor3 = color
        sw.Text = ""
        sw.AutoButtonColor = false
        Instance.new("UICorner", sw).CornerRadius = UDim.new(0, 4)
        local stroke = Instance.new("UIStroke", sw)
        stroke.Enabled = false
        swatches[#swatches + 1] = { color = color, stroke = stroke }
        sw.MouseButton1Click:Connect(function()
            cfg.silentAimFOVColor = color
            paintSelection()
        end)
    end
    paintSelection()
end

local function addSection(title, sub)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -8, 0, sub and 34 or 18)
    holder.BackgroundTransparency = 1
    holder.Parent = Scroll

    local dot = Instance.new("TextLabel", holder)
    dot.Size = UDim2.new(1, -8, 0, 16)
    dot.Position = UDim2.new(0, 4, 0, 0)
    dot.BackgroundTransparency = 1
    dot.Text = "♡  " .. title
    dot.TextColor3 = Color3.fromRGB(220, 90, 160)
    dot.Font = Enum.Font.FredokaOne
    dot.TextSize = 15
    dot.TextXAlignment = Enum.TextXAlignment.Left

    if sub then
        local subLbl = Instance.new("TextLabel", holder)
        subLbl.Size = UDim2.new(1, -8, 0, 14)
        subLbl.Position = UDim2.new(0, 16, 0, 16)
        subLbl.BackgroundTransparency = 1
        subLbl.Text = "⋆ " .. sub .. " ⋆"
        subLbl.TextColor3 = Color3.fromRGB(214, 140, 180)
        subLbl.Font = Enum.Font.FredokaOne
        subLbl.TextSize = 11
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
    end
end

-- Add all controls
addToggle("♡ silent aim", cfg.silentAim, function(v) cfg.silentAim = v end)
addToggle("♡ show fov circle", cfg.silentAimFOVShow, function(v) cfg.silentAimFOVShow = v end)
addSlider("♡ fov size", 10, 500, cfg.silentAimFOV, function(v) cfg.silentAimFOV = v end)

addFOVColorPicker()

addSection("visuals", "esp & overlays")
addToggle("♡ esp boxes", cfg.espBoxes, function(v) cfg.espBoxes = v end, "boxes through walls")
addToggle("♡ esp names", cfg.espNames, function(v) cfg.espNames = v end, "show display names")
addToggle("♡ esp health", cfg.espHealth, function(v) cfg.espHealth = v end, "health bar next to player")

do
    local card = createCard(58)
    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1, -20, 0, 22)
    title.Position = UDim2.new(0, 12, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "♡ esp color"
    title.TextColor3 = Color3.fromRGB(200, 80, 150)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left

    local colors = {
        Color3.fromRGB(235, 64, 64),
        Color3.fromRGB(255, 149, 48),
        Color3.fromRGB(255, 214, 48),
        Color3.fromRGB(92, 214, 92),
        Color3.fromRGB(48, 214, 214),
        Color3.fromRGB(72, 112, 255),
        Color3.fromRGB(168, 92, 255),
        Color3.fromRGB(255, 112, 196),
        Color3.fromRGB(24, 24, 28),
    }
    local row = Instance.new("Frame", card)
    row.Size = UDim2.new(1, -20, 0, 22)
    row.Position = UDim2.new(0, 10, 0, 28)
    row.BackgroundTransparency = 1
    local layout = Instance.new("UIListLayout", row)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 6)
    local swatches = {}
    local function paintSelection()
        for _, sw in ipairs(swatches) do
            sw.stroke.Enabled = sw.color == cfg.espColor
            sw.stroke.Color = Color3.fromRGB(255, 255, 255)
            sw.stroke.Thickness = 2
        end
    end
    for _, color in ipairs(colors) do
        local sw = Instance.new("TextButton", row)
        sw.Size = UDim2.new(0, 18, 0, 18)
        sw.BackgroundColor3 = color
        sw.Text = ""
        sw.AutoButtonColor = false
        Instance.new("UICorner", sw).CornerRadius = UDim.new(0, 4)
        local stroke = Instance.new("UIStroke", sw)
        stroke.Enabled = false
        swatches[#swatches + 1] = { color = color, stroke = stroke }
        sw.MouseButton1Click:Connect(function()
            cfg.espColor = color
            paintSelection()
        end)
    end
    paintSelection()
end

addSection("camlock", "camera assist")
addToggle("♡ camlock", cfg.camlock, function(v)
    cfg.camlock = v
    if not v then
        camlockPart = nil
    end
end, "sticky camera lock")

do
    local smoothLbl = Instance.new("TextLabel")
    smoothLbl.Size = UDim2.new(1, -8, 0, 16)
    smoothLbl.BackgroundTransparency = 1
    smoothLbl.Text = "·  smoothness :: " .. string.format("%.2f", cfg.camlockSmooth)
    smoothLbl.TextColor3 = Color3.fromRGB(255, 140, 190)
    smoothLbl.Font = Enum.Font.GothamMedium
    smoothLbl.TextSize = 12
    smoothLbl.TextXAlignment = Enum.TextXAlignment.Left
    smoothLbl.Parent = Scroll

    local card = createCard(58)
    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(0.6, 0, 0, 18)
    title.Position = UDim2.new(0, 12, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "♡ smoothness"
    title.TextColor3 = Color3.fromRGB(196, 72, 138)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", card)
    valLbl.Size = UDim2.new(0.5, 0, 0, 16)
    valLbl.Position = UDim2.new(0, 12, 0, 24)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = string.format("%.2f", cfg.camlockSmooth)
    valLbl.TextColor3 = Color3.fromRGB(255, 140, 190)
    valLbl.Font = Enum.Font.GothamMedium
    valLbl.TextSize = 13
    valLbl.TextXAlignment = Enum.TextXAlignment.Left

    local bg = Instance.new("Frame", card)
    bg.Size = UDim2.new(1, -24, 0, 6)
    bg.Position = UDim2.new(0, 12, 0, 44)
    bg.BackgroundColor3 = Color3.fromRGB(255, 214, 232)
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", bg)
    fill.Size = UDim2.new(cfg.camlockSmooth, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 176, 210)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local function applyPct(pos)
        local val = math.floor(pos * 100 + 0.5) / 100
        if val < 0.01 then val = 0.01 end
        cfg.camlockSmooth = val
        fill.Size = UDim2.new(val, 0, 1, 0)
        valLbl.Text = string.format("%.2f", val)
        smoothLbl.Text = "·  smoothness :: " .. string.format("%.2f", val)
    end

    -- same touch-friendly strip + mouse/touch handling as the other sliders
    local hit = Instance.new("TextButton", card)
    hit.Name = "SliderHit"
    hit.Size = UDim2.new(1, -24, 0, 22)
    hit.Position = UDim2.new(0, 12, 0, 36)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.AutoButtonColor = false
    bindSlider(hit, bg, applyPct)
end

do
    local card = createCard(42)
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "♡ keybind"
    lbl.TextColor3 = Color3.fromRGB(196, 72, 138)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0, 72, 0, 26)
    btn.Position = UDim2.new(1, -84, 0.5, -13)
    btn.BackgroundColor3 = Color3.fromRGB(255, 228, 240)
    btn.Text = cfg.camlockKey.Name
    btn.TextColor3 = Color3.fromRGB(255, 150, 196)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local listening = false
    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
    end)

    camlockUi = {
        set = function(state)
            cfg.camlock = state
            if not state then
                camlockPart = nil
            end
        end,
        setKey = function(key)
            cfg.camlockKey = key
            btn.Text = key.Name
            listening = false
        end,
        isListening = function()
            return listening
        end,
    }
end

addToggle("♡ skip revolver", cfg.bypassRevolver, function(v) cfg.bypassRevolver = v end)
addToggle("♡ wall check", cfg.silentAimWallCheck, function(v) cfg.silentAimWallCheck = v end)
addToggle("♡ knock check", cfg.knockCheck, function(v) cfg.knockCheck = v end, "ignore knocked players")

do
    local card = createCard(64)
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0.7, 0, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = "♡ triggerbot"
    lbl.TextColor3 = Color3.fromRGB(200, 80, 150)
    lbl.Font = Enum.Font.FredokaOne
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", card)
    sub.Size = UDim2.new(0.7, 0, 0, 14)
    sub.Position = UDim2.new(0, 12, 0, 26)
    sub.BackgroundTransparency = 1
    sub.Text = "♡ auto click on target"
    sub.TextColor3 = Color3.fromRGB(180, 110, 160)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 11
    sub.TextXAlignment = Enum.TextXAlignment.Left

    local keyLbl = Instance.new("TextButton", card)
    keyLbl.Size = UDim2.new(0.7, 0, 0, 14)
    keyLbl.Position = UDim2.new(0, 12, 0, 42)
    keyLbl.BackgroundTransparency = 1
    keyLbl.Text = "key: " .. cfg.triggerBotKey.Name
    keyLbl.TextColor3 = Color3.fromRGB(170, 100, 150)
    keyLbl.Font = Enum.Font.Gotham
    keyLbl.TextSize = 11
    keyLbl.TextXAlignment = Enum.TextXAlignment.Left
    keyLbl.AutoButtonColor = false

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0, 46, 0, 24)
    btn.Position = UDim2.new(1, -56, 0.5, -12)
    btn.BackgroundColor3 = cfg.triggerBot and Color3.fromRGB(255, 140, 200) or Color3.fromRGB(250, 230, 245)
    btn.Text = ""
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame", btn)
    circle.Size = UDim2.new(0, 20, 0, 20)
    circle.Position = cfg.triggerBot and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local listening = false

    local function setTrigger(state)
        cfg.triggerBot = state
        btn.BackgroundColor3 = state and Color3.fromRGB(255, 140, 200) or Color3.fromRGB(250, 230, 245)
        circle:TweenPosition(state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
    end

    btn.MouseButton1Click:Connect(function()
        setTrigger(not cfg.triggerBot)
    end)

    keyLbl.MouseButton1Click:Connect(function()
        listening = true
        keyLbl.Text = "key: ..."
    end)

    triggerUi = {
        set = setTrigger,
        setKey = function(key)
            cfg.triggerBotKey = key
            keyLbl.Text = "key: " .. key.Name
            listening = false
        end,
        isListening = function()
            return listening
        end,
    }
end

addToggle("♡ closest part", cfg.silentAimClosestPart, function(v) cfg.silentAimClosestPart = v end)
addDropdown("♡ hit part", bodyPartsList, cfg.silentAimPart, function(v) cfg.silentAimPart = v end)
addToggle("♡ use keybind", cfg.useKeybind, function(v) cfg.useKeybind = v end)
addKeybind("♡ aim key", cfg.silentAimKey, function(v) cfg.silentAimKey = v end)
addKeybind("♡ hide menu key", cfg.uiToggleKey, function(v) cfg.uiToggleKey = v end)

-- Whitelist menu
White = Instance.new("Frame")
White.Name = "Whitelist"
White.Size = UDim2.new(0, 340, 0, 460)
White.Position = UDim2.new(0.5, 250, 0.5, -230)
White.BackgroundColor3 = Color3.fromRGB(255, 236, 246)
White.BorderSizePixel = 0
White.Visible = false
White.Active = true
White.Parent = ScreenGui
Instance.new("UICorner", White).CornerRadius = UDim.new(0, 18)
local whiteStroke = Instance.new("UIStroke", White)
whiteStroke.Color = Color3.fromRGB(255, 176, 214)
whiteStroke.Thickness = 2

local wTitle = Instance.new("TextLabel", White)
wTitle.Size = UDim2.new(1, -50, 0, 28)
wTitle.Position = UDim2.new(0, 16, 0, 10)
wTitle.BackgroundTransparency = 1
wTitle.Text = "$ whitelist"
wTitle.TextColor3 = Color3.fromRGB(196, 72, 138)
wTitle.Font = Enum.Font.FredokaOne
wTitle.TextSize = 22
wTitle.TextXAlignment = Enum.TextXAlignment.Left

local wClose = Instance.new("TextButton", White)
wClose.Size = UDim2.new(0, 26, 0, 26)
wClose.Position = UDim2.new(1, -36, 0, 10)
wClose.BackgroundColor3 = Color3.fromRGB(255, 206, 230)
wClose.Text = "×"
wClose.TextColor3 = Color3.fromRGB(196, 72, 138)
wClose.Font = Enum.Font.FredokaOne
wClose.TextSize = 18
wClose.AutoButtonColor = false
Instance.new("UICorner", wClose).CornerRadius = UDim.new(0, 8)

local wSub = Instance.new("TextLabel", White)
wSub.Size = UDim2.new(1, -24, 0, 16)
wSub.Position = UDim2.new(0, 16, 0, 40)
wSub.BackgroundTransparency = 1
wSub.Text = "⋆ friends to skip ⋆"
wSub.Font = Enum.Font.FredokaOne
wSub.TextSize = 14
wSub.TextXAlignment = Enum.TextXAlignment.Left

local wScroll = Instance.new("ScrollingFrame", White)
wScroll.Size = UDim2.new(1, -20, 1, -78)
wScroll.Position = UDim2.new(0, 10, 0, 66)
wScroll.BackgroundTransparency = 1
wScroll.BorderSizePixel = 0
wScroll.ScrollBarThickness = 4
wScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 170, 215)
wScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local wList = Instance.new("UIListLayout", wScroll)
wList.SortOrder = Enum.SortOrder.LayoutOrder
wList.Padding = UDim.new(0, 8)
wList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    wScroll.CanvasSize = UDim2.new(0, 0, 0, wList.AbsoluteContentSize.Y + 8)
end)

local playerRows = {}

local function makePlayerRow(p)
    if playerRows[p] then return end

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, 52)
    row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    row.BorderSizePixel = 0
    row.Parent = wScroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)
    local rs = Instance.new("UIStroke", row)
    rs.Color = Color3.fromRGB(255, 214, 232)
    rs.Thickness = 1

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(1, -78, 0, 20)
    nameLbl.Position = UDim2.new(0, 12, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = p.DisplayName
    nameLbl.TextColor3 = Color3.fromRGB(70, 70, 78)
    nameLbl.Font = Enum.Font.GothamMedium
    nameLbl.TextSize = 14
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local userLbl = Instance.new("TextLabel", row)
    userLbl.Size = UDim2.new(1, -78, 0, 16)
    userLbl.Position = UDim2.new(0, 12, 0, 28)
    userLbl.BackgroundTransparency = 1
    userLbl.Text = "@" .. p.Name
    userLbl.TextColor3 = Color3.fromRGB(168, 112, 146)
    userLbl.Font = Enum.Font.Gotham
    userLbl.TextSize = 12
    userLbl.TextXAlignment = Enum.TextXAlignment.Left
    userLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local on = whitelist[p.UserId] == true
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 46, 0, 24)
    btn.Position = UDim2.new(1, -58, 0.5, -12)
    btn.BackgroundColor3 = on and Color3.fromRGB(214, 126, 168) or Color3.fromRGB(255, 228, 240)
    btn.Text = ""
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame", btn)
    circle.Size = UDim2.new(0, 18, 0, 18)
    circle.Position = on and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    circle.BackgroundColor3 = on and Color3.fromRGB(120, 48, 78) or Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    btn.MouseButton1Click:Connect(function()
        on = not on
        whitelist[p.UserId] = on or nil
        btn.BackgroundColor3 = on and Color3.fromRGB(214, 126, 168) or Color3.fromRGB(255, 228, 240)
        circle.BackgroundColor3 = on and Color3.fromRGB(120, 48, 78) or Color3.fromRGB(255, 255, 255)
        circle:TweenPosition(on and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
    end)

    playerRows[p] = row
end

local function refreshWhitelist()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            makePlayerRow(p)
        end
    end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= lp then
        makePlayerRow(p)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    local row = playerRows[p]
    if row then
        row:Destroy()
        playerRows[p] = nil
    end
end)

refreshWhitelist()

local openCard = createCard(42)
local openLbl = Instance.new("TextLabel", openCard)
openLbl.Size = UDim2.new(0.62, 0, 1, 0)
openLbl.Position = UDim2.new(0, 12, 0, 0)
openLbl.BackgroundTransparency = 1
openLbl.Text = "♡ whitelist"
openLbl.TextColor3 = Color3.fromRGB(200, 80, 150)
openLbl.Font = Enum.Font.FredokaOne
openLbl.TextSize = 14
openLbl.TextXAlignment = Enum.TextXAlignment.Left

local openBtn = Instance.new("TextButton", openCard)
openBtn.Size = UDim2.new(0, 84, 0, 26)
openBtn.Position = UDim2.new(1, -94, 0.5, -13)
openBtn.BackgroundColor3 = Color3.fromRGB(255, 230, 245)
openBtn.Text = "open"
openBtn.TextColor3 = Color3.fromRGB(196, 72, 138)
openBtn.Font = Enum.Font.GothamMedium
openBtn.TextSize = 13
openBtn.AutoButtonColor = false
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", openBtn).Color = Color3.fromRGB(255, 190, 225)

openBtn.MouseButton1Click:Connect(function()
    White.Visible = not White.Visible
    openBtn.Text = White.Visible and "close" or "open"
end)
wClose.MouseButton1Click:Connect(function()
    White.Visible = false
    openBtn.Text = "open"
end)

-- Character / outfit menu
local CharMenu = Instance.new("Frame")
CharMenu.Name = "CharMenu"
CharMenu.Size = UDim2.fromOffset(cfg.device == "mob" and 280 or 340, 230)
CharMenu.Position = UDim2.new(0.5, -170, 0.5, -115)
CharMenu.BackgroundColor3 = Color3.fromRGB(255, 236, 246)
CharMenu.BorderSizePixel = 0
CharMenu.Visible = false
CharMenu.Active = true
CharMenu.Parent = ScreenGui
Instance.new("UICorner", CharMenu).CornerRadius = UDim.new(0, 18)
local charStroke = Instance.new("UIStroke", CharMenu)
charStroke.Color = Color3.fromRGB(255, 176, 214)
charStroke.Thickness = 2

local cTitle = Instance.new("TextLabel", CharMenu)
cTitle.Size = UDim2.new(1, -50, 0, 28)
cTitle.Position = UDim2.new(0, 16, 0, 12)
cTitle.BackgroundTransparency = 1
cTitle.Text = "♡ character"
cTitle.TextColor3 = Color3.fromRGB(220, 90, 160)
cTitle.Font = Enum.Font.FredokaOne
cTitle.TextSize = 22
cTitle.TextXAlignment = Enum.TextXAlignment.Left

local cClose = Instance.new("TextButton", CharMenu)
cClose.Size = UDim2.new(0, 26, 0, 26)
cClose.Position = UDim2.new(1, -36, 0, 12)
cClose.BackgroundColor3 = Color3.fromRGB(255, 206, 230)
cClose.Text = "×"
cClose.TextColor3 = Color3.fromRGB(196, 72, 138)
cClose.Font = Enum.Font.FredokaOne
cClose.TextSize = 18
cClose.AutoButtonColor = false
Instance.new("UICorner", cClose).CornerRadius = UDim.new(0, 8)

local cSub = Instance.new("TextLabel", CharMenu)
cSub.Size = UDim2.new(1, -24, 0, 16)
cSub.Position = UDim2.new(0, 16, 0, 42)
cSub.BackgroundTransparency = 1
cSub.Text = "⋆ username or user id outfit ⋆"
cSub.TextColor3 = Color3.fromRGB(214, 140, 180)
cSub.Font = Enum.Font.FredokaOne
cSub.TextSize = 13
cSub.TextXAlignment = Enum.TextXAlignment.Left

local nameBox = Instance.new("TextBox", CharMenu)
nameBox.Size = UDim2.new(1, -32, 0, 36)
nameBox.Position = UDim2.new(0, 16, 0, 72)
nameBox.BackgroundColor3 = Color3.fromRGB(255, 248, 253)
nameBox.PlaceholderText = "♡ username or id"
nameBox.PlaceholderColor3 = Color3.fromRGB(214, 160, 190)
nameBox.Text = ""
nameBox.TextColor3 = Color3.fromRGB(196, 72, 138)
nameBox.Font = Enum.Font.FredokaOne
nameBox.TextSize = 16
nameBox.ClearTextOnFocus = false
Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", nameBox).Color = Color3.fromRGB(255, 190, 225)

local wearBtn = Instance.new("TextButton", CharMenu)
wearBtn.Size = UDim2.new(1, -32, 0, 36)
wearBtn.Position = UDim2.new(0, 16, 0, 118)
wearBtn.BackgroundColor3 = Color3.fromRGB(255, 176, 214)
wearBtn.Text = "♡ wear outfit"
wearBtn.TextColor3 = Color3.fromRGB(255, 248, 253)
wearBtn.Font = Enum.Font.FredokaOne
wearBtn.TextSize = 16
wearBtn.AutoButtonColor = false
Instance.new("UICorner", wearBtn).CornerRadius = UDim.new(0, 12)

local cStatus = Instance.new("TextLabel", CharMenu)
cStatus.Size = UDim2.new(1, -32, 0, 36)
cStatus.Position = UDim2.new(0, 16, 0, 162)
cStatus.BackgroundTransparency = 1
cStatus.Text = "⋆ type a name, then wear ⋆"
cStatus.TextColor3 = Color3.fromRGB(214, 140, 180)
cStatus.Font = Enum.Font.FredokaOne
cStatus.TextSize = 13
cStatus.TextWrapped = true

local wearing = false
local copiedUserId = nil

local function resolveUserId(typed)
    if string.match(typed, "^%d+$") then
        return tonumber(typed)
    end
    return Players:GetUserIdFromNameAsync(typed)
end

local function clearOldLook(char)
    for _, inst in ipairs(char:GetChildren()) do
        if inst:IsA("Accessory") or inst:IsA("Hat") or inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic") or inst:IsA("CharacterMesh") or inst:IsA("BodyColors") then
            inst:Destroy()
        end
    end
    local head = char:FindFirstChild("Head")
    if head then
        for _, d in ipairs(head:GetChildren()) do
            if d:IsA("Decal") then
                d:Destroy()
            end
        end
    end
end

local function paintParts(char, dummy)
    local names = {
        "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
        "UpperTorso", "LowerTorso",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
    }
    for _, name in ipairs(names) do
        local src = dummy:FindFirstChild(name)
        local dst = char:FindFirstChild(name)
        if src and dst and src:IsA("BasePart") and dst:IsA("BasePart") then
            dst.Color = src.Color
            local sm = src:FindFirstChildOfClass("SpecialMesh")
            local dm = dst:FindFirstChildOfClass("SpecialMesh")
            if sm and dm then
                dm.MeshId = sm.MeshId
                dm.TextureId = sm.TextureId
                dm.Scale = sm.Scale
            end
        end
    end
end

local function copyVisual(char, dummy)
    clearOldLook(char)
    for _, inst in ipairs(dummy:GetChildren()) do
        if inst:IsA("Accessory") or inst:IsA("Hat") or inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic") or inst:IsA("BodyColors") or inst:IsA("CharacterMesh") then
            local clone = inst:Clone()
            clone.Parent = char
        end
    end
    local srcHead = dummy:FindFirstChild("Head")
    local dstHead = char:FindFirstChild("Head")
    if srcHead and dstHead then
        for _, d in ipairs(srcHead:GetChildren()) do
            if d:IsA("Decal") then
                d:Clone().Parent = dstHead
            end
        end
    end
    paintParts(char, dummy)
end

local copiedTracks = {}

local function stopCopiedAnims()
    for _, track in ipairs(copiedTracks) do
        pcall(function()
            track:Stop()
        end)
    end
    copiedTracks = {}
end

local function assetId(n)
    if typeof(n) ~= "number" or n == 0 then return nil end
    return "rbxassetid://" .. tostring(n)
end

local function setAnimateIds(animate, desc)
    if not animate or not desc then return end
    local map = {
        idle = desc.IdleAnimation,
        walk = desc.WalkAnimation,
        run = desc.RunAnimation,
        jump = desc.JumpAnimation,
        fall = desc.FallAnimation,
        climb = desc.ClimbAnimation,
        swim = desc.SwimAnimation,
    }
    for folderName, animId in pairs(map) do
        local id = assetId(animId)
        local folder = animate:FindFirstChild(folderName)
        if folder and id then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Animation") then
                    child.AnimationId = id
                end
            end
        end
    end
end

local function copyAnimations(char, dummy, desc)
    stopCopiedAnims()
    local src = dummy and dummy:FindFirstChild("Animate")
    local old = char:FindFirstChild("Animate")
    if src then
        if old then old:Destroy() end
        local clone = src:Clone()
        clone.Disabled = false
        clone.Parent = char
        setAnimateIds(clone, desc)
    else
        setAnimateIds(old, desc)
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or not desc then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    local function play(id, priority, looped)
        local asset = assetId(id)
        if not asset then return end
        local anim = Instance.new("Animation")
        anim.AnimationId = asset
        local ok, track = pcall(function()
            return animator:LoadAnimation(anim)
        end)
        if ok and track then
            track.Priority = priority
            track.Looped = looped
            track:Play(0.15)
            table.insert(copiedTracks, track)
        end
    end
    play(desc.IdleAnimation, Enum.AnimationPriority.Idle, true)
end

local function loadDummy(userId, rig)
    local desc = Players:GetHumanoidDescriptionFromUserId(userId)
    local model
    local ok = pcall(function()
        model = Players:CreateHumanoidModelFromDescription(desc, rig)
    end)
    if not ok or not model then
        ok = pcall(function()
            model = Players:CreateHumanoidModelFromUserId(userId)
        end)
    end
    if not ok or not model then
        error("could not build avatar")
    end
    return desc, model
end

local function applyCopiedAvatar(userId)
    local char = lp.Character or lp.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")
    local rig = hum.RigType
    local desc, dummy = loadDummy(userId, rig)
    pcall(function()
        hum:ApplyDescription(desc)
    end)
    char = lp.Character or char
    copyVisual(char, dummy)
    copyAnimations(char, dummy, desc)
    dummy:Destroy()
    copiedUserId = userId
end

local function wearUsername()
    if wearing then return end
    local typed = string.gsub(nameBox.Text, "^%s+", "")
    typed = string.gsub(typed, "%s+$", "")
    typed = string.gsub(typed, "^@", "")
    if typed == "" then
        cStatus.Text = "⋆ type a username or id ⋆"
        return
    end
    wearing = true
    cStatus.Text = "⋆ finding " .. typed .. " ⋆"
    task.spawn(function()
        local ok, err = pcall(function()
            local userId = resolveUserId(typed)
            cStatus.Text = "⋆ painting outfit ⋆"
            applyCopiedAvatar(userId)
        end)
        wearing = false
        if ok then
            cStatus.Text = "♡ wearing " .. typed .. " + anims ⋆"
        else
            cStatus.Text = "⋆ could not load that outfit ⋆"
        end
    end)
end

lp.CharacterAdded:Connect(function()
    local id = copiedUserId
    if not id then return end
    task.wait(0.6)
    pcall(function()
        applyCopiedAvatar(id)
    end)
end)

wearBtn.MouseButton1Click:Connect(wearUsername)
nameBox.FocusLost:Connect(function(enter)
    if enter then
        wearUsername()
    end
end)

local charCard = createCard(42)
local charLbl = Instance.new("TextLabel", charCard)
charLbl.Size = UDim2.new(0.62, 0, 1, 0)
charLbl.Position = UDim2.new(0, 12, 0, 0)
charLbl.BackgroundTransparency = 1
charLbl.Text = "♡ character"
charLbl.TextColor3 = Color3.fromRGB(200, 80, 150)
charLbl.Font = Enum.Font.FredokaOne
charLbl.TextSize = 14
charLbl.TextXAlignment = Enum.TextXAlignment.Left

local charOpen = Instance.new("TextButton", charCard)
charOpen.Size = UDim2.new(0, 84, 0, 26)
charOpen.Position = UDim2.new(1, -94, 0.5, -13)
charOpen.BackgroundColor3 = Color3.fromRGB(255, 230, 245)
charOpen.Text = "open"
charOpen.TextColor3 = Color3.fromRGB(196, 72, 138)
charOpen.Font = Enum.Font.GothamMedium
charOpen.TextSize = 13
charOpen.AutoButtonColor = false
Instance.new("UICorner", charOpen).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", charOpen).Color = Color3.fromRGB(255, 190, 225)

charOpen.MouseButton1Click:Connect(function()
    CharMenu.Visible = not CharMenu.Visible
    charOpen.Text = CharMenu.Visible and "close" or "open"
    if cfg.device == "mob" then
        CharMenu.Size = UDim2.fromOffset(280, 230)
        CharMenu.Position = UDim2.new(0.5, -140, 0.5, -115)
    else
        CharMenu.Size = UDim2.fromOffset(340, 230)
        CharMenu.Position = UDim2.new(0.5, 20, 0.5, -115)
    end
end)
cClose.MouseButton1Click:Connect(function()
    CharMenu.Visible = false
    charOpen.Text = "open"
end)

-- Fog menu (the presets + applyFog/resetFog live near the top of the script)
do
    local Fog = Instance.new("Frame")
    Fog.Name = "FogMenu"
    Fog.Size = UDim2.fromOffset(300, 400)
    Fog.BackgroundColor3 = Color3.fromRGB(255, 236, 246)
    Fog.BorderSizePixel = 0
    Fog.Visible = false
    Fog.Active = true
    Fog.Parent = ScreenGui
    Instance.new("UICorner", Fog).CornerRadius = UDim.new(0, 18)
    local fogStroke = Instance.new("UIStroke", Fog)
    fogStroke.Color = Color3.fromRGB(255, 176, 214)
    fogStroke.Thickness = 2

    local fTitle = Instance.new("TextLabel", Fog)
    fTitle.Size = UDim2.new(1, -50, 0, 28)
    fTitle.Position = UDim2.new(0, 16, 0, 10)
    fTitle.BackgroundTransparency = 1
    fTitle.Text = "♡ fog"
    fTitle.TextColor3 = Color3.fromRGB(196, 72, 138)
    fTitle.Font = Enum.Font.FredokaOne
    fTitle.TextSize = 22
    fTitle.TextXAlignment = Enum.TextXAlignment.Left

    local fSub = Instance.new("TextLabel", Fog)
    fSub.Size = UDim2.new(1, -24, 0, 16)
    fSub.Position = UDim2.new(0, 16, 0, 40)
    fSub.BackgroundTransparency = 1
    fSub.Text = "⋆ pick a color ⋆"
    fSub.TextColor3 = Color3.fromRGB(214, 140, 180)
    fSub.Font = Enum.Font.FredokaOne
    fSub.TextSize = 14
    fSub.TextXAlignment = Enum.TextXAlignment.Left

    local fClose = Instance.new("TextButton", Fog)
    fClose.Size = UDim2.new(0, 26, 0, 26)
    fClose.Position = UDim2.new(1, -36, 0, 10)
    fClose.BackgroundColor3 = Color3.fromRGB(255, 206, 230)
    fClose.Text = "×"
    fClose.TextColor3 = Color3.fromRGB(196, 72, 138)
    fClose.Font = Enum.Font.FredokaOne
    fClose.TextSize = 18
    fClose.AutoButtonColor = false
    Instance.new("UICorner", fClose).CornerRadius = UDim.new(0, 8)

    -- invisible strip over the title: press + drag it to move the panel
    local fGrip = Instance.new("Frame", Fog)
    fGrip.Name = "DragGrip"
    fGrip.BackgroundTransparency = 1
    fGrip.Size = UDim2.new(1, -50, 0, 60)
    fGrip.Active = true
    makeDraggable(fGrip, Fog)

    local fList = Instance.new("ScrollingFrame", Fog)
    fList.Size = UDim2.new(1, -20, 1, -114)
    fList.Position = UDim2.new(0, 10, 0, 66)
    fList.BackgroundTransparency = 1
    fList.BorderSizePixel = 0
    fList.ScrollBarThickness = 4
    fList.ScrollBarImageColor3 = Color3.fromRGB(255, 170, 215)
    fList.CanvasSize = UDim2.new(0, 0, 0, 0)

    local fLayout = Instance.new("UIListLayout", fList)
    fLayout.SortOrder = Enum.SortOrder.LayoutOrder
    fLayout.Padding = UDim.new(0, 8)
    fLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        fList.CanvasSize = UDim2.new(0, 0, 0, fLayout.AbsoluteContentSize.Y + 8)
    end)

    local rowStrokes = {}
    local function markSelected(stroke)
        for _, s in ipairs(rowStrokes) do
            s.Color = Color3.fromRGB(255, 214, 232)
            s.Thickness = 1
        end
        if stroke then
            stroke.Color = Color3.fromRGB(255, 120, 190)
            stroke.Thickness = 2.5
        end
    end

    for i, preset in ipairs(FogPresets) do
        local row = Instance.new("TextButton", fList)
        row.LayoutOrder = i
        row.Size = UDim2.new(1, -6, 0, 38)
        row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)
        local rs = Instance.new("UIStroke", row)
        rs.Color = Color3.fromRGB(255, 214, 232)
        rs.Thickness = 1
        rowStrokes[#rowStrokes + 1] = rs

        local dot = Instance.new("Frame", row)
        dot.Size = UDim2.fromOffset(20, 20)
        dot.Position = UDim2.new(0, 12, 0.5, -10)
        dot.BackgroundColor3 = preset.Color
        dot.BorderSizePixel = 0
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local nm = Instance.new("TextLabel", row)
        nm.Size = UDim2.new(1, -52, 1, 0)
        nm.Position = UDim2.new(0, 44, 0, 0)
        nm.BackgroundTransparency = 1
        nm.Text = preset.name
        nm.TextColor3 = Color3.fromRGB(196, 72, 138)
        nm.Font = Enum.Font.FredokaOne
        nm.TextSize = 14
        nm.TextXAlignment = Enum.TextXAlignment.Left

        row.MouseButton1Click:Connect(function()
            applyFog(preset)
            markSelected(rs)
        end)
    end

    local resetFogBtn = Instance.new("TextButton", Fog)
    resetFogBtn.Size = UDim2.new(1, -20, 0, 32)
    resetFogBtn.Position = UDim2.new(0, 10, 1, -42)
    resetFogBtn.BackgroundColor3 = Color3.fromRGB(255, 176, 214)
    resetFogBtn.Text = "♡ reset fog"
    resetFogBtn.TextColor3 = Color3.fromRGB(255, 248, 253)
    resetFogBtn.Font = Enum.Font.FredokaOne
    resetFogBtn.TextSize = 15
    resetFogBtn.AutoButtonColor = false
    Instance.new("UICorner", resetFogBtn).CornerRadius = UDim.new(0, 12)
    resetFogBtn.MouseButton1Click:Connect(function()
        resetFog()
        markSelected(nil)
    end)

    -- the "fog" row in the main menu
    local card = createCard(42)
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0.62, 0, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "♡ fog"
    lbl.TextColor3 = Color3.fromRGB(200, 80, 150)
    lbl.Font = Enum.Font.FredokaOne
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local openFog = Instance.new("TextButton", card)
    openFog.Size = UDim2.new(0, 84, 0, 26)
    openFog.Position = UDim2.new(1, -94, 0.5, -13)
    openFog.BackgroundColor3 = Color3.fromRGB(255, 230, 245)
    openFog.Text = "open"
    openFog.TextColor3 = Color3.fromRGB(196, 72, 138)
    openFog.Font = Enum.Font.GothamMedium
    openFog.TextSize = 13
    openFog.AutoButtonColor = false
    Instance.new("UICorner", openFog).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", openFog).Color = Color3.fromRGB(255, 190, 225)

    -- open the panel next to the menu (right side, else left, else centred), sized to the
    -- device and never bigger than the screen
    local function placeFog()
        local mob = cfg.device == "mob"
        local vs = viewportSize()
        local w = math.max(200, math.min(mob and 260 or 300, vs.X - 16))
        local h = math.max(200, math.min(mob and 340 or 400, vs.Y - 16))
        Fog.Size = UDim2.fromOffset(w, h)
        local mp, ms = Main.AbsolutePosition, frameSize(Main)
        local x
        if mp.X + ms.X + 10 + w <= vs.X then
            x = mp.X + ms.X + 10
        elseif mp.X - 10 - w >= 0 then
            x = mp.X - 10 - w
        else
            x = (vs.X - w) / 2
        end
        Fog.Position = UDim2.fromOffset(clampSafe(x, 0, vs.X - w), clampSafe(mp.Y, 0, vs.Y - h))
    end

    openFog.MouseButton1Click:Connect(function()
        if Fog.Visible then
            Fog.Visible = false
            openFog.Text = "open"
        else
            placeFog()
            Fog.Visible = true
            openFog.Text = "close"
        end
    end)
    fClose.MouseButton1Click:Connect(function()
        Fog.Visible = false
        openFog.Text = "open"
    end)
end

-- Keybinds
UIS.InputBegan:Connect(function(i, gpe)
    -- "gpe" just means Roblox thinks something else already used this key press. Normally
    -- that means "ignore it", but the hide-menu key must still be able to bring the menu
    -- back, so it is only ignored while you are really typing in a text box.
    if gpe and (UIS:GetFocusedTextBox() ~= nil or i.KeyCode ~= cfg.uiToggleKey) then return end

    if cfg.useKeybind and i.KeyCode == cfg.silentAimKey then
        cfg.silentAim = not cfg.silentAim
    end

    if triggerUi and triggerUi.isListening() and i.UserInputType == Enum.UserInputType.Keyboard then
        triggerUi.setKey(i.KeyCode)
        return
    end

    if camlockUi and camlockUi.isListening() and i.UserInputType == Enum.UserInputType.Keyboard then
        camlockUi.setKey(i.KeyCode)
        return
    end

    if i.KeyCode == cfg.triggerBotKey then
        if triggerUi then
            triggerUi.set(not cfg.triggerBot)
        else
            cfg.triggerBot = not cfg.triggerBot
        end
    end

    if i.KeyCode == cfg.camlockKey then
        cfg.camlock = not cfg.camlock
        if not cfg.camlock then
            camlockPart = nil
        end
    end

    if i.KeyCode == cfg.uiToggleKey then
        toggleMenu()
    end
end)

print("♡ Angels Dan FFA loaded successfully ♡")

-- Window dragging.
-- Each window now moves ONLY when you press and drag its header / title strip.
-- (The old handler that lived here started a drag from ANYWHERE inside the menu, so dragging
-- the FOV slider dragged the whole window too - and, because it ignored scale positions, the
-- window also jumped to the top-left on the first drag. On mobile the slider never moved at
-- all because only the window handler understood touch.)
Header.Active = true
makeDraggable(Header, Main)
makeDraggable(Title, Main)
makeDraggable(Subtitle, Main)

makeDraggable(Device, Device)
makeDraggable(dTitle, Device)
makeDraggable(dSub, Device)

-- whitelist + character panels have no header frame, so give them an invisible drag strip
-- over their title area (it stops short of the close button on the right)
local function addGrip(panel)
    local grip = Instance.new("Frame", panel)
    grip.Name = "DragGrip"
    grip.BackgroundTransparency = 1
    grip.Size = UDim2.new(1, -50, 0, 60)
    grip.Active = true
    return grip
end
makeDraggable(addGrip(White), White)
makeDraggable(addGrip(CharMenu), CharMenu)

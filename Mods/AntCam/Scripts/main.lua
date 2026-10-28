-- AntCam v0.6  -  ant point-of-view camera + puppet mode for Empires of the Undergrowth (UE4SS Lua mod)
-- Single-player / offline only.  Save your game first.
--
-- Only YOUR colony's ants can be picked. The camera is a separate CameraActor; the game's own camera is
-- never touched. Leaving the view hands control back to the RTS pawn.
--
-- Keys
--   F8             ant view on/off
--   PageUp/Down    next / previous friendly ant (also leaves puppet mode)
--   Numpad 1       PUPPET mode on/off (needs ant view)   (F9 is the game's photo mode)
--       W A S D        move relative to where you look
--       Mouse          look around (the cursor is pinned to the screen centre)   Arrow keys: backup look
--       Q              AUTO-ATTACK on/off: the ant fights nearby enemies by itself (WASD disabled while on)
--       Home / End     mouse sensitivity up / down        Insert  invert mouse Y
--   Numpad 3       print abilities + the 8 nearest creatures (distance, colony, enemy?, health)
--   Numpad + / -   camera forward / back          Numpad * and /   camera up / down

local CFG = {
    bone  = "Head",
    mode  = "root",
    fov   = 100.0,
    fwd   = 3.0, up = 0.0,
    pitch = 0.0, yaw = 0.0, roll = 0.0,
    lookSpeed  = 110.0,   -- degrees per second (arrow keys)
    tickMs     = 25,
    autoRange  = 1500.0,  -- auto-attack: how far away an enemy may be to get chased
    autoAssist = true,    -- auto-attack: nudge the ant toward the nearest enemy (the game's own AI does the fighting)
    mouseLook  = true,    -- puppet mode: look with the mouse (hides the cursor while puppet mode is on)
    mouseSens  = 0.15,    -- degrees per screen pixel of mouse movement
    invertY    = false,
}

local S = {
    active = false, idx = 0, cam = nil, mesh = nil, ant = nil, headHidden = false,
    puppet = false, auto = false, moving = false,
    viewYaw = 0.0, viewPitch = 0.0, saved = {}, pc = nil,
    mouseSeen = false, mouseTicks = 0, mouseCal = 0,
}

local function say(msg) print("[AntCam] " .. tostring(msg) .. "\n") end

local function isValid(o)
    local ok, v = pcall(function() return o ~= nil and o:IsValid() end)
    return ok and v == true
end

local function down(k)
    if not k or not IsKeyBindDown then return false end
    local ok, v = pcall(IsKeyBindDown, k)
    return ok and v == true
end

local function getPC()
    local pc = FindFirstOf("EotUPlayerController")
    if isValid(pc) then return pc end
    return nil
end

local function myColony(pc)
    local c
    pcall(function() c = pc:GetColonyID() end)
    if type(c) ~= "number" then c = 0 end
    return c
end

local function sortByName(list)
    pcall(function() table.sort(list, function(a, b) return a:GetFullName() < b:GetFullName() end) end)
end

-- only living ants that belong to the player's own colony
local function listFriendly(pc)
    local colony = myColony(pc)
    local out = {}
    for _, o in ipairs(FindAllOf("ColonyCreature") or {}) do
        if isValid(o) then
            local ok, keep = pcall(function() return o.ColonyID == colony and o.Health > 0 end)
            if ok and keep then out[#out + 1] = o end
        end
    end
    sortByName(out)
    return out, colony
end

local function findMesh(ant)
    local m
    pcall(function() m = ant.Mesh end)
    if isValid(m) then return m end
    local name = ant:GetFullName()
    for _, c in ipairs(FindAllOf("SkeletalMeshComponent") or {}) do
        local ok, owner = pcall(function() return c:GetOwner():GetFullName() end)
        if ok and owner == name then return c end
    end
    return nil
end

local function ensureCam(pc)
    if isValid(S.cam) then return S.cam end
    local ok, cam = pcall(function()
        local cls = StaticFindObject("/Script/Engine.CameraActor")
        return pc:GetWorld():SpawnActor(cls, { X = 0, Y = 0, Z = 0 }, { Pitch = 0, Yaw = 0, Roll = 0 })
    end)
    if ok and isValid(cam) then
        pcall(function() cam.CameraComponent.FieldOfView = CFG.fov end)
        pcall(function() cam.CameraComponent.bConstrainAspectRatio = false end)
        S.cam = cam
        return cam
    end
    say("could not spawn the camera actor: " .. tostring(cam))
    return nil
end

local function attach(ant)
    local mesh = findMesh(ant)
    if not mesh then say("no skeletal mesh found on this ant"); return false end
    S.mesh, S.ant = mesh, ant
    local ok, err = pcall(function()
        local cam = S.cam
        pcall(function() cam:K2_DetachFromActor(1, 1, 1) end)
        local ar = ant:K2_GetActorRotation()
        S.viewYaw, S.viewPitch = ar.Yaw, 0.0
        local p = mesh:GetSocketLocation(FName(CFG.bone))
        local y = math.rad(ar.Yaw)
        cam:K2_SetActorRotation({ Pitch = ar.Pitch + CFG.pitch, Yaw = ar.Yaw + CFG.yaw, Roll = ar.Roll + CFG.roll }, false)
        cam:K2_SetActorLocation({ X = p.X + math.cos(y) * CFG.fwd, Y = p.Y + math.sin(y) * CFG.fwd, Z = p.Z + CFG.up }, false, {}, false)
        if CFG.mode == "bone" then
            cam:K2_AttachToComponent(mesh, FName(CFG.bone), 1, 1, 1, false)
        else
            cam:K2_AttachToActor(ant, FName("None"), 1, 1, 1, false)
        end
    end)
    if not ok then say("attach failed: " .. tostring(err)); return false end
    return true
end

local function setView(pc, target)
    local ok, err = pcall(function() pc:SetViewTargetWithBlend(target, 0.0, 0, 0.0, false) end)
    if not ok then say("SetViewTarget failed: " .. tostring(err)) end
end

local function showHead(hidden)
    if not isValid(S.mesh) then return end
    pcall(function()
        if hidden then S.mesh:HideBoneByName(FName(CFG.bone), 2)
        else S.mesh:UnHideBoneByName(FName(CFG.bone)) end
    end)
    S.headHidden = hidden
end

------------------------------------------------------------------ helpers about other creatures

local function dist3(a, b)
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function shortName(o)
    local ok, n = pcall(function() return o:GetClass():GetFName():ToString() end)
    return ok and n or "?"
end

-- every other creature (any colony), nearest first
local function nearbyList(ant)
    local me = ant:K2_GetActorLocation()
    local myName = ant:GetFullName()
    local out = {}
    for _, c in ipairs(FindAllOf("Creature") or {}) do
        if isValid(c) and c:GetFullName() ~= myName then
            local ok, info = pcall(function()
                local l = c:K2_GetActorLocation()
                local en = false
                pcall(function() en = (ant:IsCreatureEnemy(c) == true) end)
                return { c = c, d = dist3(me, l), enemy = en, hp = c.Health, col = c.ColonyID, loc = l }
            end)
            if ok and info then out[#out + 1] = info end
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

local function scanNearby(ant)
    pcall(function()
        say(("me: colony %s  health %.0f/%.0f"):format(tostring(ant.ColonyID), ant.Health, ant.FullHealth))
        local list = nearbyList(ant)
        say("creatures around: " .. #list)
        for i = 1, math.min(#list, 8) do
            local e = list[i]
            say(("  %-24s dist %6.0f  colony %s  enemy=%s  hp %.0f"):format(
                shortName(e.c), e.d, tostring(e.col), tostring(e.enemy), e.hp or -1))
        end
    end)
end

local function printAbilities(ant)
    pcall(function()
        local n = #ant.AbilityList
        say("abilities on this creature: " .. n)
        for i = 1, math.min(n, 12) do
            say("  [" .. i .. "] " .. ant.AbilityList[i].AbilityName:ToString())
        end
    end)
end

------------------------------------------------------------------ mouse look helpers
-- Mouse axis events do not reach the game's input system while the RTS UI owns the mouse, so instead we
-- read the cursor position (plain return values, no out-params) and put the cursor back to the screen
-- centre every time it moved. The difference is the mouse movement.

local mouseLib, mouseRef = nil, nil

local function lib()
    if not isValid(mouseLib) then
        pcall(function() mouseLib = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary") end)
    end
    if isValid(mouseLib) then return mouseLib end
    return nil
end

local function viewportCenter(pc)
    local l = lib()
    if not l then return nil end
    local ok, size = pcall(function() return l:GetViewportSize(pc) end)
    if ok and size and size.X and size.X > 0 then return size.X / 2, size.Y / 2 end
    return nil
end

local function mousePos(pc)
    local l = lib()
    if not l then return nil end
    local ok, p = pcall(function() return l:GetMousePositionOnViewport(pc) end)
    if ok and p and p.X then return p.X, p.Y end
    return nil
end

local function centerCursor(pc)
    local cx, cy = viewportCenter(pc)
    if not cx then return false end
    return (pcall(function() pc:SetMouseLocation(math.floor(cx), math.floor(cy)) end))
end

local function mouseCalibrate(pc)
    mouseRef = nil
    local cx = viewportCenter(pc)
    local centered = centerCursor(pc)
    S.mouseCal = 4   -- wait a few ticks, then remember where the cursor really is
    say(("mouse: library=%s  viewport centre found=%s  cursor centred=%s"):format(
        tostring(lib() ~= nil), tostring(cx ~= nil), tostring(centered)))
end

-- returns dx, dy in screen pixels since the last call (nil if the cursor cannot be read)
local function readMouse()
    local pc = S.pc
    if not isValid(pc) then return nil end
    if S.mouseCal > 0 then
        S.mouseCal = S.mouseCal - 1
        if S.mouseCal == 0 then
            local x, y = mousePos(pc)
            if x then mouseRef = { x, y }; say(("mouse: reference position %.0f, %.0f"):format(x, y))
            else say("mouse: could not read the cursor position") end
        end
        return 0, 0
    end
    if not mouseRef then return nil end
    local x, y = mousePos(pc)
    if not x then return nil end
    local dx, dy = x - mouseRef[1], y - mouseRef[2]
    if math.abs(dx) < 0.5 then dx = 0 end
    if math.abs(dy) < 0.5 then dy = 0 end
    if dx ~= 0 or dy ~= 0 then centerCursor(pc) end
    return dx, dy
end

------------------------------------------------------------------ puppet mode

local function aiController(ant)
    local c
    pcall(function() c = ant:GetController() end)
    if isValid(c) then return c end
    return nil
end

local function aiPause()
    local ant = S.ant
    local ai = S.saved.ai or aiController(ant)
    S.saved.ai = ai
    local a = pcall(function() ant.NoneBTControl = true end)
    local b = pcall(function() ai.BrainComponent:StopLogic("AntCam") end)
    pcall(function() ai:StopMovement() end)
    return a, b
end

local function aiResume()
    local ant = S.ant
    local ai = S.saved.ai or aiController(ant)
    pcall(function() ant.NoneBTControl = false end)
    pcall(function() ai.BrainComponent:StartLogic() end)
end

local function stopMoving()
    pcall(function() S.ant.CreatureMovement:RequestDirectMove({ X = 0.0, Y = 0.0, Z = 0.0 }, false) end)
    S.moving = false
end

local function puppetOn()
    local pc, ant = getPC(), S.ant
    if not (S.active and pc and isValid(ant)) then say("turn on ant view first (F8)"); return end
    S.saved = {}
    S.pc = pc
    local sv = S.saved
    pcall(function() sv.lockout = pc.bLockoutWorldInteraction end)
    pcall(function() pc.bLockoutWorldInteraction = true end)
    pcall(function() pc:SetIgnoreMoveInput(true) end)
    pcall(function() sv.showCursor = pc.bShowMouseCursor end)
    if CFG.mouseLook then
        pcall(function() pc.bShowMouseCursor = false end)
        mouseCalibrate(pc)
    end
    S.mouseSeen, S.mouseTicks = false, 0
    pcall(function() sv.noBT = ant.NoneBTControl end)
    local a, b = aiPause()
    say(("puppet ON (AI paused: %s/%s). WASD move, mouse/arrows look, Q auto-attack."):format(tostring(a), tostring(b)))
    S.auto, S.moving = false, false
    S.puppet = true
end

local function puppetOff()
    if not S.puppet then return end
    local pc, ant, sv = getPC(), S.ant, S.saved or {}
    S.puppet, S.auto = false, false
    if pc then
        pcall(function() pc.bLockoutWorldInteraction = sv.lockout and true or false end)
        pcall(function() pc:SetIgnoreMoveInput(false) end)
        if sv.showCursor ~= nil then pcall(function() pc.bShowMouseCursor = sv.showCursor and true or false end) end
    end
    if isValid(ant) then
        stopMoving()
        pcall(function() ant.NoneBTControl = sv.noBT and true or false end)
        pcall(function() (sv.ai or aiController(ant)).BrainComponent:StartLogic() end)
    end
    say("puppet OFF")
end

local function toggleAuto()
    if not S.puppet then say("press Numpad 1 first (puppet mode), then Q"); return end
    if S.auto then
        S.auto = false
        aiPause()
        say("auto-attack OFF - you steer again")
    else
        S.auto = true
        stopMoving()
        aiResume()
        say("auto-attack ON - the ant fights nearby enemies by itself (WASD disabled)")
    end
end

-- UE4SS's IsKeyBindDown only knows keys that were registered with RegisterKeyBind, so we register
-- the keys we poll (with empty callbacks). As a second opinion we also ask the PlayerController.
local WATCH = { "W", "A", "S", "D", "LEFT", "RIGHT", "UP", "DOWN" }
local UEKEY = { W = "W", A = "A", S = "S", D = "D", LEFT = "Left", RIGHT = "Right", UP = "Up", DOWN = "Down" }
for _, n in ipairs(WATCH) do
    local k = Key[n]
    if k then pcall(RegisterKeyBind, k, function() end)
    else say("watched key name not available in this UE4SS build: " .. n) end
end

local function pressed(name)
    if down(Key[name]) then return true end
    local pc = S.pc
    if pc and isValid(pc) then
        local ok, v = pcall(function() return pc:IsInputKeyDown({ KeyName = FName(UEKEY[name]) }) end)
        if ok and v == true then return true end
    end
    return false
end

local tickCount, assistLogs = 0, 0

local function puppetTick()
    if not (S.active and S.puppet) then return end
    if not (isValid(S.ant) and isValid(S.cam)) then return end
    tickCount = tickCount + 1
    local dt = CFG.tickMs / 1000.0

    local k = {}
    for _, n in ipairs(WATCH) do k[n] = pressed(n) end

    if S.auto then
        -- the view follows where the ant is facing; the game's AI does the fighting
        pcall(function()
            local ar = S.ant:K2_GetActorRotation()
            local d = (ar.Yaw - S.viewYaw + 540.0) % 360.0 - 180.0
            S.viewYaw = S.viewYaw + d * 0.2
        end)
        if CFG.autoAssist and tickCount % 40 == 0 then
            pcall(function()
                for _, e in ipairs(nearbyList(S.ant)) do
                    if e.enemy and (e.hp or 0) > 0 and e.d <= CFG.autoRange then
                        local cur
                        pcall(function() cur = S.ant.CurrentTarget end)
                        if not isValid(cur) then
                            S.ant.CurrentTarget = e.c
                            S.ant:UpdateMovementGoal({ X = e.loc.X, Y = e.loc.Y, Z = e.loc.Z })
                            if assistLogs < 15 then
                                assistLogs = assistLogs + 1
                                say(("auto: heading for %s (dist %.0f)"):format(shortName(e.c), e.d))
                            end
                        end
                        break
                    end
                end
            end)
        end
    else
        if CFG.mouseLook then
            local mx, my = readMouse()
            S.mouseTicks = S.mouseTicks + 1
            if mx and (mx ~= 0 or my ~= 0) then
                if not S.mouseSeen then say("mouse look: mouse input detected") end
                S.mouseSeen = true
                S.viewYaw = S.viewYaw + mx * CFG.mouseSens
                S.viewPitch = math.max(-80, math.min(80, S.viewPitch + (CFG.invertY and 1 or -1) * my * CFG.mouseSens))
            elseif not S.mouseSeen and S.mouseTicks == 240 then
                say("mouse look: no mouse movement reached the mod after ~6 s (arrow keys still work) - tell Claude")
            end
        end
        if k.LEFT  then S.viewYaw = S.viewYaw - CFG.lookSpeed * dt end
        if k.RIGHT then S.viewYaw = S.viewYaw + CFG.lookSpeed * dt end
        local f = (k.W and 1 or 0) - (k.S and 1 or 0)
        local r = (k.D and 1 or 0) - (k.A and 1 or 0)
        if f ~= 0 or r ~= 0 then
            local y = math.rad(S.viewYaw)
            local dx = math.cos(y) * f - math.sin(y) * r
            local dy = math.sin(y) * f + math.cos(y) * r
            local len = math.sqrt(dx * dx + dy * dy)
            dx, dy = dx / len, dy / len
            pcall(function()
                local mv = S.ant.CreatureMovement
                local speed = mv.MaxWalkSpeed
                if not speed or speed <= 0 then speed = 300.0 end
                mv:RequestDirectMove({ X = dx * speed, Y = dy * speed, Z = 0.0 }, true)
            end)
            S.moving = true
        elseif S.moving then
            stopMoving()   -- keys released: cancel the last requested velocity so the ant does not keep running
        end
    end
    if k.UP   then S.viewPitch = math.min(80, S.viewPitch + CFG.lookSpeed * 0.7 * dt) end
    if k.DOWN then S.viewPitch = math.max(-80, S.viewPitch - CFG.lookSpeed * 0.7 * dt) end
    pcall(function()
        S.cam:K2_SetActorRotation({ Pitch = S.viewPitch + CFG.pitch, Yaw = S.viewYaw + CFG.yaw, Roll = CFG.roll }, false)
    end)
end

------------------------------------------------------------------ view switching

local function exitView()
    puppetOff()
    local pc = getPC()
    if S.headHidden then showHead(false) end
    if pc then
        local ok, pawn = pcall(function() return pc.Pawn end)
        if ok and isValid(pawn) then setView(pc, pawn) end
    end
    S.active = false
    say("ant view OFF")
end

local function resetState(why)
    S.active, S.puppet, S.auto, S.moving = false, false, false, false
    S.cam, S.ant, S.mesh, S.pc, S.headHidden = nil, nil, nil, nil, false
    say("ant view reset (" .. why .. ")")
end

local function viewAnt(pc, ant, list, colony)
    puppetOff()
    if S.headHidden then showHead(false) end
    if not ensureCam(pc) then return false end
    if attach(ant) then
        setView(pc, S.cam)
        S.active = true
        local name = ant:GetFullName()
        for i, c in ipairs(list or {}) do
            if c:GetFullName() == name then S.idx = i; break end
        end
        say(("ant view ON  (%d/%d, colony %s)  %s"):format(S.idx, #(list or {}), tostring(colony), name))
        return true
    end
    return false
end

local function useAnt(step)
    local pc = getPC()
    if not pc then say("no player controller (are you in a match?)"); return false end
    local ants, colony = listFriendly(pc)
    if #ants == 0 then say("no living ants of your colony (colony " .. tostring(colony) .. ")"); if S.active then exitView() end; return false end
    S.idx = ((S.idx - 1 + step) % #ants) + 1
    return viewAnt(pc, ants[S.idx], ants, colony)
end

local function retune()
    if S.active and isValid(S.ant) and isValid(S.cam) and not S.puppet then attach(S.ant) end
    say(("mode=%s  offsets: fwd=%.1f up=%.1f pitch=%.1f yaw=%.1f roll=%.1f"):format(CFG.mode, CFG.fwd, CFG.up, CFG.pitch, CFG.yaw, CFG.roll))
end

local function bind(name, fn)
    local k = Key[name]
    if k then RegisterKeyBind(k, function() ExecuteInGameThread(fn) end)
    else say("key not available in this UE4SS build: " .. name) end
end

bind("F8", function() if S.active then exitView() else useAnt(1) end end)
bind("HOME",   function() CFG.mouseSens = CFG.mouseSens * 1.25; say(("mouse sensitivity %.3f"):format(CFG.mouseSens)) end)
bind("END",    function() CFG.mouseSens = CFG.mouseSens / 1.25; say(("mouse sensitivity %.3f"):format(CFG.mouseSens)) end)
bind("INSERT", function() CFG.invertY = not CFG.invertY; say("invert mouse Y: " .. tostring(CFG.invertY)) end)
bind("NUM_ONE", function() if S.puppet then puppetOff() else puppetOn() end end)
bind("Q", function() if S.puppet then toggleAuto() end end)
bind("NUM_THREE", function()
    if isValid(S.ant) then printAbilities(S.ant); scanNearby(S.ant) else say("no ant selected (F8 first)") end
end)
bind("PAGE_UP",   function() if S.active then useAnt(1) end end)
bind("PAGE_DOWN", function() if S.active then useAnt(-1) end end)
bind("ADD",       function() CFG.fwd = CFG.fwd + 2; retune() end)
bind("SUBTRACT",  function() CFG.fwd = CFG.fwd - 2; retune() end)
bind("MULTIPLY",  function() CFG.up = CFG.up + 1; retune() end)
bind("DIVIDE",    function() CFG.up = CFG.up - 1; retune() end)

LoopAsync(CFG.tickMs, function()
    if S.puppet then ExecuteInGameThread(puppetTick) end
    return false
end)

-- housekeeping: leaving a match, or the followed ant dying, must never leave the mod spinning
LoopAsync(500, function()
    if S.active then
        ExecuteInGameThread(function()
            if not S.active then return end
            if not getPC() then
                resetState("left the match")
            elseif not isValid(S.ant) then
                say("followed ant is gone, switching")
                useAnt(1)
                if not (S.active and isValid(S.ant)) then exitView() end
            end
        end)
    end
    return false
end)

say("loaded. In a match press F8 for ant view, Numpad 1 for puppet mode, Q for auto-attack.")

--[[ SRCWMenu: the computer racers' own karts, in Grand Prix and Race Park.
The computer racers get their own kart back (front, rear and tires) and its own colours instead of the random ones
the game 2.0 gives them, in the modes turned on in the menu (settings kart_gp / kart_racepark / kart_colors).
How it works:
  - before ApplyCOMCharacter: each drawn machine -> the slot driver's own one (karts.lua) when the computer may use
    it, so the game itself sets the matching machine type;
  - after it: rear and tires = that machine, and the kart's colour preset (colors.lua), for the computer racers
    only (drawn by the lottery, or the rival). Players are never touched.
Colours are left as the game drew them in team races (Race Park groups): the team colours must stay.
The racers themselves go through roster.lua first (the CPU list), in the same pre-hook. A racer's own kart is also
allowed when CanUseMachine says the player can use it (Beast Spike, McLaren car). Special karts: see M.ALTS. ]]
local U = require("util")
local S = require("settings")
local roster = require("roster")
local log = U.log
local M = {}

local KART = dofile(U.DIR .. "/Scripts/karts.lua")
local COLOR = {}
do
    local ok, t = pcall(dofile, U.DIR .. "/Scripts/colors.lua")
    if ok and type(t) == "table" then COLOR = t else log("colors.lua not loaded (" .. tostring(t) .. "): colours left as drawn") end
end
-- EGameModeId -> the setting that turns the mod on in that mode
local MODES = {[1] = {key = "kart_gp", roster = "gp", name = "Grand Prix"},
               [2] = {key = "kart_racepark", roster = "racepark", name = "Race Park"}}
local INDIVIDUAL = 0                         -- ERaceSettingGrouping::Individual (1, 2 = team races)

-- special karts (settings [Special karts]): a racer may get a second kart instead of its own one,
-- only when the player can use that kart (otherwise its own kart). colors = the kart whose colour preset it wears.
M.ALTS = {
    {key = "alt_supersonic", driver = 46, kart = 171, default = 6},   -- Super Shooting Star (DSH_26) / Super Shining
    {key = "alt_sonic", driver = 0, kart = 140, default = 0},          -- Blue Star (DSH_51) / Speedster Lightning
    {key = "alt_nine", driver = 53, kart = 37, default = 30},          -- Cyber Spear (ACL_08) / Whirlwind Sport
    {key = "alt_dread", driver = 55, kart = 101, default = 90},        -- Goromaru (POW_12) / Land Smasher
    {key = "alt_rusty", driver = 54, kart = 68, default = 60},         -- Moto Beetle (HND_09) / Pink Cabriolet
    {key = "alt_protoman", driver = 73, kart = 140, colors = 40, default = 40},  -- Blue Star in Rush Roadstar colours
}
-- the kart a racer gets, and the kart whose colours it wears
local function own_kart(d, usable)
    for _, a in ipairs(M.ALTS) do
        if a.driver == d and S.bool(a.key) and usable[a.kart] then return a.kart, a.colors or a.kart end
    end
    return KART[d], KART[d]
end

local function A()
    local a = U.cdo("/Script/UNION.Default__AppRaceConfigDataAccessor")
    if not a then error("AppRaceConfigDataAccessor not found") end
    return a
end
local function list(arr)
    local t = {}
    pcall(function() arr:ForEach(function(_, e) t[#t + 1] = e:get() end) end)
    return t
end
local function unwrap(x)
    if type(x) == "userdata" then local ok, g = pcall(function() return x:get() end); if ok then return g end end
    return x
end
local function copy(t)                      -- the out-param table, as plain values / nested tables
    local c = {}
    for k, x in pairs(t) do
        x = unwrap(x)
        if type(x) == "table" then c[k] = copy(x)
        elseif type(x) == "number" or type(x) == "boolean" or type(x) == "string" then c[k] = x end
    end
    return c
end
local function driver_of(i) local t = {}; A():GetRacerDriverId(i, t); return unwrap(t.OutId) end
local function parts_of(i) local t = {}; A():GetRacerMachineCustomizeData(i, t); return t end
local function machine_of(i) local t = {}; A():GetRacerMachineID(i, t); return unwrap(t.OutId) end

-- the kart's own colours, written the way the game writes a preset into a kart
local PRESET_MODE = 1                       -- EMachineColorMode::Preset
local AREAS = {"ColorArea1", "SurfaceArea1", "ColorArea2", "SurfaceArea2", "ColorArea3", "SurfaceArea3", "Glow"}
local GROUPS = {{"Body", 2}, {"Tire", 9}, {"Cockpit", 16}}   -- name in FUserMachineCustomizeData, first index in COLOR[]
local function set_colors(p, own)           -- true if something changed in p
    local c = COLOR[own]
    if not c then return false end
    local changed = false
    local function put(k, v) if p[k] ~= v then p[k] = v; changed = true end end
    put("ColorMode", PRESET_MODE)
    put("ColorPresetId", c[1])
    for _, g in ipairs(GROUPS) do
        for k, a in ipairs(AREAS) do
            local name = g[1] .. a
            if a == "Glow" then name = (g[1] ~= "Cockpit") and (g[1] .. "GlowColor") or nil end
            if name then put(name, c[g[2] + k - 1]) end
        end
    end
    return changed
end

local state = nil                           -- set by the pre-hook for the post-hook (same ApplyCOMCharacter call)

local function before_apply(o)
    state = nil
    U.try("settings", S.reload)             -- SRCWMenu.ini may have been edited by hand since the last race
    local mode = A():GetSelectedGameModeId()
    local drivers, machines = list(o.CalcedComDriverId), list(o.CalcedComMachineId)
    log(string.format("lottery (mode %s): drivers %s | machines %s | used %s", tostring(mode),
        table.concat(drivers, ","), table.concat(machines, ","), table.concat(list(o.CurrentUsedDriverId), ",")))
    local m = MODES[mode]
    if not m then log("karts: mode " .. tostring(mode) .. " is not handled, nothing changed"); return end
    -- first the racers (the CPU list), then their karts: the karts follow the racers actually kept
    local ok_list, forced = U.try("CPU list", roster.apply, o, m.roster)
    forced = (ok_list and type(forced) == "table") and forced or {}   -- slot -> kart of a kart combo
    drivers = list(o.CalcedComDriverId)
    local only_forced = not S.bool(m.key)
    if only_forced and next(forced) == nil then log("karts: OFF in " .. m.name .. " (menu), the game's random karts stay"); return end
    -- a kart the computer may get: one the game lets it draw (EnableMachineId, the drawn ones), or one the game says
    -- the player can use (CanUseMachine: owned paid DLC, released content). The game keeps some karts out of the
    -- computer's draw even when owned: Beast Spike 110 (Werehog), McLaren Racing Car 164; Rival Duel gives them to
    -- these racers all the same.
    local usable = {}
    for _, id in ipairs(list(o.EnableMachineId)) do usable[id] = true end
    for _, id in ipairs(machines) do usable[id] = true end
    local utils = U.cdo("/Script/UnionSystem.Default__UnionContentUtils")
    setmetatable(usable, {__index = function(t, id)
        local ok, r = pcall(function() return utils:CanUseMachine(id) == true end)
        local v = ok and r or false
        rawset(t, id, v)
        return v
    end})
    local com = {}
    for _, d in ipairs(drivers) do com[d] = true end
    local grouping = INDIVIDUAL
    pcall(function() grouping = A():GetRaceSettingGrouping() end)
    -- machine slot i = drawn driver i, then one more slot, LAST, for the rival: CurrentUsedDriverId = the
    -- player(s) then the rival (e.g. "84,7": rival Silver, "76,21": rival Wave)
    local slots = {}
    for i, d in ipairs(drivers) do slots[i] = d end
    local used = list(o.CurrentUsedDriverId)
    local has_rival = #machines == #drivers + 1 and #used >= 2
    if has_rival then slots[#machines] = used[#used] end
    -- the players come first in the race (index 0.., seen in every log): with kart combos a computer racer may be the
    -- same character as a player, so players are told apart by their place, never by their character
    local players = #used - (has_rival and 1 or 0)
    state = {usable = usable, com = com, name = m.name, players = players, only_forced = only_forced, forced = {},
             colors = S.bool("kart_colors") and (mode == 1 or grouping == INDIVIDUAL), grouping = grouping}
    local arr, changed = o.CalcedComMachineId, 0
    for i, d in pairs(slots) do
        local own = forced[i]
        if own and usable[own] then
            state.forced[d] = state.forced[d] or {}
            state.forced[d][own] = true
        else
            own = (not only_forced) and own_kart(d, usable) or nil
        end
        if i <= #machines and own ~= nil and usable[own] and machines[i] ~= own then
            arr[i] = own; changed = changed + 1
        end
    end
    log(string.format("%s: %d drawn machines set to the driver's own one -> %s (colours %s, grouping %s)", m.name,
        changed, table.concat(list(o.CalcedComMachineId), ","), state.colors and "own" or "left as drawn", tostring(grouping)))
end

local function after_apply()
    if not state then return end
    local n = A():GetRacerCount()
    local done, notes = 0, {}
    for i = 0, n - 1 do
        local d = driver_of(i)
        local rival = A():IsRaceRivalByRacerIndex(i) == true
        if i >= state.players and (state.com[d] or rival) then
            local p = copy(parts_of(i))
            local own, color_kart
            local fk = state.forced[d]
            if fk and fk[p.FrontPartsId] then
                own, color_kart = p.FrontPartsId, p.FrontPartsId       -- a kart combo: the kart it was given
            elseif not state.only_forced then
                own, color_kart = own_kart(d, state.usable)
            end
            local line = string.format("[%d] drv %s%s machineID %s parts %s/%s/%s", i, tostring(d), rival and " (rival)" or "",
                tostring(machine_of(i)), tostring(p.FrontPartsId), tostring(p.RearPartsId), tostring(p.TirePartsId))
            if state.only_forced and own == nil then
                notes[#notes + 1] = line .. " kept (karts off in this mode)"
            elseif own == nil or not state.usable[own] then
                notes[#notes + 1] = line .. " kept (own " .. tostring(own) .. " not usable)"
            elseif p.FrontPartsId ~= own then
                notes[#notes + 1] = line .. " kept (front is not its own machine " .. tostring(own) .. ")"
            else
                local before = string.format(" colour %s/%s", tostring(p.ColorMode), tostring(p.ColorPresetId))
                local parts = p.RearPartsId ~= own or p.TirePartsId ~= own
                p.RearPartsId, p.TirePartsId = own, own
                local colors = state.colors and set_colors(p, color_kart)
                if parts or colors then
                    A():SetRacerMachineCustomizeData(i, p)
                    local q = copy(parts_of(i))
                    notes[#notes + 1] = line .. before .. string.format(" -> %s/%s/%s colour %s/%s", tostring(q.FrontPartsId),
                        tostring(q.RearPartsId), tostring(q.TirePartsId), tostring(q.ColorMode), tostring(q.ColorPresetId))
                    done = done + 1
                else
                    notes[#notes + 1] = line .. before .. " already its own machine" .. (state.colors and " and colours" or "")
                end
            end
        end
    end
    log(string.format("%s: own rear / tires%s set on %d COM racers\n  %s", state.name, state.colors and " / colours" or "",
        done, table.concat(notes, "\n  ")))
    state = nil
end

local registered = false
local function register()
    local ok, err = pcall(function()
        RegisterHook("/Script/UNION.ComCharaMachineLottery:ApplyCOMCharacter", function(self)
            local ok1, e1 = pcall(function() before_apply(self:get()) end)
            if not ok1 then state = nil; log("karts: error before the apply, nothing more changed: " .. tostring(e1)) end
        end, function()
            local ok2, e2 = pcall(after_apply)
            if not ok2 then state = nil; log("karts: error after the apply, stopped: " .. tostring(e2)) end
        end)
    end)
    local n, nc = 0, 0
    for _ in pairs(KART) do n = n + 1 end
    for k in pairs(COLOR) do if type(k) == "number" then nc = nc + 1 end end
    if ok then registered = true; log("karts: hook registered (" .. n .. " drivers' karts, " .. nc .. " karts' colours known)")
    else log("karts: hook FAILED: " .. tostring(err)) end
end

-- the hook can only be registered once the function exists: try every 3 s until it is done
function M.start()
    LoopAsync(3000, function()
        if registered then return true end
        ExecuteInGameThread(function()
            if registered then return end
            local f = StaticFindObject("/Script/UNION.ComCharaMachineLottery:ApplyCOMCharacter")
            if f and f:IsValid() then register() end
        end)
        return registered
    end)
end

return M

--[[ SRCWMenu: which racers the computer may use, per mode (Grand Prix / Race Park).
Per mode: "game" = the game's own draw, untouched; otherwise the name of a list file (lists.lua).
How: in the same pre-hook as the karts (before UComCharaMachineLottery::ApplyCOMCharacter), EVERY drawn computer
racer (CalcedComDriverId) is drawn again at random from the list, never twice and never a racer a player or the rival
already uses (CurrentUsedDriverId). The rival itself is the game's (not in the draw). Every slot is drawn again, not
only the racers missing from the list: the game never draws the AI racers, so they could not come otherwise.
A racer is usable only if the game would allow it: a paid DLC only when its package is owned (m_packageIds), a
guest released by server date only when CanUseCharacter says so. Paid content is never forced in.
If the list has too few usable racers, the remaining slots keep the game's draw (written in the log). ]]
local U = require("util")
local S = require("settings")
local lists = require("lists")
local log = U.log
local M = {}

M.DRIVERS = lists.DRIVERS
M.BY_ID = {}
for _, d in ipairs(M.DRIVERS) do M.BY_ID[d.id] = d end
M.GROUPS = {"base", "ai", "aicolor", "guest", "super"}
M.MODES = {gp = {setting = "roster_gp", name = "Grand Prix"}, racepark = {setting = "roster_racepark", name = "Race Park"}}

-- a mode points at a list file by its name (lists.lua), or at "game"
function M.list_name(mode) return S.get(M.MODES[mode].setting) or "game" end
function M.custom(mode) return M.list_name(mode) ~= "game" end
function M.get_list(mode)                    -- set {id = true} of the mode's list (empty if its file is missing)
    if not M.custom(mode) then return {} end
    return lists.get(M.list_name(mode)) or {}
end
function M.set_list(mode, set)
    if M.custom(mode) then lists.save(M.list_name(mode), set) end
end
function M.count(set) local n = 0; for _ in pairs(set) do n = n + 1 end; return n end

-- the next choice for a mode: game -> each list of the folder in turn -> game
function M.cycle(mode)
    local names = lists.names() or {}
    local cur, nxt = M.list_name(mode), "game"
    local found = false
    for i, n in ipairs(names) do if n == cur then nxt = names[i + 1] or "game"; found = true end end
    if cur == "game" or not found then nxt = names[1] or "game" end
    S.set(M.MODES[mode].setting, nxt)
    return nxt
end

-- {id = true / false}: may the computer use this racer now
function M.usable_map()
    local owned = {}
    local mgr = U.live("UnionContentManager")
    if mgr then pcall(function() mgr.m_packageIds:ForEach(function(_, e) owned[e:get()] = true end) end) end
    local utils = U.cdo("/Script/UnionSystem.Default__UnionContentUtils")
    local t = {}
    for _, d in ipairs(M.DRIVERS) do
        if not d.driver then
            local ok = true
            if d.package then ok = owned[d.package] == true
            elseif d.content or d.special then
                ok = false
                pcall(function() ok = utils:CanUseCharacter(d.id) == true end)
            end
            t[d.id] = ok
        end
    end
    -- a kart combo: its kart's pack owned AND its racer usable (NiGHTS, Classic Sonic are dated guests)
    for _, d in ipairs(M.DRIVERS) do
        if d.driver then t[d.id] = owned[d.package] == true and t[d.driver] ~= false end
    end
    M.owned = owned
    return t
end
-- why a racer can't be used now: "not_owned" / "not_released" / "not_playable" / nil
function M.why_not(d, usable)
    if usable[d.id] then return nil end
    if d.special then return "not_playable" end
    if d.driver then return (M.owned and M.owned[d.package]) and "not_released" or "not_owned" end
    return d.package and "not_owned" or "not_released"
end

local function shuffle(t)
    for i = #t, 2, -1 do local j = math.random(i); t[i], t[j] = t[j], t[i] end
end

-- the pre-hook part: o = the UComCharaMachineLottery, mode = "gp" / "racepark"
function M.apply(o, mode)
    if not M.custom(mode) then return end
    local allowed = lists.get(M.list_name(mode))
    if not allowed then
        log("CPU list (" .. M.MODES[mode].name .. "): list \"" .. M.list_name(mode) .. "\" not found in Lists, the game's draw stays")
        return
    end
    local usable = M.usable_map()
    -- kart combos ("Godzilla Cruiser (Sonic)": an entry of its own, id 1001+, a racer = d.driver driving d.kart).
    -- With ComboDuplicates on, a combo may race next to the same character (a player's, the rival's or another
    -- computer racer's); plain racers are never twice in a race.
    local dup = S.get("combo_duplicates") ~= "off"
    -- FillWithClones: when the list runs out, the slots left are filled with racers of the list again (clones)
    -- instead of the game's draw
    local clones_on = S.get("fill_clones") == "on"
    local used, taken = {}, {}               -- taken = the players' and the rival's characters
    for _, d in ipairs(U.list(o.CurrentUsedDriverId)) do used[d] = true; taken[d] = true end
    local pool, n_ok = {}, 0
    for id in pairs(allowed) do
        if usable[id] then
            n_ok = n_ok + 1
            pool[#pool + 1] = id
        end
    end
    table.sort(pool)
    shuffle(pool)
    local drawn = U.list(o.CalcedComDriverId)
    local arr, picks, kept, forced = o.CalcedComDriverId, {}, {}, {}
    local function take()                    -- the next usable pick of the list for this slot, or nil
        while #pool > 0 do
            local id = table.remove(pool)
            local d = M.BY_ID[id]
            local real = d and d.driver or id
            if d and d.driver and dup then return id, real end        -- a combo: next to the same character is fine
            if not used[real] then return id, real end
        end
        return nil
    end
    local function place(i, id, real)
        arr[i] = real; used[real] = true
        local d = M.BY_ID[id]
        if d and d.kart then forced[i] = d.kart end               -- slot i drives that kart (kart.lua)
    end
    local left = {}
    for i = 1, #drawn do
        local id, real = take()
        if id then place(i, id, real); picks[#picks + 1] = id else left[#left + 1] = i end
    end
    -- the list ran out: clones of its racers (never of a player's or the rival's character, except a combo
    -- when ComboDuplicates is on), else the game's draw
    local clones = {}
    if #left > 0 and clones_on then
        local again = {}
        for id in pairs(allowed) do
            if usable[id] then
                local d = M.BY_ID[id]
                if (d and d.driver and dup) or not taken[d and d.driver or id] then again[#again + 1] = id end
            end
        end
        table.sort(again)
        shuffle(again)
        if #again > 0 then
            for k, i in ipairs(left) do
                local id = again[(k - 1) % #again + 1]
                local d = M.BY_ID[id]
                place(i, id, d and d.driver or id)
                clones[#clones + 1] = id
            end
            left = {}
        end
    end
    for _, i in ipairs(left) do
        -- the next racer the game drew that nobody uses yet
        for _, d in ipairs(drawn) do
            if not used[d] then arr[i] = d; used[d] = true; kept[#kept + 1] = d; break end
        end
    end
    log(string.format("CPU list (%s, list \"%s\"): %d usable racers in it; drawn again %s%s%s -> drivers %s (game's draw was %s)",
        M.MODES[mode].name, M.list_name(mode), n_ok, #picks > 0 and table.concat(picks, ",") or "none",
        #clones > 0 and ("; clones " .. table.concat(clones, ",")) or "",
        #kept > 0 and ("; too few, kept the game's " .. table.concat(kept, ",")) or "",
        table.concat(U.list(o.CalcedComDriverId), ","), table.concat(drawn, ",")))
    return forced
end

math.randomseed(os.time())
return M

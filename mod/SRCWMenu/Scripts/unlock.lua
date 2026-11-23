--[[ SRCWMenu: unlock the AI colour skins for the session, and lock them again.
  F7 = unlock the AI colour skins that are still locked (EDriverId 100-168), for the session.
  F8 = lock again the AI colours unlocked by F7 (also done automatically at the next launch).
relock.txt records what F7 changed (EDriverId and its original "new" flag) BEFORE the save is touched; the next
launch locks them again, and the record goes only once a launch finds the save already back to its original state.
Nothing else of the save is touched, and nothing paid or not yet released is unlocked. ]]
local U = require("util")
local log = U.log
local M = {}

-- a record file: ours, or the old UnlockKeys one while it still exists (an older session not restored yet)
local function record_path(name)
    local own, old = U.DIR .. "/" .. name, U.LEGACY_UNLOCK .. "/" .. name
    if U.exists(own) then return own end
    if U.exists(old) then return old end
    return own
end

-- ===================================================================== the game's save helper
local SONIC = 0                          -- always selectable once the save is loaded
local function H() return U.cdo("/Script/UnionSystem.Default__AppSaveGameHelper") end
local function selectable(id) return H():IsSelectableDriver(id) == true end
local function is_new(id) return H():IsNewDriver(id) == true end
local function set_prop(id, sel, new)
    local ok = pcall(function() H():SetUserDriverProperty(id, {bIsSelectable = sel, bIsNew = new}) end)
    if not ok or selectable(id) ~= sel then
        if sel then H():SetDriverSelectable(id) else H():SetDriverUnselectable(id) end
    end
    return selectable(id) == sel
end

-- the save is loaded once Sonic is selectable
function M.save_loaded()
    local ok, r = pcall(function() return H() ~= nil and selectable(SONIC) end)
    return ok and r == true
end

-- ===================================================================== F7 / F8: AI colours (save flags)
local FIRST, LAST = 100, 168            -- SonicRacerColor01 .. StormRacerColor03 (04/11/2026 build)

local function read_record()
    local t = {}
    local f = io.open(record_path("relock.txt"), "r")
    if not f then return t end
    for line in f:lines() do
        local id, new = line:match("^(%d+)%s+(%d)")
        if id then t[#t + 1] = {id = tonumber(id), new = (new == "1")} end
    end
    f:close()
    return t
end
local function write_record(t)
    local path = record_path("relock.txt")
    local f = io.open(path, "w")
    if not f then error("cannot write " .. path) end
    f:write("# AI colours unlocked by SRCWMenu / UnlockKeys (all were locked): EDriverId, original bIsNew\n")
    for _, e in ipairs(t) do f:write(string.format("%d %d\n", e.id, e.new and 1 or 0)) end
    f:close()
end
local function ids(t)
    local s = {}
    for _, e in ipairs(t) do s[#s + 1] = tostring(e.id) end
    return table.concat(s, ",")
end

function M.locked_count()
    local n = 0
    for id = FIRST, LAST do if not selectable(id) then n = n + 1 end end
    return n
end

-- F7; returns a message key (lang.lua) and its numbers
function M.unlock_colours()
    local rec = read_record()
    local have = {}
    for _, e in ipairs(rec) do have[e.id] = true end
    local todo, added = {}, 0
    for id = FIRST, LAST do
        if not selectable(id) then
            local e = {id = id, new = is_new(id)}
            todo[#todo + 1] = e
            if not have[id] then rec[#rec + 1] = e; added = added + 1 end   -- kept records keep their original bIsNew
        end
    end
    if #todo == 0 then
        log("F7: no locked AI colour left (" .. #rec .. " recorded by this mod)")
        return "msg_none_locked"
    end
    if added > 0 then write_record(rec) end   -- the record exists BEFORE the save is touched
    local bad = {}
    for _, e in ipairs(todo) do
        if not set_prop(e.id, true, e.new) then bad[#bad + 1] = e end
    end
    log(string.format("F7: unlocked %d AI colours [%s]%s", #todo - #bad, ids(todo),
        #bad > 0 and ("; FAILED for [" .. ids(bad) .. "]") or ""))
    return "msg_unlocked", #todo - #bad, #bad
end

-- F8 (why = "F8", "menu" or "launch"); returns a message key (lang.lua) and its numbers
function M.relock_colours(why)
    local rec = read_record()
    if #rec == 0 then
        if why ~= "launch" then log((why or "F8") .. ": nothing to lock again") end
        return "msg_nothing_relock"
    end
    local failed = {}
    for _, e in ipairs(rec) do
        if not set_prop(e.id, false, e.new) then failed[#failed + 1] = e end
    end
    -- a locked skin must not stay the selected character
    local ok, cur = pcall(function() return H():GetUserSelectedDriverId() end)
    if ok and type(cur) == "number" then
        for _, e in ipairs(rec) do
            if cur == e.id then
                H():SetUserSelectedDriverId(SONIC)
                log("selected character was " .. cur .. " (locked again) -> Sonic")
                break
            end
        end
    end
    log(string.format("%s: locked again %d AI colours [%s]%s; relock.txt kept until a launch finds them saved",
        why or "F8", #rec - #failed, ids(rec), #failed > 0 and ("; FAILED for [" .. ids(failed) .. "]") or ""))
    return "msg_relocked", #rec - #failed, #failed
end

-- at launch: the record goes only if the save already holds every recorded colour locked; otherwise relock
local function launch_colours()
    local rec = read_record()
    if #rec == 0 then return end
    local still = 0
    for _, e in ipairs(rec) do if selectable(e.id) then still = still + 1 end end
    if still == 0 then
        local path = record_path("relock.txt")
        os.remove(path)
        log("launch: the " .. #rec .. " recorded AI colours are locked in the save: " .. path .. " removed")
        return
    end
    M.relock_colours("launch")
end

-- once the save is loaded: put back what an earlier session changed
function M.on_save_loaded()
    log("save loaded; relock.txt entries: " .. #read_record())
    U.try("launch colours", launch_colours)
end

return M

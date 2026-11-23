--[[ SRCWMenu v0.5.0 by GibaxLeGrand - UE4SS v4 mod for Sonic Racing CrossWorlds
An in-game menu (F10) for the computer racers of Grand Prix and Race Park (offline modes; the online Festival is
never touched):
  - the CPU racers drive their own kart (and its own colours) instead of a random one, with a few special karts;
  - the CPU racers are drawn from a racer list of your own (Lists\<name>.ini), one list per mode, AI racers included;
  - the AI colour skins can be unlocked for the session, and are locked again at the next launch.
Nothing paid or not yet released is ever unlocked or given to a racer: a DLC racer or kart is used only when you own
it, a dated guest only once the game lets you play it.

HOW TO USE / MODE D'EMPLOI
  F10            open / close the menu                       ouvrir / fermer le menu
  in the menu    mouse: hover = choose, left click = select, right click = back
                 numpad 8 / 2 or Page Up / Page Down = choose, numpad 5 / 4 / 6 or Home = select, Backspace = back
                 (Num Lock on for the numpad / Verr. Num actif pour le pave numerique)
  F7 / F8        AI colour skins: unlock for the session / lock them again (also two buttons of the editor)
  F9             Grand Prix: CPU racers use their own kart, on / off
Settings in SRCWMenu.ini and Lists\*.ini (mod folder), editable by hand or with SRCWMenuEditor.exe, game closed or
open: they are read again before each race. Log: ue4ss\UE4SS.log, lines "[SRCWMenu]".

Files: util.lua (helpers), settings.lua, lang.lua (texts EN / FR), unlock.lua (F7 / F8), kart.lua (own karts),
lists.lua (list files), roster.lua (CPU racers drawn from a list), menu.lua, and data generated from the game's
tables: karts.lua (racer -> own kart), colors.lua (kart -> own colours), drivers.lua (racers the lists offer). ]]
local VERSION = "0.5.0"
local U = require("util")
local S = require("settings")
local unlock = require("unlock")
local kart = require("kart")
local menu = require("menu")
local log = U.log

local ready = false                        -- the save is loaded (the unlock functions need it)
menu.ready = function() return ready end

-- every key runs in the game thread, protected; menu-only keys do nothing while the menu is closed
local function bind(key, label, f, menu_only)
    if key == nil then log("key for " .. label .. " missing in this UE4SS, not bound"); return end
    RegisterKeyBind(key, function()
        ExecuteInGameThread(function()
            if menu_only and not menu.is_open() then return end
            U.try(label, f)
        end)
    end)
end
local function with_save(name, f)
    return function()
        if not ready then log(name .. ": the save is not loaded yet, try again in a few seconds"); return end
        menu.notify(f())
    end
end

bind(Key.F10, "F10", menu.toggle)
bind(Key.F7, "F7", with_save("F7", unlock.unlock_colours))
bind(Key.F8, "F8", with_save("F8", function() return unlock.relock_colours("F8") end))
bind(Key.F9, "F9", function()
    local on = S.toggle("kart_gp")
    log("F9: Grand Prix karts " .. (on and "ON" or "OFF") .. " (from the next race)")
    menu.notify("msg_f9", on)
end)
local up, down = function() menu.move(-1) end, function() menu.move(1) end
bind(Key.NUM_EIGHT, "menu up", up, true)
bind(Key.PAGE_UP, "menu up", up, true)
bind(Key.NUM_TWO, "menu down", down, true)
bind(Key.PAGE_DOWN, "menu down", down, true)
bind(Key.NUM_FIVE, "menu run", menu.run, true)
bind(Key.NUM_FOUR, "menu run", menu.run, true)
bind(Key.NUM_SIX, "menu run", menu.run, true)
bind(Key.HOME, "menu run", menu.run, true)
bind(Key.BACKSPACE, "menu back", menu.back, true)
bind(Key.LEFT_MOUSE_BUTTON, "menu click", menu.click, true)
bind(Key.RIGHT_MOUSE_BUTTON, "menu back", menu.back, true)

kart.start()

-- The AI skin buttons of SRCWMenuEditor.exe: the editor writes request.txt ("unlock_colours <unix time>" or
-- "relock_colours <unix time>") next to SRCWMenu.ini, then waits a few seconds for request_done.txt ("<same time>"
-- then the message). The request file is removed as soon as it is read, and a request older than 30 s is dropped:
-- nothing ever runs at a later launch.
local L = require("lang")
local REQUEST, ANSWER = U.DIR .. "/request.txt", U.DIR .. "/request_done.txt"
local ACTIONS = {
    unlock_colours = function() return unlock.unlock_colours() end,
    relock_colours = function() return unlock.relock_colours("editor") end,
}
local function check_request()
    local f = io.open(REQUEST, "r")
    if not f then return end
    local text = f:read("a")
    f:close()
    os.remove(REQUEST)
    local what, stamp = text:match("^%s*(%S+)%s+(%d+)")
    if not what or not ACTIONS[what] then log("editor request not understood: " .. text); return end
    if math.abs(os.time() - tonumber(stamp)) > 30 then log("editor request " .. what .. " too old, dropped"); return end
    local key, a, b = "msg_save", nil, nil
    if ready then key, a, b = ACTIONS[what]() end
    log("editor request " .. what .. ": " .. L.t(key, a, b))
    menu.notify(key, a, b)
    local out = io.open(ANSWER, "w")
    if out then out:write(stamp .. "\n" .. L.t(key, a, b) .. "\n"); out:close() end
end
LoopAsync(1000, function()
    ExecuteInGameThread(function() U.try("editor request", check_request) end)
    return false
end)

log(string.format("loaded v%s; karts Grand Prix %s, Race Park %s, colours %s; CPU lists GP %s, Race Park %s; " ..
    "language %s; F10 = menu; waiting for the save", VERSION, S.get("kart_gp"),
    S.get("kart_racepark"), S.get("kart_colors"), S.get("roster_gp"), S.get("roster_racepark"), S.get("lang")))
LoopAsync(2000, function()
    if ready then return true end
    ExecuteInGameThread(function()
        if ready or not unlock.save_loaded() then return end
        ready = true
        unlock.on_save_loaded()
    end)
    return false
end)

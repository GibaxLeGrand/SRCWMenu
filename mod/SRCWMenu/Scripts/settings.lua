--[[ SRCWMenu: the settings, in SRCWMenu.ini next to the mod.
  [Menu]        Language = en | fr
  [Karts]       GrandPrix / RacePark / OwnColours = on | off
  [CPU racers]  GrandPrix / RacePark = game (the game's own draw) or the name of a list of the Lists folder
  [Special karts]  see kart.lua M.ALTS
The racer lists themselves are files of their own (lists.lua). The file is read again before each race and each
time the menu opens (a hand edit counts from the next race); the menu writes it back whole (comments added by hand
are not kept: SRCWMenuEditor.exe keeps them). Early versions used settings.txt: it is imported once (its lists
become "My Grand Prix" / "My Race Park"), then left with a note. ]]
local U = require("util")
local lists = require("lists")
local S = {}

S.DEFAULTS = {
    kart_gp = "on",              -- Grand Prix: the computer racers get their own kart
    kart_racepark = "off",       -- Race Park: same
    kart_colors = "on",          -- ...and the kart's own colours (never in team races)
    roster_gp = "game",          -- Grand Prix computer racers: "game" or a list name
    roster_racepark = "game",
    combo_duplicates = "on",     -- a kart combo ("Godzilla Cruiser (Sonic)") may race next to the same character
    fill_clones = "off",         -- a list too short for the race: clones of its racers fill the slots left
    lang = "en",
    alt_supersonic = "off", alt_sonic = "off", alt_nine = "off",          -- special karts (kart.lua M.ALTS)
    alt_dread = "off", alt_rusty = "off", alt_protoman = "off",
}
local INI = U.DIR .. "/SRCWMenu.ini"
local OLD = U.DIR .. "/settings.txt"
local KEYS = {  -- section, name in the file, internal key, keep the case (list names)
    {"Menu", "Language", "lang"},
    {"Karts", "GrandPrix", "kart_gp"},
    {"Karts", "RacePark", "kart_racepark"},
    {"Karts", "OwnColours", "kart_colors"},
    {"CPU racers", "GrandPrix", "roster_gp", true},
    {"CPU racers", "RacePark", "roster_racepark", true},
    {"CPU racers", "ComboDuplicates", "combo_duplicates"},
    {"CPU racers", "FillWithClones", "fill_clones"},
    {"Special karts", "SuperSonic", "alt_supersonic"},
    {"Special karts", "Sonic", "alt_sonic"},
    {"Special karts", "Nine", "alt_nine"},
    {"Special karts", "Dread", "alt_dread"},
    {"Special karts", "RustyRose", "alt_rusty"},
    {"Special karts", "ProtoMan", "alt_protoman"},
}
local values = {}
local last_text = nil                       -- the file as last read or written (to notice outside changes)

local function read_file(p)
    local f = io.open(p, "r")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end

local function parse_ini(text)
    local v = {}
    for k, d in pairs(S.DEFAULTS) do v[k] = d end
    local section = nil
    for raw in (text .. "\n"):gmatch("(.-)\r?\n") do
        local line = raw:gsub("^%s+", ""):gsub("%s+$", "")
        local sec = line:match("^%[(.+)%]$")
        if sec then
            section = sec:lower()
        elseif line ~= "" and not line:match("^[;#]") then
            local key, val = line:match("^(.-)%s*=%s*(.-)$")
            if key then
                val = val:gsub("%s*;.*$", ""):gsub("%s+$", "")
                for _, k in ipairs(KEYS) do
                    if k[1]:lower() == section and k[2]:lower() == key:lower() then
                        v[k[3]] = k[4] and val or val:lower()
                        if k[4] and val:lower() == "game" then v[k[3]] = "game" end
                    end
                end
            end
        end
    end
    return v
end

local function ini_text()
    return table.concat({
        "; SRCWMenu settings (Sonic Racing CrossWorlds, UE4SS mod). In game: F10 opens the menu, which writes this file.",
        "; You can also edit it by hand or with SRCWMenuEditor.exe, game closed or open: it is read again before each race.",
        "", "[Menu]",
        "Language = " .. values.lang .. "        ; en or fr",
        "", "[Karts]",
        "GrandPrix = " .. values.kart_gp .. "      ; CPU racers use their own kart in Grand Prix",
        "RacePark = " .. values.kart_racepark .. "       ; same in Race Park",
        "OwnColours = " .. values.kart_colors .. "     ; and the kart's own colours (never in team races)",
        "", "[CPU racers]",
        "; game = the game's own draw; otherwise the name of a list of the Lists folder (Lists\\<name>.ini)",
        "GrandPrix = " .. values.roster_gp,
        "RacePark = " .. values.roster_racepark,
        "ComboDuplicates = " .. values.combo_duplicates ..
            "    ; on: a kart combo, \"Godzilla Cruiser (Sonic)\"..., may race next to the same character",
        "FillWithClones = " .. values.fill_clones ..
            "      ; on: a list with too few racers for the race is used again (clones) instead of the game's draw",
        "", "[Special karts]",
        "; on = this CPU racer gets the second kart (only a kart you can use; otherwise its own one)",
        "SuperSonic = " .. values.alt_supersonic .. "     ; Super Shooting Star instead of Super Shining",
        "Sonic = " .. values.alt_sonic .. "          ; Blue Star instead of Speedster Lightning",
        "Nine = " .. values.alt_nine .. "           ; Cyber Spear instead of Whirlwind Sport",
        "Dread = " .. values.alt_dread .. "          ; Goromaru instead of Land Smasher",
        "RustyRose = " .. values.alt_rusty .. "      ; Moto Beetle instead of Pink Cabriolet",
        "ProtoMan = " .. values.alt_protoman .. "       ; Blue Star in Rush Roadstar colours instead of Rush Roadstar",
    }, "\n") .. "\n"
end

function S.save()
    local text = ini_text()
    local f = io.open(INI, "w")
    if not f then U.log("cannot write " .. INI); return false end
    f:write(text)
    f:close()
    last_text = text
    return true
end

-- read the INI again if it changed since we last read or wrote it; true if something changed
function S.reload()
    local text = read_file(INI)
    if text == nil or text == last_text then return false end
    values = parse_ini(text)
    last_text = text
    U.log(string.format("settings: SRCWMenu.ini read: Grand Prix CPU racers = %s, Race Park = %s",
        values.roster_gp, values.roster_racepark))
    return true
end

function S.load()
    for k, v in pairs(S.DEFAULTS) do values[k] = v end
    U.try("default lists", lists.make_defaults)
    U.try("complete lists", lists.complete_all)
    if read_file(INI) then S.reload(); return end
    -- no SRCWMenu.ini yet: import settings.txt (early versions); its custom lists become lists of their own
    local old = read_file(OLD)
    if old then
        local o = {}
        for k, v in old:gmatch("([%w_]+)%s*=%s*(%S+)") do o[k] = v end
        for _, k in ipairs({"lang", "kart_gp", "kart_racepark", "kart_colors"}) do if o[k] then values[k] = o[k] end end
        for mode, name in pairs({gp = "My Grand Prix", racepark = "My Race Park"}) do
            if o["roster_" .. mode] == "custom" then
                local list = o["roster_" .. mode .. "_list"]
                local set = list == "default" and (lists.get("Game cast") or {}) or {}
                if list ~= "default" then for id in (list or ""):gmatch("%d+") do set[tonumber(id)] = true end end
                if lists.save(name, set) then values["roster_" .. mode] = name end
            end
        end
        U.log("settings: settings.txt imported into SRCWMenu.ini")
        local f = io.open(OLD, "w")
        if f then f:write("# no longer used: SRCWMenu.ini and the Lists folder replace this file (22/11/2026)\n"); f:close() end
    end
    S.save()
end

function S.get(k) return values[k] end
function S.set(k, v) values[k] = v; S.save() end
function S.bool(k) return values[k] == "on" end
function S.set_bool(k, b) S.set(k, b and "on" or "off") end
function S.toggle(k) S.set_bool(k, not S.bool(k)); return S.bool(k) end

S.load()
return S

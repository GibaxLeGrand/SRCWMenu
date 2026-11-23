--[[ SRCWMenu: the CPU racer lists: one file per list in the Lists folder of the mod,
"Lists\<name>.ini", and SRCWMenu.ini points each mode at a list by its name (or "game": the game's own draw).
A list file:   [Racers]  then one line per racer, "23 Sonic (AI Racer) = on" (the number is what counts).
Files are read again when they change (same text = cached), so a list edited by hand or by SRCWMenuEditor.exe counts
from the next race. The folder is listed with UE4SS's IterateGameDirectories (as BPModLoader does); Lua cannot make
a folder, so Lists is made when the mod is installed (if it is missing, nothing can be saved: written in the log). ]]
local U = require("util")
local M = {}

M.DRIVERS = dofile(U.DIR .. "/Scripts/drivers.lua")
local DIR = U.DIR .. "/Lists"
local GROUP_TITLES = {base = "Base cast", ai = "AI racers", aicolor = "AI colour skins",
                      guest = "Guests (paid DLC: only when owned; dated guests: once released)",
                      super = "Super forms (optional; only when the game lets you play them)"}
local cache = {}                           -- name -> {text = file text, set = {id = true}}

local function read_file(p)
    local f = io.open(p, "r")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end
local function path_of(name) return DIR .. "/" .. name .. ".ini" end

local function parse(text)
    local set, section = {}, nil
    for raw in (text .. "\n"):gmatch("(.-)\r?\n") do
        local line = raw:gsub("^%s+", ""):gsub("%s+$", "")
        local sec = line:match("^%[(.+)%]$")
        if sec then section = sec:lower()
        elseif section == "racers" and not line:match("^[;#]") then
            local id, val = line:match("^(%d+)[^=]*=%s*(%a+)")
            if id and (val:lower() == "on" or val:lower() == "yes" or val == "1") then set[tonumber(id)] = true end
        end
    end
    return set
end

local function text_of(name, set)
    local o = {"; SRCWMenu CPU racer list \"" .. name .. "\" (Sonic Racing CrossWorlds). SRCWMenu.ini, section [CPU racers],",
               "; points a mode at it by this name. on = the computer may use this racer. Edit it here, in the game's menu (F10)",
               "; or with SRCWMenuEditor.exe; it is read again before each race.", "", "[Racers]"}
    local group = nil
    for _, d in ipairs(M.DRIVERS) do
        if d.group ~= group then group = d.group; o[#o + 1] = "; " .. GROUP_TITLES[group] end
        o[#o + 1] = string.format("%d %s = %s", d.id, d.en, set[d.id] and "on" or "off")
    end
    return table.concat(o, "\n") .. "\n"
end

-- the set {id = true} of a list, or nil if there is no such file
function M.get(name)
    local text = read_file(path_of(name))
    if text == nil then cache[name] = nil; return nil end
    local c = cache[name]
    if c == nil or c.text ~= text then c = {text = text, set = parse(text)}; cache[name] = c end
    local copy = {}
    for id in pairs(c.set) do copy[id] = true end
    return copy
end

function M.save(name, set)
    local text = text_of(name, set)
    local f = io.open(path_of(name), "w")
    if not f then U.log("lists: cannot write " .. path_of(name) .. " (is the Lists folder there?)"); return false end
    f:write(text)
    f:close()
    cache[name] = {text = text, set = parse(text)}
    return true
end

-- the list names in the Lists folder, sorted (UE4SS IterateGameDirectories; nil if it cannot be listed)
function M.names()
    local ok, names = pcall(function()
        local d = IterateGameDirectories().Game
        local rel = U.DIR:gsub("\\", "/"):match("/Binaries/(.*)$")
        if not rel then error("mod folder not under Binaries: " .. U.DIR) end
        d = d.Binaries
        for part in rel:gmatch("[^/]+") do d = d[part]; if not d then error("no folder " .. part) end end
        d = d.Lists
        if not d then error("no Lists folder") end
        local t = {}
        for _, f in pairs(d.__files or {}) do
            local n = f.__name:match("^(.+)%.[iI][nN][iI]$")
            if n then t[#t + 1] = n end
        end
        table.sort(t, function(a, b) return a:lower() < b:lower() end)
        return t
    end)
    if ok then return names end
    U.log("lists: cannot list the Lists folder: " .. tostring(names))
    return nil
end

-- a list file written before a racer existed in drivers.lua gets the missing racers appended at its end, "off",
-- under their group title: the editor and the menu then show them. A racer whose name changed in drivers.lua gets
-- its line renamed, its on / off kept.
local BY_ID = {}
for _, d in ipairs(M.DRIVERS) do BY_ID[d.id] = d end
local function rename_lines(name, path, text)
    local out, renamed = {}, 0
    local body = text:sub(-1) == "\n" and text:sub(1, -2) or text
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        local pre, id, old, rest = line:match("^(%s*)(%d+)%s+(.-)(%s*=.*)$")
        local d = id and BY_ID[tonumber(id)]
        if d and old ~= d.en then line = pre .. id .. " " .. d.en .. rest; renamed = renamed + 1 end
        out[#out + 1] = line
    end
    if renamed == 0 then return text end
    local new = table.concat(out, "\n") .. "\n"
    local f = io.open(path, "w")
    if not f then return text end
    f:write(new)
    f:close()
    cache[name] = nil
    U.log("lists: " .. name .. ": " .. renamed .. " racer names updated")
    return new
end

function M.complete(name)
    local path = path_of(name)
    local text = read_file(path)
    if not text then return end
    text = rename_lines(name, path, text)
    local present = {}
    for id in ("\n" .. text):gmatch("\n%s*(%d+)[^\n=]*=") do present[tonumber(id)] = true end
    local add, group = {}, nil
    for _, d in ipairs(M.DRIVERS) do
        if not present[d.id] then
            if d.group ~= group then group = d.group; add[#add + 1] = "; " .. GROUP_TITLES[group] end
            add[#add + 1] = string.format("%d %s = off", d.id, d.en)
        end
    end
    if #add == 0 then return end
    local f = io.open(path, "a")
    if not f then return end
    f:write((text:sub(-1) == "\n" and "" or "\n") .. table.concat(add, "\n") .. "\n")
    f:close()
    cache[name] = nil
    U.log("lists: " .. name .. ": " .. #add .. " lines added (racers missing from the file)")
end
function M.complete_all()
    for _, n in ipairs(M.names() or {}) do U.try("complete " .. n, M.complete, n) end
end

-- the lists every install starts with (Scripts\default_lists.lua), made only when the Lists folder holds no list
function M.make_defaults()
    local names = M.names()
    if names and #names > 0 then return end
    local written = {}
    for _, l in ipairs(dofile(U.DIR .. "/Scripts/default_lists.lua")) do
        local s = {}
        for _, id in ipairs(l.ids) do s[id] = true end
        if M.save(l.name, s) then written[#written + 1] = l.name end
    end
    U.log("lists: default lists written (" .. table.concat(written, ", ") .. ")")
end

M.GROUP_TITLES = GROUP_TITLES
return M

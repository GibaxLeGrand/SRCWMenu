-- SRCWMenu: shared helpers (log, mod folder, game objects).
local U = {}

U.TAG = "[SRCWMenu] "
function U.log(s) print(U.TAG .. s .. "\n") end

-- pcall that writes the error to the log instead of breaking the caller
function U.try(label, f, ...)
    local ok, err = pcall(f, ...)
    if not ok then U.log((label or "?") .. ": error: " .. tostring(err)) end
    return ok, err
end

-- ...\ue4ss\Mods\SRCWMenu, from this file's path (...\Scripts\util.lua)
local function mod_dir()
    local ok, src = pcall(function() return debug.getinfo(1, "S").source end)
    local d = ok and src and src:match("^@(.*)[/\\]Scripts[/\\][^/\\]+%.lua$")
    return d or "ue4ss/Mods/SRCWMenu"
end
U.DIR = mod_dir()
-- the old UnlockKeys mod's folder: its relock files are still honoured (see unlock.lua)
U.LEGACY_UNLOCK = U.DIR:gsub("[/\\][^/\\]+$", "") .. "/UnlockKeys"

function U.exists(p)
    local f = io.open(p, "r")
    if f then f:close(); return true end
    return false
end

function U.valid(o) return o ~= nil and o.IsValid ~= nil and o:IsValid() end

-- a class default object (CDO), found once and kept while it stays valid
local cache = {}
function U.cdo(path)
    local o = cache[path]
    if not U.valid(o) then o = StaticFindObject(path); cache[path] = o end
    if U.valid(o) then return o end
    return nil
end

-- a game array (TArray) as a Lua list
function U.list(arr)
    local t = {}
    pcall(function() arr:ForEach(function(_, e) t[#t + 1] = e:get() end) end)
    return t
end

-- first VALID instance of a class (right after a level change FindFirstOf can return one from the old world)
function U.live(class)
    for _, o in ipairs(FindAllOf(class) or {}) do
        if U.valid(o) then return o end
    end
    return nil
end

return U

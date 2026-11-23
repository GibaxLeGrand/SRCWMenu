--[[ SRCWMenu: the in-game menu (F10). Pages: main, special karts, and one CPU racer list (the list file a mode
points at). Mouse: hover selects a row, left click runs it, right click goes back.

It borrows the game's own notice window (WBP_CMN_NoticeWindow: a window frame and one rich text, TXT_Info), the way
Split-Screen Rival Duel borrows game widgets, and writes the whole page in its text, one line per row. The window
is SelfHitTestInvisible, so its frame (Visible) catches the clicks made on it: they never reach the game's menu below.
Mouse -> row: the text's cached geometry (SlateBlueprintLibrary AbsoluteToLocal of the cursor's desktop position),
divided into equal lines. Keys (none is used by the game's menus, IM_UnionMenu_PC / IM_Menu_AZERTY):
numpad 8 / 2 or Page Up / Down = move, numpad 5 / 4 / 6 or Home = run, Backspace = back. ]]
local U = require("util")
local S = require("settings")
local L = require("lang")
local unlock = require("unlock")
local roster = require("roster")
local lists = require("lists")
local kart = require("kart")
local log = U.log
local M = {}

local CLASS = "/Game/01_Union/UI/Common/WBP_CMN_NoticeWindow.WBP_CMN_NoticeWindow_C"
local Z_ORDER = 1000
local VIS_SELF_HIT_TEST_INVISIBLE = 4      -- the window itself lets clicks through, its Visible frame catches them
local HEADER = 2                           -- lines before the first row: title, note
local PER_PAGE = 12                        -- racers per page of my list
local w = nil                              -- the widget (re-created after a level change)
local is_open = false
local sel = 1
local status = ""
local diagnosed = false
local view = {page = "main", mode = "gp", sub = 0}   -- sub: 0 = groups, 1.. = racer pages
local rows, nlines = {}, 0                 -- what is shown now (for the keys and the mouse)
M.ready = function() return false end      -- set by main.lua: the save is loaded

local function onoff(b) return b and L.t("yes") or L.t("no") end
local function dots(label, value)          -- "label ........ value"
    local n = math.max(2, 58 - #label)
    return label .. " " .. string.rep(".", n) .. " " .. value
end
-- f() returns a message key (lang.lua) and its numbers
local function need_save(f)
    return function()
        if not M.ready() then status = L.t("msg_save"); return end
        status = L.t(f())
    end
end

-- ===================================================================== page: main
local function roster_value(mode)
    if not roster.custom(mode) then return L.t("roster_game") end
    local set = lists.get(roster.list_name(mode))
    return L.t("roster_custom", roster.list_name(mode), set and roster.count(set) or -1)
end
local function choose_list(mode)            -- game -> each list of the Lists folder -> game
    local name = roster.cycle(mode)
    status = L.t("msg_list_chosen", roster.MODES[mode].name, name == "game" and L.t("roster_game") or name)
end
local function open_list(mode)
    if not roster.custom(mode) then status = L.t("msg_pick_list"); return end
    view = {page = "list", mode = mode, sub = 0}; sel = 1
end
-- ===================================================================== page: special karts
local KART_NAMES = {[6] = "Super Shining", [171] = "Super Shooting Star", [0] = "Speedster Lightning", [140] = "Blue Star",
                    [30] = "Whirlwind Sport", [37] = "Cyber Spear", [90] = "Land Smasher", [101] = "Goromaru",
                    [60] = "Pink Cabriolet", [68] = "Moto Beetle", [40] = "Rush Roadstar"}
local function special_on()
    local n = 0
    for _, a in ipairs(kart.ALTS) do if S.bool(a.key) then n = n + 1 end end
    return n
end
local function special_rows()
    local r = {{label = L.t("back"), run = function() view = {page = "main"}; sel = 1 end}}
    for _, a in ipairs(kart.ALTS) do
        local d = roster.BY_ID[a.driver]
        local value = KART_NAMES[a.default] or tostring(a.default)
        if S.bool(a.key) then
            value = a.colors and L.t("kart_in_colors", KART_NAMES[a.kart], KART_NAMES[a.colors]) or KART_NAMES[a.kart]
        end
        r[#r + 1] = {label = dots(d and L.name(d) or tostring(a.driver), value), run = function() S.toggle(a.key) end}
    end
    return r
end

local function main_rows()
    local r = {
        {label = dots(L.t("kart_gp"), onoff(S.bool("kart_gp"))), run = function() S.toggle("kart_gp") end},
        {label = dots(L.t("kart_racepark"), onoff(S.bool("kart_racepark"))), run = function() S.toggle("kart_racepark") end},
        {label = dots(L.t("kart_colors"), onoff(S.bool("kart_colors"))), run = function() S.toggle("kart_colors") end},
        {label = dots(L.t("special"), string.format("%d / %d", special_on(), #kart.ALTS)),
         run = function() view = {page = "special"}; sel = 1 end},
        {label = dots(L.t("roster_gp"), roster_value("gp")), run = function() choose_list("gp") end},
        {label = "    " .. L.t("edit_gp"), run = function() open_list("gp") end},
        {label = dots(L.t("roster_racepark"), roster_value("racepark")), run = function() choose_list("racepark") end},
        {label = "    " .. L.t("edit_racepark"), run = function() open_list("racepark") end},
        {label = dots(L.t("ai_unlock"), L.t("ai_locked", M.ready() and unlock.locked_count() or "?")),
         run = need_save(function() return unlock.unlock_colours() end)},
        {label = L.t("ai_relock"), run = need_save(function() return unlock.relock_colours("menu") end)},
        {label = L.t("language"), run = function() S.set("lang", L.lang() == "en" and "fr" or "en") end},
        {label = L.t("close"), run = function() M.close() end},
    }
    return r
end

-- ===================================================================== page: my CPU racers (one mode)
local function by_group(g)
    local t = {}
    for _, d in ipairs(roster.DRIVERS) do if d.group == g then t[#t + 1] = d end end
    return t
end
local ORDERED = {}
for _, g in ipairs(roster.GROUPS) do for _, d in ipairs(by_group(g)) do ORDERED[#ORDERED + 1] = d end end
local PAGES = math.ceil(#ORDERED / PER_PAGE)

-- change the list the page shows (its file in Lists: every mode pointing at it gets the change)
local function edit(f)
    local set = roster.get_list(view.mode)
    f(set)
    roster.set_list(view.mode, set)
end

local usable_cache = {}
local function list_rows()
    local mode, set = view.mode, roster.get_list(view.mode)
    local r = {{label = L.t("back"), run = function() view = {page = "main"}; sel = 1 end}}
    if view.sub == 0 then
        r[#r + 1] = {label = L.t("next") .. " - " .. L.t("page", 1, PAGES), run = function() view.sub = 1; sel = 2 end}
        r[#r + 1] = {label = L.t("groups"), run = function() end}
        for _, g in ipairs(roster.GROUPS) do
            local members, on = by_group(g), 0
            for _, d in ipairs(members) do if set[d.id] then on = on + 1 end end
            r[#r + 1] = {label = "    " .. L.t("grp_line", L.t("grp_" .. g), on, #members), run = function()
                edit(function(s)
                    local all = true
                    for _, d in ipairs(members) do if not s[d.id] then all = false end end
                    for _, d in ipairs(members) do s[d.id] = (not all) or nil end
                end)
            end}
        end
    else
        r[#r + 1] = {label = L.t("prev"), run = function() view.sub = view.sub - 1; sel = 2 end}
        r[#r + 1] = {label = view.sub < PAGES and (L.t("next") .. " - " .. L.t("page", view.sub + 1, PAGES)) or " ",
                     run = function() if view.sub < PAGES then view.sub = view.sub + 1; sel = 3 end end}
        for k = (view.sub - 1) * PER_PAGE + 1, math.min(view.sub * PER_PAGE, #ORDERED) do
            local d = ORDERED[k]
            local why = roster.why_not(d, usable_cache)
            r[#r + 1] = {label = (set[d.id] and "[x] " or "[  ] ") .. L.name(d) .. (why and ("   " .. L.t(why)) or ""),
                         run = function() edit(function(s) s[d.id] = (not s[d.id]) or nil end) end}
        end
    end
    return r
end
local function list_header()
    local set, n, u = roster.get_list(view.mode), 0, 0
    for id in pairs(set) do n = n + 1; if usable_cache[id] then u = u + 1 end end
    local sub = view.sub == 0 and "" or ("   " .. L.t("page", view.sub, PAGES))
    local name, users = roster.list_name(view.mode), {}
    for _, m in ipairs({"gp", "racepark"}) do if roster.list_name(m) == name then users[#users + 1] = roster.MODES[m].name end end
    return L.t("list_title", name, n, u) .. sub, L.t("list_note", table.concat(users, ", "), name)
end

-- ===================================================================== text
local function text()
    local head1, head2
    if view.page == "list" then
        pcall(function() usable_cache = roster.usable_map() end)
        rows = list_rows()
        head1, head2 = list_header()
    elseif view.page == "special" then
        rows = special_rows()
        head1, head2 = L.t("special_title"), L.t("special_note")
    else
        rows = main_rows()
        head1, head2 = L.t("title"), " "
    end
    if sel > #rows then sel = #rows end
    if sel < 1 then sel = 1 end
    local lines = {head1, head2}
    for i, r in ipairs(rows) do lines[#lines + 1] = (i == sel and ">  " or "    ") .. r.label end
    lines[#lines + 1] = " "
    lines[#lines + 1] = status ~= "" and status or " "
    lines[#lines + 1] = L.t("help")
    nlines = #lines
    return table.concat(lines, "\n")
end

-- a widget of the borrowed window that is not exposed as a variable: through its widget tree
local function child(widget, name)
    local ok, prop = pcall(function() return widget[name] end)
    if ok and U.valid(prop) then return prop end
    if U.valid(widget.WidgetTree) then
        return StaticFindObject(widget.WidgetTree:GetFullName():match("^%S+ (.+)$") .. "." .. name)
    end
    return nil
end

-- what decides whether the window can be seen (log only)
function M.state_line()
    local parts = {}
    pcall(function() parts[#parts + 1] = "widget opacity " .. tostring(w:GetRenderOpacity()) end)
    for _, n in ipairs({"CanvasPanel_23", "Overlay_43", "Window", "TXT_Info"}) do
        local c = child(w, n)
        if U.valid(c) then
            pcall(function() parts[#parts + 1] = n .. " opacity " .. tostring(c:GetRenderOpacity()) .. " vis " .. tostring(c:GetVisibility()) end)
        end
    end
    pcall(function()
        local v = U.cdo("/Script/UMG.Default__WidgetLayoutLibrary"):GetViewportSize(w)
        parts[#parts + 1] = string.format("viewport %.0f x %.0f", v.X, v.Y)
    end)
    return table.concat(parts, "; ")
end

-- first open of the session: what the borrowed window is made of (log only)
local function diagnose()
    if diagnosed or not U.valid(w) then return end
    diagnosed = true
    log("menu: widget " .. w:GetFullName())
    ExecuteWithDelay(500, function()
        ExecuteInGameThread(function()
            if U.valid(w) then log("menu: 500 ms later in viewport " .. tostring(w:IsInViewport()) .. "; " .. M.state_line()) end
        end)
    end)
end

-- The notice window starts transparent: its Display event plays Window_In (opacity), then Window_Out, then removes
-- itself (names in the asset). We never call Display: we set the opacities and play Window_In only.
local function force_visible()
    pcall(function() w:SetRenderOpacity(1.0) end)
    for _, n in ipairs({"CanvasPanel_23", "Overlay_43", "SizeBox_0", "Window", "TXT_Info"}) do
        local c = child(w, n)
        if U.valid(c) then pcall(function() c:SetRenderOpacity(1.0) end) end
    end
    local ok, anim = pcall(function() return w.Window_In end)
    if ok and U.valid(anim) then
        if not pcall(function() w:PlayAnimation(anim, 0, 1, 0, 1.0, false) end) then log("menu: Window_In could not be played") end
    else
        log("menu: no Window_In animation found")
    end
end

local function render()
    if not U.valid(w) then return end          -- gone (level change): watch() shows it again
    local t = child(w, "TXT_Info")
    if not U.valid(t) then error("TXT_Info not found in the notice window") end
    t:SetText(FText(text()))
end

local function create()
    local pc = U.live("PlayerController")
    if not pc then error("no PlayerController yet") end
    local cls = StaticFindObject(CLASS)
    if not U.valid(cls) then cls = LoadAsset(CLASS) end
    if not U.valid(cls) then error("cannot load " .. CLASS) end
    local lib = U.cdo("/Script/UMG.Default__WidgetBlueprintLibrary")
    w = lib:Create(pc, cls, pc)
    if not U.valid(w) then error("widget not created") end
    log("menu: window created")
end

local function show()
    if not U.valid(w) then create() end
    if not w:IsInViewport() then w:AddToViewport(Z_ORDER) end
    w:SetVisibility(VIS_SELF_HIT_TEST_INVISIBLE)
    force_visible()
    render()
end

-- ===================================================================== mouse
-- the row under the cursor, or nil. The text's geometry is read from the game (cached at its last paint).
local mouse_state = "untested"             -- "ok" / "failed" once known (logged once)
local function mouse_local()
    local t = child(w, "TXT_Info")
    local SBL = U.cdo("/Script/UMG.Default__SlateBlueprintLibrary")
    local WLL = U.cdo("/Script/UMG.Default__WidgetLayoutLibrary")
    local geo = t:GetCachedGeometry()
    local abs = WLL:GetMousePositionOnPlatform()
    local loc = SBL:AbsoluteToLocal(geo, {X = abs.X, Y = abs.Y})
    local size = SBL:GetLocalSize(geo)
    local desired = size.Y
    pcall(function() desired = t:GetDesiredSize().Y end)
    return loc.X, loc.Y, size.X, size.Y, desired, abs.X, abs.Y
end
local function hovered_row()
    if not U.valid(w) or nlines == 0 then return nil end
    local ok, x, y, sw, sh, dh, ax, ay = pcall(mouse_local)
    if not ok then
        if mouse_state ~= "failed" then mouse_state = "failed"; log("menu: mouse position not available: " .. tostring(x)) end
        return nil
    end
    if mouse_state ~= "ok" then
        mouse_state = "ok"
        log(string.format("menu: mouse works: cursor %.0f,%.0f -> text %.0f,%.0f; text box %.0f x %.0f, text height %.0f, %d lines",
            ax, ay, x, y, sw, sh, dh, nlines))
    end
    if not (dh and dh > 0) then dh = sh end
    local top = (sh > dh + 2) and (sh - dh) / 2 or 0   -- text shorter than its box: assume it is centred
    if x < 0 or x > sw or y < top or y > top + dh then return nil end
    local r = math.floor((y - top) / (dh / nlines)) + 1 - HEADER
    if r >= 1 and r <= #rows then return r end
    return nil
end

local mouse_loop = false
local function watch_mouse()
    if mouse_loop then return end
    mouse_loop = true
    LoopAsync(100, function()
        if not is_open then mouse_loop = false; return true end
        ExecuteInGameThread(function()
            if not is_open or mouse_state == "failed" then return end
            local r = hovered_row()
            if r and r ~= sel then sel = r; U.try("menu", render) end
        end)
        return false
    end)
end

-- ===================================================================== open / close / keys
local watching, failures = false, 0
local function watch()                     -- while the menu is open, put the window back if the game took it away
    if watching then return end
    watching = true
    LoopAsync(500, function()
        if not is_open then watching = false; return true end
        ExecuteInGameThread(function()
            if is_open and (not U.valid(w) or not w:IsInViewport()) then
                log("menu: the window was taken away, shown again")
                if U.try("menu show", show) then failures = 0 else failures = failures + 1 end
                if failures >= 5 then is_open = false; log("menu: closed, the window cannot be shown here") end
            end
        end)
        return false
    end)
end

function M.open()
    U.try("settings", S.reload)             -- SRCWMenu.ini may have been edited by hand
    is_open = true
    local ok, err = pcall(show)
    if not ok then is_open = false; error(err) end
    failures = 0
    U.try("menu diagnose", diagnose)
    watch()
    watch_mouse()
end

function M.close()
    is_open = false
    view = {page = "main", mode = "gp", sub = 0}
    if U.valid(w) and w:IsInViewport() then w:RemoveFromParent() end
end

function M.is_open() return is_open end
function M.toggle() if M.is_open() then M.close() else M.open() end end

function M.move(d)
    if #rows == 0 then return end
    sel = (sel - 1 + d) % #rows + 1
    render()
end
function M.run()
    local r = rows[sel]
    if not r then return end
    status = ""
    U.try("menu row " .. sel, r.run)
    if M.is_open() then render() end
end
function M.back()
    if view.page ~= "main" then view = {page = "main"}; sel = 1; status = ""; render() else M.close() end
end
function M.click()                         -- left button: run the row under the cursor (nothing outside the window)
    local r = hovered_row()
    if r then sel = r; M.run() end
end

-- a status line from outside (the F7 / F8 / F9 keys): a message key (lang.lua) and its numbers
function M.notify(key, ...)
    if key == nil then return end
    status = L.t(key, ...)
    if M.is_open() then U.try("menu", render) end
end

return M

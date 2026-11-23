-- SRCWMenu: the menu's texts in English and French (setting "lang"). Plain ASCII for now (accents through FText are
-- untested) and never "<" (the window's text is rich text: "<" starts a tag).
local S = require("settings")
local L = {}

local function failed(n, word) return (n and n > 0) and string.format(word, n) or "" end

local T = {
    en = {
        title = "SRCW MENU",
        yes = "ON", no = "OFF",
        kart_gp = "Grand Prix: CPU racers use their own kart",
        kart_racepark = "Race Park: CPU racers use their own kart",
        kart_colors = "Kart's own colours (never in team races)",
        special = "Special karts (switched on)",
        special_title = "SPECIAL KARTS OF THE CPU RACERS",
        special_note = "(select a line to switch it; a kart you cannot use is never given: the racer keeps its own)",
        kart_in_colors = function(k, c) return k .. " (" .. c .. " colours)" end,
        roster_gp = "Grand Prix: CPU racers",
        roster_racepark = "Race Park: CPU racers",
        roster_game = "game's choice",
        roster_custom = function(name, n) return string.format("list %s (%d)", name, n) end,
        edit_gp = "Edit the Grand Prix list",
        edit_racepark = "Edit the Race Park list",
        ai_unlock = "AI skins: unlock for this session (F7)",
        ai_locked = function(n) return string.format("%s locked", tostring(n)) end,
        ai_relock = "AI skins: lock them again (F8)",
        language = "Language: English",
        close = "Close (F10)",
        help = "Mouse, numpad 8 / 2 or Page Up / Down: choose   Click, 5 or Home: select   Right click: back   F10: close",
        list_title = function(name, n, u) return string.format("LIST %s: %d CPU racers allowed, %d usable now", name, n, u) end,
        list_note = function(users, name) return string.format("(used by: %s; saved in Lists, file %s.ini)", users ~= "" and users or "no mode", name) end,
        back = "Back",
        prev = "Previous page",
        next = "Next page",
        page = function(a, b) return string.format("Characters, page %d / %d", a, b) end,
        groups = "Groups (all on / all off)",
        grp_base = "Base cast", grp_ai = "AI racers", grp_aicolor = "AI colour skins", grp_guest = "Guests",
        grp_super = "Super forms (optional)", not_playable = "(you cannot play it yet)",
        grp_line = function(g, n, t) return string.format("%s: %d / %d allowed", g, n, t) end,
        not_owned = "(paid DLC not owned)", not_released = "(not released yet)",
        msg_save = "Save not loaded yet, try again in a moment",
        msg_unlocked = function(n, bad) return string.format("AI skins: %d unlocked for this session", n) .. failed(bad, ", %d failed") end,
        msg_none_locked = "AI skins: none is locked",
        msg_relocked = function(n, bad) return string.format("AI skins: %d locked again", n) .. failed(bad, ", %d failed") end,
        msg_nothing_relock = "AI skins: nothing to lock again",
        msg_f9 = function(on) return "Grand Prix: CPU racers use their own kart: " .. (on and "ON" or "OFF") end,
        msg_list_chosen = function(mode, name) return mode .. " CPU racers: " .. name end,
        msg_pick_list = "Choose a list on the line above first (select it to go through the lists)",
    },
    fr = {
        title = "SRCW MENU",
        yes = "OUI", no = "NON",
        kart_gp = "Grand Prix : kart d'origine des pilotes CPU",
        kart_racepark = "Race Park : kart d'origine des pilotes CPU",
        kart_colors = "Couleurs d'origine du kart (jamais en equipes)",
        special = "Karts speciaux (actives)",
        special_title = "KARTS SPECIAUX DES PILOTES CPU",
        special_note = "(valider une ligne pour changer ; un kart que tu n'as pas n'est jamais donne : le pilote garde le sien)",
        kart_in_colors = function(k, c) return k .. " (couleurs du " .. c .. ")" end,
        roster_gp = "Grand Prix : pilotes CPU",
        roster_racepark = "Race Park : pilotes CPU",
        roster_game = "choix du jeu",
        roster_custom = function(name, n) return string.format("liste %s (%d)", name, n) end,
        edit_gp = "Modifier la liste du Grand Prix",
        edit_racepark = "Modifier la liste du Race Park",
        ai_unlock = "Skins IA : debloquer pour la session (F7)",
        ai_locked = function(n) return string.format("%s verrouilles", tostring(n)) end,
        ai_relock = "Skins IA : reverrouiller (F8)",
        language = "Langue : Francais",
        close = "Fermer (F10)",
        help = "Souris, pave num. 8 / 2 ou Pg.Haut / Pg.Bas : choisir   Clic, 5 ou Origine : valider   Clic droit : retour   F10 : fermer",
        list_title = function(name, n, u) return string.format("LISTE %s : %d pilotes CPU autorises, %d utilisables", name, n, u) end,
        list_note = function(users, name) return string.format("(utilisee par : %s ; enregistree dans Lists, fichier %s.ini)", users ~= "" and users or "aucun mode", name) end,
        back = "Retour",
        prev = "Page precedente",
        next = "Page suivante",
        page = function(a, b) return string.format("Personnages, page %d / %d", a, b) end,
        groups = "Groupes (tout oui / tout non)",
        grp_base = "Persos de base", grp_ai = "Pilotes IA", grp_aicolor = "Skins IA de couleur", grp_guest = "Invites",
        grp_super = "Formes Super (option)", not_playable = "(pas encore jouable chez toi)",
        grp_line = function(g, n, t) return string.format("%s : %d / %d autorises", g, n, t) end,
        not_owned = "(DLC payant non possede)", not_released = "(pas encore sorti)",
        msg_save = "Sauvegarde pas encore chargee, reessaie dans un instant",
        msg_unlocked = function(n, bad) return string.format("Skins IA : %d debloques pour la session", n) .. failed(bad, ", %d en echec") end,
        msg_none_locked = "Skins IA : aucun n'est verrouille",
        msg_relocked = function(n, bad) return string.format("Skins IA : %d reverrouilles", n) .. failed(bad, ", %d en echec") end,
        msg_nothing_relock = "Skins IA : rien a reverrouiller",
        msg_f9 = function(on) return "Grand Prix : kart d'origine des pilotes CPU : " .. (on and "OUI" or "NON") end,
        msg_list_chosen = function(mode, name) return mode .. ", pilotes CPU : " .. name end,
        msg_pick_list = "Choisis d'abord une liste sur la ligne du dessus (la valider fait defiler les listes)",
    },
}

function L.lang() return T[S.get("lang")] and S.get("lang") or "en" end

-- L.t("key", args...): the text in the menu's language (English when a key is missing)
function L.t(key, ...)
    local v = T[L.lang()][key]
    if v == nil then v = T.en[key] end
    if type(v) == "function" then return v(...) end
    return v or key
end

-- a racer's name in the menu's language
function L.name(d) return d[L.lang()] or d.en end

return L

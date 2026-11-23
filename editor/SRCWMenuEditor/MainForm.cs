// The editor's window: tab "Settings" (SRCWMenu.ini) and tab "Lists" (Lists\<name>.ini, one CPU racer list each).
// Nothing is written until Save. A file changed meanwhile by the game's menu is never overwritten without asking.
using System.Diagnostics;
using System.Text.RegularExpressions;
using Microsoft.VisualBasic.FileIO;

namespace SRCWMenuEditor;

public sealed class MainForm : Form
{
    readonly string iniPath, modDir, listsDir;
    IniDoc main = null!;
    readonly SortedDictionary<string, IniDoc> lists = new(StringComparer.OrdinalIgnoreCase);
    readonly Dictionary<int, string> tags = new();       // racer id -> "dlc" / "dated" (Scripts\drivers.lua)
    bool loading;
    string? shownList;

    readonly TabControl tabs = new() { Dock = DockStyle.Fill };
    readonly TabPage tabSettings = new(), tabLists = new();
    readonly Label lblLang = new() { AutoSize = true }, lblGp = new() { AutoSize = true }, lblRp = new() { AutoSize = true },
                   lblHelp = new() { AutoSize = true, MaximumSize = new Size(820, 0) }, lblCount = new() { AutoSize = true };
    readonly GroupBox gbMenu = new() { Dock = DockStyle.Top, Height = 70 }, gbKarts = new() { Dock = DockStyle.Top, Height = 120 },
                      gbCpu = new() { Dock = DockStyle.Top, Height = 170 };
    readonly CheckBox chkDup = new() { AutoSize = true };   // [CPU racers] ComboDuplicates
    readonly CheckBox chkClones = new() { AutoSize = true };   // [CPU racers] FillWithClones
    // AI colour skins, run by the game itself (request.txt, see AskGame)
    readonly GroupBox gbSkins = new() { Dock = DockStyle.Top, Height = 100 };
    readonly Button btnSkinsUnlock = new() { AutoSize = true }, btnSkinsRelock = new() { AutoSize = true };
    readonly Label lblSkins = new() { AutoSize = true, MaximumSize = new Size(820, 0) };
    readonly ComboBox cbLang = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 160 },
                      cbGp = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 320 },
                      cbRp = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 320 };
    readonly CheckBox chkGp = new() { AutoSize = true }, chkRp = new() { AutoSize = true }, chkColors = new() { AutoSize = true };
    // special karts ([Special karts] in SRCWMenu.ini; the mod's table is Scripts\kart.lua M.ALTS)
    static readonly (string key, string en, string fr, string comment)[] Specials =
    {
        ("SuperSonic", "Super Sonic: Super Shooting Star instead of Super Shining", "Super Sonic : Super Shooting Star au lieu du Super Shining",
         "Super Shooting Star instead of Super Shining"),
        ("Sonic", "Sonic: Blue Star instead of Speedster Lightning", "Sonic : Blue Star au lieu du Speedster Lightning",
         "Blue Star instead of Speedster Lightning"),
        ("Nine", "Nine: Cyber Spear instead of Whirlwind Sport (Tails' car)", "Nine : Cyber Spear au lieu du Whirlwind Sport (le kart de Tails)",
         "Cyber Spear instead of Whirlwind Sport"),
        ("Dread", "Dread: Goromaru instead of Land Smasher (Knuckles' car)", "Dread : Goromaru au lieu du Land Smasher (le kart de Knuckles)",
         "Goromaru instead of Land Smasher"),
        ("RustyRose", "Rusty Rose: Moto Beetle instead of Pink Cabriolet (Amy's car)", "Rusty Rose : Moto Beetle au lieu du Pink Cabriolet (le kart d'Amy)",
         "Moto Beetle instead of Pink Cabriolet"),
        ("ProtoMan", "Proto Man: Blue Star in the Rush Roadstar's colours instead of the Rush Roadstar",
         "Proto Man : Blue Star aux couleurs du Rush Roadstar au lieu du Rush Roadstar",
         "Blue Star in Rush Roadstar colours instead of Rush Roadstar"),
    };
    readonly CheckBox[] chkSpecial = Specials.Select(_ => new CheckBox { AutoSize = true }).ToArray();
    readonly GroupBox gbSpecial = new() { Dock = DockStyle.Top, Height = 200 };
    readonly ListBox lbLists = new() { Dock = DockStyle.Fill, IntegralHeight = false };
    readonly ListView lvRacers = new()
    {
        Dock = DockStyle.Fill, View = View.Details, CheckBoxes = true, FullRowSelect = true, HeaderStyle = ColumnHeaderStyle.Nonclickable,
    };
    readonly FlowLayoutPanel groupButtons = new() { Dock = DockStyle.Top, AutoSize = true, WrapContents = true };
    readonly Button btnSave = new() { AutoSize = true }, btnReload = new() { AutoSize = true }, btnFolder = new() { AutoSize = true },
                    btnNew = new() { AutoSize = true }, btnDup = new() { AutoSize = true }, btnRename = new() { AutoSize = true },
                    btnDelete = new() { AutoSize = true };
    readonly ToolStripStatusLabel status = new() { Spring = true, TextAlign = ContentAlignment.MiddleLeft };

    // ------------------------------------------------------------------------------------------------ texts
    static readonly Dictionary<string, (string en, string fr)> Texts = new()
    {
        ["title"] = ("SRCWMenu settings", "Réglages SRCWMenu"),
        ["save"] = ("Save", "Enregistrer"), ["reload"] = ("Reload", "Recharger"), ["folder"] = ("Open the mod folder", "Ouvrir le dossier du mod"),
        ["tab_settings"] = ("Settings", "Réglages"), ["tab_lists"] = ("CPU racer lists", "Listes de pilotes CPU"),
        ["menu"] = ("Menu", "Menu"), ["language"] = ("Language of the in-game menu (F10) and of this window", "Langue du menu en jeu (F10) et de cette fenêtre"),
        ["karts"] = ("Karts of the CPU racers", "Karts des pilotes CPU"),
        ["kart_gp"] = ("Grand Prix: CPU racers use their own kart", "Grand Prix : kart d'origine des pilotes CPU"),
        ["kart_rp"] = ("Race Park: CPU racers use their own kart", "Race Park : kart d'origine des pilotes CPU"),
        ["kart_colors"] = ("...with the kart's own colours (never in team races)", "...avec les couleurs d'origine du kart (jamais en équipes)"),
        ["special_box"] = ("Special karts of the CPU racers (only a kart you can use; otherwise the racer keeps its own)",
                       "Karts spéciaux des pilotes CPU (seulement un kart que tu possèdes ; sinon le pilote garde le sien)"),
        ["cpu"] = ("Which racers the computer uses", "Pilotes utilisés par l'ordinateur"),
        ["clones"] = ("When a list has too few usable racers for the race: clones of its racers fill the slots left",
                      "Si une liste a trop peu de pilotes utilisables pour la course : des clones de ses pilotes remplissent le reste"),
        ["dup_combo"] = ("Kart combos (Godzilla Cruiser (Sonic)...) may race next to the same character",
                         "Les combos perso + kart (Godzilla Cruiser (Sonic)...) peuvent courir à côté du même perso"),
        ["gp"] = ("Grand Prix:", "Grand Prix :"), ["rp"] = ("Race Park:", "Race Park :"),
        ["game"] = ("game (the game's own draw)", "game (le tirage du jeu)"),
        ["missing"] = ("(missing list)", "(liste introuvable)"),
        ["help"] = ("The game reads these files again before each race and when its menu (F10) opens: what you save here counts "
                   + "from the next race, game open or closed. A list only gives the racers the computer MAY use: a paid DLC "
                   + "only when you own it, a dated guest once it is out.",
                   "Le jeu relit ces fichiers avant chaque course et à l'ouverture de son menu (F10) : ce que tu enregistres ici "
                   + "compte dès la course suivante, jeu ouvert ou fermé. Une liste donne seulement les pilotes que l'ordinateur "
                   + "PEUT prendre : un DLC payant seulement s'il est possédé, un invité daté une fois sorti."),
        ["new"] = ("New list", "Nouvelle liste"), ["dup"] = ("Duplicate", "Dupliquer"), ["rename"] = ("Rename", "Renommer"),
        ["delete"] = ("Delete", "Supprimer"),
        ["all_on"] = ("all on", "tout oui"), ["all_off"] = ("all off", "tout non"),
        ["count"] = ("{0} racers allowed in \"{1}\" - used by: {2}", "{0} pilotes autorisés dans \"{1}\" - utilisée par : {2}"),
        ["nobody"] = ("no mode", "aucun mode"),
        ["col_racer"] = ("Racer", "Pilote"), ["col_note"] = ("Note", "Note"),
        ["special"] = ("only if you can play it", "seulement s'il est jouable chez toi"),
        ["dlc"] = ("paid DLC: only if owned", "DLC payant : seulement si possédé"), ["dated"] = ("dated guest: once released", "invité daté : une fois sorti"),
        ["ask_name"] = ("Name of the list (it becomes Lists\\<name>.ini):", "Nom de la liste (devient Lists\\<nom>.ini) :"),
        ["bad_name"] = ("This name cannot be a file name, or the list already exists.", "Ce nom ne peut pas être un nom de fichier, ou la liste existe déjà."),
        ["ask_delete"] = ("Delete the list \"{0}\"? Its file goes to the Recycle Bin; a mode using it goes back to the game's draw.",
                          "Supprimer la liste \"{0}\" ? Son fichier part à la corbeille ; un mode qui l'utilise revient au tirage du jeu."),
        ["changed"] = ("{0} was changed outside this window (by the game's menu?) since it was opened.\n\nYes = write mine over it\nNo = keep the other one (my changes to this file are lost)",
                       "{0} a été modifié hors de cette fenêtre (par le menu du jeu ?) depuis son ouverture.\n\nOui = écrire le mien par-dessus\nNon = garder l'autre (mes changements de ce fichier sont perdus)"),
        ["unsaved"] = ("Save the changes before closing?", "Enregistrer les changements avant de fermer ?"),
        ["discard"] = ("Reload and lose the changes not saved?", "Recharger et perdre les changements non enregistres ?"),
        ["saved"] = ("Saved. The game uses it from the next race.", "Enregistré. Le jeu l'utilise dès la course suivante."),
        ["loaded"] = ("Read: SRCWMenu.ini and {0} lists.", "Lu : SRCWMenu.ini et {0} listes."),
        ["skins"] = ("AI colour skins (the game must be running, past the title screen)",
                     "Skins de couleur des IA (le jeu doit tourner, après l'écran titre)"),
        ["skins_unlock"] = ("Unlock the locked ones for this session (F7)", "Débloquer ceux qui sont verrouillés, pour la session (F7)"),
        ["skins_relock"] = ("Lock them again (F8)", "Les reverrouiller (F8)"),
        ["skins_note"] = ("For this session only: the next launch of the game locks them again by itself.",
                          "Pour la session seulement : le prochain lancement du jeu les reverrouille tout seul."),
        ["skins_sent"] = ("Sent to the game, waiting for its answer...", "Envoyé au jeu, en attente de sa réponse..."),
        ["skins_answer"] = ("Game: {0}", "Jeu : {0}"),
        ["skins_none"] = ("No answer from the game: start it with SRCWMenu, go past the title screen, then try again.",
                          "Pas de réponse du jeu : lance-le avec SRCWMenu, passe l'écran titre, puis réessaie."),
        ["no_lists"] = ("The Lists folder has no list yet: start the game once with SRCWMenu, it writes the default ones.",
                        "Le dossier Lists n'a encore aucune liste : lance le jeu une fois avec SRCWMenu, il écrit celles de départ."),
    };
    bool French => main.Get("Menu", "Language", "en").Trim().Equals("fr", StringComparison.OrdinalIgnoreCase);
    string T(string key) => Texts.TryGetValue(key, out var t) ? (French ? t.fr : t.en) : key;

    // ------------------------------------------------------------------------------------------------ layout
    public MainForm(string path)
    {
        iniPath = Path.GetFullPath(path);
        modDir = Path.GetDirectoryName(iniPath)!;
        listsDir = Path.Combine(modDir, "Lists");
        Size = new Size(940, 950);
        MinimumSize = new Size(760, 560);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 9.5f);

        var top = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, Padding = new Padding(6) };
        top.Controls.AddRange(new Control[] { btnSave, btnReload, btnFolder });
        var bar = new StatusStrip();
        bar.Items.Add(status);

        // Settings tab
        var pMenu = new FlowLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(6) };
        cbLang.Items.AddRange(new object[] { "English", "Français" });
        pMenu.Controls.AddRange(new Control[] { cbLang, lblLang });
        gbMenu.Controls.Add(pMenu);
        var pKarts = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, Padding = new Padding(6) };
        pKarts.Controls.AddRange(new Control[] { chkGp, chkRp, chkColors });
        gbKarts.Controls.Add(pKarts);
        var pCpu = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, Padding = new Padding(6) };
        pCpu.Controls.Add(lblGp, 0, 0); pCpu.Controls.Add(cbGp, 1, 0);
        pCpu.Controls.Add(lblRp, 0, 1); pCpu.Controls.Add(cbRp, 1, 1);
        pCpu.Controls.Add(chkDup, 0, 2); pCpu.SetColumnSpan(chkDup, 2);
        pCpu.Controls.Add(chkClones, 0, 3); pCpu.SetColumnSpan(chkClones, 2);
        gbCpu.Controls.Add(pCpu);
        var pSpecial = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, Padding = new Padding(6) };
        pSpecial.Controls.AddRange(chkSpecial);
        gbSpecial.Controls.Add(pSpecial);
        var pSkins = new FlowLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(6) };
        pSkins.Controls.AddRange(new Control[] { btnSkinsUnlock, btnSkinsRelock, lblSkins });
        pSkins.SetFlowBreak(btnSkinsRelock, true);
        gbSkins.Controls.Add(pSkins);
        var pHelp = new Panel { Dock = DockStyle.Top, Height = 90, Padding = new Padding(8) };
        pHelp.Controls.Add(lblHelp);
        tabSettings.Padding = new Padding(8);
        tabSettings.AutoScroll = true;
        tabSettings.Controls.AddRange(new Control[] { pHelp, gbSkins, gbCpu, gbSpecial, gbKarts, gbMenu });   // docked top: last added = first shown

        // Lists tab
        var split = new SplitContainer { Dock = DockStyle.Fill, FixedPanel = FixedPanel.Panel1 };
        Load += (_, _) => split.SplitterDistance = 220;
        var listButtons = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
        };
        foreach (var b in new[] { btnNew, btnDup, btnRename, btnDelete }) { b.AutoSize = false; b.Width = 200; b.Height = 30; }
        listButtons.Controls.AddRange(new Control[] { btnNew, btnDup, btnRename, btnDelete });
        split.Panel1.Controls.Add(lbLists);
        split.Panel1.Controls.Add(listButtons);
        lvRacers.Columns.Add("", 380);
        lvRacers.Columns.Add("", 260);
        var countPanel = new Panel { Dock = DockStyle.Top, Height = 26, Padding = new Padding(4) };
        countPanel.Controls.Add(lblCount);
        split.Panel2.Controls.Add(lvRacers);
        split.Panel2.Controls.Add(groupButtons);
        split.Panel2.Controls.Add(countPanel);
        tabLists.Controls.Add(split);

        tabs.TabPages.Add(tabSettings);
        tabs.TabPages.Add(tabLists);
        Controls.Add(tabs);
        Controls.Add(top);
        Controls.Add(bar);

        // events
        btnSave.Click += (_, _) => SaveAll();
        btnReload.Click += (_, _) => { if (!Dirty || Ask(T("discard"), MessageBoxButtons.YesNo) == DialogResult.Yes) LoadAll(); };
        btnFolder.Click += (_, _) => Process.Start("explorer.exe", modDir);
        cbLang.SelectedIndexChanged += (_, _) => { if (loading) return; main.Set("Menu", "Language", cbLang.SelectedIndex == 1 ? "fr" : "en"); ApplyTexts(); };
        chkGp.CheckedChanged += (_, _) => SetOnOff("Karts", "GrandPrix", chkGp.Checked);
        chkRp.CheckedChanged += (_, _) => SetOnOff("Karts", "RacePark", chkRp.Checked);
        chkColors.CheckedChanged += (_, _) => SetOnOff("Karts", "OwnColours", chkColors.Checked);
        for (int i = 0; i < Specials.Length; i++)
        {
            var s = Specials[i];
            var box = chkSpecial[i];
            box.CheckedChanged += (_, _) =>
            {
                if (loading) return;
                main.SetOrAdd("Special karts", s.key, box.Checked ? "on" : "off", s.comment);
                MarkDirty();
            };
        }
        cbGp.SelectedIndexChanged += (_, _) => SetMode("GrandPrix", cbGp);
        cbRp.SelectedIndexChanged += (_, _) => SetMode("RacePark", cbRp);
        chkClones.CheckedChanged += (_, _) =>
        {
            if (loading) return;
            main.SetOrAdd("CPU racers", "FillWithClones", chkClones.Checked ? "on" : "off",
                          "on: a list with too few racers for the race is used again (clones) instead of the game's draw");
            MarkDirty();
        };
        chkDup.CheckedChanged += (_, _) =>
        {
            if (loading) return;
            main.SetOrAdd("CPU racers", "ComboDuplicates", chkDup.Checked ? "on" : "off",
                          "on: a kart combo, \"Godzilla Cruiser (Sonic)\"..., may race next to the same character");
            MarkDirty();
        };
        lbLists.SelectedIndexChanged += (_, _) => ShowList(lbLists.SelectedItem as string);
        lvRacers.ItemChecked += (_, e) => RacerChecked(e.Item);
        btnNew.Click += (_, _) => NewList(false);
        btnDup.Click += (_, _) => NewList(true);
        btnRename.Click += (_, _) => RenameList();
        btnDelete.Click += (_, _) => DeleteList();
        btnSkinsUnlock.Click += async (_, _) => await AskGame("unlock_colours");
        btnSkinsRelock.Click += async (_, _) => await AskGame("relock_colours");
        FormClosing += OnClosing;

        ReadTags();
        LoadAll();
    }

    // ------------------------------------------------------------------------------------------------ files
    bool Dirty => main.Dirty || lists.Values.Any(d => d.Dirty);

    void LoadAll()
    {
        loading = true;
        main = IniDoc.Load(iniPath);
        lists.Clear();
        if (Directory.Exists(listsDir))
            foreach (var f in Directory.GetFiles(listsDir, "*.ini"))
                lists[Path.GetFileNameWithoutExtension(f)] = IniDoc.Load(f);
        cbLang.SelectedIndex = French ? 1 : 0;
        chkGp.Checked = IsOn("Karts", "GrandPrix");
        chkRp.Checked = IsOn("Karts", "RacePark");
        chkColors.Checked = IsOn("Karts", "OwnColours");
        chkClones.Checked = IsOn("CPU racers", "FillWithClones");
        chkDup.Checked = !main.Get("CPU racers", "ComboDuplicates", "on").Trim().Equals("off", StringComparison.OrdinalIgnoreCase);
        for (int i = 0; i < Specials.Length; i++) chkSpecial[i].Checked = IsOn("Special karts", Specials[i].key);
        loading = false;
        RefreshLists(shownList);
        ApplyTexts();
        status.Text = lists.Count == 0 ? T("no_lists") : string.Format(T("loaded"), lists.Count);
    }

    void SaveAll()
    {
        foreach (var doc in new[] { main }.Concat(lists.Values).Where(d => d.Dirty).ToList())
        {
            if (doc.ChangedOnDisk() && Ask(string.Format(T("changed"), Path.GetFileName(doc.Path)), MessageBoxButtons.YesNo) != DialogResult.Yes)
                continue;
            Directory.CreateDirectory(Path.GetDirectoryName(doc.Path)!);
            doc.Save();
        }
        status.Text = T("saved");
        LoadAll();
    }

    void ReadTags()   // which racers are paid DLC / dated guests, from the mod's own data
    {
        var drivers = Path.Combine(modDir, "Scripts", "drivers.lua");
        if (!File.Exists(drivers)) return;
        foreach (Match m in Regex.Matches(File.ReadAllText(drivers), @"\{id = (\d+),[^}]*?(package|content|special) = \w+"))
            tags[int.Parse(m.Groups[1].Value)] = m.Groups[2].Value switch { "package" => "dlc", "content" => "dated", _ => "special" };
    }

    bool IsOn(string section, string key) => main.Get(section, key, "off").Trim().Equals("on", StringComparison.OrdinalIgnoreCase);
    void SetOnOff(string section, string key, bool on) { if (!loading) { main.Set(section, key, on ? "on" : "off"); MarkDirty(); } }

    void SetMode(string key, ComboBox cb)
    {
        if (loading || cb.SelectedIndex < 0 || cb.Tag is not List<string> values) return;
        main.Set("CPU racers", key, values[cb.SelectedIndex]);
        MarkDirty();
        UpdateCount();
    }

    void MarkDirty() => Text = T("title") + (Dirty ? " *" : "") + " - " + ShownPath;

    // the title shows the path from ue4ss\Mods on (the folders above it say nothing, and may hold a user name)
    string ShownPath
    {
        get
        {
            var i = iniPath.IndexOf(@"\ue4ss\Mods\", StringComparison.OrdinalIgnoreCase);
            return i < 0 ? iniPath : "..." + iniPath[i..];
        }
    }

    // ------------------------------------------------------------------------------------------------ AI skins
    // The game itself runs it (main.lua): request.txt = "<action> <unix time>", the answer comes in
    // request_done.txt ("<same time>", then the message). A request the game has not taken within 6 s is taken back,
    // so it never runs at a later launch (the mod also drops any request older than 30 s).
    async Task AskGame(string action)
    {
        var req = Path.Combine(modDir, "request.txt");
        var done = Path.Combine(modDir, "request_done.txt");
        btnSkinsUnlock.Enabled = btnSkinsRelock.Enabled = false;
        try
        {
            if (File.Exists(done)) File.Delete(done);
            var stamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
            File.WriteAllText(req, action + " " + stamp + "\n");
            status.Text = T("skins_sent");
            for (int i = 0; i < 24; i++)
            {
                await Task.Delay(250);
                if (!File.Exists(done)) continue;
                string[] lines;
                try { lines = File.ReadAllLines(done); } catch (IOException) { continue; }
                if (lines.Length < 2 || lines[0].Trim() != stamp) continue;
                try { File.Delete(done); } catch (IOException) { }
                status.Text = string.Format(T("skins_answer"), lines[1].Trim());
                return;
            }
            if (File.Exists(req)) File.Delete(req);
            status.Text = T("skins_none");
        }
        catch (Exception ex) { status.Text = ex.Message; }
        finally { btnSkinsUnlock.Enabled = btnSkinsRelock.Enabled = true; }
    }

    DialogResult Ask(string text, MessageBoxButtons buttons) =>
        MessageBox.Show(this, text, T("title"), buttons, MessageBoxIcon.Question);

    void OnClosing(object? sender, FormClosingEventArgs e)
    {
        if (!Dirty) return;
        var r = Ask(T("unsaved"), MessageBoxButtons.YesNoCancel);
        if (r == DialogResult.Cancel) e.Cancel = true;
        else if (r == DialogResult.Yes) SaveAll();
    }

    // ------------------------------------------------------------------------------------------------ texts on screen
    void ApplyTexts()
    {
        Text = T("title") + (Dirty ? " *" : "") + " - " + ShownPath;
        btnSave.Text = T("save"); btnReload.Text = T("reload"); btnFolder.Text = T("folder");
        tabSettings.Text = T("tab_settings"); tabLists.Text = T("tab_lists");
        gbMenu.Text = T("menu"); lblLang.Text = T("language");
        gbKarts.Text = T("karts"); chkGp.Text = T("kart_gp"); chkRp.Text = T("kart_rp"); chkColors.Text = T("kart_colors");
        gbSpecial.Text = T("special_box");
        for (int i = 0; i < Specials.Length; i++) chkSpecial[i].Text = French ? Specials[i].fr : Specials[i].en;
        gbCpu.Text = T("cpu"); lblGp.Text = T("gp"); lblRp.Text = T("rp"); lblHelp.Text = T("help"); chkDup.Text = T("dup_combo"); chkClones.Text = T("clones");
        gbSkins.Text = T("skins"); btnSkinsUnlock.Text = T("skins_unlock"); btnSkinsRelock.Text = T("skins_relock"); lblSkins.Text = T("skins_note");
        btnNew.Text = T("new"); btnDup.Text = T("dup"); btnRename.Text = T("rename"); btnDelete.Text = T("delete");
        lvRacers.Columns[0].Text = T("col_racer"); lvRacers.Columns[1].Text = T("col_note");
        FillModeCombo(cbGp, "GrandPrix");
        FillModeCombo(cbRp, "RacePark");
        ShowList(shownList);
    }

    void FillModeCombo(ComboBox cb, string key)
    {
        var was = loading;
        loading = true;
        var current = main.Get("CPU racers", key, "game").Trim();
        var values = new List<string> { "game" };
        values.AddRange(lists.Keys);
        cb.Items.Clear();
        cb.Items.Add(T("game"));
        foreach (var n in lists.Keys) cb.Items.Add(n);
        var i = values.FindIndex(n => n.Equals(current, StringComparison.OrdinalIgnoreCase));
        if (i < 0) { values.Add(current); cb.Items.Add(current + "  " + T("missing")); i = values.Count - 1; }
        cb.Tag = values;
        cb.SelectedIndex = i;
        loading = was;
    }

    // ------------------------------------------------------------------------------------------------ lists tab
    void RefreshLists(string? select)
    {
        lbLists.Items.Clear();
        foreach (var n in lists.Keys) lbLists.Items.Add(n);
        if (select != null && lists.ContainsKey(select)) lbLists.SelectedItem = lists.Keys.First(k => k.Equals(select, StringComparison.OrdinalIgnoreCase));
        else if (lbLists.Items.Count > 0) lbLists.SelectedIndex = 0;
        else ShowList(null);
    }

    void ShowList(string? name)
    {
        shownList = name;
        loading = true;
        lvRacers.BeginUpdate();
        lvRacers.Items.Clear();
        lvRacers.Groups.Clear();
        groupButtons.Controls.Clear();
        if (name != null && lists.TryGetValue(name, out var doc))
        {
            var groups = new Dictionary<string, ListViewGroup>();
            foreach (var e in doc.Racers())
            {
                if (!groups.TryGetValue(e.Group, out var g))
                {
                    g = new ListViewGroup(e.Group, e.Group);
                    groups[e.Group] = g;
                    lvRacers.Groups.Add(g);
                    AddGroupButtons(doc, e.Group);
                }
                var note = tags.TryGetValue(e.RacerId!.Value, out var t) ? T(t) : "";
                var item = new ListViewItem(new[] { e.RacerName, note }, g) { Checked = e.Value.Equals("on", StringComparison.OrdinalIgnoreCase), Tag = e };
                lvRacers.Items.Add(item);
            }
        }
        lvRacers.EndUpdate();
        loading = false;
        UpdateCount();
    }

    void AddGroupButtons(IniDoc doc, string group)
    {
        var label = group.Split('(')[0].Trim();
        var on = new Button { AutoSize = true, Text = label + ": " + T("all_on") };
        var off = new Button { AutoSize = true, Text = label + ": " + T("all_off") };
        on.Click += (_, _) => SetGroup(group, true);
        off.Click += (_, _) => SetGroup(group, false);
        groupButtons.Controls.Add(on);
        groupButtons.Controls.Add(off);
    }

    void SetGroup(string group, bool value)
    {
        foreach (ListViewItem item in lvRacers.Items)
            if (((IniEntry)item.Tag!).Group == group) item.Checked = value;   // ItemChecked writes each one
    }

    void RacerChecked(ListViewItem item)
    {
        if (loading || shownList == null || !lists.TryGetValue(shownList, out var doc)) return;
        var e = (IniEntry)item.Tag!;
        var value = item.Checked ? "on" : "off";
        if (e.Value.Equals(value, StringComparison.OrdinalIgnoreCase)) return;   // the ListView re-sends states when shown
        doc.Set(e, value);
        MarkDirty();
        UpdateCount();
    }

    void UpdateCount()
    {
        if (shownList == null || !lists.TryGetValue(shownList, out var doc)) { lblCount.Text = ""; return; }
        var n = doc.Racers().Count(e => e.Value.Equals("on", StringComparison.OrdinalIgnoreCase));
        var users = new List<string>();
        if (main.Get("CPU racers", "GrandPrix", "").Trim().Equals(shownList, StringComparison.OrdinalIgnoreCase)) users.Add("Grand Prix");
        if (main.Get("CPU racers", "RacePark", "").Trim().Equals(shownList, StringComparison.OrdinalIgnoreCase)) users.Add("Race Park");
        lblCount.Text = string.Format(T("count"), n, shownList, users.Count > 0 ? string.Join(", ", users) : T("nobody"));
    }

    static readonly Regex HeaderName = new("^(; SRCWMenu CPU racer list \")([^\"]*)(\".*)$");
    static void SetHeaderName(IniDoc doc, string name)
    {
        for (int i = 0; i < doc.Lines.Count; i++)
        {
            var m = HeaderName.Match(doc.Lines[i]);
            if (m.Success) { doc.ReplaceLine(i, m.Groups[1].Value + name + m.Groups[3].Value); return; }
        }
    }

    string? AskName(string start)
    {
        using var f = new Form
        {
            Text = T("title"), FormBorderStyle = FormBorderStyle.FixedDialog, StartPosition = FormStartPosition.CenterParent,
            MinimizeBox = false, MaximizeBox = false, ClientSize = new Size(440, 110), Font = Font,
        };
        var lbl = new Label { Text = T("ask_name"), AutoSize = true, Location = new Point(10, 10) };
        var box = new TextBox { Text = start, Location = new Point(10, 36), Width = 420 };
        var ok = new Button { Text = "OK", DialogResult = DialogResult.OK, Location = new Point(270, 72) };
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, Location = new Point(355, 72) };
        f.Controls.AddRange(new Control[] { lbl, box, ok, cancel });
        f.AcceptButton = ok; f.CancelButton = cancel;
        if (f.ShowDialog(this) != DialogResult.OK) return null;
        var name = box.Text.Trim();
        if (name.Length == 0 || name.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 || name.Equals("game", StringComparison.OrdinalIgnoreCase)
            || lists.ContainsKey(name))
        {
            Ask(T("bad_name"), MessageBoxButtons.OK);
            return null;
        }
        return name;
    }

    void NewList(bool duplicate)
    {
        IniDoc? template = duplicate && shownList != null ? lists[shownList]
            : lists.TryGetValue("Game cast", out var g) ? g : lists.Values.FirstOrDefault();
        if (template == null) { Ask(T("no_lists"), MessageBoxButtons.OK); return; }
        var name = AskName(duplicate && shownList != null ? shownList + " 2" : "");
        if (name == null) return;
        var doc = IniDoc.New(Path.Combine(listsDir, name + ".ini"), template.Text);
        SetHeaderName(doc, name);
        if (!duplicate) foreach (var e in doc.Racers().ToList()) doc.Set(e, "off");
        lists[name] = doc;
        RefreshLists(name);
        ApplyTexts();
        MarkDirty();
    }

    void RenameList()
    {
        if (shownList == null) return;
        var old = shownList;
        var name = AskName(old);
        if (name == null) return;
        var doc = lists[old];
        var newPath = Path.Combine(listsDir, name + ".ini");
        if (File.Exists(doc.Path)) File.Move(doc.Path, newPath);
        doc.MoveTo(newPath);
        SetHeaderName(doc, name);
        lists.Remove(old);
        lists[name] = doc;
        foreach (var key in new[] { "GrandPrix", "RacePark" })
            if (main.Get("CPU racers", key, "").Trim().Equals(old, StringComparison.OrdinalIgnoreCase)) main.Set("CPU racers", key, name);
        RefreshLists(name);
        ApplyTexts();
        MarkDirty();
    }

    void DeleteList()
    {
        if (shownList == null) return;
        var name = shownList;
        if (Ask(string.Format(T("ask_delete"), name), MessageBoxButtons.YesNo) != DialogResult.Yes) return;
        var doc = lists[name];
        if (File.Exists(doc.Path)) FileSystem.DeleteFile(doc.Path, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
        lists.Remove(name);
        foreach (var key in new[] { "GrandPrix", "RacePark" })
            if (main.Get("CPU racers", key, "").Trim().Equals(name, StringComparison.OrdinalIgnoreCase)) main.Set("CPU racers", key, "game");
        shownList = null;
        RefreshLists(null);
        ApplyTexts();
        if (main.Dirty) MarkDirty();
    }
}

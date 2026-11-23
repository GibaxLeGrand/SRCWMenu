// Checks of SRCWMenuEditor without showing anything on screen:
//  1. every file reads back to the same bytes; 2. changing one racer changes one line only;
//  3. both tabs are drawn off screen into PNG files. Usage: Tests <mod folder copy> <png out folder>
using System.Reflection;
using System.Text;
using SRCWMenuEditor;

var mod = args[0]; var outDir = args[1];
// "--shots <list>": only draw the window (screenshots for the mod page), the Lists tab showing <list>; nothing checked
bool shotsOnly = args.Length > 2 && args[2] == "--shots";
string? shotList = shotsOnly && args.Length > 3 ? args[3] : null;
int fails = 0;
void Check(bool ok, string what) { Console.WriteLine((ok ? "OK   " : "FAIL ") + what); if (!ok) fails++; }

if (!shotsOnly) {
foreach (var f in new[] { Path.Combine(mod, "SRCWMenu.ini") }.Concat(Directory.GetFiles(Path.Combine(mod, "Lists"), "*.ini")))
{
    var doc = IniDoc.Load(f);
    Check(doc.Text == File.ReadAllText(f, new UTF8Encoding(false)).Replace("\r\n", "\n"), "round trip " + Path.GetFileName(f));
}
var listPath = Path.Combine(mod, "Lists", "Base cast.ini");
var before = File.ReadAllLines(listPath);
var list = IniDoc.Load(listPath);
Check(list.Racers().Count() >= 156, "156+ racers in Base cast.ini (" + list.Racers().Count() + ")");
var tails = list.Racers().First(e => e.RacerId == 1);
list.Set(tails, "off");
list.Set(list.Racers().First(e => e.RacerId == 23), "on");
list.Save();
var after = File.ReadAllLines(listPath);
var diff = before.Zip(after).Count(p => p.First != p.Second);
Check(before.Length == after.Length && diff == 2, $"2 lines changed in Base cast.ini ({diff})");
Check(after.Contains("1 Tails = off") && after.Contains("23 Sonic (AI Racer) = on"), "the two racer lines");
var main = IniDoc.Load(Path.Combine(mod, "SRCWMenu.ini"));
main.Set("CPU racers", "GrandPrix", "Base cast");
main.Save();
// a setting newer than the file: the section and the line are added, nothing else moves
var mainBefore = File.ReadAllLines(Path.Combine(mod, "SRCWMenu.ini"));
var main2 = IniDoc.Load(Path.Combine(mod, "SRCWMenu.ini"));
var hadSection = main2.Find("Special karts", "ProtoMan") != null;
main2.SetOrAdd("Special karts", "ProtoMan", "on", "Blue Star in Rush Roadstar colours instead of Rush Roadstar");
main2.SetOrAdd("Special karts", "Dread", "on", "Goromaru instead of Land Smasher");
main2.Save();
var mainAfter = File.ReadAllLines(Path.Combine(mod, "SRCWMenu.ini"));
Check(IniDoc.Load(Path.Combine(mod, "SRCWMenu.ini")).Get("Special karts", "ProtoMan", "") == "on", "ProtoMan = on in [Special karts] (section was there: " + hadSection + ")");
Check(mainBefore.All(l => mainAfter.Contains(l)) || hadSection, "the lines that were there are all kept");
Check(File.ReadAllText(Path.Combine(mod, "SRCWMenu.ini")).Contains("\nGrandPrix = Base cast\n"), "GrandPrix = Base cast written");
}

// draw the window off screen
ApplicationConfiguration.Initialize();
var form = new MainForm(Path.Combine(mod, "SRCWMenu.ini")) { StartPosition = FormStartPosition.Manual, Location = new Point(-4000, -4000) };
form.Show();
Application.DoEvents();
var tabs = form.Controls.OfType<TabControl>().First();
IEnumerable<Control> All(Control c) => c.Controls.Cast<Control>().SelectMany(x => new[] { x }.Concat(All(x)));
if (shotList != null) { All(form).OfType<ListBox>().First().SelectedItem = shotList; Application.DoEvents(); }
for (int i = 0; i < tabs.TabCount; i++)
{
    tabs.SelectedIndex = i;
    Application.DoEvents();
    using var bmp = new Bitmap(form.Width, form.Height);
    form.DrawToBitmap(bmp, new Rectangle(0, 0, form.Width, form.Height));
    bmp.Save(Path.Combine(outDir, $"editor_tab{i}.png"));
}
// the bottom of the racer list (Super forms)
tabs.SelectedIndex = 1;
Application.DoEvents();
var lv = All(form).OfType<ListView>().First();
lv.Items[lv.Items.Count - 1].EnsureVisible();
Application.DoEvents();
// "--shots <list> <racer>": that racer at the top of the view instead (scrolled down first, then back up to it)
var topRacer = shotsOnly && args.Length > 4 ? lv.Items.Cast<ListViewItem>().FirstOrDefault(x => x.Text == args[4]) : null;
if (topRacer != null) { topRacer.EnsureVisible(); Application.DoEvents(); }
using (var bmp = new Bitmap(form.Width, form.Height))
{
    form.DrawToBitmap(bmp, new Rectangle(0, 0, form.Width, form.Height));
    bmp.Save(Path.Combine(outDir, "editor_tab1_bottom.png"));
}
if (shotsOnly) { form.Close(); Console.WriteLine("shots written"); return 0; }
var supers = lv.Items.Cast<ListViewItem>().Where(x => x.Text is "Super Sonic" or "Super Shadow").ToList();
Check(supers.Count == 2 && supers.All(x => x.Group?.Header.StartsWith("Super forms") == true), "Super Sonic / Super Shadow in the Super forms group");
var combos = lv.Items.Cast<ListViewItem>().Where(x => x.Text.StartsWith("Godzilla Cruiser") || x.Text.StartsWith("Mothra Surf") || x.Text.StartsWith("King Ghidorah")).ToList();
Check(combos.Count is 0 or 3 && combos.All(x => x.Group?.Header.StartsWith("Guests") == true), "kart combos in the Guests group (" + combos.Count + ")");
// the AI skin buttons: a fake game answers request.txt; then no game at all (the request is taken back)
var askGame = typeof(MainForm).GetMethod("AskGame", BindingFlags.NonPublic | BindingFlags.Instance)!;
var statusLabel = form.Controls.OfType<StatusStrip>().First().Items[0];
var reqPath = Path.Combine(mod, "request.txt"); var donePath = Path.Combine(mod, "request_done.txt");
string seen = "";
var fakeGame = Task.Run(async () =>
{
    for (int i = 0; i < 100 && !File.Exists(reqPath); i++) await Task.Delay(50);
    seen = File.ReadAllText(reqPath); File.Delete(reqPath);
    File.WriteAllText(donePath, seen.Split(' ')[1].Trim() + "\nAI skins: 46 unlocked for this session\n");
});
var t1 = (Task)askGame.Invoke(form, new object[] { "unlock_colours" })!;
while (!t1.IsCompleted) { Application.DoEvents(); Thread.Sleep(20); }
Check(seen.StartsWith("unlock_colours ") && statusLabel.Text == "Game: AI skins: 46 unlocked for this session" && !File.Exists(donePath),
      "AI skin button: request sent, answer shown (" + statusLabel.Text + ")");
var t2 = (Task)askGame.Invoke(form, new object[] { "relock_colours" })!;
while (!t2.IsCompleted) { Application.DoEvents(); Thread.Sleep(20); }
Check(!File.Exists(reqPath) && statusLabel.Text.StartsWith("No answer"), "AI skin button, no game: request taken back (" + statusLabel.Text + ")");
form.Close();
Console.WriteLine(fails == 0 ? "ALL OK" : fails + " FAILED");
return fails;

// SRCWMenu Editor: edits SRCWMenu.ini, the settings of the SRCWMenu UE4SS mod for
// Sonic Racing CrossWorlds, outside the game. The game reads the file again before each race and when its menu (F10)
// opens, so saving here counts from the next race even with the game running.
// Which file: the path given on the command line, else SRCWMenu.ini next to this exe, else one picked by hand.
namespace SRCWMenuEditor;

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        ApplicationConfiguration.Initialize();
        string? path = args.Length > 0 ? args[0] : null;
        if (path == null)
        {
            var near = System.IO.Path.Combine(AppContext.BaseDirectory, "SRCWMenu.ini");
            if (File.Exists(near)) path = near;
            // in the mod folder before the game's first start with the mod, there is no
            // SRCWMenu.ini yet: the mod writes it (and the default lists) at that start
            else if (File.Exists(System.IO.Path.Combine(AppContext.BaseDirectory, "Scripts", "drivers.lua")))
            {
                MessageBox.Show(
                    "SRCWMenu.ini is not there yet: start the game once with SRCWMenu, it writes this file and the default racer lists. Then open this editor again.\n\n" +
                    "SRCWMenu.ini n'existe pas encore : lance le jeu une fois avec SRCWMenu, il écrit ce fichier et les listes de départ. Ouvre ensuite cet éditeur à nouveau.",
                    "SRCWMenu Editor", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
        }
        if (path == null || !File.Exists(path))
        {
            using var dlg = new OpenFileDialog
            {
                Title = "SRCWMenu.ini (ue4ss\\Mods\\SRCWMenu)",
                Filter = "SRCWMenu.ini|SRCWMenu.ini|INI (*.ini)|*.ini",
            };
            if (dlg.ShowDialog() != DialogResult.OK) return;
            path = dlg.FileName;
        }
        Application.Run(new MainForm(path));
    }
}

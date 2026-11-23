// An INI file of SRCWMenu (SRCWMenu.ini or a list, Lists\<name>.ini), kept line by line: only the values that change
// are rewritten, everything else (comments added by hand, unknown lines, spacing) stays as it was. Same rules as the
// mod's readers (Scripts/settings.lua, Scripts/lists.lua): [Section], "key = value ; comment", lines starting with
// ; or # are comments, and in [Racers] each racer is "<id> <name> = on|off".
using System.Text;
using System.Text.RegularExpressions;

namespace SRCWMenuEditor;

public sealed class IniEntry
{
    public int Line;
    public string Section = "";
    public string Key = "";
    public string Value = "";
    public string Prefix = "";   // the line up to the value ("0 Sonic = ")
    public string Suffix = "";   // after the value (spaces and comment)
    public int? RacerId;         // racer lines only
    public string RacerName = "";
    public string Group = "";    // the comment line above it ("Base cast"...)
}

public sealed class IniDoc
{
    public const string RacersSection = "Racers";
    static readonly Regex KeyValue = new(@"^(\s*(.*?)\s*=\s*)(.*?)(\s*([;#].*)?)$", RegexOptions.Compiled);
    static readonly Regex Racer = new(@"^(\d+)\s+(.*)$", RegexOptions.Compiled);
    static readonly UTF8Encoding Utf8 = new(false);

    public string Path { get; private set; } = "";
    public DateTime LoadedWriteTime { get; private set; }
    public readonly List<string> Lines = new();
    public readonly List<IniEntry> Entries = new();
    string? savedText;                               // the text on disk (null: a new file, never written)
    // changed = the text differs from the file, whatever happened in between (on, off, on again = not changed)
    public bool Dirty => savedText == null || Text != savedText;

    public static IniDoc Load(string path)
    {
        var doc = Parse(path, File.ReadAllText(path, Utf8));
        doc.LoadedWriteTime = File.GetLastWriteTimeUtc(path);
        doc.savedText = doc.Text;
        return doc;
    }

    // a file that does not exist yet (a new list): written by the next Save
    public static IniDoc New(string path, string text)
    {
        return Parse(path, text);
    }

    static IniDoc Parse(string path, string text)
    {
        var doc = new IniDoc { Path = path };
        doc.Lines.AddRange(text.TrimStart('﻿').Replace("\r\n", "\n").Split('\n'));
        if (doc.Lines.Count > 0 && doc.Lines[^1] == "") doc.Lines.RemoveAt(doc.Lines.Count - 1);
        doc.Reindex();
        return doc;
    }

    // the entries from the lines (again after a line is added)
    void Reindex()
    {
        Entries.Clear();
        string section = "", group = "";
        for (int i = 0; i < Lines.Count; i++)
        {
            var line = Lines[i].Trim();
            if (line.StartsWith('[') && line.EndsWith(']')) { section = line[1..^1].Trim(); group = ""; continue; }
            if (line.Length == 0) continue;
            if (line[0] == ';' || line[0] == '#') { group = line.TrimStart(';', '#', ' '); continue; }
            var m = KeyValue.Match(Lines[i]);
            if (!m.Success) continue;
            var e = new IniEntry
            {
                Line = i, Section = section, Key = m.Groups[2].Value.Trim(), Value = m.Groups[3].Value.Trim(),
                Prefix = m.Groups[1].Value, Suffix = m.Groups[4].Value, Group = group,
            };
            var r = Racer.Match(e.Key);
            if (r.Success && section.Equals(RacersSection, StringComparison.OrdinalIgnoreCase))
            {
                e.RacerId = int.Parse(r.Groups[1].Value);
                e.RacerName = r.Groups[2].Value.Trim();
            }
            Entries.Add(e);
        }
    }

    // a value that may be missing from the file (a setting newer than the file): added at the end of its section,
    // the section itself at the end of the file when it is missing too
    public void SetOrAdd(string section, string key, string value, string comment = "")
    {
        var found = Find(section, key);
        if (found != null) { Set(found, value); return; }
        var line = key + " = " + value + (comment.Length > 0 ? "      ; " + comment : "");
        int header = Lines.FindIndex(l => l.Trim().Equals("[" + section + "]", StringComparison.OrdinalIgnoreCase));
        if (header < 0)
        {
            if (Lines.Count > 0 && Lines[^1].Trim().Length > 0) Lines.Add("");
            Lines.Add("[" + section + "]");
            Lines.Add(line);
        }
        else
        {
            int at = header + 1;
            while (at < Lines.Count && !Lines[at].TrimStart().StartsWith('[')) at++;
            while (at > header + 1 && Lines[at - 1].Trim().Length == 0) at--;
            Lines.Insert(at, line);
        }
        Reindex();
    }

    public IniEntry? Find(string section, string key) =>
        Entries.FirstOrDefault(e => e.Section.Equals(section, StringComparison.OrdinalIgnoreCase)
                                    && e.Key.Equals(key, StringComparison.OrdinalIgnoreCase));

    public string Get(string section, string key, string fallback) => Find(section, key)?.Value ?? fallback;

    public IEnumerable<IniEntry> Racers() => Entries.Where(e => e.RacerId != null);

    public void Set(IniEntry e, string value)
    {
        if (e.Value == value) return;
        e.Value = value;
        Lines[e.Line] = e.Prefix + value + e.Suffix;   // the spaces and the comment after the value stay as they were
    }

    public void Set(string section, string key, string value)
    {
        var e = Find(section, key);
        if (e != null) Set(e, value);
    }

    public string Text => string.Join("\n", Lines) + "\n";

    public void ReplaceLine(int index, string text) => Lines[index] = text;

    public void MoveTo(string path)
    {
        Path = path;
        LoadedWriteTime = File.Exists(path) ? File.GetLastWriteTimeUtc(path) : default;
    }

    public bool ChangedOnDisk() => File.Exists(Path) && LoadedWriteTime != default && File.GetLastWriteTimeUtc(Path) != LoadedWriteTime;

    public void Save()
    {
        var tmp = Path + ".tmp";
        File.WriteAllText(tmp, Text, Utf8);
        File.Move(tmp, Path, true);
        LoadedWriteTime = File.GetLastWriteTimeUtc(Path);
        savedText = Text;
    }
}

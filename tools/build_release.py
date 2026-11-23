"""Build the release zip of SRCWMenu.

    dotnet publish editor/SRCWMenuEditor -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -o build/editor
    python tools/build_release.py build/editor/SRCWMenuEditor.exe

Takes mod/SRCWMenu (Scripts/*.lua, README.txt) and the editor exe, and makes
    dist/SRCWMenu_v<version>/UNION/Binaries/Win64/ue4ss/Mods/SRCWMenu/...   (staging, extracted as a user would)
    dist/SRCWMenu_v<version>.zip                                            (root = the game folder)
The version is read from mod/SRCWMenu/Scripts/main.lua (local VERSION = "...").

SRCWMenu.ini, Lists/*.ini and relock.txt are not shipped: they belong to one player and are written by the mod at its
first start. The Lists folder ships with a README only (Lua cannot create a folder; with no .ini in it the mod writes
its starting lists, Scripts/default_lists.lua, so an update never overwrites a list a player edited).
The build stops if a shipped file holds a local user path.
"""
import pathlib, re, shutil, sys, zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "mod" / "SRCWMenu"
DIST = ROOT / "dist"
REL = pathlib.PurePosixPath("UNION/Binaries/Win64/ue4ss/Mods/SRCWMenu")
FORBIDDEN = [":\\users\\", ":/users/"]  # a local user path, never in a shipped file (case-insensitive)
LISTS_README = """CPU racer lists of SRCWMenu: one list per file, <name>.ini (the name is what SRCWMenu.ini and the menu show).
At its first start the mod writes six lists here (Everyone + AI, Base Cast, Base Sonic Cast, Sonics, AI only, Duel Mode
Roster) when the folder holds no list. A line is "<racer number> <name> = on" or "= off"; only the number counts. Copy a file to make a new list,
or use SRCWMenuEditor.exe (one folder up).
"""


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    exe = pathlib.Path(sys.argv[1]).read_bytes()
    main_lua = (SRC / "Scripts" / "main.lua").read_text(encoding="utf-8")
    version = re.search(r'local VERSION = "([^"]+)"', main_lua).group(1)
    out = DIST / f"SRCWMenu_v{version}"
    zpath = DIST / f"SRCWMenu_v{version}.zip"
    for p in (out, zpath):
        if p.exists():
            sys.exit(f"{p} already exists: move it away first (nothing overwritten)")
    files = {f"Scripts/{p.name}": p.read_bytes() for p in sorted((SRC / "Scripts").glob("*.lua"))}
    files["README.txt"] = (SRC / "README.txt").read_bytes()
    files["enabled.txt"] = b"on\n"
    files["Lists/README.txt"] = LISTS_README.encode("utf-8")

    bad = []
    for name, data in list(files.items()) + [("SRCWMenuEditor.exe", exe)]:
        low = data.decode("utf-8", "replace").lower() if name.endswith((".lua", ".txt")) else \
            data.decode("latin-1").lower() + data.decode("utf-16-le", "replace").lower()
        bad += [f"{name}: '{word}'" for word in FORBIDDEN if word in low]
    if bad:
        sys.exit("local paths found, nothing built:\n  " + "\n  ".join(bad))

    mod = out / pathlib.Path(*REL.parts)
    (mod / "Scripts").mkdir(parents=True)
    (mod / "Lists").mkdir()
    for name, data in files.items():
        dest = mod / name
        dest.write_bytes(data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n") if name.endswith(".txt") else data)
    (mod / "SRCWMenuEditor.exe").write_bytes(exe)

    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for d in [REL.parents[i] for i in range(len(REL.parts) - 1, -1, -1)][1:] + [REL, REL / "Scripts", REL / "Lists"]:
            z.writestr(zipfile.ZipInfo(str(d) + "/"), b"")
        for p in sorted(mod.rglob("*")):
            if p.is_file():
                z.write(p, str(REL / p.relative_to(mod).as_posix()))
    n = sum(1 for p in mod.rglob("*") if p.is_file())
    print(f"SRCWMenu v{version}: {n} files in {out}")
    print(f"zip: {zpath} ({zpath.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()

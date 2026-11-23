# SRCWMenu

An in-game menu (F10) for the computer racers (CPU) of **Sonic Racing CrossWorlds** (PC), as a [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) v4 Lua mod, with a small Windows editor for its settings.

- **Own karts**: in Grand Prix (and Race Park if you want), every CPU racer drives its own kart, in that kart's own colours, instead of a random machine. Team races keep the team colours.
- **Special karts** (each one on / off): Super Sonic in the Super Shooting Star, Sonic in the Blue Star, Nine in the Cyber Spear, Dread in the Goromaru, Rusty Rose in the Moto Beetle, Proto Man in a Blue Star with Rush Roadstar colours.
- **CPU racer lists**: choose which racers the computer may use, one list per mode. Lists can hold the AI racers and their colour skins, the guests, Super Sonic / Super Shadow, and kart combos such as "Godzilla Cruiser (Sonic)".
- **AI colour skins**: unlock the ones still locked for the session (F7), lock them again (F8); they are locked again by themselves at the next launch.

It never unlocks or hands out anything paid or not yet released, and the online modes (Festival) are never touched.

The user documentation (install, keys, files) is in [`mod/SRCWMenu/README.txt`](mod/SRCWMenu/README.txt), the version history in [`CHANGELOG.md`](CHANGELOG.md).

## Requirements

- Sonic Racing CrossWorlds on PC (Steam), game version of November 2026.
- UE4SS v4 (experimental build), tested with v4.0.0-14-g682a75f1.
- For the editor: Windows and the .NET 10 Desktop Runtime (x64). Building it needs the .NET 10 SDK.

## Repository layout

| Path | What |
|---|---|
| `mod/SRCWMenu/Scripts/` | The UE4SS mod (Lua). `main.lua` is the entry point; `karts.lua`, `colors.lua` and `drivers.lua` are data generated from the game's tables. |
| `editor/SRCWMenuEditor/` | SRCWMenuEditor.exe (WinForms, .NET 10): edits `SRCWMenu.ini` and the list files outside the game. |
| `editor/SRCWMenuEditor.Tests/` | Off-screen checks of the editor (files read back byte for byte, one change = one line, window drawn to PNG). |
| `tools/build_release.py` | Builds the release zip (root = the game folder). |

## Building

The mod itself needs no build: copy `mod/SRCWMenu` into `UNION\Binaries\Win64\ue4ss\Mods\` of the game, and create an empty `Lists` folder in it (Lua cannot create folders).

```
dotnet publish editor/SRCWMenuEditor -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -o build/editor
dotnet run --project editor/SRCWMenuEditor.Tests -- <copy of an installed mod folder> <png output folder>
python tools/build_release.py build/editor/SRCWMenuEditor.exe
```

## Credits

[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (UE4SS-RE team). The menu borrows the game's own notice window, the way Split-Screen Rival Duel borrows game widgets.

# Changelog

## Mod

### 0.5.0 — first public version
- The editor's two AI skin buttons ask the running game to unlock / lock the AI colour skins (`request.txt`, answered in `request_done.txt`; a request older than 30 s is dropped).
- Six starting lists: Everyone + AI, Base Cast, Base Sonic Cast, Sonics, AI only, Duel Mode Roster.

### 0.4.5
- King Ghidorah Coupe is driven by Knuckles.
- SEGA console combos: Genesis (Classic Sonic), Sega Saturn (NiGHTS), Dreamcast (Shadow).
- `FillWithClones` option: a list too short for the race is used again instead of the game's draw.

### 0.4.4
- Kart combos: Godzilla Cruiser (Sonic), Mothra Surf (Tails), King Ghidorah Coupe.
- `ComboDuplicates` option: a combo may race next to the same character.

### 0.4.3
- Six special karts, each one on / off (`[Special karts]`).

### 0.4.2
- Super Sonic and Super Shadow can be added to the lists.

### 0.4.1
- A racer's own kart is also used when the player can use it (Beast Spike, McLaren Racing Car).

### 0.4
- CPU racer lists are files of their own (`Lists/<name>.ini`); `SRCWMenu.ini` points each mode at a list or at the game's draw.
- SRCWMenuEditor.exe.

### 0.3
- Settings in `SRCWMenu.ini`, read again before each race.
- Every CPU slot is drawn again from the list, so AI racers can come.

### 0.2
- English / French, a CPU racer list per mode, mouse support.

### 0.1
- F10 menu in the game's own notice window; own karts and colours in Grand Prix, extended to Race Park.

## Editor

### 0.2.0
- AI skin buttons; works in the mod folder before the game's first start with the mod.

### 0.1.0
- Settings tab and Lists tab (new / rename / delete a list); only changed lines are rewritten.

SRCWMenu 0.5.0 - Sonic Racing CrossWorlds (PC, UE4SS mod)                        by GibaxLeGrand
=====================================================================================================

An in-game menu (F10) for the computer racers (CPU) of Grand Prix and Race Park.

WHAT IT DOES
  * Own karts: in Grand Prix (and Race Park if you want), every CPU racer drives its own kart, in that kart's own
    colours, instead of a random machine. Team races keep the team colours.
  * Special karts (each one on / off): Super Sonic in the Super Shooting Star, Sonic in the Blue Star, Nine in the
    Cyber Spear, Dread in the Goromaru, Rusty Rose in the Moto Beetle, Proto Man in a Blue Star with Rush Roadstar
    colours.
  * CPU racer lists: choose which racers the computer may use, one list per mode (Grand Prix, Race Park). The
    lists can hold the AI racers and their colour skins, the guests, Super Sonic / Super Shadow, and kart combos
    such as "Godzilla Cruiser (Sonic)" or "Dreamcast EU (Shadow)". Options: a combo may race next to the same
    character; a list too short for the race can be filled with clones of its racers.
  * AI colour skins: unlock the ones still locked for the session (F7, the menu, or a button of the editor while
    the game runs), lock them again (F8). They are locked again by themselves at the next launch of the game.

  It never unlocks or hands out anything paid or not yet released: a DLC racer or kart is used only if you own it,
  a dated guest only once the game lets you play it. Grand Prix and Race Park only: the online modes (Festival)
  are never touched.

REQUIREMENTS
  * Sonic Racing CrossWorlds on PC (Steam), game version of November 2026.
  * UE4SS v4 (experimental build). Tested with UE4SS v4.0.0-14-g682a75f1.
  * For SRCWMenuEditor.exe only: Windows, with the .NET 10 Desktop Runtime (x64).

INSTALL
  1. Install UE4SS v4 in the game if it is not there yet.
  2. Extract this archive into the game folder (...\steamapps\common\SonicRacingCrossWorlds): the mod lands in
     UNION\Binaries\Win64\ue4ss\Mods\SRCWMenu. Its enabled.txt turns it on.
  3. Start the game once: the mod writes SRCWMenu.ini and six starting lists in its Lists folder: Everyone + AI,
     Base Cast, Base Sonic Cast, Sonics, AI only and Duel Mode Roster (the guests and Super forms). Point a mode at
     one of them in the menu (F10), or in the editor.

KEYS
  F10            open / close the menu
  In the menu    mouse: hover = choose, left click = select, right click = back
                 numpad 8 / 2 or Page Up / Page Down = choose, numpad 5 / 4 / 6 or Home = select,
                 Backspace = back (Num Lock on for the numpad)
  F7 / F8        AI colour skins: unlock for the session / lock them again
  F9             Grand Prix own karts on / off

FILES (in the mod folder)
  SRCWMenu.ini        the settings (written by the menu; you can also edit it by hand)
  Lists\<name>.ini    one CPU racer list per file: "23 Sonic (AI Racer) = on". Copy a file to make a new list.
  SRCWMenuEditor.exe  edits all of it outside the game (settings tab, lists tab: new / rename / delete a list);
                      its two AI skin buttons ask the running game to unlock / lock them again
  Both are read again before each race, so a change counts from the next race, even with the game running.
  Log: ue4ss\UE4SS.log, lines starting with [SRCWMenu].

GOOD TO KNOW
  * F7 writes "unlocked" flags into your save for the session, and SRCWMenu writes down what it changed
    (relock.txt) before touching anything. Back up your save first anyway:
    %APPDATA%\SEGA\SonicRacingCrossWorlds\steam\<your Steam ID>\app.sav
  * After a game update, the menu still opens but a new racer or kart may be missing from the lists until the
    mod is updated.
  * Uninstall: delete the SRCWMenu folder (start the game once before, so F7 skins are locked again).

Credits: UE4SS (UE4SS-RE team). Made by GibaxLeGrand, with Claude (Anthropic).


-----------------------------------------------------------------------------------------------------
FRANCAIS
  Un menu en jeu (F10) pour les pilotes ordinateur du Grand Prix et du Race Park : chacun reprend son propre
  kart et ses couleurs, quelques karts speciaux a cocher, des listes de pilotes a soi par mode (pilotes IA,
  invites, Super Sonic / Super Shadow, combos comme "Godzilla Cruiser (Sonic)"), et les skins de couleur des IA a
  debloquer pour la session (F7) ou a reverrouiller (F8). Rien de payant ni de pas encore sorti n'est jamais
  debloque ; les modes en ligne (Festival) ne sont jamais touches.
  Installation : UE4SS v4, puis extraire l'archive dans le dossier du jeu, lancer le jeu une fois (il ecrit six
  listes de depart, dont Everyone + AI, Base Cast et Duel Mode Roster). Langue du
  menu : ligne "Language" du menu, ou "Language = fr" dans SRCWMenu.ini. L'editeur (SRCWMenuEditor.exe) demande
  le runtime .NET 10 Desktop.

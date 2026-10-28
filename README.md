# Wrestle (working title)

An original 90s-style arcade pro wrestling game: grapples, top-rope dives, rope rebounds,
turnbuckle slams, folding chairs and tables. Includes 1v1 arcade/practice, 2v2 tag team
(1–4 local players) and a career mode.

- **Engine:** Godot 4.7 (GDScript, Forward+, Jolt physics), project in [`game/`](game/)
- **Assets:** generated procedurally by Blender 5.2 Python scripts in [`blender/`](blender/)
- **Design:** [`docs/DESIGN.md`](docs/DESIGN.md) · **Art pipeline:** [`docs/ART_PIPELINE.md`](docs/ART_PIPELINE.md) · **Credits/licenses:** [`docs/CREDITS.md`](docs/CREDITS.md)

![Ring](docs/img/m1_ring.png)
![Wrestlers](docs/img/m1_wrestlers.png)

## Getting started

```bash
git lfs install            # once per machine (tools/setup.sh does this too)
git clone https://github.com/intra-secdsm/slamquake.git
cd wrestle
tools/setup.sh             # installs pinned Godot, Blender, git-lfs into ~/.local (no sudo)
tools/build_assets.sh      # regenerate models/animations with Blender (see docs/ART_PIPELINE.md)
tools/test.sh              # run the test suite headlessly
godot --path game          # play
godot -e --path game       # open the editor
```

Pinned tool versions live in [`tools/versions.env`](tools/versions.env).
`tools/export.sh [Linux|Windows]` builds standalone executables into `build/`.

## Controls

| Action | Gamepad | Keyboard P1 | Keyboard P2 |
|---|---|---|---|
| Move | Left stick / D-pad | WASD | Arrows |
| Punch (tap repeatedly for a combo) | X | J | Num 1 |
| Kick (each wrestler's own kick; knocks down as a combo ender) | Y | I | Num 5 |
| Grapple: tie-up; from behind = their back grapple; vs a running opponent = back body drop | A | K | Num 2 |
| Run (hold; bounce off the ropes; punch/kick while running = their running attack) | B | L | Num 3 |
| Block (hold); **tap** just before a hit = parry, as a move starts on you = reversal; next to a downed opponent = **pin** | RB | Space | Num 0 |
| Taunt (builds momentum); with a SPECIAL = **finisher** | LB | U | Num 4 |
| Get up faster / kick out of a pin | mash any button | | |
| Pause | Start | Esc | Num Enter |
| Menus: move / change · confirm · back · change tab | D-pad or stick · A · B · LB/RB | Arrows · Enter · Esc · Q/E | |

**Every wrestler has their own moveset** (pause → *Move List* shows it, and the on-screen help names
your moves). **In a tie-up:** punch, punch + direction, kick and kick + direction are four moves of
the wrestler's own (e.g. Thunder Mack: headbutt, body slam, vertical suplex, piledriver); run
(+ direction) = Irish whip into the ropes or a corner, grapple = shove away.
**Opponent down:** grapple = pick up, punch = their ground move (elbow/leg/knee drop), kick = stomp,
block = pin.
Whipped opponents coming back off the ropes can be clotheslined (punch/kick) or back body dropped (grapple).
**Using the ring:** hold a direction into the ropes for a moment to roll out to the floor (and into the
apron to roll back in). Whip an opponent toward nearby ropes from a tie-up to toss them over the top;
big hits near the ropes knock people out too. Grapple next to a corner to climb up, then punch/kick to
dive (crossbody onto a standing opponent, elbow drop/splash onto a downed one); strike a perched opponent
to knock them off. Grapple next to the chair to pick it up, punch to swing, grapple to drop it.
Land someone on the ringside table to smash it.

**Momentum and finishers:** landing offence, kicking out, parries, reversals and taunts fill the
momentum meter under your health bar (you also gain a little from taking punishment). A full meter
banks a **SPECIAL** for 20 seconds: you glow gold and hit a little harder. Press taunt in a tie-up, or
next to a dazed opponent, to hit your finisher. Kicking out right after a finisher is much harder.
**Reversals:** tap block just before a strike lands to parry it and leave the striker open; tap block
just as a tie-up move (or finisher, or Irish whip) starts on you to reverse it into a hip toss (or a
reversed whip). Mashing block never works: a press right after another one doesn't count.

**Tag team (2v2):** pick *Tag Team* in the menu; each of the four slots can be a human or the CPU
(press Enter/A on a slot to switch). Humans get input in slot order: P1 and P2 can use the keyboard,
P3 and P4 need gamepads 3 and 4. The legal wrestler fights while the partner waits on the far apron and
slowly recovers. **Tag** by pressing grapple next to your corner. Tagging out below half health is a
**hot tag**: your partner comes in with a burst of momentum. On the apron, push toward the ring to climb
in illegally; you get 5 seconds before the referee sends you back. Use that time to **break up a pin**
(strike the pinner) or to grab an opponent your partner has tied up for a **double suplex**. Only legal
wrestlers can pin, be pinned or be counted out, and the whole team wins or loses together.

Win by pinfall (pins under the ropes are broken). Normal rules add a 20-count count-out and
disqualification for chair shots; No DQ allows anything and has no count-outs.

Gamepad N always controls player N. F1 toggles the on-screen controls.

**The roster** (all original characters). Stats are power / speed / toughness / charisma (1–5, the
same 12-point budget for everyone); the CPU fights each one in character.

| Wrestler | Style | Finisher | Theme |
|---|---|---|---|
| Thunder Mack — "The Storm from South Street" | brawler | Thunder Bomb (powerbomb) | hard rock |
| Zip Volta — "100,000 Volts of High-Flying" | high-flyer | Volt Shock (jawbreaker) | electro |
| Bruno Kessler — "The Iron Wall" | powerhouse | Iron Drop (chokeslam) | heavy and slow |
| Quetzal Neón — "The Emerald Wings of Lucha" | high-flyer (masked) | Quetzal Rana (hurricanrana) | latin party rock |
| Silas Wren — "The Grandmaster of the Mat" | technician | Checkmate (exploder suplex) | baroque rock |
| Kai Breakwater — "Hang Ten. Hit Hard." | showman | Wipeout (spear) | surf rock |
| Overclock — "The Cybernetic Superstar" | powerhouse | System Crash (spinebuster) | industrial techno |
| Nova Reyes — "Brighter Than a Thousand Suns" | high-flyer | Supernova (fireman's-carry driver) | eurodance |

**Create-a-Wrestler** (main menu): start fresh or copy a roster wrestler, then edit the profile
(name, nickname, colour, entrance theme, pyro, titantron), body (type, height, build, muscle, gut,
skin), head (hair, facial hair, face paint, masks), attire (trunks, tights, singlet, top, patterns,
boots, pads, tattoos), every move slot including the finisher, and stats. The wrestler is previewed
live, moves play as you pick them, and names can be entered with a pad. Created wrestlers are saved
to `user://created_wrestlers.json` and can be picked anywhere a roster wrestler can.

**Career** (main menu): take a roster or created wrestler from the bottom of the rankings on
*Saturday Slamtime* to the World title. Each month is three weekly shows and then a pay-per-view.
Wins earn ranking points, and whoever is number one when a month starts challenges the champion at
that PPV. You also get a tag partner (two tag wins earn a tag title shot) and a rival each month,
with comic-style promo scenes and a no-DQ grudge match at the PPV. Champions wear their belts to the
ring. Unlocks: the *Champion* pyro for created wrestlers and two hidden wrestlers, Roxy Ravage and
Mister Midnight. The career saves after every show to `user://career.json`, and unlocks go to
`user://unlocks.json`.

**Presentation:** matches open with entrances (theme music, pyro, the titantron, a walk down the ramp);
press any button to skip. Pinfall wins get a slow-motion VHS instant replay of the finish. **Options**
(main menu): music, sound effects and crowd volume, fullscreen, the CRT filter, entrances and replays,
saved to `user://settings.cfg`.

## Testing

```bash
tools/test.sh                                                          # unit tests (GUT)
godot --headless --fixed-fps 60 --path game res://dev/soak.tscn -- --seconds=300  # CPU-vs-CPU soak
tools/screenshot.sh res://dev/pose_lineup.tscn out.png 20 --poses=run@0,knockdown@0.4
```

## Repository conventions

- Binary assets (`.glb`, `.blend`, images, audio, fonts) are stored with Git LFS. See `.gitattributes`.
- Generated assets in `game/assets/generated/` are committed so the game opens without Blender.
  Regenerate them with the Blender scripts. Never hand-edit them.
- Work happens on milestone branches (`m1-asset-pipeline`, …) that merge to `main`. Each
  milestone is tagged (`v0.1`, `v0.2`, …).

## Milestones

| | Milestone | Status |
|---|---|---|
| M0 | Toolchain, repo, project skeleton, tests | ✅ |
| M1 | Blender → Godot asset pipeline (rig, wrestler, ring) | ✅ |
| M2 | Movement, strikes, camera, HUD | ✅ |
| M3 | Grapples, whips, rope rebounds, pinfalls: first full match | ✅ |
| M4 | Top rope, outside the ring, chair, tables, count-outs | ✅ |
| M5 | Momentum, finishers, reversals, game feel, AI | ✅ |
| M6 | Tag team, 4 local players | ✅ |
| M7 | Arena, crowd, entrances, menus, audio | ✅ |
| M8 | Roster of 8 + Create-a-Wrestler | ✅ |
| M9 | Career mode | ✅ |
| M10 | Polish & release builds | |

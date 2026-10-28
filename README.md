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
| Kick (big boot; knocks down as a combo ender) | Y | I | Num 5 |
| Grapple: tie-up; from behind = German suplex; vs a running opponent = back body drop | A | K | Num 2 |
| Run (hold; bounce off the ropes; punch/kick while running = clothesline) | B | L | Num 3 |
| Block (hold); press next to a downed opponent to **pin** | RB | Space | Num 0 |
| Taunt | LB | U | Num 4 |
| Get up faster / kick out of a pin | mash any button | | |
| Pause | Start | Esc | Num Enter |

**In a tie-up:** punch = headbutt, punch + direction = body slam, kick = suplex,
kick + direction = DDT, run (+ direction) = Irish whip into the ropes or a corner, grapple = shove away.
**Opponent down:** grapple = pick up, punch = elbow drop, kick = stomp, block = pin.
Whipped opponents coming back off the ropes can be clotheslined (punch/kick) or back body dropped (grapple).
Win by pinfall; pins with the head or body under the ropes are broken.

Gamepad N always controls player N. F1 toggles the on-screen controls.

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
| M4 | Top rope, apron, outside, chair, tables, ragdoll | |
| M5 | Momentum, finishers, reversals, game feel, AI | |
| M6 | Tag team, 4 local players | |
| M7 | Arena, crowd, entrances, menus, audio | |
| M8 | Roster of 8 + Create-a-Wrestler | |
| M9 | Career mode | |
| M10 | Polish & release builds | |

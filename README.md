# Wrestle (working title)

An original 90s-style arcade pro wrestling game: grapples, top-rope dives, rope rebounds,
turnbuckle slams, folding chairs and tables. Includes 1v1 arcade/practice, 2v2 tag team
(1–4 local players) and a career mode.

- **Engine:** Godot 4.7 (GDScript, Forward+, Jolt physics), project in [`game/`](game/)
- **Assets:** generated procedurally by Blender 5.2 Python scripts in [`blender/`](blender/)
- **Design:** [`docs/DESIGN.md`](docs/DESIGN.md) · **Credits/licenses:** [`docs/CREDITS.md`](docs/CREDITS.md)

## Getting started

```bash
git lfs install            # once per machine (tools/setup.sh does this too)
git clone https://github.com/intra-secdsm/slamquake.git
cd wrestle
tools/setup.sh             # installs pinned Godot, Blender, git-lfs into ~/.local (no sudo)
tools/test.sh              # run the test suite headlessly
godot --path game          # play
godot -e --path game       # open the editor
```

Pinned tool versions live in [`tools/versions.env`](tools/versions.env).

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
| M1 | Blender → Godot asset pipeline (rig, wrestler, ring) | |
| M2 | Movement, strikes, camera, HUD | |
| M3 | Grapples, whips, rope rebounds, pinfalls: first full match | |
| M4 | Top rope, apron, outside, chair, tables, ragdoll | |
| M5 | Momentum, finishers, reversals, game feel, AI | |
| M6 | Tag team, 4 local players | |
| M7 | Arena, crowd, entrances, menus, audio | |
| M8 | Roster of 8 + Create-a-Wrestler | |
| M9 | Career mode | |
| M10 | Polish & release builds | |

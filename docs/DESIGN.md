# Design Document

## Overview
**SLAMQUAKE! Suplex Spectacular!** (working name; box art in `docs/art/`): an original, 90s-style arcade pro wrestling game. Assets are generated procedurally with Blender; the game runs in Godot.

**Core decisions:**
- **Visuals:** stylized modern. Bold, chunky "action-figure" characters, modern lighting, bloom, volumetric spotlights and pyro, and 90s attitude (neon, CRT/VHS-style menus and replays).
- **Combat:** a grapple-system core (strikes, weak/strong grapples, reversals, positional moves). Specials and finishers are flashy and exaggerated, with hit-stop, camera zooms and particles.
- **Players:** local 1–4 players with gamepad or keyboard. Any slot can be human or CPU. No online play.
- **Assets:** procedural and scripted only. Blender Python generates the models, rigs and pose-based animations. Free CC0 audio is allowed, and licenses are tracked.
- **Modes:** an arcade 1v1 practice match, 2v2 tag team, and a career mode (ladder, belts and a light story).
- **Roster:** about 8 original fictional wrestlers, plus create-a-wrestler (CAW). No real people or trademarks. This is an original game, not a remake of any existing title.
- **Repo:** `intra-secdsm/slamquake` on GitHub, `main` branch, Git LFS for binary files.


## Tech stack
- **Godot 4.7 (standard build) with typed GDScript.** No C#/.NET, so headless runs and tests stay simple.
- Rendering: Forward+ renderer and Jolt physics (both built in).
- **Blender 5.2 LTS (official tarball)**, run headless: `blender -b -P blender/build.py`.
- Tools (Godot, Blender, git-lfs) are installed without sudo into `~/.local/opt/<tool>/<ver>`, with symlinks in `~/.local/bin`. Versions are pinned in `tools/versions.env`, and `tools/setup.sh` downloads them and verifies their published checksums.
- Godot export templates are installed so we can build Linux and Windows versions.
- Testing: **GUT** (Godot Unit Test) addon, run with `godot --headless`.

## Repo layout
```
wrestle/
  game/                     Godot project (project.godot)
    core/                   autoloads: GameState, InputRouter, AudioDirector, SaveSystem
    wrestler/               Wrestler.tscn, state machine, MovePlayer, damage, AI
    match/                  MatchDirector, rules (pin/submission/countout/DQ), Referee, Camera
    ring/                   ring, ropes, turnbuckles, apron, ringside, props (chair, table)
    data/                   moves/*.tres, wrestlers/*.tres, career/*.tres
    ui/                     menus, HUD, CAW, career screens
    fx/                     shaders (toon+rim, CRT/VHS post), particles
    assets/generated/       .glb from Blender (LFS, committed)
    assets/audio/           CC0 audio (LFS) + licenses.json
    tests/                  GUT unit tests + headless sim tests
  blender/                  bpy generators: rig, bodies, attire, ring, arena, props, poses
  tools/                    setup.sh, build_assets.sh, export.sh, fetch_audio.py, screenshot.gd
  docs/                     DESIGN.md, MOVES.md, ART_PIPELINE.md, CREDITS.md
  .gitattributes            LFS: *.glb *.blend *.png *.jpg *.exr *.wav *.ogg *.mp3 *.ttf
```
The generated `.glb` files are committed through LFS. That way the game opens in Godot even without Blender, and regenerating them is deterministic.

## Core architecture

**Procedural characters (Blender):**
- One shared humanoid armature with about 30 bones and standard names, so every wrestler shares one animation library.
- The body is a parametric mesh with shape keys (height, mass, muscle, gut, shoulder width). These export as Godot blend shapes, so CAW sliders change the body live.
- Modular attire meshes: trunks, singlet, tights, boots, kneepads, mask, jacket, wristbands and hair styles.
- A shader tints colors and draws patterns, face paint and tattoos from a small texture atlas.

**Animation (the hardest part with procedural-only assets):**
- Animations are built from pose libraries. Key poses are written in Blender Python as bone rotations, then interpolated with easing curves and baked into actions. They export together in one GLB `AnimationLibrary`.
- Paired grapple moves are authored in a shared "pair space": the attacker and defender tracks are relative to one anchor.
- Runtime layers make the motion feel alive:
  - foot IK and look-at
  - additive hit reactions
  - spring-based secondary motion (hair, belly, jacket)
  - physics ragdoll (`PhysicalBoneSimulator3D`) blended in for knockdowns, falls to the floor and table spots
- Hit-stop, camera shake, slow-mo on finishers, motion trails and impact particles cover some of the stiffness in the animation. This is a known quality risk, and the rig and data format keep the door open to hand-animated replacements later.

**Moves are data-driven:**
- A `MoveData` resource holds: context, input, animation names (attacker/defender), hit frames, damage per body part, momentum gain, reversal window, SFX cues, camera cue, and the end state for each wrestler.
- A `WrestlerData` resource holds: name, gimmick, body parameters, attire, colors, stats, moveset (per context), finisher, special, taunt, entrance theme and pyro.
- `MoveResolver` picks a move from context × input direction × button × moveset. Contexts include: front/back grapple (weak/strong), running, rebounding off the ropes, opponent in the corner, ground (head or legs), top rope (standing or diving), apron, outside, and holding a weapon.

**Wrestler state machine:**
- States: Idle/Move, Run, Strike, Block, GrappleInit, Grappling, Whip/RopeRebound, Stunned, Down, GettingUp, ClimbTurnbuckle, OnTopRope, Aerial, Apron, ThroughRopes, Outside, HoldingWeapon, Pinning/Pinned, Submission, Taunt, Ragdoll, Entrance, Celebrate.
- `MovePlayer` snaps both wrestlers to the pair anchor, runs the timeline and handles reversal input.

**Ring and environment:**
- Ring: canvas floor, 3 ropes per side, 4 turnbuckles, apron, steel steps, padded floor, barricade.
- Ropes are dynamic: a spring-driven deformation of the rope bones, Irish-whip rebounds, a slingshot off the ropes, and dazed/tangled-in-the-ropes states.
- `Area3D` zones for turnbuckle climbing, the apron, rolling in and out, and slamming into the turnbuckle (corner whip).
- **Props:** a folding chair (pick up, swing, throw, sit on, wedge in the corner) and a folding table (set up, put the opponent on it, splash or powerbomb through it). The table has a pre-fractured breakable mesh plus debris physics. Ring steps and a ladder are stretch goals.

**Match rules:**
- Per-body-part damage, stamina, and a **momentum meter**. A full meter stores a "Special", which unlocks the finisher.
- Pinfall uses a kick-out timing/mash minigame that scales with damage. Submissions use a meter tug-of-war, with a rope break when a rope is in reach.
- 20-count count-out, DQ rules, and no-DQ/hardcore toggles.
- **Referee NPC** who counts, can be knocked down, and reacts to weapons.

**Tag team:**
- Legal-man rules, apron partners, tag hands, hot-tag boost.
- Double-team moves, saves that break up pins, and the ref forcing the illegal man out. A countdown timer limits how long the illegal man can stay in.

**AI:**
- Utility-based: scores actions by health, momentum, distance, context and difficulty. Difficulty levels are Easy/Normal/Hard/Legend.
- Has tag-partner logic and an option to make the CPU go for weapons.

**Camera:**
- A broadcast-style camera that keeps every active wrestler in frame and smooths its movement.
- Cinematic cuts and zooms for finishers.
- An instant replay of the finisher with a VHS filter. It plays back a ring buffer of recorded transforms.

**Input:**
- `InputRouter` maps up to 4 devices (gamepads and keyboard) to player slots.
- Controls can be remapped and are saved.

**Presentation and audio:**
- Arena: a procedural venue with stands, an entrance ramp, a stage, and a "titantron" that shows procedural visuals rendered in a `SubViewport`.
- Lighting: spotlights with volumetric fog, glow, SSAO, and baked lightmaps or SDFGI.
- Crowd: low-poly fans drawn with `MultiMesh` and a GPU vertex-animation shader, waving signs and holding camera-flash particles. Their excitement follows the match's momentum.
- Entrances: walk-out animation, pyro, lights and theme music.
- `AudioDirector`:
  - layered impact SFX by type (strike, slam, table break, chair hit, ropes)
  - a dynamic crowd bed (murmur → cheer → "pop"), bell, ref counts
  - CC0 or synthesized music stings, and entrance themes
- All audio licenses are tracked in `assets/audio/licenses.json` and `docs/CREDITS.md`. `tools/fetch_audio.py` keeps a manifest with URLs and checksums.
- Optional: offline TTS for announcer and ref callouts, after checking the voice license.

## Modes
1. **Arcade 1v1 practice:** choose wrestlers, CPU difficulty and rules. Practice extras: infinite health, a dummy behavior setting (idle/block/reverse/fight back), an on-screen move list and an input display.
2. **Tag Team 2v2:** 1–4 humans, the rest CPU.
3. **Career:**
   - Pick a roster wrestler or a CAW.
   - Weekly TV-show cards, plus a monthly PPV.
   - Rivalries generated from story templates. Promo and storyline beats appear as text/comic-panel screens.
   - Climb the rankings to earn shots at the Tag and World titles, then defend the belt.
   - Unlock moves, attire and hidden wrestlers.
   - Save/load as JSON under `user://`.
4. **Create-a-Wrestler:** body sliders, attire pieces and colors, face paint, moveset builder, finisher, entrance music and pyro.
5. **Options:** controls, audio, video. Plus a move list/help screen.

## Milestones
Each milestone has its own feature branch, merges to `main`, and gets a tag (`v0.N`). DESIGN.md and the tests grow along the way.

- **M0: Setup.** Install Godot, Blender and git-lfs. Create the git repo and set up LFS. Add the skeleton layout, README, .gitignore/.gitattributes, GUT and the tools scripts. First push.
- **M1: Asset pipeline proof.** Blender scripts generate the rig, one parametric wrestler, the ring with ropes and turnbuckles, and 3 animations, then export GLB. Godot loads and renders it with the toon shader. A headless screenshot shows the result.
- **M2: Movement and strikes.** Basic 1v1 movement, strikes and blocks, the broadcast camera, the HUD, a CPU dummy and input for 2 players.
- **M3: First fun (vertical slice).**
  - Grapples with about 10 paired moves.
  - Irish whip and rope rebound, the turnbuckle slam, and the ground game.
  - Pinfall, the referee and rules → a complete 1v1 match.
- **M4: Using the environment.** Climbing the top rope and aerial moves, apron moves, leaving and re-entering the ring, outside-the-ring spots, the folding chair, the breakable table, ragdoll and count-outs.
- **M5: Specials and feel.** The momentum meter, specials and finishers with cinematics, reversals, and a polish pass on hit-stop, particles and layered SFX. AI v1 with difficulty levels.
- **M6: Tag team.** 2v2 rules, double-teams and saves, 4 local players, and partner AI.
- **M7: Presentation.** Arena, lighting, crowd, entrances, titantron, menus and front-end flow (90s neon/CRT style), music, plus a full audio pass.
- **M8: Roster and CAW.** 8 original wrestlers, each with a unique gimmick, a unique finisher, a theme and a moveset. The Create-a-Wrestler editor.
- **M9: Career mode.** Schedule, rankings, belts, rivalries, story beats, unlocks, saves.
- **M10: Polish and release.** Balance, performance (target 60 fps), bug sweep, Linux and Windows export builds, and a `v1.0` tag.

M3 is the key gate: the core grapple and animation approach must feel good there before content scales up.

### Status notes
- **M4 (v0.4):** ragdoll and apron moves are deferred. Falls use authored animations. The apron is only a route in and out.
- **v0.4.1 (playtest):** defenders always get a way back. Time down is capped at 4.5 s, whatever the attacker does. There is a 0.6 s wake-up grace. The corner releases after 3 hits or 2.4 s, and mashing gets you out sooner.
- **M5 (v0.5):**
  - **Momentum** (0–100) comes from offence, parries, reversals, taunts and kick-outs. A full meter banks a SPECIAL for 20 s, which gives +15% damage and a gold aura.
  - **Finishers** come from a tie-up or onto a dazed opponent. They get slow-mo, an in-ring orbiting camera, a flash and a crowd pop. Kick-outs right after one are harder.
  - **Reversals** use timed block presses: a parry before a strike lands, and a reversal in the first ~0.2–0.3 s of tie-up moves. A mash guard stops spamming.
  - **CPU:** five difficulty levels (Dummy → Legend), with reversal, parry and taunt odds, finisher use, and a block-hold cap.
  - **Deferred to M7:** the finisher instant replay with VHS filter, the crowd bed, and recorded audio.
- **M6 (v0.6):**
  - **Setup and tagging:** four entrants make a tag match. Partners wait on the far apron (±1.9, −3.25) so they stay out of the camera's view. Tags happen at the team's own spot just inside the ropes. Regen on the apron is 0.2 health/s, and a hot tag below 50% health gives +25 momentum.
  - **Illegal partners:** a 5 s timer, after which the wrestler is steered back to the corner. They can't pin or be counted out.
  - **Saves and double teams:** a strike on the pinner breaks the pin. The double suplex reuses the suplex animations for two side-by-side attackers.
  - **Partner AI:** saves (35–80% per pin by difficulty), returns to the corner, tags out when hurt, and occasionally comes in for a double team.
  - **Fix:** distance checks that used a normalized vector, which had also made the grab range unlimited since M3.
- **M7 (v0.7):**
  - **Arena** (`blender/wrestle_gen/arena.py`): seating tiers, stage, ramp, truss and walls. About 3,000 instanced fans with vertex-shader animation, plus signs and camera flashes. Crowd "heat" comes from match events and drives the crowd's animation, its noise and the sweep speed of the house lights.
  - **Titantron:** a SubViewport with a neon shader.
  - **Entrances:** theme, pyro and a walk down the ramp, then a roll into the ring or a climb onto the apron. Skippable.
  - **Replay:** an 8 s transform/animation ring buffer replays the last finisher, or the run-up to the pin, through a VHS shader.
  - **Front end:** title screen, setup panel with live 3D picks, options, and a CRT shader.
  - **Audio:** synthesized music and crowd loops. Settings drive the audio buses.
- **M8 (v0.8):**
  - **Movesets** (`game/data/movesets.gd`): 12 slots (kick, running attack, four tie-up moves, from behind, on a downed opponent, two top-rope dives, taunt, finisher) with 2–8 options each. `Wrestler.move_for(slot)` falls back to the slot default if a move isn't built.
  - **Stats** (`game/data/stats.gd`): power, speed, toughness, charisma (1–5, budget 12) scale damage dealt and taken, kick-outs, movement and momentum.
  - **Roster:** 8 wrestlers, each with a finisher, signature taunt, theme, pyro style, titantron motif and CPU fighting style (brawler, high-flyer, powerhouse, technician, showman).
  - **New moves:** 5 finishers, 5 strikes, 10 tie-up/back moves, 2 ground moves, 2 dives and 7 taunts.
  - **Looks:** a feminine body blend shape; shader-painted masks, face paint, singlets, tops, trunk patterns, bare feet and tattoos; 5 more hair styles and 4 facial-hair meshes.
  - **Create-a-Wrestler** (`game/ui/caw_editor.gd`, `game/data/caw_store.gd`): a tabbed editor with a live preview; saves to `user://created_wrestlers.json`.
  - **Also:** a pause-menu move list, big-move callouts, and 8 new synthesized themes (5 for the roster, 3 for created wrestlers).
  - **Deferred:** submissions, apron moves and ragdoll.
- **M9 (v0.9):**
  - **Career** (`game/data/career.gd`): one saved career (`user://career.json`). A month is three TV shows (*Saturday Slamtime*) and a PPV:
    - week 1: a ranking match
    - week 2: a tag match with your CPU partner
    - week 3: a ranking match
    - PPV: a World title match if you're the champion or the top contender, otherwise a no-DQ grudge match with your rival
  - **Rankings and titles:**
    - A win is worth 3 points, 5 at a PPV and 2 in a tag match. A loss costs 1.
    - The contender is whoever is top of the rankings when the month starts.
    - Two tag wins earn a tag title shot.
    - Everyone else's matches are simulated from points and stats.
    - Title matches are one CPU difficulty step harder.
    - Pacing, measured over 20 careers: a 75% win rate usually reaches a title shot by week 11 to 15.
  - **Story** (`game/data/stories.gd`):
    - Rivalry templates: jealousy, ambush, respect, mind games, spotlight, plus title chase and title defence.
    - Each template has start, build, PPV, win and loss scenes.
    - One-off moments: debut, new partner, tag titles won or lost, Hall of Fame.
    - Played as promo scenes: the cast in the ring (`MenuStage.promo`) with comic captions.
  - **Belts:** a shader-painted championship belt (gold for the World title, silver for the tag titles). It's worn to the ring, handed over at the bell, and put on the winners of a title match.
  - **Unlocks** (`game/data/unlocks.gd`, `user://unlocks.json`):
    - Champion pyro: win a PPV match.
    - Roxy Ravage: win the tag titles.
    - Mister Midnight: win the World title.
    - Hall of Fame: three successful World title defences.
  - **Tests:** a GUT pre-run hook points every save file at throwaway test files.
- **M10 (v1.0-rc1):**
  - **Name:** *SLAMQUAKE! Suplex Spectacular!* (working name). The box art is in `docs/art/`, and its artwork is the boot splash. Saves live in the user folder `slamquake`, which stays the same if the name changes. Saves from the old "Wrestle (working title)" folder are copied over once.
  - **Entrances:** a wide stage shot that shows the pyro and titantron, then a looser follow down the aisle.
  - **Performance:**
    - Measured with the dev `--fps` hook (GPU time, worst frames, and what was added on a slow frame). At 1080p on an RTX 4090, the GPU averages about 3.7 ms per frame, and headless CPU frames stay under 10 ms.
    - Hit effects share their meshes and materials, and are drawn once while the match loads. Fresh ones on every hit had caused ~80 ms hitches.
    - The Graphics option has High and Low. Low turns off volumetric haze, SSAO and MSAA, and renders 3D at 75% with FSR.
  - **Balance:**
    - Measured with `soak.tscn --balance`: equal CPUs, about 420 singles per run, with per-wrestler records and damage by move.
    - Stat effects per point:
      - power: ±4% damage dealt
      - toughness: ∓3.5% damage taken, ∓4% kick-out difficulty
      - speed: ±6% movement, ∓10% time down (capped at 4.5 s), ±12% reversal window and CPU reversal rate
      - charisma: ±20% momentum
    - The roster win spread narrowed from 23–74% to about 33–61%. High-flyers are still the weakest as CPUs.
  - **Bugs found by long soaks:**
    - stalls against the ringside table and steel steps
    - endless diagonal runs
    - chair swings at nobody
    - sinking into the canvas
    - throws landing inside the barricade

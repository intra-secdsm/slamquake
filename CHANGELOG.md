# Changelog

## 1.01 (2026-11-06)

A bug-fix release. Controls and save files are unchanged: 1.0 career and Create-a-Wrestler saves
carry over as they are.

### Matches
- **Wrestler height no longer throws off ring exits and climbs.** Tall wrestlers sank into the
  floor and short ones floated above it while rolling out of the ring, climbing back in, going
  over the top rope or climbing a turnbuckle, then snapped into place at the end. Every height
  now follows the same path to the floor, the apron and the top rope. (#8)
- **No more dip after landing on the floor.** A wrestler knocked over the top rope or thrown with a
  rope toss briefly dropped about a metre below the floor before popping back up, and every throw
  that leaves the opponent down slid them a short way on landing. They now land and stay put.
- **Double teams at ringside play on the floor.** A double suplex started from a tie-up under the
  ring played out under the canvas. (#13)
- **Irish whips outside the ring stay outside.** A whip on the floor could aim at an in-ring
  turnbuckle and snap the wrestler across the ring onto it. (#14)
- **Pausing freezes entrances.** Wrestlers kept walking to the ring, and the next entrance started,
  while the match was paused. (#18)
- **Moves near the ropes stay on one side of them.** Ground attacks and running grapples could pull
  an opponent through the ropes, between the ring and the floor. (#2)
- **Tag-team count-outs are scored correctly.** After a tag, a count-out win could be recorded as a
  draw. (#1)

### Career
- **Failed saves are no longer silent.** If the career can't be saved (for example, the save folder
  can't be written), you now see a warning and can retry. Save & quit only leaves once the save has
  worked, and throwing away unsaved progress needs a confirmed **Discard progress**. A retried save
  never counts a match result twice. (#16)
- **A restarted career plays its opening story.** Starting a new career in the same session skipped
  the introduction. (#19)
- **A post-match promo no longer skips the next show's story.** (#5)
- **Pay-per-view cards book each wrestler once.** A simulated title loser could be booked a second
  time on the same show. (#6)

### Create-a-Wrestler
- **A failed save or delete leaves your roster alone.** If the wrestler file can't be written, edits
  and deletions no longer half-apply. A failed delete keeps you in the editor with a message, so you
  can try again. (#15)

### Sound and graphics
- **Quick menu changes no longer silence the music.** Switching screens while a theme was still
  fading in could leave the new theme inaudible. (#17)
- **The crowd's fan boxes face outward.** (#7)
- **Cyber face plates get their metallic shine.** (#10)

### For developers
- `tools/export.sh` fails when Godot's import or export fails, instead of reporting success and
  keeping an old build. (#3)
- `tools/build_assets.sh` fails when a Blender generator raises an error or the import fails. (#4)
- The regenerated-model check no longer ignores changes that only fix triangle winding. (#9)
- GitHub Actions runs the test suite and a 10-minute simulated soak on every push to `main` and every pull request.
- New tests cover root motion at every wrestler height, landings, save failures, music fades,
  paused entrances and ringside moves.

Numbers in brackets are GitHub issues.

## 1.0 (2026-10-28)

First release.

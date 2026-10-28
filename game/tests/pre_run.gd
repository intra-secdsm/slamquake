extends GutHookScript
## Runs before any test: every save file points at a throwaway test file, so no test
## can ever read or write the player's real created wrestlers, unlocks or career.

const SAVES := {"wrestle/caw_save_path": "caw", "wrestle/unlocks_path": "unlocks", "wrestle/career_save_path": "career"}


func run() -> void:
	for key in SAVES:
		var p := "user://test_%s_%d.json" % [SAVES[key], OS.get_process_id()]
		ProjectSettings.set_setting(key, p)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	CawStore.reload()
	Unlocks.reload()

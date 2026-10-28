extends GutHookScript
## Clean up the throwaway save files pre_run.gd pointed everything at.


func run() -> void:
	for key in ["wrestle/caw_save_path", "wrestle/unlocks_path", "wrestle/career_save_path"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ProjectSettings.get_setting(key)))

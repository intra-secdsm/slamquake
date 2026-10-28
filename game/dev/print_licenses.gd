extends SceneTree
## Prints Godot's own licence and the copyright/licence of every third-party component built
## into the engine, as Markdown, for docs/THIRD_PARTY_NOTICES.md:
##   godot --headless --path game -s res://dev/print_licenses.gd


func _init() -> void:
	var out := PackedStringArray()
	out.append("## Godot Engine %s\n" % Engine.get_version_info()["string"])
	out.append("```\n%s\n```\n" % Engine.get_license_text().strip_edges())
	out.append("### Third-party components built into the engine\n")
	for c: Dictionary in Engine.get_copyright_info():
		out.append("#### %s\n" % c["name"])
		for part: Dictionary in c["parts"]:
			for line: String in part["copyright"]:
				out.append("- © %s" % line)
			out.append("- License: %s\n" % part["license"])
	out.append("### License texts\n")
	var info := Engine.get_license_info()
	var names := info.keys()
	names.sort()
	for n: String in names:
		out.append("#### %s\n" % n)
		out.append("```\n%s\n```\n" % String(info[n]).strip_edges())
	print("@@BEGIN@@\n" + "\n".join(out) + "\n@@END@@")
	quit()

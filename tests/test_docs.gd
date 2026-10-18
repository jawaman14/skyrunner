extends TestCase
## The docs stand on their own: every relative link in the project's Markdown
## resolves inside the Godot project, and none points back at the archival
## Python prototype (only tools/reference and the fixtures' README may name it).

const DOCS := ["res://README.md", "res://docs/DESIGN.md", "res://docs/DECISIONS.md", "res://docs/ROADMAP.md", "res://docs/MULTIPLAYER.md", "res://docs/BALANCE.md",
	"res://docs/PORTING.md", "res://tests/fixtures/README.md",
	"res://docs/README.md", "res://docs/archive/README.md", "res://AGENTS.md"]


func _links(text: String) -> Array:
	var re := RegEx.new()
	re.compile("\\]\\(([^)#\\s]+)")
	var out := []
	for m in re.search_all(text):
		var l := m.get_string(1)
		if not (l.begins_with("http") or l.begins_with("mailto:")):
			out.append(l)
	return out


func test_relative_links_resolve() -> void:
	for d in DOCS:
		check(FileAccess.file_exists(d), d + " exists")
		var text := FileAccess.get_file_as_string(d)
		var base: String = d.get_base_dir()
		for l in _links(text):
			var p: String = base.path_join(l).simplify_path()
			check(FileAccess.file_exists(p) or DirAccess.dir_exists_absolute(p), "%s: link %s resolves" % [d.get_file(), l])


func test_nothing_links_to_the_python_prototype() -> void:
	for d in DOCS:
		if d.ends_with("fixtures/README.md"):
			continue
		for l in _links(FileAccess.get_file_as_string(d)):
			check(not l.contains("../skyrunner/"), "%s links %s" % [d.get_file(), l])


## The owner's decisions ledger (docs/DECISIONS.md, 18 Oct): every decision has a known status and a tracker, and a
## roadmap section it names exists, so a decision cannot drop out of every work list again (the uncle storyline did).
func test_every_owner_decision_is_tracked() -> void:
	var text := FileAccess.get_file_as_string("res://docs/DECISIONS.md")
	var roadmap := FileAccess.get_file_as_string("res://docs/ROADMAP.md")
	check(text != "" and roadmap != "", "both files exist")
	var rows := 0
	for line in text.split("\n"):
		if not line.begins_with("| D-"):
			continue
		rows += 1
		var cells := Array(line.split("|")).map(func(c): return str(c).strip_edges())
		var id: String = cells[1]
		var status: String = cells[4]
		var tracked: String = cells[5]
		check(status in ["planned", "in-pr", "done", "open", "superseded"], "%s: status %s" % [id, status])
		check(tracked != "", "%s: tracked somewhere" % id)
		if status in ["planned", "in-pr", "open"]:
			check(tracked.begins_with("ROADMAP: ") or tracked.contains("#"), "%s: open work needs a roadmap section or an issue/PR: %s" % [id, tracked])
		if tracked.begins_with("ROADMAP: "):
			var heading := tracked.trim_prefix("ROADMAP: ")
			check(roadmap.contains("## " + heading), "%s: the roadmap has a section '%s'" % [id, heading])
	check(rows >= 30, "the ledger has its rows (%d)" % rows)

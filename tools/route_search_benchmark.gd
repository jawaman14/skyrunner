extends SceneTree
## Compare exact path parity and isolated search timings against the historical oracle.
func _initialize() -> void:
	World.use_map(MapCity.SEED)
	var world := World.new()
	var graph := RoadGraph.new(world.map.roads)
	var oracle = load("res://tests/test_roads.gd").new()
	var linear_build := []
	var indexed_build := []
	var construction_mismatches := 0
	for i in 7:
		var start := Time.get_ticks_usec()
		var old: RoadGraph = load("res://tests/test_roads.gd").LinearNodes.new(world.map.roads)
		linear_build.append((Time.get_ticks_usec()-start)/1000.0)
		start = Time.get_ticks_usec()
		var next := RoadGraph.new(world.map.roads)
		indexed_build.append((Time.get_ticks_usec()-start)/1000.0)
		if old.nodes != next.nodes or old.adj != next.adj or old._network_edges != next._network_edges: construction_mismatches += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 2718
	var pairs := []
	for i in 100:
		pairs.append([rng.randi_range(0, graph.nodes.size() - 1), rng.randi_range(0, graph.nodes.size() - 1)])
	var linear := []
	var heap := []
	var mismatches := 0
	for pair in pairs:
		var start := Time.get_ticks_usec()
		var expected: Array = oracle._linear_path(graph, pair[0], pair[1], Callable(), Callable())
		linear.append((Time.get_ticks_usec() - start) / 1000.0)
		start = Time.get_ticks_usec()
		var actual := graph.path(pair[0], pair[1])
		heap.append((Time.get_ticks_usec() - start) / 1000.0)
		if expected != actual:
			mismatches += 1
	linear.sort()
	heap.sort()
	var result := {"map": "Costa Brava", "pairs": pairs.size(), "nodes": graph.nodes.size(), "path_mismatches": mismatches,
		"construction_runs":7,"construction_mismatches":construction_mismatches,"linear_build_mean_ms":_mean(linear_build),"indexed_build_mean_ms":_mean(indexed_build),
		"linear_mean_ms": _mean(linear), "heap_mean_ms": _mean(heap), "linear_p95_ms": linear[94], "heap_p95_ms": heap[94],
		"note": "Paired search microbenchmark, no concurrent suite; not frame-time or gameplay balance evidence."}
	print(JSON.stringify(result))
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t"))
	quit(0 if mismatches == 0 and construction_mismatches == 0 else 1)


func _mean(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()

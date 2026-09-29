extends RefCounted
## The Factory tech tree as data (scripts/tech.gd START / TREE / CUT / MAKES):
## every piece id is real, every build-bar piece is classified exactly once,
## tech needs resolve with no cycles, each tier's science can be made from
## pieces of lower tiers, and unlocked_types() follows Tech.levels.
## Logs "FAIL ..." for each broken check and "tech tree: ALL OK" if none.

const Tech = preload("res://scripts/tech.gd")
const BuildBar = preload("res://scripts/build_bar.gd")

## What each producer takes to make a kind: kind -> {BuildType: [inputs]}.
## flask_clock / flask_bronze are the planned Pass D recipes.
const INPUTS := {
	"copper": {2: []},
	"iron": {2: []},
	"copper_ingot": {75: ["copper"], 3: ["copper"]},
	"iron_ingot": {75: ["iron"], 3: ["iron"]},
	"gear": {16: ["iron_ingot", "copper_ingot"], 94: ["iron_ingot"]},
	"shot": {93: ["grit"], 16: ["iron_ingot"]},
	"grit": {92: ["copper"], 21: ["copper"]},
	"bronze": {131: ["copper_ingot", "iron_ingot"]},
	"flask": {16: ["gear", "copper_ingot"]},
	"flask_clock": {16: ["gear", "shot"]},
	"flask_bronze": {16: ["bronze"]},
}


static func run(t) -> void:
	t.main._wave_timer = -9999.0
	await t.wait(0.3)
	var fails: Array[String] = []
	var bs = t.main.get_node("/root/BuildSystem")
	var pieces: Dictionary = BuildBar.PIECES
	var pname := func(id: int) -> String:
		return String(pieces[id][1]).get_slice(" (", 0) if pieces.has(id) else "?%d" % id

	# 1. every id is a real piece
	var where := {}   # id -> ["START"/"tier N:<tech>"/"CUT", ...]
	var add := func(id: int, tag: String) -> void:
		if not where.has(id):
			where[id] = []
		where[id].append(tag)
	for id in Tech.START:
		add.call(int(id), "START")
	for tt in Tech.TREE:
		for id in tt.unlocks:
			add.call(int(id), "tier %d:%s" % [tt.tier, tt.id])
	for id in Tech.CUT:
		add.call(int(id), "CUT")
	for id in where:
		if not bs._scenes.has(id):
			fails.append("id %d not in BuildSystem._scenes" % id)
		if not pieces.has(id):
			fails.append("id %d not in build_bar PIECES" % id)

	# 2. every piece classified exactly once
	for id in pieces:
		if not where.has(id):
			fails.append("unclassified: %d %s" % [id, pname.call(id)])
		elif where[id].size() > 1:
			fails.append("classified %dx: %d %s %s" % [where[id].size(), id, pname.call(id), where[id]])
	for id in bs._scenes:
		if not pieces.has(int(id)):
			fails.append("scene %d has no build_bar PIECES entry" % id)
	t.log_line("pieces: %d in PIECES, %d in _scenes, %d classified" % [pieces.size(), bs._scenes.size(), where.size()])

	# 3. tech ids unique, not clashing with upgrade TECHS; needs exist; no cycles
	var ids := {}
	for tt in Tech.TREE:
		if ids.has(tt.id):
			fails.append("duplicate tree id %s" % tt.id)
		ids[tt.id] = tt
		if not Tech.info(tt.id).is_empty():
			fails.append("tree id %s clashes with an upgrade TECHS id" % tt.id)
		for k in ["id", "name", "tier", "needs", "cost", "unlocks", "desc"]:
			if not tt.has(k):
				fails.append("%s missing %s" % [tt.id, k])
	for tt in Tech.TREE:
		for n in tt.needs:
			if not ids.has(n):
				fails.append("%s needs unknown %s" % [tt.id, n])
			elif int(ids[n].tier) > int(tt.tier):
				fails.append("%s (tier %d) needs higher-tier %s" % [tt.id, tt.tier, n])
	var state := {}   # 1 visiting, 2 done
	var visit := func(self_ref: Callable, id: String, path: Array) -> void:
		if state.get(id, 0) == 2 or not ids.has(id):
			return
		if state.get(id, 0) == 1:
			fails.append("cycle: %s" % " -> ".join(path + [id]))
			return
		state[id] = 1
		for n in ids[id].needs:
			self_ref.call(self_ref, n, path + [id])
		state[id] = 2
	for id in ids:
		visit.call(visit, id, [])

	# 4. MAKES agrees with the producer table; each tier's science is
	# reachable from START plus strictly lower tiers
	for kind in INPUTS:
		var mk: Array = Tech.MAKES.get(kind, [])
		for p in INPUTS[kind]:
			if not mk.has(p):
				fails.append("MAKES[%s] lacks producer %d" % [kind, p])
		for p in mk:
			if not INPUTS[kind].has(p):
				fails.append("MAKES[%s] has %d with no recipe in the test" % [kind, p])
	var tier_of := {}
	for id in Tech.START:
		tier_of[int(id)] = 0
	for tt in Tech.TREE:
		for id in tt.unlocks:
			tier_of[int(id)] = int(tt.tier)
	var reach := func(self_ref: Callable, kind: String, max_tier: int, seen: Array) -> bool:
		if seen.has(kind):
			return false
		for p in INPUTS.get(kind, {}):
			if tier_of.get(p, 99) > max_tier:
				continue
			var ok := true
			for i in INPUTS[kind][p]:
				if not self_ref.call(self_ref, i, max_tier, seen + [kind]):
					ok = false
					break
			if ok:
				return true
		return false
	var max_tier := 0
	for tt in Tech.TREE:
		max_tier = maxi(max_tier, int(tt.tier))
	for tier in range(1, max_tier + 1):
		var kinds := {}
		for tt in Tech.TREE:
			if int(tt.tier) == tier:
				for k in Tech.cost_of(tt):
					kinds[k] = true
		for k in kinds:
			var ok: bool = reach.call(reach, k, tier - 1, [])
			t.log_line("tier %d science %s: makeable from tier <= %d: %s" % [tier, k, tier - 1, ok])
			if not ok:
				fails.append("tier %d science %s unreachable from lower tiers" % [tier, k])
	# the intended chains, not just any route: shot for clockwork flasks from
	# the pellet press line, bronze from the crucible
	for need in [[92, 1, "grindstone"], [93, 1, "pellet press"], [131, 2, "crucible"]]:
		if tier_of.get(need[0], 99) > need[1]:
			fails.append("%s is tier %s, must be <= %d" % [need[2], tier_of.get(need[0], "CUT"), need[1]])

	# 5. unlocked_types / researched / available / cost_of against Tech.levels
	var saved: Dictionary = Tech.levels.duplicate()
	Tech.levels = {}
	var base: Array = Tech.unlocked_types()
	if base.size() != Tech.START.size() or not base.all(func(x): return Tech.START.has(x)):
		fails.append("unlocked_types() with nothing researched %s != START" % [base])
	if Tech.available("forging"):
		fails.append("forging available with nothing researched")
	if not Tech.available("routing"):
		fails.append("routing (no needs) not available")
	for tt in Tech.TREE:
		if int(tt.tier) == 1:
			Tech.levels[tt.id] = 1
	var t1: Array = Tech.unlocked_types()
	for tt in Tech.TREE:
		for id in tt.unlocks:
			var want: bool = int(tt.tier) == 1
			if t1.has(id) != want:
				fails.append("after tier 1: %d %s unlocked=%s" % [id, pname.call(id), t1.has(id)])
	if not Tech.available("forging") or Tech.available("beam_optics"):
		fails.append("after tier 1: forging available %s, beam_optics %s" % [Tech.available("forging"), Tech.available("beam_optics")])
	t.log_line("unlocked: %d with nothing, %d after all tier 1" % [base.size(), t1.size()])
	Tech.levels = saved
	if Tech.cost_of(Tech.TECHS[0]) != {"flask": int(Tech.TECHS[0].cost)}:
		fails.append("cost_of(TECHS[0]) = %s" % Tech.cost_of(Tech.TECHS[0]))
	if Tech.tree_tech("nope") != {} or Tech.tree_tech("routing").get("name") != "Routing":
		fails.append("tree_tech lookup")

	# summary
	t.log_line("START (%d): %s" % [Tech.START.size(), ", ".join(Tech.START.map(func(i): return pname.call(i)))])
	for tier in range(1, max_tier + 1):
		var n := 0
		for tt in Tech.TREE:
			if int(tt.tier) == tier:
				n += tt.unlocks.size()
		t.log_line("TIER %d: %d pieces" % [tier, n])
		for tt in Tech.TREE:
			if int(tt.tier) == tier:
				t.log_line("  %s %s (%d): %s" % [tt.name, Tech.cost_of(tt), tt.unlocks.size(), ", ".join(tt.unlocks.map(func(i): return pname.call(i)))])
	t.log_line("CUT (%d): %s" % [Tech.CUT.size(), ", ".join(Tech.CUT.map(func(i): return pname.call(i)))])
	for f in fails:
		t.log_line("FAIL %s" % f)
	t.log_line("tech tree: %s" % ("ALL OK" if fails.is_empty() else "%d FAILED" % fails.size()))

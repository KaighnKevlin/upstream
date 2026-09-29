extends RefCounted
## TrackFork: the junction a marble piece makes on the track net when a
## track's open end sits at its mouth (a chute ending over a rocker's
## funnel, at a magnet drum's face): the piece then routes the riders
## natively, by the net's junction pick() (scripts/track/track_net.gd),
## instead of the riders flying off the end and the piece sorting physics
## bodies. A queue it can't send on waits on the feeding track, so
## backpressure runs back through it; its rate is what pick() allows.
##
## The piece says where its mouth is (a local rect a feeding end may lie
## in) and, given the feeding end, the paths to make: fork_paths(src,
## tangent) -> {"feed": path from src to where the branches start (or none:
## they start at src itself), "branches": [path, path, ...], "open": [bool,
## ...] (a branch whose end never feeds track: the piece takes its riders
## there as physics), "feed_vcap": the speed the feed lets a rider keep (a
## funnel or a landing that soaks up the drop)}. It implements
## pick(kind, free) and passed(i, kind), and rider_released(track, body)
## for a rider flying off a branch's open end as physics ore.
##
## update() every physics tick: every half second it looks for a feeding
## end (so a chute laid, moved or removed later is followed). With none,
## the piece has no tracks and works on physics ore alone, as it always did.

const TrackNet = preload("res://scripts/track/track_net.gd")
const EVERY := 30

var piece: Node2D
var mouth: Rect2                 # local to the piece
var net: Node = null
var feed = null                  # its feed track (scripts/track/track.gd), or null
var branches: Array = []
var src := Vector2.INF           # the feeding end it's built on
var src_track = null
var _t := 0


func _init(p: Node2D, mouth_rect: Rect2) -> void:
	piece = p
	mouth = mouth_rect


func linked() -> bool:
	return not branches.is_empty()


func update() -> void:
	_t -= 1
	if linked() and (not is_instance_valid(net) or not net.tracks.has(branches[0])):
		_forget()                # the net retired under it
	if _t > 0:
		return
	_t = EVERY
	relink()


func relink() -> void:
	if piece == null or not piece.is_inside_tree():
		return
	var n: Node = TrackNet.find_net(piece)
	if n != net:
		teardown()
		net = n
	if net == null:
		return
	var box := Rect2(piece.global_position + mouth.position, mouth.size)
	var hit: Array = net.open_end_in(box, piece)
	if hit.is_empty():
		teardown()
		return
	if linked() and hit[0] == src_track and (hit[1] as Vector2).distance_to(src) < 0.5:
		return
	teardown()
	_build(hit[0], hit[1])


func _build(tr, at: Vector2) -> void:
	var last: int = tr.tan.size() - 1
	var paths: Dictionary = piece.fork_paths(at, tr.tan[last])
	src = at
	src_track = tr
	var open: Array = paths.get("open", [])
	for i in paths.branches.size():
		var b = net.add_track(piece, paths.branches[i], false)
		b.lip_mode = 0
		b.ends_open = i < open.size() and open[i]
		branches.append(b)
	var fp: PackedVector2Array = paths.get("feed", PackedVector2Array())
	if fp.size() >= 2:
		feed = net.add_track(piece, fp, false)
		feed.lip_mode = 0
		feed.vcap = paths.get("feed_vcap", 0.0)


## Its tracks go (riders on them fly off as physics ore).
func teardown() -> void:
	if is_instance_valid(net):
		for b in branches:
			net.remove_track(b)
		if feed != null:
			net.remove_track(feed)
	_forget()


func _forget() -> void:
	branches.clear()
	feed = null
	src = Vector2.INF
	src_track = null


## Which branch a track is (-1: not one of them).
func branch_index(tr) -> int:
	return branches.find(tr)

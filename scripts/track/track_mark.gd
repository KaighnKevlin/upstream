extends RefCounted
## TrackMark: a point on a track where a piece acts on the riders going by
## (scripts/track/track_net.gd, marks), for pieces set across or over a
## chute rather than on its end: a gate that holds the queue (escapement,
## sluice, check valve) or a counter that reads what passes (tally wheel,
## speed trap). No zone: the riders stay riders, the queue behind a shut
## gate is the track's own queue (backpressure all the way up the line),
## and what passes is counted exactly, once.
##
## The piece makes one with the point it acts at (local) and how far below
## / above that point the rail may run, calls update() every physics tick
## (it finds the track under the point every half second, so a chute laid
## or dragged later is picked up), and sets gate(fwd, back): fwd -1 open,
## 0 shut, n let n more by; back: whether riders rolling back pass. The net
## tells the piece mark_event(mark, kind, v, ev): ev 1 passed forward, -1
## passed back, 2 stopped going forward, -2 stopped going back.
##
## Where no track runs under the point (a physics-only chute, nothing laid
## yet) the piece keeps working on physics ore as before; watching() says
## which, for its ore_watch() (a zone round it only while it isn't linked).

const TrackNet = preload("res://scripts/track/track_net.gd")
const EVERY := 30                # ticks between looks for the track under it

var piece: Node2D
var at := Vector2.ZERO           # the point it acts at, local to the piece
var up := 8.0                    # the rail may run this far above the point
var down := 12.0                 # or this far below it
var net: Node = null
var m = null                     # the net's mark (a Dictionary), when linked
var _fwd := -1
var _back := true
var _t := 0


func _init(p: Node2D, point: Vector2, reach_up: float, reach_down: float) -> void:
	piece = p
	at = point
	up = reach_up
	down = reach_down


## Every physics tick: relink now and then; keeps the gate state applied.
func update() -> void:
	_t -= 1
	if m != null and (not is_instance_valid(net) or not net.tracks.has(m.track)):
		m = null                 # its track went (the chute removed, the net retired)
	if _t > 0:
		return
	_t = EVERY
	relink()


func relink() -> void:
	if piece == null or not piece.is_inside_tree():
		return
	var n: Node = TrackNet.find_net(piece)
	if n != net:
		drop()
		net = n
	if net == null:
		return
	var hit: Array = net.mark_at(piece.global_position + at, up, down, piece)
	if hit.is_empty():
		drop()
		return
	if m != null and m.track == hit[0] and absf(m.s - float(hit[1])) < 0.5:
		return
	drop()
	m = net.add_mark(hit[0], hit[1], piece)
	m.fwd = _fwd
	m.back = _back


func drop() -> void:
	if m != null and is_instance_valid(net):
		net.remove_mark(m)
	m = null


func linked() -> bool:
	return m != null


## fwd: -1 open, 0 shut, n let n more by. back: riders rolling back pass.
func gate(fwd: int, back := true) -> void:
	_fwd = fwd
	_back = back
	if m != null:
		m.fwd = fwd
		m.back = back


## How many more it lets by (-1: open), as the net left it.
func fwd() -> int:
	return m.fwd if m != null else _fwd


## The queue held at the point: the riders nose to tail behind it, the
## first within `reach` px of it.
func queued(reach: float) -> int:
	if m == null:
		return 0
	var tr = m.track
	var n := 0
	var edge: float = m.s               # where the next one back has to touch
	var i: int = tr.count() - 1
	while i >= 0 and tr.rs[i] > m.s:
		i -= 1
	while i >= 0:
		var r: float = net.KR[tr.rkind[i]]
		var gap: float = edge - (tr.rs[i] + r)
		if gap > (reach if n == 0 else 3.0):
			break
		n += 1
		edge = tr.rs[i] - r
		i -= 1
	return n


## The rider nearest in front of the point, held against it: its index, or -1.
func front() -> int:
	if m == null:
		return -1
	var tr = m.track
	var i: int = tr.count() - 1
	while i >= 0:
		if tr.rs[i] < m.s:
			return i if tr.rs[i] > m.s - net.KR[tr.rkind[i]] - 3.0 else -1
		i -= 1
	return -1


## The piece's rects for the net's zones: none while linked (it reads the
## riders), the old watch round the piece otherwise (physics ore there).
func watching(r := 40.0) -> Array:
	if m != null:
		return []
	var c := piece.global_position
	return [Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)]

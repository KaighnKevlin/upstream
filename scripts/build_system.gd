extends Node

enum BuildType { NONE, TRAMPOLINE, MINER, LASER, UPSTREAM, HOPPER, TURRET, SPIKES, CATAPULT, CHUTE, SPLITTER, BUMPER, BELT, BELLOWS, PENDULUM, WHEEL, ASSEMBLER, LAB, TESLA, FLAMER, TRAPDOOR, CRUSHER, MAGNET, HARPOON, SEESAW, TUBE, KEG, SNARE, TRIPWIRE, PLATE, BORER, LANTERN, SENTRY, TIMER, DOCK, BARRICADE, ENGINE, DOMINOES, TAP, ROCKER, ESCAPEMENT, BUCKET, SIEVE, SCREW, ARM, STAIRS, FERRIS, JUMP, BELL, LOOP, DISPENSER, GOAL, SCALE, CANNON, FELT, CHIME, PLUNGER, VORTEX, FLAPS, OVERFLOW, DEFLECTOR, BOOSTER, NET, DRUM, SLUICE, TALLY, POINTS, BRAKE, TEETER, CROSSOVER, FLYWHEEL, DISTRIBUTOR, FLIPPER, COUNTERWEIGHT, PAIR, FURNACE, SILO, ROPEWAY, LOADCELL, TURN, GAUSS, TREAD, TREBUCHET, PADDLE, MAT, KICKER, TIPTUBE, HAMMER, VOLCANO, BOWLING, GRAPESHOT, STAMP, GRINDSTONE, PELLET, GEARSTAMP, HELIX, DRAWBRIDGE, TRANSFER, LATCH, DELAY, HUB, LISTENER, PLATING, STEAMJET, TROMMEL, DICE, FLOWMETER, CHECKVALVE, MINECART, POPBUMPER, SPEEDTRAP, SLING, IGNITER, SPINNER, GABION, MAGRAIL, ROPEBRIDGE, BALLOON, FLAIL, FLUME, WRECKBALL, SPRINGTRAP, BOWLFEEDER, WATERWHEEL, BALANCE, HOURGLASS, CALTROPS, PANNING }

var current_build: BuildType = BuildType.NONE
var _ghost: Node2D = null
var _placed_buildings: Array[Node2D] = []
var ui_rects: Array[Callable] = []   # screen rects (HUD) that clicks don't build/remove through

var _scenes := {
	BuildType.TRAMPOLINE: preload("res://scenes/trampoline.tscn"),
	BuildType.MINER: preload("res://scenes/miner.tscn"),
	BuildType.LASER: preload("res://scenes/laser_smelter.tscn"),
	BuildType.UPSTREAM: preload("res://scenes/upstream_shaft.tscn"),
	BuildType.HOPPER: preload("res://scenes/hopper.tscn"),
	BuildType.TURRET: preload("res://scenes/funnel_turret.tscn"),
	BuildType.SPIKES: preload("res://scenes/spikes.tscn"),
	BuildType.CATAPULT: preload("res://scenes/catapult.tscn"),
	BuildType.CHUTE: preload("res://scenes/chute.tscn"),
	BuildType.SPLITTER: preload("res://scenes/splitter.tscn"),
	BuildType.BUMPER: preload("res://scenes/bumper.tscn"),
	BuildType.BELT: preload("res://scenes/belt.tscn"),
	BuildType.BELLOWS: preload("res://scenes/bellows.tscn"),
	BuildType.PENDULUM: preload("res://scenes/pendulum.tscn"),
	BuildType.WHEEL: preload("res://scenes/gravity_wheel.tscn"),
	BuildType.ASSEMBLER: preload("res://scenes/assembler.tscn"),
	BuildType.LAB: preload("res://scenes/lab.tscn"),
	BuildType.TESLA: preload("res://scenes/tesla.tscn"),
	BuildType.FLAMER: preload("res://scenes/flamer.tscn"),
	BuildType.TRAPDOOR: preload("res://scenes/trapdoor.tscn"),
	BuildType.CRUSHER: preload("res://scenes/crusher.tscn"),
	BuildType.MAGNET: preload("res://scenes/magnet.tscn"),
	BuildType.HARPOON: preload("res://scenes/harpoon.tscn"),
	BuildType.SEESAW: preload("res://scenes/seesaw.tscn"),
	BuildType.TUBE: preload("res://scenes/tube.tscn"),
	BuildType.KEG: preload("res://scenes/keg.tscn"),
	BuildType.SNARE: preload("res://scenes/snare.tscn"),
	BuildType.TRIPWIRE: preload("res://scenes/tripwire.tscn"),
	BuildType.PLATE: preload("res://scenes/plate.tscn"),
	BuildType.BORER: preload("res://scenes/borer.tscn"),
	BuildType.LANTERN: preload("res://scenes/lantern.tscn"),
	BuildType.SENTRY: preload("res://scenes/sentry.tscn"),
	BuildType.TIMER: preload("res://scenes/timer.tscn"),
	BuildType.DOCK: preload("res://scenes/dock.tscn"),
	BuildType.BARRICADE: preload("res://scenes/barricade.tscn"),
	BuildType.ENGINE: preload("res://scenes/steam_engine.tscn"),
	BuildType.DOMINOES: preload("res://scenes/dominoes.tscn"),
	BuildType.TAP: preload("res://scenes/beam_tap.tscn"),
	BuildType.ROCKER: preload("res://scenes/rocker.tscn"),
	BuildType.ESCAPEMENT: preload("res://scenes/escapement.tscn"),
	BuildType.BUCKET: preload("res://scenes/tipping_bucket.tscn"),
	BuildType.SIEVE: preload("res://scenes/sieve.tscn"),
	BuildType.SCREW: preload("res://scenes/screw.tscn"),
	BuildType.ARM: preload("res://scenes/arm.tscn"),
	BuildType.STAIRS: preload("res://scenes/stair_lift.tscn"),
	BuildType.FERRIS: preload("res://scenes/ferris_lift.tscn"),
	BuildType.JUMP: preload("res://scenes/jump.tscn"),
	BuildType.BELL: preload("res://scenes/bell.tscn"),
	BuildType.LOOP: preload("res://scenes/loop.tscn"),
	BuildType.DISPENSER: preload("res://scenes/dispenser.tscn"),
	BuildType.GOAL: preload("res://scenes/goal_cup.tscn"),
	BuildType.SCALE: preload("res://scenes/weigh_scale.tscn"),
	BuildType.CANNON: preload("res://scenes/cannon.tscn"),
	BuildType.FELT: preload("res://scenes/felt_chute.tscn"),
	BuildType.CHIME: preload("res://scenes/chime.tscn"),
	BuildType.PLUNGER: preload("res://scenes/plunger.tscn"),
	BuildType.VORTEX: preload("res://scenes/vortex.tscn"),
	BuildType.FLAPS: preload("res://scenes/flap_sorter.tscn"),
	BuildType.OVERFLOW: preload("res://scenes/overflow_gate.tscn"),
	BuildType.DEFLECTOR: preload("res://scenes/deflector.tscn"),
	BuildType.BOOSTER: preload("res://scenes/booster.tscn"),
	BuildType.NET: preload("res://scenes/catch_net.tscn"),
	BuildType.DRUM: preload("res://scenes/magnet_drum.tscn"),
	BuildType.SLUICE: preload("res://scenes/sluice.tscn"),
	BuildType.TALLY: preload("res://scenes/tally.tscn"),
	BuildType.POINTS: preload("res://scenes/points.tscn"),
	BuildType.BRAKE: preload("res://scenes/brake.tscn"),
	BuildType.TEETER: preload("res://scenes/teeter.tscn"),
	BuildType.CROSSOVER: preload("res://scenes/crossover.tscn"),
	BuildType.FLYWHEEL: preload("res://scenes/flywheel.tscn"),
	BuildType.DISTRIBUTOR: preload("res://scenes/distributor.tscn"),
	BuildType.FLIPPER: preload("res://scenes/flipper.tscn"),
	BuildType.COUNTERWEIGHT: preload("res://scenes/counterweight.tscn"),
	BuildType.PAIR: preload("res://scenes/pair_gate.tscn"),
	BuildType.FURNACE: preload("res://scenes/furnace_rail.tscn"),
	BuildType.SILO: preload("res://scenes/silo.tscn"),
	BuildType.ROPEWAY: preload("res://scenes/ropeway.tscn"),
	BuildType.LOADCELL: preload("res://scenes/load_cell.tscn"),
	BuildType.TURN: preload("res://scenes/banked_turn.tscn"),
	BuildType.GAUSS: preload("res://scenes/gauss.tscn"),
	BuildType.TREAD: preload("res://scenes/treadwheel.tscn"),
	BuildType.TREBUCHET: preload("res://scenes/trebuchet.tscn"),
	BuildType.PADDLE: preload("res://scenes/paddle_wheel.tscn"),
	BuildType.MAT: preload("res://scenes/bearing_mat.tscn"),
	BuildType.KICKER: preload("res://scenes/kicker.tscn"),
	BuildType.TIPTUBE: preload("res://scenes/tiptube.tscn"),
	BuildType.HAMMER: preload("res://scenes/hammer.tscn"),
	BuildType.VOLCANO: preload("res://scenes/volcano.tscn"),
	BuildType.BOWLING: preload("res://scenes/bowling_ramp.tscn"),
	BuildType.GRAPESHOT: preload("res://scenes/grapeshot_mortar.tscn"),
	BuildType.STAMP: preload("res://scenes/stamp_press.tscn"),
	BuildType.GRINDSTONE: preload("res://scenes/grindstone.tscn"),
	BuildType.PELLET: preload("res://scenes/pellet_press.tscn"),
	BuildType.GEARSTAMP: preload("res://scenes/gear_stamp.tscn"),
	BuildType.HELIX: preload("res://scenes/helix.tscn"),
	BuildType.DRAWBRIDGE: preload("res://scenes/drawbridge.tscn"),
	BuildType.TRANSFER: preload("res://scenes/transfer_arm.tscn"),
	BuildType.LATCH: preload("res://scenes/latch.tscn"),
	BuildType.DELAY: preload("res://scenes/delay_relay.tscn"),
	BuildType.HUB: preload("res://scenes/relay_hub.tscn"),
	BuildType.LISTENER: preload("res://scenes/ground_listener.tscn"),
	BuildType.PLATING: preload("res://scenes/iron_plating.tscn"),
	BuildType.STEAMJET: preload("res://scenes/steam_jet.tscn"),
	BuildType.TROMMEL: preload("res://scenes/trommel.tscn"),
	BuildType.DICE: preload("res://scenes/dice_box.tscn"),
	BuildType.FLOWMETER: preload("res://scenes/flow_meter.tscn"),
	BuildType.CHECKVALVE: preload("res://scenes/check_valve.tscn"),
	BuildType.MINECART: preload("res://scenes/mine_cart.tscn"),
	BuildType.POPBUMPER: preload("res://scenes/pop_bumper.tscn"),
	BuildType.SPEEDTRAP: preload("res://scenes/speed_trap.tscn"),
	BuildType.SLING: preload("res://scenes/sling.tscn"),
	BuildType.IGNITER: preload("res://scenes/igniter.tscn"),
	BuildType.SPINNER: preload("res://scenes/spinner.tscn"),
	BuildType.GABION: preload("res://scenes/gabion.tscn"),
	BuildType.MAGRAIL: preload("res://scenes/magnet_rail.tscn"),
	BuildType.ROPEBRIDGE: preload("res://scenes/rope_bridge.tscn"),
	BuildType.BALLOON: preload("res://scenes/balloon_lift.tscn"),
	BuildType.FLAIL: preload("res://scenes/flail.tscn"),
	BuildType.FLUME: preload("res://scenes/flume.tscn"),
	BuildType.WRECKBALL: preload("res://scenes/wrecking_ball.tscn"),
	BuildType.SPRINGTRAP: preload("res://scenes/spring_trap.tscn"),
	BuildType.BOWLFEEDER: preload("res://scenes/bowl_feeder.tscn"),
	BuildType.WATERWHEEL: preload("res://scenes/water_wheel.tscn"),
	BuildType.BALANCE: preload("res://scenes/balance.tscn"),
	BuildType.HOURGLASS: preload("res://scenes/hourglass.tscn"),
	BuildType.CALTROPS: preload("res://scenes/caltrop_spreader.tscn"),
	BuildType.PANNING: preload("res://scenes/panning_box.tscn"),
}

var _ghost_colors := {
	BuildType.TRAMPOLINE: Color(0.2, 0.85, 0.3, 0.4),
	BuildType.MINER: Color(0.3, 0.3, 0.8, 0.4),
	BuildType.LASER: Color(1.0, 0.2, 0.1, 0.4),
	BuildType.UPSTREAM: Color(0.3, 0.5, 1.0, 0.4),
	BuildType.HOPPER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.TURRET: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.SPIKES: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.CATAPULT: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.CHUTE: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.SPLITTER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.BUMPER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.BELT: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.BELLOWS: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.PENDULUM: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.WHEEL: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.ASSEMBLER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.LAB: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.TESLA: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.FLAMER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.TRAPDOOR: Color(1.0, 0.85, 0.5, 0.6),
	BuildType.CRUSHER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.MAGNET: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.HARPOON: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.SEESAW: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.TUBE: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.KEG: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.SNARE: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.TRIPWIRE: Color(1.0, 0.85, 0.5, 0.7),
	BuildType.PLATE: Color(1.0, 0.85, 0.5, 0.6),
	BuildType.BORER: Color(1.0, 0.85, 0.5, 0.5),
	BuildType.LANTERN: Color(1.0, 0.85, 0.5, 0.7),
	BuildType.SENTRY: Color(0.7, 0.95, 1.0, 0.6),
	BuildType.TIMER: Color(1.0, 0.85, 0.5, 0.6),
	BuildType.DOCK: Color(0.7, 0.95, 1.0, 0.6),
	BuildType.BARRICADE: Color(1.0, 0.85, 0.5, 0.6),
	BuildType.ENGINE: Color(1.0, 0.85, 0.5, 0.6),
	BuildType.DOMINOES: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.TAP: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.ROCKER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.ESCAPEMENT: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.BUCKET: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.SIEVE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.SCREW: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.ARM: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.STAIRS: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.FERRIS: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.JUMP: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.BELL: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.LOOP: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.DISPENSER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.GOAL: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.SCALE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.CANNON: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.FELT: Color(0.6, 1.0, 0.7, 0.8),
	BuildType.CHIME: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.PLUNGER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.VORTEX: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.FLAPS: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.OVERFLOW: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.DEFLECTOR: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.BOOSTER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.NET: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.DRUM: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.SLUICE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.TALLY: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.POINTS: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.BRAKE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.TEETER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.CROSSOVER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.FLYWHEEL: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.DISTRIBUTOR: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.FLIPPER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.COUNTERWEIGHT: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.PAIR: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.FURNACE: Color(1.0, 0.7, 0.4, 0.8),
	BuildType.SILO: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.ROPEWAY: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.LOADCELL: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.TURN: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.GAUSS: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.TREAD: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.TREBUCHET: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.PADDLE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.MAT: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.KICKER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.TIPTUBE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.HAMMER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.VOLCANO: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.BOWLING: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.GRAPESHOT: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.STAMP: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.GRINDSTONE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.PELLET: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.GEARSTAMP: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.HELIX: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.DRAWBRIDGE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.TRANSFER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.LATCH: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.DELAY: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.HUB: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.LISTENER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.PLATING: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.STEAMJET: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.TROMMEL: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.DICE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.FLOWMETER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.CHECKVALVE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.MINECART: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.POPBUMPER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.SPEEDTRAP: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.SLING: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.IGNITER: Color(1.0, 0.6, 0.3, 0.8),
	BuildType.SPINNER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.GABION: Color(0.7, 0.72, 0.8, 0.8),
	BuildType.MAGRAIL: Color(0.6, 0.75, 1.0, 0.8),
	BuildType.ROPEBRIDGE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.BALLOON: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.FLAIL: Color(0.7, 0.72, 0.8, 0.8),
	BuildType.FLUME: Color(0.5, 0.75, 1.0, 0.8),
	BuildType.WRECKBALL: Color(0.7, 0.72, 0.8, 0.8),
	BuildType.SPRINGTRAP: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.BOWLFEEDER: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.WATERWHEEL: Color(0.5, 0.75, 1.0, 0.8),
	BuildType.BALANCE: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.HOURGLASS: Color(1.0, 0.85, 0.5, 0.8),
	BuildType.CALTROPS: Color(0.6, 0.7, 0.75, 0.8),
	BuildType.PANNING: Color(0.5, 0.75, 1.0, 0.8),
}

signal build_mode_changed(build_type: BuildType)


func _input(event: InputEvent) -> void:
	# Number keys to select build type
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_set_build(BuildType.TRAMPOLINE)
			KEY_2:
				_set_build(BuildType.MINER)
			KEY_3:
				_set_build(BuildType.LASER)
			KEY_4:
				_set_build(BuildType.UPSTREAM)
			KEY_5:
				_set_build(BuildType.HOPPER)
			KEY_6:
				_set_build(BuildType.TURRET)
			KEY_7:
				_set_build(BuildType.SPIKES)
			KEY_8:
				_set_build(BuildType.CATAPULT)
			KEY_9:
				_set_build(BuildType.CHUTE)
			KEY_0:
				_set_build(BuildType.SPLITTER)
			KEY_B:
				_set_build(BuildType.BUMPER)
			KEY_C:
				_set_build(BuildType.BELT)
			KEY_V:
				_set_build(BuildType.BELLOWS)
			KEY_M:
				_set_build(BuildType.PENDULUM)
			KEY_N:
				_set_build(BuildType.WHEEL)
			KEY_T:
				_set_build(BuildType.ASSEMBLER)
			KEY_Y:
				_set_build(BuildType.LAB)
			KEY_U:
				_set_build(BuildType.TESLA)
			KEY_I:
				_set_build(BuildType.FLAMER)
			KEY_X:
				_set_build(BuildType.TRAPDOOR)
			KEY_R:
				_set_build(BuildType.CRUSHER)
			KEY_Z:
				_set_build(BuildType.MAGNET)
			KEY_ESCAPE, KEY_Q:
				_set_build(BuildType.NONE)

	# Chutes and belts are drawn: press at the top end, drag, release at the other end
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _drag_from != null:
		_place_chute(_drag_from, _get_world_mouse_pos() - _drag_from)
		_drag_from = null
		get_viewport().set_input_as_handled()
		return

	# Place building on click
	if event is InputEventMouseButton and event.pressed:
		for r in ui_rects:
			if (r.call() as Rect2).has_point(event.position):
				return  # the HUD handles it
		if event.button_index == MOUSE_BUTTON_LEFT and current_build in [BuildType.CHUTE, BuildType.BELT, BuildType.TUBE, BuildType.TRIPWIRE, BuildType.DOMINOES, BuildType.SIEVE, BuildType.SCREW, BuildType.JUMP, BuildType.FELT, BuildType.CHIME, BuildType.FLAPS, BuildType.BOOSTER, BuildType.BRAKE, BuildType.FURNACE, BuildType.ROPEWAY, BuildType.PLATING, BuildType.TROMMEL, BuildType.MINECART, BuildType.MAGRAIL, BuildType.ROPEBRIDGE, BuildType.FLUME]:
			var at := _get_world_mouse_pos()
			if _can_place(at):
				_drag_from = at
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and current_build != BuildType.NONE:
			_place_building()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_remove_building_at_mouse()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _ghost != null and _drag_from != null:
		# drawing a chute: the ghost's top stays put, its end follows the mouse
		_ghost.global_position = _drag_from
		var off: Vector2 = _get_world_mouse_pos() - _drag_from
		if off.length() >= DRAG_MIN:
			_ghost.set_end(off)
		return
	if _ghost != null:
		var pos := _get_world_mouse_pos()
		_ghost.global_position = _ghost.snap_pos(pos) if _ghost.has_method("snap_pos") else pos

		# Show red ghost if placement is invalid
		var valid := _can_place(pos)
		_ghost.modulate = _ghost_colors[current_build] if valid else Color(1.0, 0.2, 0.2, 0.4)


var _drag_from = null   # Vector2 while a chute is being drawn
const DRAG_MIN := 12.0


func _place_chute(from: Vector2, off: Vector2) -> void:
	var building: Node2D = _scenes[current_build].instantiate()
	building.global_position = from
	if off.length() >= DRAG_MIN:  # a plain click keeps the default slope
		building.end_offset = off.normalized() * clampf(off.length(), building.LEN_MIN, building.LEN_MAX)
	get_tree().current_scene.add_child(building)
	_placed_buildings.append(building)
	if _ghost:
		_ghost.set_end(building.end_offset)  # next one starts from the same shape


func _set_build(build_type: BuildType) -> void:
	_drag_from = null
	current_build = build_type
	build_mode_changed.emit(build_type)

	# Remove old ghost
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null

	# Create ghost preview
	if build_type != BuildType.NONE:
		_ghost = _scenes[build_type].instantiate()
		_ghost.set_meta("ghost", true)  # buildings skip physics setup for ghosts
		_ghost.modulate = _ghost_colors[build_type]
		# Disable all processing on ghost
		_ghost.set_physics_process(false)
		_ghost.set_process(false)
		# Disable collisions on ghost children
		_disable_collisions(_ghost)
		get_tree().current_scene.add_child(_ghost)


func _can_place(pos: Vector2) -> bool:
	var tilemap := _get_tilemap()

	if current_build == BuildType.MINER:
		# Tappers: on an ore block whose top face is dug out (the rig sits above it)
		if tilemap:
			var tile_pos := tilemap.local_to_map(tilemap.to_local(pos))
			if tilemap.get_cell_source_id(tile_pos) == -1:
				return false
			var atlas_coords := tilemap.get_cell_atlas_coords(tile_pos)
			if atlas_coords.x != 2 and atlas_coords.x != 3:
				return false
			if tilemap.get_cell_source_id(tile_pos + Vector2i(0, -1)) != -1:
				return false
	elif current_build == BuildType.TRAPDOOR:
		# over a pit: the cell and the one below it open
		if tilemap:
			var tile_pos := tilemap.local_to_map(tilemap.to_local(pos))
			if tilemap.get_cell_source_id(tile_pos) != -1 or tilemap.get_cell_source_id(tile_pos + Vector2i(0, 1)) != -1:
				return false
	elif current_build in [BuildType.SPIKES, BuildType.CATAPULT, BuildType.BUMPER, BuildType.ASSEMBLER, BuildType.LAB, BuildType.TESLA, BuildType.FLAMER, BuildType.CRUSHER, BuildType.HARPOON, BuildType.SEESAW, BuildType.KEG, BuildType.SNARE, BuildType.PLATE, BuildType.BORER, BuildType.SENTRY, BuildType.TIMER, BuildType.DOCK, BuildType.BARRICADE, BuildType.ENGINE]:
		# on a floor: empty cell with solid ground just below
		if tilemap:
			var tile_pos := tilemap.local_to_map(tilemap.to_local(pos))
			if tilemap.get_cell_source_id(tile_pos) != -1:
				return false
			if tilemap.get_cell_source_id(tile_pos + Vector2i(0, 1)) == -1:
				return false
	else:
		# Trampolines and lasers: must be in empty space (no solid tile)
		if tilemap:
			var tile_pos := tilemap.local_to_map(tilemap.to_local(pos))
			var source_id := tilemap.get_cell_source_id(tile_pos)
			if source_id != -1:
				return false

	# Check overlap with existing buildings
	for building in _placed_buildings:
		if not is_instance_valid(building):
			continue
		if building.global_position.distance_to(pos) < 30:
			return false

	return true


func _place_building() -> void:
	var pos := _get_world_mouse_pos()
	if current_build == BuildType.UPSTREAM:
		# on top of a lift: it grows instead
		var lift := _lift_below(pos)
		if lift:
			lift.extend()
			return
	if not _can_place(pos):
		return

	var building: Node2D = _scenes[current_build].instantiate()
	building.global_position = pos
	get_tree().current_scene.add_child(building)
	_placed_buildings.append(building)


## A lift whose top is just under `pos` (building there extends it).
func _lift_below(pos: Vector2) -> Node2D:
	for b in _placed_buildings:
		if is_instance_valid(b) and b.has_method("extend") and absf(b.global_position.x - pos.x) < 28.0 \
				and pos.y < b.top_y() + 30.0 and pos.y > b.top_y() - 100.0:
			return b
	return null


func _get_tilemap() -> TileMapLayer:
	var scene := get_tree().current_scene
	if scene and scene.has_node("TileMapLayer"):
		return scene.get_node("TileMapLayer") as TileMapLayer
	return null


func _remove_building_at_mouse() -> void:
	var mouse_pos := _get_world_mouse_pos()
	var closest: Node2D = null
	var closest_dist := 50.0  # max removal distance
	# a tall lift: right-clicking its upper part takes off the top segment
	for building in _placed_buildings:
		if is_instance_valid(building) and building.has_method("shorten") and building.segments > 1 \
				and absf(mouse_pos.x - building.global_position.x) < 24.0 \
				and mouse_pos.y < building.global_position.y - 40.0 and mouse_pos.y > building.top_y() - 20.0:
			building.shorten()
			return

	for building in _placed_buildings:
		if not is_instance_valid(building):
			continue
		var dist: float = building.global_position.distance_to(mouse_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = building

	if closest != null:
		_placed_buildings.erase(closest)
		closest.queue_free()


func _get_world_mouse_pos() -> Vector2:
	var viewport := get_viewport()
	var canvas := viewport.get_canvas_transform()
	return canvas.affine_inverse() * viewport.get_mouse_position()


func _disable_collisions(node: Node) -> void:
	if node is CollisionShape2D:
		node.disabled = true
	if node is Area2D:
		node.monitoring = false
	for child in node.get_children():
		_disable_collisions(child)

extends AnimationTree

@onready var enemy: CharacterBody3D = get_parent()
var last_oneshot: String = ""          # empty = "none"
var anim_length: float = 0.5

@onready var state_machine_node: AnimationNodeStateMachinePlayback = self["parameters/Movement/playback"]

signal animation_measured(anim_length: float)

@export var max_attack_count: int = 2
var attack_count: int = 1
var hurt_count: int = 1

func _ready() -> void:
	enemy.attack_started.connect(_on_attack_started)
	enemy.retreat_started.connect(_on_retreat_started)
	enemy.hurt_started.connect(_on_hurt_started)
	enemy.parried_started.connect(_on_parried_started)
	enemy.death_started.connect(_on_death_started)

	animation_started.connect(_on_animation_started)

func _process(_delta: float) -> void:
	set_movement()

func set_movement() -> void:
	var speed := Vector2.ZERO
	var near := false

	match enemy.current_state:
		enemy.state.FREE:
			near = (enemy.target.global_position.distance_to(enemy.global_position) < 0.2)
			speed.y = 0.0 if near else 0.5
		enemy.state.CHASE:
			near = (enemy.target.global_position.distance_to(enemy.global_position) < 4.0)
			speed.y = 0.5 if near else 1.0
		enemy.state.DEAD:
			speed.y = 0.0

	var v: Variant = get("parameters/Movement/Movement2D/blend_position")

	var current_blend: Vector2 = v if v is Vector2 else Vector2.ZERO
	set("parameters/Movement/Movement2D/blend_position", current_blend.lerp(speed, 0.1))


func _on_attack_started() -> void:
	attack_count = randi_range(1, max_attack_count)
	request_oneshot("attack")

func _on_retreat_started() -> void:
	request_oneshot("retreat")

func request_oneshot(oneshot: String) -> void:
	last_oneshot = oneshot
	set("parameters/%s/request" % oneshot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func abort_oneshot(oneshot: String) -> void:
	if oneshot.is_empty():
		return
	# Optional: only abort if node exists to avoid "Invalid set index" spam if misnamed
	# if not has_parameter_path("parameters/%s/request" % oneshot): return
	set("parameters/%s/request" % oneshot, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

func _on_hurt_started() -> void:
	hurt_count = randi_range(1, 2)
	abort_oneshot(last_oneshot)
	request_oneshot("hurt")

func _on_parried_started() -> void:
	abort_oneshot(last_oneshot)
	request_oneshot("parried")

func _on_death_started() -> void:
	abort_oneshot(last_oneshot)
	state_machine_node.travel("Dead")

func _on_animation_started(anim_name: StringName) -> void:
	anim_length = get_node(anim_player).get_animation(anim_name).length
	animation_measured.emit(anim_length)

extends RigidBody2D

const rotation_speed = 1.5 * PI # radians / sec
const forward_speed = 800 # pixels / sec
const accel_time = 0.5 # sec
const forward_accel = forward_speed / accel_time # pixels / sec^2
const input_accel_time = 0.5 # sec

var current_heading = PI / 2 # face up by default
var desired_heading = current_heading
var last_turn_direction = 1 # turn CCW by default
var input_physics_frame_count = 0

func _ready():
	position = Vector2(200, 200)

func _physics_process(delta):
#	print(Engine.get_physics_interpolation_fraction())
	update_heading(delta)
	update_linear_velocity(delta)

func update_heading(delta):
	update_desired_heading()
	# the most the heading could change this frame, radians
	var max_heading_delta = rotation_speed * delta;
	# the unit circle arc distance from current_heading to desired_heading, radians
	var heading_error = Vector2.from_angle(current_heading).angle_to(Vector2.from_angle(desired_heading))
	if heading_error == 0:
		pass
	elif abs(heading_error) <= max_heading_delta:
		current_heading = desired_heading
		last_turn_direction = binary_sign(heading_error)
	else:
		var turn_direction = binary_sign(heading_error)
		# if starting a 180, turn in the direction of the last turn
		if abs(heading_error) > (0.99999 * PI) && abs(heading_error) < (1.00001 * PI):
			turn_direction = last_turn_direction
		# turn by max increment in the specified direction
		current_heading += max_heading_delta * turn_direction
		last_turn_direction = turn_direction
	set_heading(current_heading)

func update_desired_heading():
	var vector = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		vector.x -= 1
	if Input.is_action_pressed("move_right"):
		vector.x += 1
	
	if Input.is_action_pressed("move_down"):
		vector.y -= 1
	if Input.is_action_pressed("move_up"):
		vector.y += 1
	
	if vector.length() > 0:
		vector = vector.normalized()
		desired_heading = vector.angle()
		input_physics_frame_count += 1
	else:
		input_physics_frame_count = 0

func set_heading(heading):
	# convert unit circle rotation to godot's rotation
	heading = -heading;
	heading -= PI / 2
	# apply
	$Sprite2D.rotation = heading
	$CollisionShape2D.rotation = heading

func binary_sign(value):
	if value >= 0.0:
		return 1.0
	return -1.0

func update_linear_velocity(delta):
	# dot product of current_heading and desired_heading, range: [-1, 1]
	var heading_error_dot = Vector2.from_angle(current_heading).dot(Vector2.from_angle(desired_heading))
	# maps heading_error_dot -> velocity_multiplier: [-1, 0) -> [-0.5, 0); [0, 1] -> [0, 1]
	# var velocity_multiplier = heading_error_dot if heading_error_dot >= 0 else heading_error_dot / 2.0
	# maps heading_error_dot -> velocity_multiplier: [-1, 0) -> 0; [0, 1] -> [0, 1]
	# var velocity_multiplier = heading_error_dot if heading_error_dot >= 0 else 0
	var velocity_multiplier = heading_error_dot
	
	# set movement_vector to current_heading vector with y flipped
	var movement_vector = Vector2.from_angle(current_heading) * Vector2(1, -1)
	var input_accel_multiplier = get_input_accel_multiplier(delta)
	var desired_linear_velocity = movement_vector * (forward_speed * velocity_multiplier * input_accel_multiplier)
	if input_physics_frame_count == 0:
		desired_linear_velocity = Vector2.ZERO
	
	var desired_linear_velocity_x = move_toward(linear_velocity.x, desired_linear_velocity.x, forward_accel * delta)
	var desired_linear_velocity_y = move_toward(linear_velocity.y, desired_linear_velocity.y, forward_accel * delta)
	linear_velocity = Vector2(desired_linear_velocity_x, desired_linear_velocity_y)

func get_input_accel_multiplier(delta):
	var seconds_since_input_began = input_physics_frame_count * delta
	var t = seconds_since_input_began / input_accel_time
	t = clampf(t, 0, 1)
	return sqrt(t)

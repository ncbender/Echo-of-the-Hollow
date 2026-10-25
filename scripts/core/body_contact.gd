class_name BodyContact
extends RefCounted
## Character-vs-character contact rule shared by player and enemies.
##
## Kinematic bodies never push each other directly, but if one keeps moving into
## another, Godot's penetration recovery nudges the *other* body a little every
## tick. Removing the velocity component that would move into another character
## this tick stops that ratchet: characters block each other, nobody shoves
## anybody. Walls are unaffected (move_and_slide handles them normally).


static func strip_push(body: CharacterBody2D, velocity: Vector2, delta: float) -> Vector2:
	for i in 2:   # at most two touching characters (e.g. squeezed between two)
		if velocity.length_squared() < 0.0001:
			break
		var collision := KinematicCollision2D.new()
		if not body.test_move(body.global_transform, velocity * delta, collision, body.safe_margin):
			break
		if not collision.get_collider() is CharacterBody2D:
			break
		var normal := collision.get_normal()
		var into := velocity.dot(normal)
		if into >= 0.0:
			break
		velocity -= normal * into
	return velocity

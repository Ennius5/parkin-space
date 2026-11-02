extends TestCase

const EXIT_SCENE := preload("res://scenes/actors/ExitPad.tscn")


func test_contains_matches_the_drawn_gate() -> void:
	var exit: ExitPad = EXIT_SCENE.instantiate()
	exit.position = Vector2(1000, 500)
	tree.root.add_child(exit)
	assert_true(exit.contains(Vector2(1000, 500)))
	assert_true(exit.contains(Vector2(1000, 500 + 100)), "inside the gate near its bottom edge")
	assert_true(exit.contains(Vector2(1000 + 60, 500 - 100)), "inside a corner")
	assert_false(exit.contains(Vector2(1000, 500 + 120)))
	assert_false(exit.contains(Vector2(1000 + 80, 500)))
	exit.queue_free()

extends Node2D



@onready var tile_map: TileMap = $TileMap


@export var noise_density: int = 45   # Percentage of black tile coverage
@export var grid_size: Vector2i = Vector2i(30, 20)
@export var iterations: int = 5

func _ready() -> void:
	generate_noise_grid()
	
func generate_noise_grid() -> Array:
	var noise_grid: Array = []
	for y in range(grid_size.y):
		var row: Array = []
		for x in range(grid_size.x):
			var rng = randf_range(0, 100)
			var value = 0
			if rng < noise_density:
				value = 1
			row.append(value)
			
			if value == 1:
				tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))  # place tile with atlas coords
			else:
				tile_map.set_cell(0, Vector2i(x, y), -1)  # clear tile
		noise_grid.append(row)
	apply_cellular_automation(noise_grid)
	return noise_grid
	



func apply_cellular_automation(noise_grid):
	for i in range(iterations):
		var temp_grid = noise_grid

extends Node2D



@onready var tile_map: TileMap = $TileMap

@export var dev_mode: bool = true
@export var noise_density: int = 40   # Percentage of black tile coverage
@export var grid_size: Vector2i = Vector2i(0, 0)
@export var iterations: int = 4
@export var room_size_min: float = 0.3
@export var floater_size_min: int = 8




func _ready() -> void:
	if dev_mode:
		print("Noise Generated")
	generate_noise_grid()
	boarder_bufferzone()

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("regenerate"):
		print("Regenerate")
		generate_noise_grid()

func boarder_bufferzone():
	# Define a padded bounding box
	var padding := 20  # you can increase this for larger fill area
	var total_width = grid_size.x + padding * 2
	var total_height = grid_size.y + padding * 2

	for y in range(-padding, grid_size.y + padding):
		for x in range(-padding, grid_size.x + padding):
			# Only fill tiles outside the actual noise grid
			if is_within_map_bounds(x, y):
				continue  # skip actual playable area
			tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))  # Fill with outer solid tile

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
	if dev_mode:
		await get_tree().process_frame
		while not Input.is_action_just_pressed("step"):
			update_tilemap_from_grid(noise_grid)
			await get_tree().process_frame
		print("Deploy Automata")
	apply_cellular_automation(noise_grid)
	return noise_grid

func apply_cellular_automation(noise_grid: Array) -> void:
	#Initial Generation
	for i in range(iterations):
		var temp_grid = noise_grid.duplicate(true)
		for y in range(grid_size.y):
			for x in range(grid_size.x):
				var neighbor_wall_count = 0
				for ny in range(y - 1, y + 2):
					for nx in range(x - 1, x + 2):
						if is_within_map_bounds(nx, ny):
							if nx != x or ny != y:
								if temp_grid[ny][nx] == 1:
									neighbor_wall_count += 1
						else:
							neighbor_wall_count += 1  # treat out-of-bounds as wall
				if neighbor_wall_count >= 4:
					noise_grid[y][x] = 1
				else:
					noise_grid[y][x] = 0
		if dev_mode:
			update_tilemap_from_grid(noise_grid)
	#Cleanup Pass (Removes 1x1 to 2x2 voids or floater)
	for i in range(iterations):
		var temp_grid = noise_grid.duplicate(true)
		for y in range(grid_size.y):
			for x in range(grid_size.x):
				var neighbor_wall_count = 0
				for ny in range(y - 1, y + 2):
					for nx in range(x - 1, x + 2):
						if is_within_map_bounds(nx, ny):
							if nx != x or ny != y:
								if temp_grid[ny][nx] == 1:
									neighbor_wall_count += 1
						else:
							neighbor_wall_count += 1  # treat out-of-bounds as wall
				if neighbor_wall_count >= 6:
					noise_grid[y][x] = 1
				elif neighbor_wall_count <= 2:
					noise_grid[y][x] = 0
	if dev_mode:
		await get_tree().process_frame
		while not Input.is_action_just_pressed("step"):
			update_tilemap_from_grid(noise_grid)
			await get_tree().process_frame
		print("Boarder Created")
	create_map_boarder(noise_grid)
func is_within_map_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < grid_size.x and y >= 0 and y < grid_size.y


func create_map_boarder(noise_grid: Array) -> void:
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var is_border = (
				x == 0 or x == grid_size.x - 1 or
				y == 0 or y == grid_size.y - 1
			)
			if is_border:
				noise_grid[y][x] = 1
	if dev_mode:
		await get_tree().process_frame
		while not Input.is_action_just_pressed("step"):
			update_tilemap_from_grid(noise_grid)
			await get_tree().process_frame
		print("Remove Disconnected rooms")
	remove_disconnected_rooms(noise_grid)

func remove_disconnected_rooms(noise_grid: Array) -> void:
	var visited := {}
	var rooms := []

	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var pos := Vector2i(x, y)
			if noise_grid[y][x] == 0 and not visited.has(pos):
				# New room found — flood fill it
				var room := []
				var queue := [pos]
				visited[pos] = true

				while queue.size() > 0:
					var current: Vector2i = queue.pop_front()
					room.append(current)

					for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						var neighbor: Vector2i = current + dir
						if is_within_map_bounds(neighbor.x, neighbor.y):
							if noise_grid[neighbor.y][neighbor.x] == 0 and not visited.has(neighbor):
								queue.append(neighbor)
								visited[neighbor] = true

				rooms.append(room)

	# Find the largest room
	var largest_room := []
	for room in rooms:
		if room.size() > largest_room.size():
			largest_room = room

	# Fill in all smaller rooms
	for room in rooms:
		if room != largest_room:
			for pos in room:
				noise_grid[pos.y][pos.x] = 1
	
	# Regenerate if room is too small
	var largest_room_size = largest_room.size()
	var grid_area = grid_size.x * grid_size.y
	var room_ratio = float(largest_room_size) / float(grid_area)
	if dev_mode:
		print("Room Size: ", room_ratio)
	if room_ratio < room_size_min:
		print("Largest room too small, regenerating...")
		generate_noise_grid()
		return
	if dev_mode:
		await get_tree().process_frame
		while not Input.is_action_just_pressed("step"):
			update_tilemap_from_grid(noise_grid)
			await get_tree().process_frame
		print("Fill Pits")
	fill_pits(noise_grid)


func fill_pits(noise_grid: Array) -> void:
	var neighbors: Dictionary
	var temp_grid = noise_grid.duplicate(true)
	for i in range(2):
		for y in range(grid_size.y):
			for x in range(grid_size.x):
				var tile = temp_grid[y][x]
				if tile == 1:
					continue  # skip empty tiles
				
				neighbors = {
					"N":    y > 0 and temp_grid[y - 1][x] == 1,
					"S":  y < temp_grid.size() - 1 and temp_grid[y + 1][x] == 1,
					"E": x < temp_grid[y].size() - 1 and temp_grid[y][x + 1] == 1,
					"W":  x > 0 and temp_grid[y][x - 1] == 1
				}
				#Remove Pits
				var solid_count = 0
				for dir in neighbors.values():
					if dir:
						solid_count += 1

				if solid_count == 3:
					noise_grid[y][x] = 1
	if dev_mode:
		await get_tree().process_frame
		while not Input.is_action_just_pressed("step"):
			update_tilemap_from_grid(noise_grid)
			await get_tree().process_frame
		print("Remove Peaks")
	remove_peaks(noise_grid)

func remove_peaks(noise_grid: Array) -> void:
	var neighbors: Dictionary
	var temp_grid = noise_grid.duplicate(true)
	for i in range(2):
		for y in range(grid_size.y):
			for x in range(grid_size.x):
				var tile = temp_grid[y][x]
				if tile == 0:
					continue  # skip empty tiles
				
				neighbors = {
					"N":    y > 0 and temp_grid[y - 1][x] == 1,
					"S":  y < temp_grid.size() - 1 and temp_grid[y + 1][x] == 1,
					"E": x < temp_grid[y].size() - 1 and temp_grid[y][x + 1] == 1,
					"W":  x > 0 and temp_grid[y][x - 1] == 1
				}
				#Remove Pits
				var solid_count = 0
				for dir in neighbors.values():
					if dir:
						solid_count += 1

				if solid_count == 1:
					noise_grid[y][x] = 0
	if dev_mode:
		await get_tree().process_frame
		while not Input.is_action_just_pressed("step"):
			update_tilemap_from_grid(noise_grid)
			await get_tree().process_frame
		print("Remove floaters")
	remove_floaters(noise_grid)
	
	
func remove_floaters(noise_grid: Array) -> void:
	var visited := {}
	var islands := []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var pos := Vector2i(x, y)
			if noise_grid[y][x] == 1 and not visited.has(pos):
				# New island found — flood fill it
				var island := []
				var queue := [pos]
				visited[pos] = true

				while queue.size() > 0:
					var current: Vector2i = queue.pop_front()
					island.append(current)

					for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						var neighbor: Vector2i = current + dir
						if is_within_map_bounds(neighbor.x, neighbor.y):
							if noise_grid[neighbor.y][neighbor.x] == 1 and not visited.has(neighbor):
								queue.append(neighbor)
								visited[neighbor] = true

				islands.append(island)

	for island in islands:
		if island.size() < floater_size_min:
			for pos in island:
				noise_grid[pos.y][pos.x] = 0  # convert floater to empty
	if dev_mode:
		await get_tree().process_frame
		while not Input.is_action_just_pressed("step"):
			update_tilemap_from_grid(noise_grid)
			await get_tree().process_frame
		print("Remove Bridges")
	remove_bridges(noise_grid)

func remove_bridges(noise_grid: Array) -> void:
	var neighbors: Dictionary
	var temp_grid = noise_grid.duplicate(true)
	for i in range(5):
		for y in range(grid_size.y):
			for x in range(grid_size.x):
				var tile = temp_grid[y][x]
				if tile == 0:
					continue  # skip empty tiles
				
				var is_border = (
				x == 0 or x == grid_size.x - 1 or
				y == 0 or y == grid_size.y - 1
				)
				
				neighbors = {
					"N":    y > 0 and temp_grid[y - 1][x] == 1,
					"S":  y < temp_grid.size() - 1 and temp_grid[y + 1][x] == 1,
					"E": x < temp_grid[y].size() - 1 and temp_grid[y][x + 1] == 1,
					"W":  x > 0 and temp_grid[y][x - 1] == 1
				}
				
				if neighbors["N"] and neighbors["S"] and not neighbors["E"] and not neighbors["W"] and not is_border:
					noise_grid[y][x] = 0
				if neighbors["E"] and neighbors["W"] and not neighbors["N"] and not["S"] and not is_border:
					noise_grid[y][x] = 0


	if dev_mode:
		await get_tree().process_frame
		while not Input.is_action_just_pressed("step"):
			update_tilemap_from_grid(noise_grid)
			await get_tree().process_frame
		print("Room Complete")
	update_tilemap_from_grid(noise_grid)
	classify_tiles(noise_grid)

func update_tilemap_from_grid(noise_grid: Array) -> void:
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if noise_grid[y][x] == 1:
				tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))
			else:
				tile_map.set_cell(0, Vector2i(x, y), -1)




func classify_tiles(noise_grid: Array) -> Dictionary:
	var neighbors: Dictionary
	var classifications = {}  # key: Vector2i(x, y), value: "floor", "wall", etc.
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var tile = noise_grid[y][x]
			if tile == 0:
				continue  # skip empty tiles
			
			neighbors = {
				"N":    y > 0 and noise_grid[y - 1][x] == 1,
				"S":  y < noise_grid.size() - 1 and noise_grid[y + 1][x] == 1,
				"E": x < noise_grid[y].size() - 1 and noise_grid[y][x + 1] == 1,
				"W":  x > 0 and noise_grid[y][x - 1] == 1
			}


						# Very basic example rules:
			if neighbors["N"] and neighbors["S"] and neighbors["E"] and neighbors["W"]:
				classifications[Vector2i(x, y)] = "solid"
			elif neighbors["N"] and neighbors["S"] and neighbors["W"]:
				classifications[Vector2i(x, y)] = "left_wall"
			elif neighbors["N"] and neighbors["S"] and neighbors["E"]:
				classifications[Vector2i(x, y)] = "right_wall"
			elif neighbors["E"] and neighbors["W"] and neighbors["S"]:
				classifications[Vector2i(x, y)] = "floor"
			elif neighbors["E"] and neighbors["W"] and neighbors["N"]:
				classifications[Vector2i(x, y)] = "roof"
			elif neighbors["E"] and neighbors["S"]:
				classifications[Vector2i(x, y)] = "SE_corner"
			elif neighbors["W"] and neighbors["S"]:
				classifications[Vector2i(x, y)] = "SW_corner"
			elif neighbors["E"] and neighbors["N"]:
				classifications[Vector2i(x, y)] = "NE_corner"
			elif neighbors["W"] and neighbors["N"]:
				classifications[Vector2i(x, y)] = "NW_corner"
			else:
				classifications[Vector2i(x, y)] = "undefined"
	tile_texture_grid(classifications)
	return classifications

func tile_texture_grid(classifications: Dictionary) -> void:
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var is_border = (
				x == 0 or x == grid_size.x - 1 or
				y == 0 or y == grid_size.y - 1
			)
			if not is_border:
				var tile_class = classifications.get(Vector2i(x, y), "")
				if tile_class == "floor" and y != 0:
					tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(1, randi_range(0,3)))
				if tile_class == "roof" and y != (grid_size.y - 1):
					tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(2, randi_range(0,3)))
				if tile_class == "right_wall" and  x != 0:
					tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(3, randi_range(0,3)))
				if tile_class == "left_wall" and x != (grid_size.x - 1):
					tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(4, randi_range(0,3)))
				if tile_class == "SE_corner" and x != (grid_size.x - 1):
					tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(5, randi_range(0,3)))
				if tile_class == "SW_corner" and x != (grid_size.x - 1):
					tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(6, randi_range(0,3)))
				if tile_class == "NE_corner" and x != (grid_size.x - 1):
					tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(7, randi_range(0,3)))
				if tile_class == "NW_corner" and x != (grid_size.x - 1):
					tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(8, randi_range(0,3)))

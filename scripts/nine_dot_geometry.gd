extends RefCounted
class_name NineDotGeometry
## 3x3 node layout + king-move edges (incl. diagonals).

static func node_centers(origin: Vector2, size: float) -> Array[Vector2]:
	var cell := size / 3.0
	var out: Array[Vector2] = []
	for row in range(3):
		for col in range(3):
			out.append(origin + Vector2((col + 0.5) * cell, (row + 0.5) * cell))
	return out

static func cell_size(size: float) -> float:
	return size / 3.0

## Returns Array of PackedInt32Array [a, b] with a < b, nodes 1..9.
static func legal_edges() -> Array:
	var edges: Array = []
	for a in range(1, 10):
		for b in range(a + 1, 10):
			if _adjacent(a, b):
				edges.append(PackedInt32Array([a, b]))
	return edges

static func is_legal_edge(a: int, b: int) -> bool:
	if a == b:
		return false
	return _adjacent(a, b)

static func _adjacent(a: int, b: int) -> bool:
	var ra := (a - 1) / 3
	var ca := (a - 1) % 3
	var rb := (b - 1) / 3
	var cb := (b - 1) % 3
	return abs(ra - rb) <= 1 and abs(ca - cb) <= 1

static func edge_endpoints(centers: Array[Vector2], a: int, b: int) -> PackedVector2Array:
	return PackedVector2Array([centers[a - 1], centers[b - 1]])

static func hit_node(centers: Array[Vector2], pos: Vector2, radius: float) -> int:
	var best := -1
	var best_d := radius
	for i in range(centers.size()):
		var d := centers[i].distance_to(pos)
		if d <= best_d:
			best_d = d
			best = i + 1
	return best

## Distance from point to segment; also returns closest point on segment via out args pattern.
static func dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func progress_on_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0001:
		return 0.0
	return clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)

static func slide_band_half_width(cell: float) -> float:
	return cell * NineDotConfig.SLIDE_BAND_FRAC * 0.5

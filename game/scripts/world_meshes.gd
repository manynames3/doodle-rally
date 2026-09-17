extends RefCounted
## Small reusable organic meshes; all world placements remain MultiMesh batches.

static func cliff(variant: int = 0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 20
	var heights: Array[float] = [-0.5, -0.36, -0.23, -0.06, 0.12, 0.28, 0.40, 0.5]
	var rings: Array[PackedVector3Array] = []
	for ring in range(heights.size()):
		var points := PackedVector3Array()
		for i in range(sides):
			var angle: float = TAU * i / sides + sin(ring * 0.42 + variant) * 0.03
			# Broad vertical fracture faces. Offset strata are local, never concentric shelves.
			var contour: float = 0.43 + sin(i * 1.77 + variant * 2.1) * 0.047 + sin(i * 0.71) * 0.036
			var fracture: float = sin(i * 2.9 + floori(ring / 2.0) * 2.7 + variant) * 0.032
			var radius: float = contour + fracture - maxf(0.0, heights[ring] - 0.20) * (0.30 + sin(i * 0.8) * 0.14)
			var y: float = heights[ring]
			if ring > 0:
				y += sin(i * 1.42 + variant) * 0.038 + sin(i * 2.9 + ring) * 0.016
			points.append(Vector3(cos(angle) * radius, y, sin(angle) * radius))
		rings.append(points)
	for ring in range(rings.size() - 1):
		for i in range(sides):
			var j: int = (i + 1) % sides
			var shade: float = 0.83 + (sin(i * 2.7 + ring * 1.3 + variant) + 1) * 0.08
			var tint := Color(shade * 1.01, shade, shade * 0.98)
			for vertex in [rings[ring][i], rings[ring][j], rings[ring + 1][i], rings[ring + 1][i], rings[ring][j], rings[ring + 1][j]]:
				var moss_amount: float = smoothstep(0.29, 0.49, vertex.y) * 0.75
				st.set_color(tint.lerp(Color(0.48, 0.67, 0.33), moss_amount))
				st.set_uv(Vector2(atan2(vertex.z, vertex.x) / TAU + 0.5, vertex.y + 0.5))
				st.add_vertex(vertex)
	for i in range(sides):
		for vertex in [Vector3(0, 0.5, 0), rings.back()[i], rings.back()[(i + 1) % sides]]:
			st.set_color(Color(0.58, 0.70, 0.41))
			st.set_uv(Vector2(vertex.x + 0.5, vertex.z + 0.5))
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


static func boulder(variant: int = 0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 16
	var rings: Array[PackedVector3Array] = []
	for ring in range(9):
		var v: float = ring / 8.0
		var y: float = cos(v * PI) * 0.5
		var points := PackedVector3Array()
		for i in range(sides):
			var a: float = i / float(sides) * TAU
			var r: float = sin(v * PI) * (0.43 + sin(i * 1.71 + variant * 1.13) * 0.040 + sin(ring * 1.79 + i) * 0.034)
			points.append(Vector3(cos(a) * r, y * (0.96 + sin(i + variant) * 0.08), sin(a) * r))
		rings.append(points)
	for ring in range(8):
		for i in range(sides):
			var j: int = (i + 1) % sides
			for v in [rings[ring][i], rings[ring + 1][i], rings[ring][j], rings[ring][j], rings[ring + 1][i], rings[ring + 1][j]]:
				st.set_color(Color.WHITE)
				st.set_uv(Vector2(atan2(v.z, v.x) / TAU + 0.5, v.y + 0.5))
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func pine_bough() -> ArrayMesh:
	# A cupped, tapered branch gives the needles depth and catches grazing sunlight.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(4):
		for col in range(2):
			for corner in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var u: float = (col + corner.x) / 2.0
				var v: float = (row + corner.y) / 4.0
				var x: float = u - 0.5
				var z: float = v - 0.5
				var y: float = 0.20 * pow(absf(x) * 2.0, 1.5) - 0.10 * cos(v * PI) + 0.08 * sin(v * PI)
				st.set_uv(Vector2(u, v))
				st.add_vertex(Vector3(x, y, z))
	st.generate_normals()
	return st.commit()


static func needle_cluster() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(18):
		var a: float = i * 2.399
		var t: float = (i % 13) / 12.0
		var start := Vector3(0, t * 0.60 - 0.3, 0)
		var r: float = sin(t * PI) * 0.20 + 0.06
		var end: Vector3 = start + Vector3(cos(a) * r, 0.18 + t * 0.12, sin(a) * r)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.032
		var light: float = 0.68 + t * 0.32
		for v in [start - side, end, start + side, start + side, end, start - side]:
			st.set_color(Color(light, light, light))
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func pine_branches() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 14
	var heights: Array[float] = [-0.50, -0.44, -0.24, -0.19, 0.02, 0.07, 0.29, 0.5]
	var radii: Array[float] = [0.37, 0.50, 0.29, 0.37, 0.19, 0.25, 0.10, 0.0]
	var rings: Array[PackedVector3Array] = []
	for ring in range(heights.size()):
		var points := PackedVector3Array()
		for i in range(sides):
			var angle: float = TAU * i / sides + (0.07 if ring % 2 == 0 else 0.0)
			var radius: float = radii[ring] * (0.93 + (0.16 if i % 2 == 0 else 0.0))
			points.append(Vector3(cos(angle) * radius, heights[ring] + (0.015 * sin(i * 1.6) if ring < 7 else 0.0), sin(angle) * radius))
		rings.append(points)
	for ring in range(rings.size() - 1):
		for i in range(sides):
			var j: int = (i + 1) % sides
			var shade: float = 0.89 + (sin(i * 1.3 + ring) + 1.0) * 0.055
			for vertex in [rings[ring][i], rings[ring][j], rings[ring + 1][i], rings[ring + 1][i], rings[ring][j], rings[ring + 1][j]]:
				st.set_color(Color(shade, shade, shade))
				st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


static func grass() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(22):
		var angle: float = i * 2.399
		var p := Vector3(cos(angle) * (0.15 + (i % 5) * 0.07), 0, sin(angle) * (0.15 + (i % 5) * 0.07))
		var width: float = 0.025 + (i % 3) * 0.007
		var height: float = 0.20 + (i % 7) * 0.038
		var x_axis := Vector3(cos(angle), 0, sin(angle)) * width
		var tip: Vector3 = p + Vector3(sin(angle) * 0.10, height, cos(angle) * 0.10)
		for vertex in [p - x_axis, p + x_axis, tip, p + x_axis, p - x_axis, tip]:
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


static func ridge(snow_only: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: int = 28
	for z in range(grid):
		for x in range(grid):
			var x0: float = x / float(grid) - 0.5
			var x1: float = (x + 1) / float(grid) - 0.5
			var z0: float = z / float(grid) - 0.5
			var z1: float = (z + 1) / float(grid) - 0.5
			var a := Vector3(x0, _ridge_height(x0, z0) - 0.5, z0)
			var b := Vector3(x1, _ridge_height(x1, z0) - 0.5, z0)
			var c := Vector3(x0, _ridge_height(x0, z1) - 0.5, z1)
			var d := Vector3(x1, _ridge_height(x1, z1) - 0.5, z1)
			for triangle in [[a, b, c], [b, d, c]]:
				var mid_height: float = (triangle[0].y + triangle[1].y + triangle[2].y) / 3.0
				if snow_only and mid_height < 0.15:
					continue
				for vertex in triangle:
					st.add_vertex(vertex + Vector3.UP * (0.001 if snow_only else 0.0))
	if not snow_only:
		for side in range(4):
			for i in range(grid):
				var t0: float = i / float(grid) - 0.5
				var t1: float = (i + 1) / float(grid) - 0.5
				var first: Vector2
				var second: Vector2
				match side:
					0:
						first = Vector2(t0, -0.5)
						second = Vector2(t1, -0.5)
					1:
						first = Vector2(0.5, t0)
						second = Vector2(0.5, t1)
					2:
						first = Vector2(-t0, 0.5)
						second = Vector2(-t1, 0.5)
					_:
						first = Vector2(-0.5, -t0)
						second = Vector2(-0.5, -t1)
				var a := Vector3(first.x, _ridge_height(first.x, first.y) - 0.5, first.y)
				var b := Vector3(second.x, _ridge_height(second.x, second.y) - 0.5, second.y)
				var bottom_a := Vector3(first.x, -0.5, first.y)
				var bottom_b := Vector3(second.x, -0.5, second.y)
				for vertex in [a, bottom_a, b, b, bottom_a, bottom_b]:
					st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


static func _ridge_height(x: float, z: float) -> float:
	var peaks: Array[Vector4] = [Vector4(-0.25, -0.1, 0.84, 0.40), Vector4(-0.015, 0.11, 1.0, 0.43), Vector4(0.24, -0.10, 0.92, 0.40), Vector4(0.30, 0.26, 0.68, 0.31)]
	var height: float = 0.0
	for peak in peaks:
		var distance: float = Vector2(x - peak.x, z - peak.y).length()
		height = maxf(height, peak.z * pow(maxf(0.0, 1.0 - distance / peak.w), 0.82))
	height += (sin(x * 61 + z * 31) * sin(z * 43 - x * 19) * 0.045 + sin(x * 21 + z * 16) * 0.055) * minf(1.0, height * 2.0)
	return clampf(height, 0.0, 1.0)


static func plank() -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var arrays: Array = box.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in range(uvs.size()):
		uvs[i] = Vector2(uvs[i].y, uvs[i].x)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func cat_ear() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front: Array[Vector3] = [Vector3(-0.5, -0.5, 0.4), Vector3(0, 0.5, 0.15), Vector3(0.5, -0.5, 0.4)]
	var back: Array[Vector3] = [Vector3(-0.5, -0.5, -0.5), Vector3(0, 0.5, -0.4), Vector3(0.5, -0.5, -0.5)]
	for vertex in [front[0], front[1], front[2], back[0], back[2], back[1]]:
		st.add_vertex(vertex)
	for i in range(3):
		var j: int = (i + 1) % 3
		for vertex in [front[i], back[i], front[j], front[j], back[i], back[j]]:
			st.add_vertex(vertex)
	st.generate_normals()
	return st.commit()


static func tunnel_portal() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Individual wedge-shaped limestone blocks, bevelled at the visible perimeter.
	for i in range(23):
		var a0: float = PI * i / 23.0 + 0.008
		var a1: float = PI * (i + 1) / 23.0 - 0.008
		var points: Array[Vector3] = []
		for z in [10.0, 13.0, 15.0]:
			var bevel: float = 0.25 if z == 15.0 else 0.0
			for ar in [Vector2(a0, 12.6 + bevel), Vector2(a1, 12.6 + bevel), Vector2(a1, 17.6 - bevel), Vector2(a0, 17.6 - bevel)]:
				points.append(Vector3(cos(ar.x) * ar.y, 4.1 + sin(ar.x) * ar.y, z))
		var shade: float = 0.88 + sin(i * 2.71) * 0.09
		for face in [[8, 9, 10, 11], [0, 4, 7, 3], [1, 2, 6, 5], [0, 1, 5, 4], [3, 7, 6, 2], [4, 8, 11, 7], [5, 6, 10, 9], [4, 5, 9, 8], [7, 11, 10, 6]]:
			for corner in [face[0], face[1], face[2], face[0], face[2], face[3]]:
				var p: Vector3 = points[corner]
				st.set_color(Color(shade, shade, shade))
				st.set_uv(Vector2(p.x * 0.09, p.y * 0.09))
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


static func cascade(width: float, height: float, seed_value: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(40):
		for col in range(8):
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var u: float = (col + corner.x) / 8.0
				var v: float = (row + corner.y) / 40.0
				var spread: float = 0.62 + v * 0.36 + sin(v * 10.0 + seed_value) * 0.055
				var x: float = (u - 0.5) * width * spread + sin(v * 12.0 + seed_value) * width * 0.035
				var z: float = sin(v * PI * 0.8) * height * 0.035 + pow(v, 5.0) * width * 0.55 + sin(u * 11.0 + v * 20.0 + seed_value) * 0.12
				st.set_uv(Vector2(u, v))
				st.add_vertex(Vector3(x, -height * v, z))
	st.generate_normals()
	return st.commit()

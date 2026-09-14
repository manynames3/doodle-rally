extends RefCounted
## Small reusable organic meshes; all world placements remain MultiMesh batches.

static func cliff(variant: int = 0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 12
	var heights: Array[float] = [-0.5, -0.40, -0.30, -0.27, -0.10, -0.07, 0.14, 0.18, 0.32, 0.35, 0.5]
	var radii: Array[float] = [0.45, 0.50, 0.50, 0.42, 0.42, 0.50, 0.50, 0.38, 0.38, 0.44, 0.35]
	var rings: Array[PackedVector3Array] = []
	for ring in range(heights.size()):
		var points := PackedVector3Array()
		for i in range(sides):
			var angle: float = TAU * i / sides + sin(ring * 1.6 + variant) * 0.10
			var radius: float = radii[ring] * (1.0 + sin(i * 2.3 + variant * 1.7) * 0.14 + cos(i * 1.3 + ring * 0.8) * 0.07)
			var y: float = heights[ring]
			if ring > 0 and ring < heights.size() - 1:
				y += sin(i * 1.5 + ring + variant) * 0.012
			points.append(Vector3(cos(angle) * radius, y, sin(angle) * radius))
		rings.append(points)
	for ring in range(rings.size() - 1):
		for i in range(sides):
			var j: int = (i + 1) % sides
			var shade: float = 0.86 + (sin(i * 2.7 + ring * 1.3 + variant) + 1) * 0.07
			var tint := Color(shade * 1.01, shade, shade * 0.98)
			for vertex in [rings[ring][i], rings[ring][j], rings[ring + 1][i], rings[ring + 1][i], rings[ring][j], rings[ring + 1][j]]:
				st.set_color(tint)
				st.set_uv(Vector2(atan2(vertex.z, vertex.x) / TAU + 0.5, vertex.y + 0.5))
				st.add_vertex(vertex)
	for i in range(sides):
		for vertex in [Vector3(0, 0.5, 0), rings.back()[i], rings.back()[(i + 1) % sides]]:
			st.set_color(Color.WHITE)
			st.set_uv(Vector2(vertex.x + 0.5, vertex.z + 0.5))
			st.add_vertex(vertex)
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

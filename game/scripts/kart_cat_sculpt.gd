extends RefCounted
## Continuous facial sculpture and groomed opaque microgeometry.
static var _cache: Dictionary = {}

static func face_point(normal: Vector3, longhair: bool = false) -> Vector3:
	var y: float = normal.y * 0.66
	var cheek: float = exp(-pow((y + 0.19) / 0.27, 2.0))
	var width: float = 0.83 + cheek * (0.13 if longhair else 0.075)
	# Narrow the crown gently while leaving the lower cheek full. This gives the
	# ears a natural triangular transition instead of a perfectly round mask.
	width *= 1.0 - smoothstep(0.12, 0.66, y) * 0.10
	var x: float = normal.x * width
	var z: float = normal.z * 0.635
	if normal.z < 0.0:
		var forward_weight: float = pow(clampf(-normal.z * 1.65, 0.0, 1.0), 2.0)
		var muzzle: float = exp(-pow((absf(x) - 0.16) / 0.24, 2.0) - pow((y + 0.24) / 0.17, 2.0))
		var bridge: float = exp(-pow(x / 0.19, 2.0) - pow((y + 0.02) / 0.34, 2.0))
		var eye_socket: float = exp(-pow((absf(x) - 0.365) / 0.215, 2.0) - pow((y - 0.09) / 0.20, 2.0))
		var brow: float = exp(-pow((absf(x) - 0.37) / 0.27, 2.0) - pow((y - 0.255) / 0.085, 2.0))
		var lower_lid: float = exp(-pow((absf(x)-0.37)/0.24,2.0)-pow((y+0.09)/0.07,2.0))
		var outer_corner: float = exp(-pow((absf(x)-0.54)/0.12,2.0)-pow((y-0.06)/0.20,2.0))
		z -= (muzzle * 0.30 + bridge * 0.13 + brow * 0.088 + lower_lid*0.040 + outer_corner*0.065 - eye_socket * 0.052) * forward_weight
	# A tapered jaw, full cheek bones and subtly flattened crown.
	if y < -0.39:
		x *= lerpf(1.0, 0.79, clampf((-y - 0.39) / 0.25, 0.0, 1.0))
	return Vector3(x, y, z) + Vector3(0, 2.64, 0.12)

static func head(longhair: bool = false) -> ArrayMesh:
	var key: String = "sculpted_head_%s" % longhair
	if _cache.has(key): return _cache[key]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var latitude: int = 74
	var longitude: int = 144
	for j: int in range(latitude):
		for i: int in range(longitude):
			for index: int in [0, 2, 1, 1, 2, 3]:
				var u: float = float(i + (index % 2)) / longitude
				var v: float = float(j + (index / 2)) / latitude
				var phi: float = v * PI
				var theta: float = u * TAU
				var normal: Vector3 = Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
				surface.set_uv(Vector2(u, v))
				surface.add_vertex(face_point(normal, longhair))
	surface.index()
	surface.generate_normals()
	surface.generate_tangents()
	_cache[key] = surface.commit()
	return _cache[key]

static func lens() -> ArrayMesh:
	if _cache.has("lens"): return _cache.lens
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: int in range(18):
		for i: int in range(80):
			for corner: int in [0, 2, 1, 1, 2, 3]:
				var r: float = float(ring + corner / 2) / 18.0
				var a: float = (i + corner % 2) * TAU / 80.0
				var x: float = cos(a) * r
				var y: float = sin(a) * r
				# A shallow lens reads as a soft illustrated iris instead of a polished
				# glass bead while retaining a gentle catchlight from the eye shader.
				var p: Vector3 = Vector3(x * 0.256, y * 0.205 * (0.76 + 0.24 * absf(sin(a))), -sqrt(maxf(0.0, 1.0 - r*r)) * 0.065)
				surface.set_uv(Vector2(x,y) * 0.5 + Vector2.ONE * 0.5)
				surface.add_vertex(p)
	surface.index()
	surface.generate_normals()
	surface.generate_tangents()
	_cache.lens = surface.commit()
	return _cache.lens

static func ear(side: float, inner: bool = false) -> ArrayMesh:
	var key: String = "sculpted_ear_%s_%s" % [side, inner]
	if _cache.has(key): return _cache[key]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# One cupped ear. The skin is a material region on the exact same surface,
	# bounded by an integral thick furry rim; there is no separate inset plane.
	var steps: int = 32
	for depth_side: int in [-1, 1]:
		for j: int in range(steps):
			for i: int in range(steps):
				var center_u: float = (i + 0.5) / steps
				var center_v: float = (j + 0.5) / steps
				var is_inner: bool = depth_side == -1 and center_u > 0.20 and center_u < 0.80 and center_v > 0.13 and center_v < 0.91
				if inner != is_inner: continue
				var order: Array[int] = []
				order.assign([0,1,2,1,3,2] if depth_side == -1 else [0,2,1,1,2,3])
				for corner: int in order:
					var u: float = float(i + corner % 2) / steps
					var v: float = float(j + corner / 2) / steps
					var width: float = 0.67 * pow(1.0 - v, 0.70) + 0.015
					var x: float = (u - 0.5) * width + side * (0.51 + v * 0.17)
					var y: float = 3.035 + v * 0.59
					var bowl: float = sin(u*PI) * sin(v*PI)
					var z: float = 0.10 + v*0.025 + (0.10 if depth_side == 1 else -0.155 + bowl * 0.175)
					surface.set_uv(Vector2(u,v))
					surface.add_vertex(Vector3(x,y,z))
	if not inner:
		for border: int in range(4):
			for j: int in range(steps):
				for corner: int in [0,1,2,1,3,2,0,2,1,1,2,3]:
					var t: float = float(j+corner%2)/steps
					var u: float = t if border in [0,2] else float(border == 1)
					var v: float = t if border in [1,3] else float(border == 2)
					var width: float = 0.67*pow(1.0-v,0.70)+0.015
					var x: float = (u-0.5)*width+side*(0.51+v*0.17)
					var y: float = 3.035+v*0.59
					var z: float = 0.10+v*0.025+(0.10 if corner/2 == 1 else -0.155+sin(u*PI)*sin(v*PI)*0.175)
					surface.set_uv(Vector2(u,v))
					surface.add_vertex(Vector3(x,y,z))
	surface.index()
	surface.generate_normals()
	surface.generate_tangents()
	_cache[key] = surface.commit()
	return _cache[key]

static func groom(longhair: bool = false) -> ArrayMesh:
	var key: String = "groom_%s" % longhair
	if _cache.has(key): return _cache[key]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 2200 if longhair else 1600
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 5207
	for i: int in range(count):
		var ny: float = random.randf_range(-1.0,1.0)
		var circle: float = sqrt(maxf(0.0, 1.0-ny*ny))
		var a: float = random.randf_range(0.0,TAU)
		var normal: Vector3 = Vector3(cos(a)*circle,ny,sin(a)*circle)
		var start: Vector3 = face_point(normal,longhair)
		# The eye/lip regions are groomed by the underlying short-fur texture.
		var front: bool = normal.z < -0.40
		if front and absf(start.x) < 0.64 and start.y > 2.35 and start.y < 2.98: continue
		var desired_flow: Vector3 = Vector3(signf(normal.x)*0.55+random.randf_range(-0.25,0.25),-0.75,0.10+random.randf_range(-0.2,0.2))
		var flow: Vector3 = (desired_flow - normal * desired_flow.dot(normal)).normalized()
		if flow.length_squared() < 0.1: flow = Vector3.RIGHT
		var length: float = (0.045 if longhair else 0.020) + random.randf()*(0.090 if longhair else 0.043)
		if start.y > 3.11: length *= 0.55
		var width: float = 0.0013 + random.randf()*0.0017
		var cross: Vector3 = normal.cross(flow).normalized()
		var path: Array[Vector3] = []
		for j: int in range(4):
			var t: float = float(j)/3.0
			path.append(start + normal*(0.003 + sin(t*PI)*length*0.16) + flow*t*length)
		for j: int in range(3):
			for face: int in range(3):
				for corner: int in [0,1,2,1,3,2]:
					var segment: int = j + corner / 2
					var t: float = float(segment)/3.0
					var theta: float = (face + corner%2)*TAU/3.0
					var r: float = width*(1.0-t)
					var p: Vector3 = path[segment] + cross*cos(theta)*r + normal*sin(theta)*r
					surface.set_uv(Vector2(float(face+corner%2)/3.0,t))
					surface.add_vertex(p)
	surface.index()
	surface.generate_normals()
	_cache[key] = surface.commit()
	return _cache[key]

static func curved_line(points: Array[Vector3], radius: float) -> ArrayMesh:
	var path: Curve3D = Curve3D.new()
	for i: int in range(points.size()):
		var tangent: Vector3 = (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)])*0.18
		path.add_point(points[i],-tangent,tangent)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var total: float = path.get_baked_length()
	for i: int in range(22):
		for side: int in range(5):
			for corner: int in [0,1,2,1,3,2]:
				var t: float = float(i+corner/2)/22.0
				var p: Vector3 = path.sample_baked(t*total)
				var tangent: Vector3 = (path.sample_baked(minf(total,t*total+0.005))-path.sample_baked(maxf(0,t*total-0.005))).normalized()
				var basis: Basis = Basis.looking_at(tangent,Vector3.UP)
				var a: float = (side+corner%2)*TAU/5.0
				var r: float = radius * pow(1.0-t,0.68)
				surface.add_vertex(p+(basis.x*cos(a)+basis.y*sin(a))*r)
	surface.index()
	surface.generate_normals()
	return surface.commit()

static func tire() -> ArrayMesh:
	if _cache.has("rounded_tire"): return _cache.rounded_tire
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2] = [Vector2(-0.267,0.33),Vector2(-0.261,0.37),Vector2(-0.248,0.421),Vector2(-0.222,0.464),Vector2(-0.18,0.489),Vector2(-0.105,0.502),Vector2(0.105,0.502),Vector2(0.18,0.489),Vector2(0.222,0.464),Vector2(0.248,0.421),Vector2(0.261,0.37),Vector2(0.267,0.33)]
	for ring: int in range(profile.size()-1):
		for segment: int in range(72):
			for corner: int in [0,2,1,1,2,3]:
				var p: Vector2 = profile[ring+corner/2]
				var a: float = (segment+corner%2)*TAU/72.0
				surface.set_uv(Vector2(float(segment+corner%2)/72.0,float(ring+corner/2)/float(profile.size()-1)))
				surface.add_vertex(Vector3(p.x,cos(a)*p.y,sin(a)*p.y))
	surface.index()
	surface.generate_normals()
	_cache.rounded_tire = surface.commit()
	return _cache.rounded_tire

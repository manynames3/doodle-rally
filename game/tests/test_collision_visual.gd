extends SceneTree
## Isolated temporal collision replay. No main scene, sound, saved settings, or user app.
## Native capture: godot --path game --script res://tests/test_collision_visual.gd -- --output=/absolute/work/path
## Optional --sim=... --main=... --kart=... --objects=... select read-only baseline scripts.
## --render-hz=120 samples the live renderer twice per 60 Hz physics tick.
## --effects adds boost/stun/hop contacts; --course=0|1|2 uses that actual curved circuit.
## --mode=minecraft checks the voxel roster; --assert-clearance fails camera intrusion.
## Short CI: --headless ... -- --no-capture --frames=90 --render-hz=120 --effects --max-penetration=.025
## Default output is user://collision_visual_qa; use --output to keep captures in work/.
const DT := 1.0/60.0
const FRAMES := 150
class StraightTrack extends Node3D:
	var length := 2000.0
	var road_width := 18.0
	var item_spots: Array[Dictionary] = []
	var boost_spots: Array[Dictionary] = []
	func sample(distance: float,lane: float=0) -> Vector3:
		return Vector3(lane,0,-distance)
	func tangent(_distance: float) -> Vector3:
		return Vector3.FORWARD
	func frame(_distance: float) -> Basis:
		return Basis.IDENTITY

var world: Node3D
var sim: RefCounted
var objects: Node3D
var karts: Array[Node3D] = []
var solid_meshes: Array[MeshInstance3D] = []
var local_bounds: Array[AABB] = []
var camera: Camera3D
var driver: Node
var output := "user://collision_visual_qa"
var data: Dictionary = {"frames":[],"summary":{},"sources":{}}
var violations := 0
var capture := true
var allowed_penetration := -1.0
var tick_count := FRAMES
var render_steps := 1
var include_effects := false
var course := -1
var base_distance := 100.0
var supports_interpolation := false
var mesh_groups: Array = []
var vertex_cache: Dictionary = {}
var footprint_cache: Dictionary = {}
var effect_nodes: Array[Node] = []
var forced_no_capture := false
var assert_clearance := false
var racer_mode := "cats"
var sim_source := "res://scripts/race_sim.gd"
var main_source := "res://scripts/main.gd"
var kart_source := "res://scripts/kart_visual.gd"
var objects_source := "res://scripts/race_objects.gd"

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--sim="): sim_source=arg.trim_prefix("--sim=")
		if arg.begins_with("--main="): main_source=arg.trim_prefix("--main=")
		if arg.begins_with("--kart="): kart_source=arg.trim_prefix("--kart=")
		if arg.begins_with("--objects="): objects_source=arg.trim_prefix("--objects=")
		if arg.begins_with("--max-penetration="): allowed_penetration=arg.trim_prefix("--max-penetration=").to_float()
		if arg.begins_with("--frames="): tick_count=maxi(1,arg.trim_prefix("--frames=").to_int())
		if arg.begins_with("--render-hz="): render_steps=clampi(int(arg.trim_prefix("--render-hz=").to_int()/60),1,4)
		if arg.begins_with("--course="): course=clampi(arg.trim_prefix("--course=").to_int(),0,2)
		if arg=="--effects": include_effects=true
		if arg=="--no-capture": forced_no_capture=true
		if arg=="--assert-clearance": assert_clearance=true
		if arg=="--mode=minecraft": racer_mode="minecraft"
	capture = DisplayServer.get_name() != "headless" and not forced_no_capture
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.title="Doodle Rally • Isolated collision visual QA"
	root.size=Vector2i(1280,800)
	root.content_scale_size=Vector2i(1280,800)
	if not InputMap.has_action("r_look"): InputMap.add_action("r_look")
	world=StraightTrack.new() if course<0 else load("res://scripts/track_world.gd").new()
	root.add_child(world)
	if course<0:
		_build_stage()
	else:
		world.build(course,racer_mode)
		world.set_animations_enabled(false)
		# Start at the strongest local turn, using the real road's curve and frames.
		var sharpest:=0.0
		for d in range(50,int(world.length)-50,5):
			var curvature: float=world.tangent(d-4).angle_to(world.tangent(d+4))
			if curvature>sharpest:
				sharpest=curvature
				base_distance=float(d)-20.0
	camera=Camera3D.new()
	camera.near=.25
	camera.far=600
	camera.fov=64
	world.add_child(camera)
	camera.current=true
	driver=Node.new()
	driver.set_script(load(main_source))
	driver.world=world
	driver.camera=camera
	driver.state="racing"
	for method in driver.get_method_list():
		if method.name=="_update_karts": supports_interpolation=method.args.size()>1
	data.sources={"sim":sim_source,"main":main_source,"kart":kart_source,"objects":objects_source,"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"camera_near":camera.near,"render_hz":60*render_steps,"course":course,"base_distance":base_distance}
	data.sources.mode=racer_mode
	data.sources.sha256={}
	for source in [sim_source,main_source,kart_source,objects_source,"res://scripts/track_world.gd","res://scripts/kart_fur.gdshader"]:
		data.sources.sha256[source]=FileAccess.get_sha256(source)
	var scenarios: Array[String]=["rear_end","side_contact","barrier_pack"]
	if include_effects: scenarios.append("effects_contact")
	for scenario in scenarios:
		await _scenario(scenario)
		if allowed_penetration>=0 and float(data.summary[scenario].max_penetration)>allowed_penetration:
			violations+=1
			push_error("Visual collision penetration exceeds margin: " + scenario)
		if assert_clearance and int(data.summary[scenario].camera_inside_rival_frames)>0:
			violations+=1
			push_error("Camera entered a rival model: " + scenario)
	var file:=FileAccess.open(output.path_join("telemetry.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
	file.close()
	print("COLLISION VISUAL QA: ",JSON.stringify(data.summary)," assertion violations=",violations)
	driver.free()
	quit(1 if violations>0 else 0)

func _build_stage() -> void:
	var environment:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("a9c9df")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("b8c7d6")
	env.ambient_light_energy=.5
	environment.environment=env
	world.add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-44,-30,0)
	sun.light_energy=1.35
	sun.shadow_enabled=true
	world.add_child(sun)
	_box(Vector3(0,-.15,-200),Vector3(20,.3,600),Color("d4b080"))
	for z in range(50,350,5):
		for side in [-1,1]:
			_box(Vector3(side*9.4,.62,-z),Vector3(.5,1.2,5),Color("bf5444") if z%10==0 else Color("eae2cc"))
		_box(Vector3(0,.012,-z),Vector3(.12,.025,2),Color("f8dfb6"))

func _box(point: Vector3,dimensions: Vector3,color: Color) -> void:
	var instance:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=dimensions
	instance.mesh=mesh
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	instance.material_override=material
	instance.position=point
	world.add_child(instance)

func _scenario(title: String) -> void:
	if objects:
		objects.queue_free()
	for kart in karts:
		kart.queue_free()
	karts.clear()
	solid_meshes.clear()
	local_bounds.clear()
	mesh_groups.clear()
	effect_nodes.clear()
	await process_frame
	sim=load(sim_source).new()
	sim.setup(world,0,0,racer_mode)
	for i in range(8):
		var r: Dictionary=sim.racers[i]
		r.distance=300.0+i*12.0
		r.lane=0.0
		r.speed=25.0
		r.ai_item_time=999.0
		var kart: Node3D=load(kart_source).new()
		world.add_child(kart)
		kart.build(int(r.character),racer_mode)
		effect_nodes.append_array(kart.get("_flames"))
		effect_nodes.append_array(kart.get("_sparks"))
		karts.append(kart)
	match title:
		"rear_end":
			sim.racers[0].merge({"distance":100.0,"lane":0.0,"speed":48.0},true)
			sim.racers[1].merge({"distance":105.0,"lane":0.0,"speed":10.0},true)
		"side_contact":
			sim.racers[0].merge({"distance":100.0,"lane":0.0,"speed":34.0,"angle":.35},true)
			sim.racers[1].merge({"distance":100.7,"lane":2.8,"speed":32.0},true)
		"barrier_pack":
			for i in range(8):
				sim.racers[i].merge({"distance":100.0+float(i/2)*2.0,"lane":7.1+float(i%2)*.15,"speed":26.0},true)
		"effects_contact":
			sim.racers[0].merge({"distance":100.0,"lane":-1.5,"speed":42.0,"turbo":1.2},true)
			sim.racers[1].merge({"distance":106.0,"lane":-1.0,"speed":19.0,"stun":.55},true)
			sim.racers[2].merge({"distance":103.5,"lane":3.5,"speed":32.0,"hop_timer":.55},true)
	for racer in sim.racers:
		racer.distance=float(racer.distance)+base_distance-100.0
	sim.call("_update_transforms")
	if sim.has_method("snap_interpolation"): sim.snap_interpolation()
	driver.sim=sim
	driver.karts=karts
	driver.call("_update_karts",0.0)
	driver.call("_update_camera",1.0,true)
	objects=load(objects_source).new()
	world.add_child(objects)
	objects.build(world,sim)
	driver.objects=objects
	await process_frame
	for kart in karts:
		var baseline_meshes: Array[MeshInstance3D]=[]
		_collect_visible_meshes(kart,baseline_meshes)
		solid_meshes.append_array(baseline_meshes)
		mesh_groups.append(baseline_meshes)
		var bounds:=AABB()
		var initialized:=false
		for mesh in baseline_meshes:
			var relative: Transform3D=kart.global_transform.affine_inverse()*mesh.global_transform
			var bound: AABB=relative*mesh.get_aabb()
			bounds=bound if not initialized else bounds.merge(bound)
			initialized=true
		local_bounds.append(bounds)
	_audit_materials()
	var stats: Dictionary={"overlap_frames":0,"max_pairs":0,"max_penetration":0.0,"camera_inside_rival_frames":0,"camera_near_margin_frames":0,"rival_occlusion_frames":0,"max_camera_offset_step":0.0,"max_camera_angle_step_degrees":0.0,"solid_meshes":solid_meshes.size(),"samples":tick_count*render_steps,"player_visual_bounds":str(local_bounds[0]),"stun_samples":0,"boost_samples":0,"hop_samples":0}
	var last_offset: Vector3=camera.global_position-karts[0].global_position
	var last_rotation: Quaternion=camera.global_basis.get_rotation_quaternion()
	for frame_index in range(tick_count):
		var controls: Dictionary={"throttle":1.0,"steer":1.0 if title=="side_contact" else .35 if title=="barrier_pack" else 0.0}
		if title=="effects_contact":
			controls.steer=.6 if frame_index<65 else -.5
			controls.boost=frame_index>=75 and frame_index<105
			if frame_index==30: sim.racers[0].stun=.6
			if frame_index==60: sim.racers[0].hop_timer=.55
		sim.tick(DT,controls)
		# Deliberately planted initial pack overlaps have no valid previous pose.
		# Resolve them on the first tick before auditing interpolation between poses.
		if frame_index==0 and sim.has_method("snap_interpolation"): sim.snap_interpolation()
		for subframe in range(render_steps):
			var render_dt:=DT/float(render_steps)
			var interpolation:=float(subframe+1)/float(render_steps)
			if supports_interpolation: driver.call("_update_karts",render_dt,interpolation)
			else: driver.call("_update_karts",render_dt)
			driver.call("_update_camera",render_dt)
			objects.update_visuals(render_dt,false)
			_refresh_visual_bounds()
			var pairs:=0
			var max_penetration:=0.0
			for a in range(8):
				for b in range(a+1,8):
					var penetration:=_footprint_penetration(a,b)
					if penetration>0.005:
						pairs+=1
						max_penetration=maxf(max_penetration,penetration)
			var inside:=false
			var near_margin:=false
			var occlusion:=false
			for i in range(1,8):
				var local_camera: Vector3=karts[i].to_local(camera.global_position)
				inside=inside or local_bounds[i].has_point(local_camera)
				near_margin=near_margin or local_bounds[i].grow(camera.near).has_point(local_camera)
				var local_target: Vector3=karts[i].to_local(karts[0].global_position+Vector3.UP*1.6)
				occlusion=occlusion or local_bounds[i].intersects_segment(local_camera,local_target)
			for mesh in solid_meshes:
				if not mesh.is_visible_in_tree() or mesh.transparency>0.001:
					violations+=1
				var material: Material=mesh.material_override
				if material is BaseMaterial3D and (material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or material.albedo_color.a<.999):
					violations+=1
			if float(sim.racers[0].stun)>0: stats.stun_samples+=1
			if float(sim.racers[0].turbo)>0: stats.boost_samples+=1
			if float(sim.racers[0].hop)>0: stats.hop_samples+=1
			if pairs>0: stats.overlap_frames+=1
			stats.max_pairs=maxi(stats.max_pairs,pairs)
			stats.max_penetration=maxf(stats.max_penetration,max_penetration)
			var offset: Vector3=camera.global_position-karts[0].global_position
			var rotation: Quaternion=camera.global_basis.get_rotation_quaternion()
			var camera_step:=offset.distance_to(last_offset)
			var angle_step:=rad_to_deg(rotation.angle_to(last_rotation))
			if frame_index>0:
				stats.max_camera_offset_step=maxf(stats.max_camera_offset_step,camera_step)
				stats.max_camera_angle_step_degrees=maxf(stats.max_camera_angle_step_degrees,angle_step)
			last_offset=offset
			last_rotation=rotation
			if inside: stats.camera_inside_rival_frames+=1
			if near_margin: stats.camera_near_margin_frames+=1
			if occlusion: stats.rival_occlusion_frames+=1
			var snapshot: Dictionary={"scenario":title,"frame":frame_index,"subframe":subframe,"interpolation":interpolation,"time":float(frame_index)*DT+float(subframe)*render_dt,"overlap_pairs":pairs,"penetration":max_penetration,"camera_inside_rival":inside,"camera_near_margin":near_margin,"camera_offset_step":camera_step,"camera_angle_step_degrees":angle_step,"rival_on_camera_line":occlusion,"player_distance":sim.racers[0].distance,"player_lane":sim.racers[0].lane,"rival_distance":sim.racers[1].distance,"rival_lane":sim.racers[1].lane,"player_bump_cooldown":sim.racers[0].bump_cooldown}
			data.frames.append(snapshot)
			if capture:
				await RenderingServer.frame_post_draw
				if frame_index%15==0 and subframe==render_steps-1:
					root.get_texture().get_image().save_png(output.path_join(title+"_%03d.png"%frame_index))
			else:
				await process_frame
	data.summary[title]=stats

func _collect_visible_meshes(node: Node,list: Array[MeshInstance3D]) -> void:
	if node in effect_nodes: return
	if node is MeshInstance3D and node.is_visible_in_tree():
		list.append(node)
	for child in node.get_children():
		_collect_visible_meshes(child,list)

func _footprint_penetration(a: int,b: int) -> float:
	# SAT on conservative visual footprints, using actual built model bounds.
	var ta: Transform3D=karts[a].global_transform
	var tb: Transform3D=karts[b].global_transform
	var ca: Vector3=ta*local_bounds[a].get_center()
	var cb: Vector3=tb*local_bounds[b].get_center()
	var delta:=Vector2(cb.x-ca.x,cb.z-ca.z)
	var ax:=Vector2(ta.basis.x.x,ta.basis.x.z).normalized()
	var az:=Vector2(ta.basis.z.x,ta.basis.z.z).normalized()
	var bx:=Vector2(tb.basis.x.x,tb.basis.x.z).normalized()
	var bz:=Vector2(tb.basis.z.x,tb.basis.z.z).normalized()
	var half_a:=Vector2(local_bounds[a].size.x,local_bounds[a].size.z)*.5
	var half_b:=Vector2(local_bounds[b].size.x,local_bounds[b].size.z)*.5
	var least:=INF
	for axis in [ax,az,bx,bz]:
		var projected_a:=absf(ax.dot(axis))*half_a.x+absf(az.dot(axis))*half_a.y
		var projected_b:=absf(bx.dot(axis))*half_b.x+absf(bz.dot(axis))*half_b.y
		var overlap:=projected_a+projected_b-absf(delta.dot(axis))
		if overlap<=0: return 0.0
		least=minf(least,overlap)
	# A rotating tire's transformed AABB contains empty corners. Confirm a broad
	# overlap against the actual vertices' convex projected footprints before failing.
	var hull_a:=_exact_footprint(a)
	var hull_b:=_exact_footprint(b)
	least=INF
	for polygon in [hull_a,hull_b]:
		for i in range(polygon.size()-1):
			var edge: Vector2=polygon[i+1]-polygon[i]
			var axis:=Vector2(-edge.y,edge.x).normalized()
			var amin:=INF
			var amax:=-INF
			var bmin:=INF
			var bmax:=-INF
			for point: Vector2 in hull_a:
				amin=minf(amin,point.dot(axis)); amax=maxf(amax,point.dot(axis))
			for point: Vector2 in hull_b:
				bmin=minf(bmin,point.dot(axis)); bmax=maxf(bmax,point.dot(axis))
			var overlap:=minf(amax,bmax)-maxf(amin,bmin)
			if overlap<=0: return 0.0
			least=minf(least,overlap)
	return least

func _exact_footprint(index: int) -> PackedVector2Array:
	if footprint_cache.has(index): return footprint_cache[index]
	var points:=PackedVector2Array()
	for mesh: MeshInstance3D in mesh_groups[index]:
		var key:=mesh.mesh.get_instance_id()
		if not vertex_cache.has(key):
			var unique: Dictionary={}
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays: Array=mesh.mesh.surface_get_arrays(surface)
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: unique[vertex]=true
			vertex_cache[key]=PackedVector3Array(unique.keys())
		var vertices: PackedVector3Array=mesh.global_transform*vertex_cache[key]
		for vertex in vertices: points.append(Vector2(vertex.x,vertex.z))
	var hull:=Geometry2D.convex_hull(points)
	footprint_cache[index]=hull
	return hull

func _refresh_visual_bounds() -> void:
	footprint_cache.clear()
	for i in range(karts.size()):
		var inverse: Transform3D=karts[i].global_transform.affine_inverse()
		var bounds:=AABB()
		var initialized:=false
		for mesh: MeshInstance3D in mesh_groups[i]:
			var bound: AABB=(inverse*mesh.global_transform)*mesh.get_aabb()
			bounds=bound if not initialized else bounds.merge(bound)
			initialized=true
		local_bounds[i]=bounds

func _audit_materials() -> void:
	# Effect meshes are excluded from solid_meshes. Racing bodies must stay opaque.
	var checked: Dictionary={}
	var alpha_write:=RegEx.new()
	alpha_write.compile("\\b(ALPHA|ALPHA_SCISSOR_THRESHOLD|ALPHA_HASH_SCALE)\\s*=")
	var discard_statement:=RegEx.new()
	discard_statement.compile("\\bdiscard\\s*;")
	for mesh in solid_meshes:
		var materials: Array[Material]=[]
		if mesh.material_override: materials.append(mesh.material_override)
		else:
			for surface in range(mesh.mesh.get_surface_count()):
				var material:=mesh.get_active_material(surface)
				if material: materials.append(material)
		for material in materials:
			if checked.has(material.get_instance_id()): continue
			checked[material.get_instance_id()]=true
			if material is BaseMaterial3D:
				if material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or material.albedo_color.a<.999:
					violations+=1
			elif material is ShaderMaterial:
				var code: String=material.shader.code
				if alpha_write.search(code) or discard_statement.search(code):
					violations+=1
					push_error("Solid racer shader uses transparency or discard")

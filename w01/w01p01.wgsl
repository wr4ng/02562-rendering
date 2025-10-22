struct VSOut {
	@builtin(position) position: vec4f,
	@location(0) coords: vec2f,
}

@vertex
fn main_vs(@builtin(vertex_index) VertexIndex: u32) -> VSOut {
	const pos = array<vec2f, 4>(vec2f(- 1.0, 1.0), vec2f(- 1.0, - 1.0), vec2f(1.0, 1.0), vec2f(1.0, - 1.0));
	var vsOut: VSOut;
	vsOut.position = vec4f(pos[VertexIndex], 0.0, 1.0);
	// Pass coords of vertex to fragment shader. Is interpolated over each fragment
	vsOut.coords = pos[VertexIndex];
	return vsOut;
}

struct Ray {
	origin: vec3f,
	direction: vec3f,
	tmin: f32,
	tmax: f32
}

fn get_camera_ray(ipcoords: vec2f) -> Ray {
	const eye_point = vec3(2.0, 1.5, 2.0);
	const look_point = vec3(0.0, 0.5, 0.0);
	const up_vector = vec3(0.0, 1.0, 0.0);
	const camera_constant = 1.0;
	const t_max = 100;

	var v = normalize(look_point - eye_point);
	var b1 = normalize(cross(v, up_vector));
	var b2 = cross(b1, v);

	var q = b1 * ipcoords.x + b2 * ipcoords.y + v * camera_constant;
	var w = normalize(q);

	return Ray(eye_point, w, camera_constant, t_max);
}

@fragment
fn main_fs(@location(0) coords: vec2f) -> @location(0) vec4f {
	let ipcoords = coords * 0.5;
	var r = get_camera_ray(ipcoords);
	return vec4f(r.direction * 0.5 + 0.5, 1.0);
}
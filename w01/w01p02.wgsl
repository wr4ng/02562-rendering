struct Uniforms {
	aspect: f32,
	camera_constant: f32,
	eye_point: vec3f,
	b1: vec3f,
	b2: vec3f,
	v: vec3f,
}

@group(0) @binding(0)
var<uniform> uniforms: Uniforms;

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
	const t_max = 100;

	var q = uniforms.b1 * ipcoords.x + uniforms.b2 * ipcoords.y + uniforms.v * uniforms.camera_constant;
	var w = normalize(q);

	return Ray(uniforms.eye_point, w, uniforms.camera_constant, t_max);
}

@fragment
fn main_fs(@location(0) coords: vec2f) -> @location(0) vec4f {
	let ipcoords = vec2f(coords.x * uniforms.aspect * 0.5, coords.y * 0.5);
	var r = get_camera_ray(ipcoords);
	return vec4f(r.direction * 0.5 + 0.5, 1.0);
}
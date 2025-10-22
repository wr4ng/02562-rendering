struct Uniforms {
	aspect: f32,
	camera_constant: f32,
	gamma: f32,
	eye_point: vec3f,
	b1: vec3f,
	b2: vec3f,
	v: vec3f,
}

struct Ray {
	origin: vec3f,
	direction: vec3f,
	tmin: f32,
	tmax: f32
}

struct HitInfo {
	has_hit: bool,
	distance: f32,
	position: vec3f,
	normal: vec3f,
	color: vec3f,
	shader: u32,
	// To be extended...
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
	vsOut.coords = pos[VertexIndex];
	return vsOut;
}

// Calculate a ray from the camera through the image plane
fn get_camera_ray(ipcoords: vec2f) -> Ray {
	const t_max = 100;
	var q = uniforms.b1 * ipcoords.x + uniforms.b2 * ipcoords.y + uniforms.v * uniforms.camera_constant;
	var w = normalize(q);
	return Ray(uniforms.eye_point, w, uniforms.camera_constant, t_max);
}

// Intersection functions
fn intersect_plane(r: Ray, hit: ptr<function, HitInfo>, position: vec3f, normal: vec3f) -> bool {
	var q = dot(r.direction, normal);
	if (abs(q) < 0.0001) {
		return false;
	}

	var t = dot(position - r.origin, normal) / q;
	if (t < r.tmin || t > r.tmax) {
		return false;
	}

	hit.has_hit = true;
	hit.position = r.origin + r.direction * t;
	hit.distance = t;
	hit.normal = normal;

	return true;
}

fn intersect_triangle(r: Ray, hit: ptr<function, HitInfo>, v: array<vec3f, 3>) -> bool {
	let e0 = v[1] - v[0];
	let e1 = v[2] - v[0];
	let n = cross(e0, e1);

	let q = dot(r.direction, n);
	if (abs(q) < 0.0001) {
		return false;
	}

	let a = v[0] - r.origin;
	let t = dot(a, n) / q;
	if (t < r.tmin || t > r.tmax) {
		return false;
	}

	let beta = dot(cross(a, r.direction), e1) / q;
	let gamma = - dot(cross(a, r.direction), e0) / q;

	if (beta < 0.0 || gamma < 0.0 || (1.0 - beta - gamma) < 0.0) {
		return false;
	}

	hit.has_hit = true;
	hit.position = r.origin + r.direction * t;
	hit.distance = t;
	hit.normal = normalize(n);

	return hit.has_hit;
}

fn intersect_sphere(r: Ray, hit: ptr<function, HitInfo>, center: vec3f, radius: f32) -> bool {
	let oc = r.origin - center;
	let bhalf = dot(oc, r.direction);
	let c = dot(oc, oc) - radius * radius;

	let discriminant = bhalf * bhalf - c;
	if (discriminant < 0.0) {
		return false;
	}

	let sqrt_disc = sqrt(discriminant);

	let t1 = - bhalf - sqrt_disc;
	if (t1 > r.tmin && t1 < r.tmax) {
		hit.has_hit = true;
		hit.distance = t1;
		hit.position = r.origin + r.direction * t1;
		hit.normal = normalize(hit.position - center);
		return true;
	}
	else {
		let t2 = - bhalf + sqrt_disc;
		if (t2 > r.tmin && t2 < r.tmax) {
			hit.has_hit = true;
			hit.distance = t2;
			hit.position = r.origin + r.direction * t2;
			hit.normal = normalize(hit.position - center);
			return true;
		}
	}

	return false;
}

// Shading functions
fn lambertian(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
	let light = sample_point_light(hit.position);
	return (hit.color / 3.14) * light.L_i * dot(hit.normal, light.w_i);
}
// fn phong(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f { }
// fn mirror(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f { }

fn shade(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
	switch hit.shader {
		case 1 {
			return lambertian(r, hit);
		}
		// case 2 {
		// 	return phong(r, hit);
		// }
		// case 3 {
		// 	return mirror(r, hit);
		// }
		case default {
			return hit.color;
		}
	}
}

fn intersect_scene(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> bool {
	// Define scene data as constants.
	const plane_position = vec3f(0.0, 0.0, 0.0);
	const plane_normal = vec3f(0.0, 1.0, 0.0);
	const plane_color = vec3f(0.1, 0.7, 0.0);

	const v0 = vec3f(- 0.2, 0.1, 0.9);
	const v1 = vec3f(0.2, 0.1, 0.9);
	const v2 = vec3f(- 0.2, 0.1, - 0.1);
	const triangle = array<vec3f, 3>(v0, v1, v2);
	const triangle_color = vec3f(0.4, 0.3, 0.2);

	const sphere_center = vec3f(0.0, 0.5, 0.0);
	const sphere_radius = 0.3;
	const sphere_color = vec3f(0.0, 0.0, 0.0);

	// Call an intersection function for each object.
	// For each intersection found, update r.tmax and store additional info about the hit.
	if (intersect_plane(*r, hit, plane_position, plane_normal)) {
		hit.color = plane_color;
		hit.shader = 1u;
		r.tmax = hit.distance;
	}
	if (intersect_triangle(*r, hit, triangle)) {
		hit.color = triangle_color;
		hit.shader = 1u;
		r.tmax = hit.distance;
	}
	if (intersect_sphere(*r, hit, sphere_center, sphere_radius)) {
		hit.color = sphere_color;
		hit.shader = 1u;
		r.tmax = hit.distance;
	}
	return hit.has_hit;
}

// Light
struct Light {
	L_i: vec3f,
	w_i: vec3f,
	dist: f32
}

fn sample_point_light(pos: vec3f) -> Light {
	var light = Light();
	const light_position = vec3f(0.0, 1.0, 0.0);
	const intensity = vec3f(1.0, 1.0, 1.0) * 3.14;

	light.dist = length(light_position - pos);
	light.w_i = normalize(light_position - pos);
	light.L_i = intensity / (light.dist * light.dist);

	return light;
}

@fragment
fn main_fs(@location(0) coords: vec2f) -> @location(0) vec4f {
	const bgcolor = vec4f(0.1, 0.3, 0.6, 1.0);
	const max_depth = 10;
	let uv = vec2f(coords.x * uniforms.aspect * 0.5f, coords.y * 0.5f);
	var r = get_camera_ray(uv);
	var result = vec3f(0.0);
	var hit = HitInfo(false, 0.0, vec3f(0.0), vec3f(0.0), vec3f(0.0), 0u);
	for (var i = 0; i < max_depth; i++) {
		if (intersect_scene(&r, & hit)) {
			result += shade(&r, & hit);
		}
		else {
			result += bgcolor.rgb;
			break;
		}
		if (hit.has_hit) {
			break;
		}
	}
	return vec4f(pow(result, vec3f(1.0 / uniforms.gamma)), bgcolor.a);
}
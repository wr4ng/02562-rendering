struct Uniforms {
	aspect: f32,
	camera_constant: f32,
	gamma: f32,
	texture_scaling: f32,
	plane_shader: u32,
	triangle_shader: u32,
	sphere_shader: u32,
	texture_enabled: u32,
	texture_edge_mode: u32,
	texture_interpolation: u32,
	subpixels: u32,
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
	diffuse: vec3f,
	emission: vec3f,
	specular: vec3f,
	ior1_over_ior2: f32,
	shininess: f32,
	shader: u32,
	// To be extended...
}

fn default_hitinfo() -> HitInfo {
	return HitInfo(false, 0.0, vec3f(0.0), vec3f(0.0), vec3f(0.0), vec3f(0.0), vec3f(0.0), 0.0, 0.0, 0u);
}

struct Material {
	emission: vec3f,
	diffuse: vec3f,
}

@group(0) @binding(0)
var<uniform> uniforms: Uniforms;
// @group(0) @binding(1) var my_texture: texture_2d<f32>;
@group(0) @binding(2)
var<storage> jitter: array<vec2f>;
@group(0) @binding(3)
var<storage> vPositions: array<vec3f>;
@group(0) @binding(4)
var<storage> meshFaces: array<vec3u>;
@group(0) @binding(5)
var<storage> meshNormals: array<vec3f>;
@group(0) @binding(6)
var<storage> materials: array<Material>;
@group(0) @binding(7)
var<storage> matIndices: array<u32>;
@group(0) @binding(8)
var<storage> lightIndices: array<u32>;

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
	const t_max = 1e10;
	var q = uniforms.b1 * ipcoords.x + uniforms.b2 * ipcoords.y + uniforms.v * uniforms.camera_constant;
	var w = normalize(q);
	return Ray(uniforms.eye_point, w, 1e-4, t_max);
}

// Intersection functions
fn intersect_plane(r: Ray, hit: ptr<function, HitInfo>, position: vec3f, normal: vec3f) -> bool {
	var q = dot(r.direction, normal);
	if (abs(q) < 1e-4) {
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

fn intersect_triangle(r: Ray, hit: ptr<function, HitInfo>, i: u32) -> bool {
	// Retrieve triangle vertices
	let face = meshFaces[i];
	let v0 = vPositions[face.x];
	let v1 = vPositions[face.y];
	let v2 = vPositions[face.z];

	// Retrieve vertex normals
	let n0 = meshNormals[face.x];
	let n1 = meshNormals[face.y];
	let n2 = meshNormals[face.z];

	let e0 = v1 - v0;
	let e1 = v2 - v0;
	let n = cross(e0, e1);

	let q = dot(r.direction, n);
	if (abs(q) < 0.0001) {
		return false;
	}

	let a = v0 - r.origin;
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

	// Use barycentric interpolation for normal
	hit.normal = normalize(n0 * (1.0 - beta - gamma) + n1 * beta + n2 * gamma);

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
	if (t1 >= r.tmin && t1 <= r.tmax) {
		hit.has_hit = true;
		hit.distance = t1;
		hit.position = r.origin + r.direction * t1;
		hit.normal = normalize(hit.position - center);
		return true;
	}
	else {
		let t2 = - bhalf + sqrt_disc;
		if (t2 >= r.tmin && t2 <= r.tmax) {
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
	let light = sample_area_light(hit.position);
	var shadow_ray = Ray(hit.position, light.w_i, 0.001, light.dist - 0.001);
	var shadow_hit = default_hitinfo();
	if (intersect_scene(&shadow_ray, & shadow_hit)) {
		return hit.emission;
	}

	return (hit.diffuse / 3.14) * light.L_i * dot(hit.normal, light.w_i) + hit.emission;
}

fn phong(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
	let light = sample_point_light(hit.position);
	var shadow_ray = Ray(hit.position, light.w_i, 0.0001, light.dist);
	var shadow_hit = default_hitinfo();
	if (intersect_scene(&shadow_ray, & shadow_hit)) {
		return hit.emission;
	}

	let n = normalize(hit.normal);
	let wi = light.w_i;
	let wr = normalize(reflect(- wi, n));
	//NOTE: Reflect takes direction towards surface
	let wo = - r.direction;

	let wo_dot_wr = max(dot(wo, wr), 0);

	let Lr = ((hit.diffuse / 3.14) + (hit.specular * (hit.shininess + 2.0) / (2 * 3.14) * pow(wo_dot_wr, hit.shininess))) * light.L_i * dot(light.w_i, n);
	return Lr;
}

fn mirror(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
	let reflected_dir = reflect(r.direction, hit.normal);
	hit.has_hit = false;
	r.origin = hit.position;
	r.direction = reflected_dir;
	r.tmin = 1e-4;
	r.tmax = 100.0;
	return vec3f(0.0, 0.0, 0.0);
}

fn refraction(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
	var eta = hit.ior1_over_ior2;
	var n = hit.normal;

	var costhetai = dot(- r.direction, n);

	if (costhetai < 0.0) {
		eta = 1 / hit.ior1_over_ior2;
		n = - hit.normal;
	}

	costhetai = dot(- r.direction, n);

	let sin2thetai = 1.0 - costhetai * costhetai;
	let sinthetat = eta * sqrt(sin2thetai);
	let cos2thetat = 1.0 - eta * eta * sin2thetai;

	if (cos2thetat < 0.0) {
		return mirror(r, hit);
	}

	let t = (costhetai * n - (- r.direction)) / sqrt(sin2thetai);
	let tsinthetat = eta * (costhetai * n - (- r.direction));

	let refracted_dir = normalize(tsinthetat - n * sqrt(cos2thetat));

	hit.has_hit = false;
	r.origin = hit.position;
	r.direction = refracted_dir;
	r.tmin = 1e-4;
	r.tmax = 100.0;
	return vec3f(0.0, 0.0, 0.0);
}

fn shade(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> vec3f {
	switch hit.shader {
		case 1 {
			return lambertian(r, hit);
		}
		case 2 {
			return phong(r, hit);
		}
		case 3 {
			return mirror(r, hit);
		}
		case 4 {
			return refraction(r, hit);
		}
		case 5 {
			return phong(r, hit) + refraction(r, hit);
		}
		case default {
			return hit.diffuse + hit.emission;
		}
	}
}

struct Onb {
	tangent: vec3f,
	binormal: vec3f,
	normal: vec3f,
}

fn intersect_scene(r: ptr<function, Ray>, hit: ptr<function, HitInfo>) -> bool {
	const triangle_color = vec3f(0.9);
	let numTriangles = arrayLength(&meshFaces);
	for (var i = 0u; i < numTriangles; i++) {
		if (intersect_triangle(*r, hit, i)) {
			let mat = materials[matIndices[i]];
			hit.diffuse = mat.diffuse;
			hit.emission = mat.emission;
			hit.specular = vec3f(0.0, 0.0, 0.0);
			hit.shader = uniforms.triangle_shader;
			r.tmax = hit.distance;
		}
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

fn sample_directional_light(pos: vec3f) -> Light {
	var light = Light();
	let dir = normalize(vec3f(- 1.0));
	const intensity = vec3f(1.0) * 3.14;
	light.w_i = - dir;
	light.L_i = intensity;
	light.dist = 1.0e32;
	return light;
}

fn sample_area_light(pos: vec3f) -> Light {
	var light = Light();
	var light_position = vec3f(0.0);
	var light_intensity = vec3f(0.0);

	let numLights = arrayLength(&lightIndices);
	for (var i = 0u; i < numLights; i++) {
		let lightIndex = lightIndices[i];

		let face = meshFaces[lightIndex];

		let v0 = vPositions[face.x];
		let v1 = vPositions[face.y];
		let v2 = vPositions[face.z];

		let n0 = meshNormals[face.x];
		let n1 = meshNormals[face.y];
		let n2 = meshNormals[face.z];

		let center = (v0 + v1 + v2) / 3.0;
		let n = normalize(n0 + n1 + n2);

		light_position += center;

		// Compute triangle area
		let edge1 = v1 - v0;
		let edge2 = v2 - v0;
		let area = length(cross(edge1, edge2)) * 0.5;

		let w_i = normalize(center - pos); // This w_i is different from w_i used outside. However does not impact result significantly
		light_intensity += 	dot(-w_i, n) * materials[matIndices[lightIndex]].emission * area;
	}

	light_position /= f32(numLights);

	light.dist = length(light_position - pos);
	light.w_i = normalize(light_position - pos);
	light.L_i = light_intensity / (light.dist * light.dist);

	return light;
}

// Texture mapping
fn texture_nearest(texture: texture_2d<f32>, texcoords: vec2f, repeat: bool) -> vec3f {
	let res = textureDimensions(texture);
	var st = uv_to_st(texcoords);
	let ab = st * vec2f(res);
	let uv = vec2u(ab + 0.5) % res;
	let texcolor = textureLoad(texture, uv, 0);
	return texcolor.rgb;
}

fn texture_linear(texture: texture_2d<f32>, texcoords: vec2f, repeat: bool) -> vec3f {
	let res = textureDimensions(texture);
	var st = uv_to_st(texcoords);
	let ab = st * vec2f(res);

	let uv = vec2u(ab);
	let c = ab - vec2f(uv);

	let t1 = mix(textureLoad(texture, uv % res, 0), textureLoad(texture, (uv + vec2u(1, 0)) % res, 0), c.x);
	let t2 = mix(textureLoad(texture, (uv + vec2u(0, 1)) % res, 0), textureLoad(texture, (uv + vec2u(1, 1)) % res, 0), c.x);
	let texcolor = mix(t1, t2, c.y);
	return texcolor.rgb;
}

fn uv_to_st(uv: vec2f) -> vec2f {
	switch uniforms.texture_edge_mode {
		case 0u {
			// 0 = repeat, 1 = clamp
			return uv - floor(uv);
		}
		case 1u {
			return clamp(uv, vec2f(0.0), vec2f(1.0));
		}
		case default {
			return vec2f(uv);
			// Should not happen
		}
	}
}

fn texture_map(texture: texture_2d<f32>, texcoords: vec2f, repeat: bool) -> vec3f {
	switch uniforms.texture_interpolation {
		case 0u {
			// 0 = nearest, 1 = bilinear
			return texture_nearest(texture, texcoords, repeat);
		}
		case 1u {
			return texture_linear(texture, texcoords, repeat);
		}
		case default {
			return vec3f(1.0, 0.0, 1.0);
			// Magenta for error
		}
	}
}

// Main fragment shader
@fragment
fn main_fs(@location(0) coords: vec2f) -> @location(0) vec4f {
	const bgcolor = vec4f(0.1, 0.3, 0.6, 1.0);
	const max_depth = 10;
	let uv = vec2f(coords.x * uniforms.aspect * 0.5f, coords.y * 0.5f);
	let subpixels = uniforms.subpixels * uniforms.subpixels;
	var result = vec3f(0.0);
	for (var p = 0u; p < subpixels; p++) {
		let jit = jitter[p];
		var r = get_camera_ray(uv + jit);
		var hit = default_hitinfo();
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
	}
	return vec4f(pow(result / f32(subpixels), vec3f(1.0 / uniforms.gamma)), bgcolor.a);
}
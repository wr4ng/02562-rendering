"use strict";

async function load_texture(device, filename) {
	const response = await fetch(filename);
	const blob = await response.blob();
	const img = await createImageBitmap(blob, { colorSpaceConversion: 'none' });
	const texture = device.createTexture({
		size: [img.width, img.height, 1],
		format: "rgba8unorm",
		usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT
	});
	device.queue.copyExternalImageToTexture(
		{ source: img, flipY: true },
		{ texture: texture },
		{ width: img.width, height: img.height },
	);
	return texture;
}

function compute_jitters(jitter, pixelsize, subdivs) {
	const step = pixelsize / subdivs;
	if (subdivs < 2) {
		jitter[0] = 0.0;
		jitter[1] = 0.0;
	}
	else {
		for (var i = 0; i < subdivs; ++i)
			for (var j = 0; j < subdivs; ++j) {
				const idx = (i * subdivs + j) * 2;
				jitter[idx] = (Math.random() + j) * step - pixelsize * 0.5;
				jitter[idx + 1] = (Math.random() + i) * step - pixelsize * 0.5;
			}
	}
}

window.onload = function () { main(); }

async function main() {
	let gamma = 1.0;
	let cameraConstant = document.getElementById('zoom-slider').value;
	let planeShaderIndex = document.getElementById('plane-shader-select').value;
	let triangleShaderIndex = document.getElementById('triangle-shader-select').value;
	let sphereShaderIndex = document.getElementById('sphere-shader-select').value;
	let textureEnabled = document.getElementById('texture-enable').value;
	let textureEdgeMode = document.getElementById('texture-edge-mode').value;
	let textureInterpolation = document.getElementById('texture-interpolation').value;
	let textureScaling = document.getElementById('texture-scaling-slider').value;
	let subpixelCount = document.getElementById('subpixel-slider').value;

	document.getElementById('gamma-slider').oninput = (e) => {
		gamma = Number(e.target.value);
		document.getElementById('gamma-slider-label').innerText = `Gamma: ${gamma.toFixed(1)}`;
		requestAnimationFrame(render);
	}

	document.getElementById('zoom-slider').oninput = (e) => {
		cameraConstant = Number(e.target.value);
		document.getElementById('zoom-slider-label').innerText = `Zoom: ${cameraConstant.toFixed(1)}`;
		requestAnimationFrame(render);
	}

	document.getElementById('plane-shader-select').onchange = (e) => {
		planeShaderIndex = Number(e.target.value);
		requestAnimationFrame(render);
	}

	document.getElementById('triangle-shader-select').onchange = (e) => {
		triangleShaderIndex = Number(e.target.value);
		requestAnimationFrame(render);
	}

	document.getElementById('sphere-shader-select').onchange = (e) => {
		sphereShaderIndex = Number(e.target.value);
		requestAnimationFrame(render);
	}

	document.getElementById('texture-enable').onchange = (e) => {
		textureEnabled = Number(e.target.value);
		requestAnimationFrame(render);
	}

	document.getElementById('texture-edge-mode').onchange = (e) => {
		textureEdgeMode = Number(e.target.value);
		requestAnimationFrame(render);
	}

	document.getElementById('texture-interpolation').onchange = (e) => {
		textureInterpolation = Number(e.target.value);
		requestAnimationFrame(render);
	}

	document.getElementById('texture-scaling-slider').oninput = (e) => {
		textureScaling = Number(e.target.value);
		document.getElementById('texture-scaling-slider-label').innerText = `Texture Scaling: ${textureScaling.toFixed(1)}`;
		requestAnimationFrame(render);
	}

	document.getElementById('subpixel-slider').oninput = (e) => {
		subpixelCount = Number(e.target.value);
		document.getElementById('subpixel-slider-label').innerText = `Subpixels: ${subpixelCount}`;

		compute_jitters(jitter, 1 / canvas.height, subpixelCount);
		device.queue.writeBuffer(jitterBuffer, 0, jitter);

		requestAnimationFrame(render);
	}

	const gpu = navigator.gpu;
	const adapter = await gpu.requestAdapter();
	const device = await adapter.requestDevice();
	const canvas = document.getElementById('my-canvas');
	const context = canvas.getContext('webgpu');
	const canvasFormat = navigator.gpu.getPreferredCanvasFormat();
	context.configure({
		device: device,
		format: canvasFormat,
	});

	// Load WGSL file
	const wgslfile = document.getElementById('wgsl').src;
	const wgslcode
		= await fetch(wgslfile, { cache: "reload" }).then(r => r.text());
	const wgsl = device.createShaderModule({
		code: wgslcode
	});

	// Load texture
	const texture = await load_texture(device, './grass.jpg');

	// Load model
	const obj_filename = 'data/teapot.obj';
	const obj = await readOBJFile(obj_filename, 1, true); // file name, scale, ccw vertices

	const positionBuffer = device.createBuffer({
		size: obj.vertices.byteLength,
		usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE
	});
	device.queue.writeBuffer(positionBuffer, 0, obj.vertices);
	const indexBuffer = device.createBuffer({
		size: obj.indices.byteLength,
		usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE
	});
	device.queue.writeBuffer(indexBuffer, 0, obj.indices);

	// Setup pipeline
	const pipeline = device.createRenderPipeline({
		layout: 'auto',
		vertex: { module: wgsl, entryPoint: 'main_vs' },
		fragment: {
			module: wgsl,
			entryPoint: 'main_fs',
			targets: [{ format: canvasFormat }],
		},
		primitive: { topology: 'triangle-strip', },
	});

	// Jitter buffer
	let jitter = new Float32Array(200); // allowing subdivs from 1 to 10
	const jitterBuffer = device.createBuffer({
		size: jitter.byteLength,
		usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE
	});
	compute_jitters(jitter, 1 / canvas.height, subpixelCount);
	device.queue.writeBuffer(jitterBuffer, 0, jitter);

	// Setup uniforms buffer
	let bytelength = 7 * sizeof['vec4']; // Buffers are allocated in vec4 chunks
	let uniforms = new ArrayBuffer(bytelength);
	const uniformBuffer = device.createBuffer({
		size: uniforms.byteLength,
		usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
	});
	const bindGroup = device.createBindGroup({
		layout: pipeline.getBindGroupLayout(0),
		entries: [
			{
				binding: 0,
				resource: { buffer: uniformBuffer }
			},
			{
				binding: 1,
				resource: texture.createView()
			},
			{
				binding: 2,
				resource: { buffer: jitterBuffer }
			},
			{
				binding: 3,
				resource: { buffer: positionBuffer }
			},
			{
				binding: 4,
				resource: { buffer: indexBuffer }
			},
		],
	});

	const eye = vec3(0.15, 1.5, 10.0);
	const look = vec3(0.15, 1.5, 0.0);
	const up = vec3(0.0, 1.0, 0.0);

	const v = normalize(subtract(look, eye));
	const b1 = normalize(cross(v, up));
	const b2 = normalize(cross(b1, v));

	const aspect = canvas.width / canvas.height;

	function render() {
		// Write updated values to uniform buffer
		new Float32Array(uniforms, 0, 4 * 7).set([
			aspect, cameraConstant, gamma, textureScaling,
			0.0, 0.0, 0.0, 0.0,
			0.0, 0.0, 0.0, 0.0,
			...eye, 0.0,
			...b1, 0.0,
			...b2, 0.0,
			...v, 0.0,
		]);
		new Uint32Array(uniforms, 4 * 4, 7).set([
			planeShaderIndex,
			triangleShaderIndex,
			sphereShaderIndex,
			textureEnabled,
			textureEdgeMode,
			textureInterpolation,
			subpixelCount,
		]);
		device.queue.writeBuffer(uniformBuffer, 0, uniforms);

		// Create a render pass in a command buffer and submit it
		const encoder = device.createCommandEncoder();
		const pass = encoder.beginRenderPass({
			colorAttachments: [{
				view: context.getCurrentTexture().createView(),
				loadOp: "clear",
				storeOp: "store",
			}]
		});
		// Insert render pass commands here
		pass.setPipeline(pipeline);
		pass.setBindGroup(0, bindGroup);
		pass.draw(4); // 4 vertices (corners of quad)

		pass.end();
		device.queue.submit([encoder.finish()]);
	}

	render();
} 

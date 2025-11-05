"use strict";

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

function setupOptions(callback) {
	const sliders = [
		['gamma-slider', 'Gamma'],
		['zoom-slider', 'Zoom'],
		['subpixel-slider', 'Subpixels'],
	];
	const selects = [
		'triangle-shader-select',
	];

	sliders.forEach(([id, label]) => {
		document.getElementById(id).oninput = (e) => {
			document.getElementById(`${id}-label`).innerText = `${label}: ${e.target.value}`;
			callback();
		}
	});

	selects.forEach(id => {
		document.getElementById(id).onchange = (e) => {
			callback();
		}
	});

	document.getElementById('render-button').onclick = () => {
		callback();
	};
}

function getOptions() {
	const gamma = document.getElementById('gamma-slider').value;
	const cameraConstant = document.getElementById('zoom-slider').value;
	const triangleShaderIndex = document.getElementById('triangle-shader-select').value;
	const subpixelCount = document.getElementById('subpixel-slider').value;

	return {
		gamma,
		cameraConstant,
		triangleShaderIndex,
		subpixelCount,
	};
}

window.onload = function () { main(); }

async function main() {
	const gpu = navigator.gpu;
	const adapter = await gpu.requestAdapter();

	const canTimestamp = adapter.features.has('timestamp-query');
	const device = await adapter.requestDevice({
		requiredFeatures: [
			...(canTimestamp ? ['timestamp-query'] : []),
		],
	});
	const timingHelper = new TimingHelper(device);
	let gpuTime = 0;

	const canvas = document.getElementById('my-canvas');
	const context = canvas.getContext('webgpu');
	const canvasFormat = navigator.gpu.getPreferredCanvasFormat();
	context.configure({
		device: device,
		format: canvasFormat,
	});

	// Load options
	let { subpixelCount } = getOptions();

	// Load WGSL file
	const wgslfile = document.getElementById('wgsl').src;
	const wgslcode
		= await fetch(wgslfile, { cache: "reload" }).then(r => r.text());
	const wgsl = device.createShaderModule({
		code: wgslcode
	});

	const models = {
		'CornellBoxWithBlocks': {
			path: 'data/CornellBoxWithBlocks.obj',
			eye: vec3(277.0, 275.0, -570.0),
			look: vec3(277.0, 275.0, 0.0),
			up: vec3(0.0, 1.0, 0.0),
		},
	}
	const model = models['CornellBoxWithBlocks'];
	const obj = await readOBJFile(model.path, 1.0, true); // file name, scale, ccw vertices

	const buffers = {};
	build_bsp_tree(obj, device, buffers);

	// Load materials
	let mat_bytelength = obj.materials.length * 2 * sizeof['vec4'];
	var materials = new ArrayBuffer(mat_bytelength);
	const materialBuffer = device.createBuffer({
		size: mat_bytelength,
		usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE,
	});
	for (var i = 0; i < obj.materials.length; ++i) {
		const mat = obj.materials[i];
		const emission = vec4(mat.emission.r, mat.emission.g, mat.emission.b, mat.emission.a);
		const color = vec4(mat.color.r, mat.color.g, mat.color.b, mat.color.a);
		new Float32Array(materials, i * 2 * sizeof['vec4'], 8).set([...emission, ...color]);
	}
	device.queue.writeBuffer(materialBuffer, 0, materials);

	const lightidxBuffer = device.createBuffer({
		size: obj.light_indices.byteLength,
		usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE
	});
	device.queue.writeBuffer(lightidxBuffer, 0, obj.light_indices);

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
				resource: { buffer: jitterBuffer }
			},
			{
				binding: 2,
				resource: { buffer: buffers.attribs }
			},
			// {
			// 	binding: 2,
			// 	resource: { buffer: buffers.positions }
			// },
			{
			binding: 3,
			resource: { buffer: buffers.indices }
			},
			// {
			// 	binding: 4,
			// 	resource: { buffer: buffers.normals }
			// },
			{
				binding: 5,
				resource: { buffer: materialBuffer }
			},
			{
				binding: 6,
				resource: { buffer: buffers.aabb }
			},
			{
				binding: 7,
				resource: { buffer: buffers.treeIds }
			},
			{
				binding: 8,
				resource: { buffer: buffers.bspTree }
			},
			{
				binding: 9,
				resource: { buffer: buffers.bspPlanes }
			},
			{
				binding: 10,
				resource: { buffer: lightidxBuffer }
			},
		],
	});

	// const eye = vec3(0.15, 1.5, 10.0);
	// const look = vec3(0.15, 1.5, 0.0);
	// const up = vec3(0.0, 1.0, 0.0);
	const { eye, look, up } = model;

	const v = normalize(subtract(look, eye));
	const b1 = normalize(cross(v, up));
	const b2 = normalize(cross(b1, v));

	const aspect = canvas.width / canvas.height;

	function render() {
		// Load options
		let {
			gamma,
			cameraConstant,
			triangleShaderIndex,
			subpixelCount,
		} = getOptions();

		// Write updated values to uniform buffer
		new Float32Array(uniforms, 0, 4 * 7).set([
			aspect, cameraConstant, gamma, 0.0,
			0.0, 0.0, 0.0, 0.0,
			...eye, 0.0,
			...b1, 0.0,
			...b2, 0.0,
			...v, 0.0,
		]);
		new Uint32Array(uniforms, 4 * 3, 2).set([
			triangleShaderIndex,
			subpixelCount,
		]);
		device.queue.writeBuffer(uniformBuffer, 0, uniforms);

		// Timing
		const timingHelper = new TimingHelper(device);


		// Create a render pass in a command buffer and submit it
		const encoder = device.createCommandEncoder();
		const pass = timingHelper.beginRenderPass(encoder, {
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
		timingHelper.getResult().then(time => {
			gpuTime = time / 1000000; // Convert to ms
			console.log(`GPU time: ${gpuTime.toFixed(3)} ms`);
		});
	}

	setupOptions(render);
	render();
} 

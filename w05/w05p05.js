"use strict";

window.onload = function () { main(); }

async function main() {
	let gamma = document.getElementById('gamma-slider').value;
	let cameraConstant = document.getElementById('zoom-slider').value;
	let triangleShaderIndex = document.getElementById('triangle-shader-select').value;

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

	document.getElementById('triangle-shader-select').onchange = (e) => {
		triangleShaderIndex = Number(e.target.value);
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

	// Load model
	const obj_filename = 'data/CornellBoxWithBlocks.obj';
	const obj = await readOBJFile(obj_filename, 1, true); // file name, scale, ccw vertices

	const positionBuffer = device.createBuffer({
		size: obj.vertices.byteLength,
		usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE
	});
	device.queue.writeBuffer(positionBuffer, 0, obj.vertices);

	const normalBuffer = device.createBuffer({
		size: obj.normals.byteLength,
		usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE
	});
	device.queue.writeBuffer(normalBuffer, 0, obj.normals);

	const indexBuffer = device.createBuffer({
		size: obj.indices.byteLength,
		usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE
	});
	device.queue.writeBuffer(indexBuffer, 0, obj.indices);

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

	const matidxBuffer = device.createBuffer({
		size: obj.mat_indices.byteLength,
		usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE
	});
	device.queue.writeBuffer(matidxBuffer, 0, obj.mat_indices);

	//TODO: Why does this bindgroup not work?
	const lightidxBuffer = device.createBuffer({
		size: 8,
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
			{ binding: 0, resource: { buffer: uniformBuffer } },
			{ binding: 1, resource: { buffer: positionBuffer } },
			{ binding: 2, resource: { buffer: indexBuffer } },
			{ binding: 3, resource: { buffer: normalBuffer } },
			{ binding: 4, resource: { buffer: materialBuffer } },
			{ binding: 5, resource: { buffer: matidxBuffer } },
			{ binding: 6, resource: { buffer: lightidxBuffer } },

		],
	});

	const eye = vec3(277.0, 275.0, -570.0);
	const look = vec3(277.0, 275.0, 0.0);
	const up = vec3(0.0, 1.0, 0.0);

	const v = normalize(subtract(look, eye));
	const b1 = normalize(cross(v, up));
	const b2 = normalize(cross(b1, v));

	const aspect = canvas.width / canvas.height;

	function render() {
		// Write updated values to uniform buffer
		new Float32Array(uniforms, 0, 4 * 7).set([
			aspect, cameraConstant, gamma, 0.0,
			...eye, 0.0,
			...b1, 0.0,
			...b2, 0.0,
			...v, 0.0,
		]);
		new Uint32Array(uniforms, 4 * 3, 1).set([
			triangleShaderIndex,
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

"use strict";

window.onload = function () { main(); }

async function main() {
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
	let bytelength = 5 * sizeof['vec4']; // Buffers are allocated in vec4 chunks
	let uniforms = new ArrayBuffer(bytelength);
	const uniformBuffer = device.createBuffer({
		size: uniforms.byteLength,
		usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
	});
	const bindGroup = device.createBindGroup({
		layout: pipeline.getBindGroupLayout(0),
		entries: [{
			binding: 0,
			resource: { buffer: uniformBuffer }
		}],
	});

	const eye = vec3(2.0, 1.5, 2.0);
	const look = vec3(0.0, 0.5, 0.0);
	const up = vec3(0.0, 1.0, 0.0);
	const v = normalize(subtract(look, eye));
	const b1 = normalize(cross(v, up));
	const b2 = cross(b1, v);
	const aspect = canvas.width / canvas.height;
	const cam_const = 1.0;
	new Float32Array(uniforms, 0, 4 * 5).set([
		aspect,
		cam_const,
		0.0,
		0.0,
		...eye,
		0.0,
		...b1,
		0.0,
		...b2,
		0.0,
		...v,
		0.0]
	);
	device.queue.writeBuffer(uniformBuffer, 0, uniforms);

	function render() {
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

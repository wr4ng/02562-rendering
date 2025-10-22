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
	pass.draw(4);

	pass.end();
	device.queue.submit([encoder.finish()]);
} 

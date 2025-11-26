"use strict";

window.onload = function () { main(); }

async function main() {
	var myHDR = new HDRImage();
	myHDR.src = 'park_music_stage_4k.hdr';
	myHDR.onload = function () {
		myHDR.toHDRBlob(function (blob) {
			var a = document.createElement('a');
			a.href = URL.createObjectURL(blob);
			a.download = 'park_music_stage_4k.RGBE.PNG';
			a.innerHTML = 'click to save';
			document.body.appendChild(a);
		});
	};
}

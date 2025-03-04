THREE = require "three"
$ = require 'jquery'

{ EffectComposer } = require 'three/examples/jsm/postprocessing/EffectComposer.js'
{ RenderPass } = require 'three/examples/jsm/postprocessing/RenderPass.js'
{ AfterimagePass } = require 'three/examples/jsm/postprocessing/AfterimagePass.js'
{ UnrealBloomPass } = require 'three/examples/jsm/postprocessing/UnrealBloomPass.js'
{ ShaderPass } = require 'three/examples/jsm/postprocessing/ShaderPass.js'

{ LuminosityHighPassShader } = require 'three/examples/jsm/shaders/LuminosityHighPassShader.js'

# Hack to trick esbuild to not try to bundle up the node module.
# Esbuild seems to pass through non-constant-string requires.
# There's probably a nicer way to do this.
require_node = (module) -> require module
USE_NODE = typeof nw != 'undefined'
if USE_NODE
	waa = require_node 'node-web-audio-api'
	Object.assign globalThis, waa
	fs = require_node 'fs'
	
	win = nw.Window.get()
	nw.App.registerGlobalHotKey new nw.Shortcut
		key: "F11"
		active: -> win.toggleFullscreen()
	nw.App.registerGlobalHotKey new nw.Shortcut
		key: "ctrl+r"
		active: -> win.reloadIgnoringCache()
else
	globalThis.mediaDevices = navigator.mediaDevices

speed_of_sound = 331 # 0⁰C
class Reflector
	constructor: (@ctx, @_state) ->
		@gainer = ctx.createGain()
		@delayer = ctx.createDelay()
		@panner = ctx.createStereoPanner()
		
		@gainer.connect(@delayer).connect(@panner)

		@input = @gainer
		@output = @panner

		@update(0)
	
	set_listener: (listener) ->
		@_state.listener = listener
		@update()

	update: (transition=0.1) ->
		{position, listener, decay} = @_state
		rel_pos = position - listener
		length = Math.abs(rel_pos)*2
		# Hacky supergain
		@gain = 20/(1 + length)
		@gain = Math.min 0.2, @gain
		@delay = length/speed_of_sound
		@panning = Math.sign(rel_pos)
		at = @ctx.currentTime + transition

		@gainer.gain.linearRampToValueAtTime @gain, at
		@delayer.delayTime.linearRampToValueAtTime @delay, at
		#@panner.pan.linearRampToValueAtTime @panning, at


ctx = new AudioContext latency_hint: "interactive"

input = new GainNode(ctx)
output = new GainNode(ctx)
input.connect output
output.connect ctx.destination

acoustics = new GainNode ctx
acoustics_only = new GainNode(ctx)
acoustics.connect output


init_listener = 40
reflectors = [0, 120].map (position) ->
	r = new Reflector(ctx, {listener: init_listener, position})
	input.connect r.input
	acoustics_only.connect r.input
	r.output.connect acoustics
	return r

move_listener = (position) ->
	# TODO: Reactive
	$("#distance_value").text position.toFixed 1
	r.set_listener position for r in reflectors
move_listener init_listener

load_sample = (url) ->
	if USE_NODE
		buf = fs.readFileSync(url).buffer
	else
		buf = await fetch url
		buf = await buf.arrayBuffer()
	buf = await ctx.decodeAudioData(buf)
	buf.channelInterpretation = "speakers"
	return buf
	
play_sample = (sample, dst=input) ->
	src = ctx.createBufferSource()
	src.buffer = sample
	src.connect dst
	src.start()

last_beat_time = null
play_drum = (sample, dst=input) ->
	play_sample sample, dst
	time = performance.now()/1000
	dt = time - last_beat_time
	last_beat_time = time
	bpm = 1/dt*60
	$("#bpm_value").html Math.round bpm

beat_interval = reflectors[0].delay*3
loop_on = false
setInterval (->
	return if not loop_on
	play_drum drum_sample
	
	),
	beat_interval*1000

shaman_sample = await load_sample "shaman_trimmed.wav"
snare_sample = await load_sample "snare_trimmed.wav"
drum_sample = shaman_sample

singing_sample = await load_sample "singing.wav"

analyser = ctx.createAnalyser()
analyser.fftSize = 1024*2
analyser_data = new Float32Array(analyser.frequencyBinCount)
acoustics.connect analyser

$(document).one "keydown mousedown pointerdown pointerup touchend", ->
	ctx.resume()
	mic_dev = await mediaDevices.getUserMedia
		audio:
			echoCancellation: false
			noiseSupression: false
			autoGainControl: false
	
	mic_raw = ctx.createMediaStreamSource mic_dev
	mic = ctx.createChannelMerger 1
	mic_raw.connect mic
	mic.connect acoustics_only

$(window).on "message", ({originalEvent}) ->
	switch originalEvent.data
		when "slide:start"
			ctx.resume()
		when "slide:stop"
			ctx.suspend()

$(document).on "keydown", (ev) ->
	ev = ev.originalEvent
	return if ev.repeat
	if ev.key == " "
		play_drum drum_sample
	
	if ev.key == "m"
		if acoustics.gain.value == 0
			acoustics.gain.value = 1
		else
			acoustics.gain.value = 0
	
	if ev.key == ","
		drum_sample = switch drum_sample
			when shaman_sample then snare_sample
			when snare_sample then shaman_sample
			else shaman_sample
	
	if ev.key == "l"
		loop_on = not loop_on

	if ev.key == "n"
		play_sample singing_sample

```
let camera, scene, renderer, mesh, composer, bloomPass, material;

let isUserInteracting = false,
	onPointerDownMouseX = 0, onPointerDownMouseY = 0,
	lon = 0, onPointerDownLon = 0,
	lat = 0, onPointerDownLat = 0,
	phi = 0, theta = 0;
lat = 15;
let time = null;
let speed_x = 0;
let speed_z = 0;
//let FOV = 75;
let FOV = 45;

const sphere_radius = 40;
init();
animate();

function init() {

	const container = document.getElementById( 'container' );

	camera = new THREE.PerspectiveCamera( FOV, window.innerWidth / window.innerHeight, 1, 1100 );

	scene = new THREE.Scene();

	const geometry = new THREE.SphereGeometry( sphere_radius, 60, 40 );
	// invert the geometry on the x-axis so that all of the faces point inward
	geometry.scale( - 1, 1, 1 );

	const texture = new THREE.TextureLoader().load( 'pano0006.jpg' );
	const texture_overlay = new THREE.TextureLoader().load( 'pano0006_paintings.png' );
	texture.colorSpace = THREE.SRGBColorSpace;
	texture_overlay.colorSpace = THREE.SRGBColorSpace;
	//const material = new THREE.MeshBasicMaterial( { map: texture } );
	
	material = new THREE.ShaderMaterial({
	  uniforms: {
	    texture1: { value: texture },
	    texture2: { value: texture_overlay },
	    blendFactor: { value: 0.0 } // Adjustable additive intensity
	  },
	  vertexShader: \`
	    varying vec2 vUv;
	    void main() {
	      vUv = uv;
	      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
	    }
	  \`,
	  fragmentShader: \`
	    uniform sampler2D texture1;
	    uniform sampler2D texture2;
	    uniform float blendFactor;
	    varying vec2 vUv;
	    
	    void main() {
	      vec4 color1 = texture2D(texture1, vUv);
	      vec4 color2 = texture2D(texture2, vUv);
	      
	      // Additive blending
	      vec4 blendedColor = color1 + color2 * blendFactor;
	      blendedColor.a = 1.0; // Ensure alpha is valid
	      
	      gl_FragColor = blendedColor;
	    }
	  \`,
	  transparent: true // Allow transparency
	});



	mesh = new THREE.Mesh( geometry, material );
	mesh.rotateY(Math.PI);
	scene.add( mesh );

	renderer = new THREE.WebGLRenderer();
	renderer.setPixelRatio( window.devicePixelRatio );
	renderer.setSize( window.innerWidth, window.innerHeight );
	renderer.toneMapping = THREE.LinearToneMapping;
	//renderer.toneMapping = THREE.ACESFilmicToneMapping;
	//renderer.toneMapping = THREE.ReinhardToneMapping;
	//renderer.toneMapping = THREE.CineonToneMapping;
	renderer.toneMappingExposure = 3.0;

	composer = new EffectComposer(renderer);
	const renderPass = new RenderPass(scene, camera);
	composer.addPass(renderPass);

	const afterimagePass = new AfterimagePass();
	afterimagePass.uniforms['damp'].value = 0.9; // Adjust between 0 (no blur) to 1 (strong blur)
	composer.addPass(afterimagePass);

	bloomPass = new UnrealBloomPass(undefined)//, 1.5, 0.4, 0.85)
	composer.addPass(bloomPass)
	
	container.appendChild( renderer.domElement );

	container.style.touchAction = 'none';
	container.addEventListener( 'pointerdown', onPointerDown );

	document.addEventListener( 'wheel', onDocumentMouseWheel );

	//

	document.addEventListener( 'dragover', function ( event ) {

		event.preventDefault();
		event.dataTransfer.dropEffect = 'copy';

	} );

	document.addEventListener( 'dragenter', function () {

		document.body.style.opacity = 0.5;

	} );

	document.addEventListener( 'dragleave', function () {

		document.body.style.opacity = 1;

	} );

	document.addEventListener( 'drop', function ( event ) {

		event.preventDefault();

		const reader = new FileReader();
		reader.addEventListener( 'load', function ( event ) {

			material.map.image.src = event.target.result;
			material.map.needsUpdate = true;

		} );
		reader.readAsDataURL( event.dataTransfer.files[ 0 ] );

		document.body.style.opacity = 1;

	} );

	//

	window.addEventListener( 'resize', onWindowResize );

	document.addEventListener( 'keydown', (event) => {
		if(event.key == "w") {
			speed_x = 1;
		}

		if(event.key == "s") {
			speed_x = -1;
		}

		if(event.key == "a") {
			speed_z = -1;
		}

		if(event.key == "d") {
			speed_z = 1;
		}
	});

	document.addEventListener( 'keyup', (event) => {
		if(event.key == "w") {
			speed_x = 0;
		}

		if(event.key == "s") {
			speed_x = 0;
		}

		if(event.key == "a") {
			speed_z = 0;
		}

		if(event.key == "d") {
			speed_z = 0;
		}
	});

}

function onWindowResize() {

	camera.aspect = window.innerWidth / window.innerHeight;
	camera.updateProjectionMatrix();

	renderer.setSize( window.innerWidth, window.innerHeight );

}

function onPointerDown( event ) {

	if ( event.isPrimary === false ) return;

	isUserInteracting = true;

	onPointerDownMouseX = event.clientX;
	onPointerDownMouseY = event.clientY;

	onPointerDownLon = lon;
	onPointerDownLat = lat;

	document.addEventListener( 'pointermove', onPointerMove );
	document.addEventListener( 'pointerup', onPointerUp );

}

function onPointerMove( event ) {

	if ( event.isPrimary === false ) return;

	lon = ( onPointerDownMouseX - event.clientX ) * 0.1 + onPointerDownLon;
	lat = ( event.clientY - onPointerDownMouseY ) * 0.1 + onPointerDownLat;

}

function onPointerUp() {

	if ( event.isPrimary === false ) return;

	isUserInteracting = false;

	document.removeEventListener( 'pointermove', onPointerMove );
	document.removeEventListener( 'pointerup', onPointerUp );

}

function onDocumentMouseWheel( event ) {

	const fov = camera.fov + event.deltaY * 0.05;

	camera.fov = THREE.MathUtils.clamp( fov, 10, 75 );

	camera.updateProjectionMatrix();

}

function animate(timestamp) {
	let prev_time = time;
	time = timestamp/1000;
	let dt = time - prev_time;
	if(dt != dt) {
		dt = 0;
	}
	update(dt);
	requestAnimationFrame( animate );

}

var scale = 0;
var scale2 = 0;
var cumEnergy = 0.0;
var rattle_phase = 0.0;
var bloom_phase = 0.0;
function update(dt) {
	if(dt == 0) {
		return
	}
	/**
	analyser.getFloatTimeDomainData(analyser_data)
	let energy = 0.0;
	for(let i=0; i < analyser_data.length; ++i) {
		energy += (analyser_data[i]**2)/analyser_data.length
	}

	cumEnergy += energy
	
	let scale = 1 + Math.sin(time*2*Math.PI)*0.5
	console.log(scale)
	mesh.scale.set(scale, scale, scale)
	**/

	// TODO: Rattle on sound!?!
	lat = Math.max( - 85, Math.min( 85, lat ) );
	phi = THREE.MathUtils.degToRad( 90 - lat );
	theta = THREE.MathUtils.degToRad( lon );
	
	//const sway1_freq = 0.3;
	const sway1_freq = 0.15;
	const sway2_freq = sway1_freq*0.2;
	//const sway_amp = THREE.MathUtils.degToRad(1);
	
	
	//phi += sway1*THREE.MathUtils.degToRad(0.2);
	//theta += sway2*THREE.MathUtils.degToRad(0.5);
	

	
	analyser.getFloatTimeDomainData(analyser_data);
	let mean = analyser_data.reduce((total, x) => total += Math.abs(x), 0)/analyser_data.length;
	mean *= 500.0
	mean = Math.min(1, mean)
	let smooth = Math.exp(-dt/0.2) 
	scale = scale*smooth + mean*(1 - smooth);

	let smooth2 = Math.exp(-dt/10.0)
	
	scale2 = scale2*(smooth2) + mean*(1 - smooth2);
	
	let listener_position = init_listener - scale2**4*30
	
	//let rattle = scale
	rattle_phase += (scale2**4*20*Math.PI*2)*dt
	//let rattle = Math.sin(time*2*Math.PI*23)*(scale**4)*0.25 + scale*0.5 + scale2**4*25 //*scale*0.5
	let rattle = Math.sin(rattle_phase)*scale2**20*0.6 + scale*0.5 //+ scale2**4*30 //*scale*0.5
	
	// TODO: Heartbeat-like pulse
	let bloom_bpm = 120*scale2**4
	//let bloom_freq = bloom_bpm/60
	let bloom_freq = 1/(listener_position*2/speed_of_sound)/4
	bloom_phase += (bloom_freq*Math.PI*2)*dt
	bloom_phase = bloom_phase%(2*Math.PI*2)
	bloomPass.strength = (scale2**3*(0.8 + 0.2*(Math.sin(bloom_phase) + 1)/2))**2*5
	//bloomPass.strength = scale2**4*mean**4*5

	camera.fov = FOV - rattle
	camera.updateProjectionMatrix();
	
	let sway_amp = THREE.MathUtils.degToRad(0.5);
	//sway_amp *= (1 + scale2**4)*2
	
	material.uniforms.blendFactor.value = scale2**20
	
	$("#distance_value").text((scale2**4).toFixed(1))
	

	$("#instructions_container").css({
		opacity: 1 - scale2*1.2,
		left: (0.05 - scale2*5)*100 + "%"
	})
	
	let sway1 = Math.sin(time*sway1_freq*2*Math.PI);
	let sway2 = Math.sin(time*sway2_freq*2*Math.PI);

	phi += sway1*sway_amp/2;
	theta += sway2*sway_amp;
	//console.log(scale);
	//mesh.scale.set(scale, scale, scale);
	//mesh.matrixWorldNeedsUpdate = true;
	//mesh.updateMatrix();
	
	const x = sphere_radius * Math.sin( phi ) * Math.cos( theta );
	let y = sphere_radius * Math.cos( phi );
	const z = sphere_radius * Math.sin( phi ) * Math.sin( theta );
	
	// TODO: Do in camera local coordinates?
	//camera.position.x += 3*speed_x*dt;
	//camera.position.z += 3*speed_z*dt;
	camera.position.x = sphere_radius - listener_position
	move_listener(listener_position)

	//if(speed_x) {
	//	move_listener(sphere_radius - camera.position.x);
	//}

	camera.lookAt( x + camera.position.x, y, z + camera.position.z );
	
	//renderer.render( scene, camera );
	composer.render()

}
```

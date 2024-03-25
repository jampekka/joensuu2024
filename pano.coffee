THREE = require "three"
$ = require 'jquery'
mediaDevices = navigator.mediaDevices


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
		@gain = 10/(1 + length)
		@gain = Math.min 0.2, @gain
		@delay = length/speed_of_sound
		@panning = Math.sign(rel_pos)
		at = @ctx.currentTime + transition

		@gainer.gain.linearRampToValueAtTime @gain, at
		@delayer.delayTime.linearRampToValueAtTime @delay, at
		@panner.pan.linearRampToValueAtTime @panning, at


ctx = new AudioContext latency_hint: "interactive"

input = new GainNode(ctx)
input.connect ctx.destination

acoustics = new GainNode ctx
acoustics_only = new GainNode(ctx)
acoustics.connect ctx.destination


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




drum_sample = await load_sample "shaman_trimmed.wav"

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
	
	if ev.key == "l"
		loop_on = not loop_on

```
let camera, scene, renderer;

let isUserInteracting = false,
	onPointerDownMouseX = 0, onPointerDownMouseY = 0,
	lon = 0, onPointerDownLon = 0,
	lat = 0, onPointerDownLat = 0,
	phi = 0, theta = 0;
lat = 15;
let time = null;
let speed_x = 0;
let speed_z = 0;

const sphere_radius = 40;
init();
animate();

function init() {

	const container = document.getElementById( 'container' );

	camera = new THREE.PerspectiveCamera( 75, window.innerWidth / window.innerHeight, 1, 1100 );

	scene = new THREE.Scene();

	const geometry = new THREE.SphereGeometry( sphere_radius, 60, 40 );
	// invert the geometry on the x-axis so that all of the faces point inward
	geometry.scale( - 1, 1, 1 );

	const texture = new THREE.TextureLoader().load( 'pano0006.jpg' );
	texture.colorSpace = THREE.SRGBColorSpace;
	const material = new THREE.MeshBasicMaterial( { map: texture } );

	const mesh = new THREE.Mesh( geometry, material );
	mesh.rotateY(Math.PI);
	scene.add( mesh );

	renderer = new THREE.WebGLRenderer();
	renderer.setPixelRatio( window.devicePixelRatio );
	renderer.setSize( window.innerWidth, window.innerHeight );
	renderer.toneMapping = THREE.LinearToneMapping;
	//renderer.toneMapping = THREE.ACESFilmicToneMapping;
	//renderer.toneMapping = THREE.ReinhardToneMapping;
	//renderer.toneMapping = THREE.CineonToneMapping;
	renderer.toneMappingExposure = 2.0;
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

function update(dt) {
	// TODO: Rattle on sound!?!
	lat = Math.max( - 85, Math.min( 85, lat ) );
	phi = THREE.MathUtils.degToRad( 90 - lat );
	theta = THREE.MathUtils.degToRad( lon );
	
	const sway1_freq = 0.3;
	const sway2_freq = sway1_freq*0.2;
	const sway_amp = THREE.MathUtils.degToRad(1);
	
	let sway1 = Math.sin(time*sway1_freq*2*Math.PI);
	let sway2 = Math.sin(time*sway2_freq*2*Math.PI);
	
	phi += sway1*THREE.MathUtils.degToRad(0.2);
	theta += sway2*THREE.MathUtils.degToRad(0.5);

	const x = sphere_radius * Math.sin( phi ) * Math.cos( theta );
	let y = sphere_radius * Math.cos( phi );
	const z = sphere_radius * Math.sin( phi ) * Math.sin( theta );
	
	// TODO: Do in camera local coordinates?
	camera.position.x += 3*speed_x*dt;
	camera.position.z += 3*speed_z*dt;

	if(speed_x) {
		move_listener(sphere_radius - camera.position.x);
	}

	camera.lookAt( x + camera.position.x, y, z + camera.position.z );
	
	renderer.render( scene, camera );

}
```

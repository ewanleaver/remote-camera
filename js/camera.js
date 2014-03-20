//var SKYWAY_APIKEY = "4362638a-9e84-11e3-9939-47b360702393";
var SKYWAY_APIKEY = "b0a007fa-af27-11e3-b735-7312b2da93b5";

// Media compatability
navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia;


function makeid()
{
    var text = "";
    var possible = "0123456789";

    for( var i=0; i < 4; i++ )
        text += possible.charAt(Math.floor(Math.random() * possible.length));

    return text;
}

// Connect to Skyway, have server assign an ID instead of providing one
var peer = new Peer (makeid(), { key: SKYWAY_APIKEY }); // Skyway API key

// Track all connections
var connectedPeers = {};

// Show this peer's ID.
peer.on('open', function(id){
	console.log('My peer ID is: ' + id);
  	$('#my-id').text(id); // Instead assign it to HTML id my-id
});

// Receiving a call
peer.on('call', function(call){
		// Answer the call automatically (instead of prompting user) for demo purposes
		//call.answer(window.localStream);
		call.answer();
		step3(call);
});

peer.on('error', function(err){
		alert(err.message);
		// Return to step 2 if error occurs
});

function step1() {
		// Get audio/video stream
		navigator.getUserMedia({audio: false, video: true}, function(stream){
		// Set your video displays
		//$('#my-video').prop('src', URL.createObjectURL(stream));

		window.localStream = stream;

		}, function(){ $('#step1-error').show(); });
}

function step3 (call) {
		// Hang up on an existing call if present
		if (window.existingCall) {
		window.existingCall.close();
		}

		// Wait for stream on the call, then set peer video display
		call.on('stream', function(stream){
		$('#camera').prop('src', URL.createObjectURL(stream));
		});

		// UI stuff
		window.existingCall = call;
		$('#callto-id').text(call.peer);


		// PC side?
		$('.pc-ui').hide();
    	$('.connected-ui').show();
		$('#step3').show();
}

// Handle a connection object.
function connect(c) {

	// Handle a call connection.
  	if (c.label === 'call') {
    	$('.status-area').addClass('active').attr('id', c.peer);
    	var header = $('<div style="font-size:18px; padding-top:5px">Connection with <strong>' + c.peer + '</strong></div>');
    	var messages = $('<div><em>  Peer connected.</em></div>').addClass('messages');
    	$('.status-area').append(header);
    	$('.status-area').append(messages);

    	var shutter_sound = document.createElement("audio"); 
    	shutter_sound.setAttribute("src", "resources/shutter.wav");

    	/*
    	// Select connection handler.
    	commandBox.on('click', function() {
    		if ($(this).attr('class').indexOf('active') === -1) {
        		$(this).addClass('active');
      		} else {
        		$(this).removeClass('active');
      		}
    	});
*/

    	$('.filler').hide();
    	//$('#connections').append(commandBox);

    	c.on('data', function(data) {
    		if (data === "call-me") {
  				$('.status-area').append('<div class="event">Request to share camera</div>');

  				var call = peer.call(c.peer, window.localStream);

  				// UI stuff
				window.existingCall = call;
				$('#camera').prop('src', URL.createObjectURL(window.localStream));

    			//step3(call);
    			$('.camera-ui').hide();
    			//$('.sharing-ui').show();
    		} else if (data === "shutter") {
    			$('.status-area').append('<div class="event">Shutter request</div>');

    			var video  = document.getElementById('camera');
				var canvas = document.createElement('canvas');
				canvas.width  = video.videoWidth;
				canvas.height = video.videoHeight;
				var ctx = canvas.getContext('2d');
				ctx.drawImage(video, 0, 0);

				var dataURL = canvas.toDataURL();

				shutter_sound.play();
				document.getElementById('picture').src = dataURL;


				eachActiveConnection(function(c, $c) {
						if (c.label === 'file') {
						c.send(dataURL);
						$('.status-area').append('<div class="request">Sent photo</div>');
						}
				});

				/*
    			var photo = document.getElementById('picture'), context = photo.getContext('2d');
					var video = $('#camera');
					var dataURI = video.toDataURL();

					photo.width = video.clientWidth;
					photo.height = video.clientHeight;

					var download = document.createElement('a');
				download.href = dataURI;
				download.download = 'test.png';
				download.click();
  				*/
					//context.drawImage(video, 0, 0, photo.width, photo.height);

					// Goes through each active peer and calls FN on its connections.
				function eachActiveConnection(fn) {
					var actives = $('.active');
					var checkedIds = {};
					actives.each(function() {
	    				var peerId = $(this).attr('id');

	      				if (!checkedIds[peerId]) {
	        				var conns = peer.connections[peerId];
	        				for (var i = 0, ii = conns.length; i < ii; i += 1) {
	          					var conn = conns[i];
	          					fn(conn, $(this));
	        				}
	      				}

	      				checkedIds[peerId] = 1;
	    			});
				}

    		}
			});

    	// Close the call
    	c.on('close', function() {
      		$('.status-area').append('<div class="messages"><em>Peer ' + c.peer + ' has disconnected</em></div>');
        	//commandBox.remove();
        	if ($('.connection').length === 0) {
        		$('.filler').show();
        	}
        	delete connectedPeers[c.peer];
    	});

  	} else if (c.label === 'file') {
    	c.on('data', function(data) {
    		//$('.status-area').append('<div class="event">' + c.peer + ' has sent you a <a target="_blank" href="' + url + '">file</a></div>');
    		$('.status-area').append('<div class="event">Received photo from ' + c.peer + '</div>');
    		document.getElementById('picture').src = data;
     		// If we're getting a file, create a URL for it.
      		if (data.constructor === ArrayBuffer) {
        		var dataView = new Uint8Array(data);
        		var dataBlob = new Blob([dataView]);
        		var url = window.URL.createObjectURL(dataBlob);
        		
      		}
    	});
  	}
}

$(document).ready(function() {

	// Get things started
	step1();

	// Await connections from others
	peer.on('connection', connect); // Calls the connect function

});
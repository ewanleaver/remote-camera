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

    	$('#make-connection').hide();
    	$('#make-call').show();



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

     		$('#picture').append('<img id="picture" style="width:225px; height:168.75px;"></img>')
     		

      		/*if (data.constructor === ArrayBuffer) {
        		var dataView = new Uint8Array(data);
        		var dataBlob = new Blob([dataView]);
        		var url = window.URL.createObjectURL(dataBlob);
        		
      		}*/
    	});
  	}
}

$(document).ready(function() {

	// Await connections from others
	peer.on('connection', connect); // Calls the connect function

	var shutter_sound = document.createElement("audio"); 
    shutter_sound.setAttribute("src", "resources/shutter.wav");

	// Button handlers

	// Connect to a peer
	$('.custom-button').mousedown(function() {
  		//$(this).animate({ backgroundColor:'#0000CC'},1000);
  		$(this).fadeTo(20,1);
  	})

  	$('.custom-button').mouseup(function() {
  		//$(this).animate({ backgroundColor:'#00CC00'},1000);
  		$(this).fadeTo(20,0.8);
  	})

	$('#connect-button').click(function() {
    	requestedPeer = $('#callto-id').val();
    	if (!connectedPeers[requestedPeer]) {
      		// Create 2 connections, one for commands and another for file transfer.
      		var c = peer.connect(requestedPeer, {
        		label: 'call',
        		serialization: 'none',
        		metadata: {message: 'hi i want to call you!'}
      		});
      		c.on('open', function() {
        		connect(c);

      			$('#status').text("Connected");
    			$('#callto-id').hide();
    			$('#connect-button').hide();
    			$('#call-button').show();

      		});
      		c.on('error', function(err) { alert(err); });
      
			// File connection (for sending photos)
      		var f = peer.connect(requestedPeer, { label: 'file', reliable: true });
      		f.on('open', function() {
      			connect(f);
      		});
      		f.on('error', function(err) { alert(err); });

    	}

    	connectedPeers[requestedPeer] = 1; // Mark peer as connected

  	});

  	// Request peer's camera
	$('#call-button').click(function() {

	    // For each active connection, send the message.
	    var msg = "call-me";
	    eachActiveConnection(function(c, $c) {
	      	if (c.label === 'call') {
	        	c.send(msg);
	        	$('.status-area').append('<div class="request">Requesting camera</div>');
	      	}
	    });

	});

	$('#inner-shutter').mousedown(function() {
  		//$(this).animate({ backgroundColor:'#0000CC'},1000);
  		$('#inner-shutter').fadeTo(20,0);
  	})

  	$('#inner-shutter').mouseup(function() {
  		//$(this).animate({ backgroundColor:'#00CC00'},1000);
  		$('#inner-shutter').fadeTo(20,0.7);
  	})

	$('#inner-shutter').click(function() {

		// For each active connection, send the message.
	    var msg = "shutter";
	    eachActiveConnection(function(c, $c) {
	      	if (c.label === 'call') {
	        	c.send(msg);
	        	shutter_sound.play();
	        	$('.status-area').append('<div class="request">Requesting photo</div>');
	      	}
	    });

	});

	$('#end-call').click(function(){
		window.existingCall.close();
	});

  	// Close a connection.
  	$('#close').click(function() {
    	eachActiveConnection(function(c) {
      		c.close();
    	});
  	});

  	$('.custom-button').mouseenter(function () {
  		$(this).fadeTo(50,0.8); 
  	});

  	$('.custom-button').mouseleave(function () {
  		$(this).fadeTo(50,0.5); 
  	});

  	$('#inner-shutter').mouseenter(function() {

  		$('#inner-shutter').fadeTo(100,0.7); 
  		$('#outer-shutter').fadeTo(100,0.3); 

  	});

  	$('#inner-shutter').mouseleave(function() {

  		$('#inner-shutter').fadeTo(100,0.3); 
  		$('#outer-shutter').fadeTo(100,0.1); 

  	});



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

});
// #####################
//  Made by Ewan Leaver
// #####################

//var SKYWAY_APIKEY = "4362638a-9e84-11e3-9939-47b360702393";
var SKYWAY_APIKEY = "b0a007fa-af27-11e3-b735-7312b2da93b5";

// Media compatability
navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia;

// Generate a managable user ID
function makeid() {
    var text = "";
    var possible = "0123456789";

    for (var i = 0; i < 4; i++)
        text += possible.charAt(Math.floor(Math.random() * possible.length));

    return text;
}

// Connect to Skyway, generating own ID instead of server providing one
var peer = new Peer(makeid(), {
    key: SKYWAY_APIKEY
});

// Show this peer's ID.
peer.on('open', function (id) {
    console.log('My peer ID is: ' + id);
    $('#my-id').text(id); // Instead assign it to HTML id my-id
});

peer.on('error', function (err) {
    alert(err.message);
});

function getCamera() {

    // Get and set audio/video stream
    navigator.getUserMedia({
        audio: false,
        video: true
    }, function (stream) {
        window.localStream = stream;
    });
}

// Handle a connection object.
function connect(c) {

    // Handle a call connection.
    if (c.label === 'call') {
    	// Status area isn't currently visible on the camera-side
        $('.status-area').addClass('active').attr('id', c.peer);
        var header = $('<div style="font-size:18px; padding-top:5px">Connection with <strong>' + c.peer + '</strong></div>');
        var messages = $('<div><em>  Peer connected.</em></div>').addClass('messages');
        $('.status-area').append(header);
        $('.status-area').append(messages);

        // Sound doesn't play on android... moving to PC side
        //var shutter_sound = document.createElement("audio"); 
        //shutter_sound.setAttribute("src", "resources/shutter.wav");

        c.on('data', function (data) {

            if (data === "call-me") {
            	// If PC requests a call...

                $('.status-area').append('<div class="event">Request to share camera</div>');

                var call = peer.call(c.peer, window.localStream);

                // UI stuff
                window.existingCall = call;
                $('#camera-view').prop('src', URL.createObjectURL(window.localStream));

                $('.camera-connection-ui').hide();

            } else if (data === "shutter") {
            	// If PC requests a photo...

                $('.status-area').append('<div class="event">Shutter request</div>');

                var video = document.getElementById('camera-view');
                var canvas = document.createElement('canvas');
                canvas.width = video.videoWidth;
                canvas.height = video.videoHeight;
                var ctx = canvas.getContext('2d');
                ctx.drawImage(video, 0, 0);

                var dataURL = canvas.toDataURL();

                //shutter_sound.play(); // Sound doesn't play on android :( Moving to PC-side...
                document.getElementById('picture').src = dataURL;

                eachActiveConnection(function (c, $c) {
                    if (c.label === 'file') {
                        c.send(dataURL);
                        $('.status-area').append('<div class="request">Sent photo</div>');
                    }
                });

                // Goes through each active peer and calls FN on its connections.
                function eachActiveConnection(fn) {
                    var actives = $('.active');
                    var checkedIds = {};
                    actives.each(function () {
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
        c.on('close', function () {
            $('.status-area').append('<div class="messages"><em>Peer ' + c.peer + ' has disconnected</em></div>');
            //commandBox.remove();
            if ($('.connection').length === 0) {
                $('.filler').show();
            }

        });

    } 
}

$(document).ready(function () {

    // Get things started
    getCamera();

    // Await connections from others
    peer.on('connection', connect); // Calls the connect function

});
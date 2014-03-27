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

// Track all connections
var connectedPeers = {};

// Show this peer's ID.
peer.on('open', function (id) {
    console.log('My peer ID is: ' + id);
    $('#my-id').text(id); // Instead assign it to HTML id my-id
});

// Receiving a call
peer.on('call', function (call) {
    // Answer the call automatically
    call.answer();
    answerCall(call);
});

peer.on('error', function (err) {
    alert(err.message);
});

function answerCall(call) {
    // Hang up on an existing call if present
    if (window.existingCall) {
        window.existingCall.close();
    }

    // Wait for stream on the call, then set peer video display
    call.on('stream', function (stream) {
        $('#camera-view').prop('src', URL.createObjectURL(stream));
    });

    // UI stuff
    window.existingCall = call;
    $('#callto-id').text(call.peer);

    // PC-side UI management
    $('.pc-connection-ui').fadeTo(300,0);
    $('.pc-connected-ui').show();

}

// Handle a connection object.
function connect(c) {

    if (c.label === 'call') {
        // Handle a call connection.

        $('.status-area').addClass('active').attr('id', c.peer);
        var header = $('<div style="font-size:18px; padding-top:5px">Connection with <strong>' + c.peer + '</strong></div>');
        var messages = $('<div><em>  Peer connected.</em></div>').addClass('messages');
        $('.status-area').append(header);
        $('.status-area').append(messages);

        // Close the call
        c.on('close', function () {
            $('.status-area').append('<div class="messages"><em>Peer ' + c.peer + ' has disconnected</em></div>');

            delete connectedPeers[c.peer];
        });

    } else if (c.label === 'file') {
        // Handle an incoming photo

        c.on('data', function (data) {
            //$('.status-area').append('<div class="event">' + c.peer + ' has sent you a <a target="_blank" href="' + url + '">file</a></div>');
            $('.status-area').append('<div class="event">Received photo from ' + c.peer + '</div>');
            // document.getElementById('picture').src = data;

            var photos = $('.photo');
            photos.each(function () {
                $(this).animate({
                    top: '+=250px'
                }, 200);
            });

            $('.photo').animate({
                top: '+=250px'
            }, 200);

            // $('#picture').before('<img id="picture" style="width:225px; height:168.75px;"></img>')
            $("#photo-stream").prepend('<img class="photo" src=' + data + ' style="opacity:0; width:225px; height:168.75px; download="photo.png"></img>');
            $(".photo").fadeTo(300,1);

        });
    }
}

$(document).ready(function () {

    // Await connections from others
    peer.on('connection', connect); // Calls the connect function

    var shutter_sound = document.createElement("audio");
    shutter_sound.setAttribute("src", "resources/shutter.wav");

    $('#photo-stream').delegate(".photo", "click", function (event) {

        var a = document.createElement('a');

        a.download = "photo.png";
        a.type = "image/png";
        a.href = $(this).attr('src');

        //document.getElementsByTagName('body')[0].appendChild(a);
        //location.href = $(this).attr('src');

        a.click();

    });

    // Button handlers

    // Connect to a peer
    $('.custom-button').mousedown(function () {
        //$(this).animate({ backgroundColor:'#0000CC'},1000); // Failed attempt to change button colour
        $(this).fadeTo(20, 1);
    })

    $('.custom-button').mouseup(function () {
        //$(this).animate({ backgroundColor:'#00CC00'},1000);
        $(this).fadeTo(20, 0.8);
    })

    $('#connect-button').click(function () {
        requestedPeer = $('#callto-id').val();
        if (!connectedPeers[requestedPeer]) {
            // Create 2 connections, one for sending commands and another for file transfer.
            var c = peer.connect(requestedPeer, {
                label: 'call',
                serialization: 'none',
                metadata: {
                    message: 'I want to call you!'
                }
            });
            c.on('open', function () {
                connect(c);

                // Kept mysteriously reappearing? Using different hide method
                $('#connect-button').css('visibility', 'hidden');
                //$('#callto-id').css('visibility', 'hidden');
                $('#call-button').show();

                $('#status').text("Connected");
                
            });
            c.on('error', function (err) {
                alert(err);
            });

            // Create file connection (for receiving photos)
            var f = peer.connect(requestedPeer, {
                label: 'file',
                reliable: true
            });
            f.on('open', function () {
                connect(f);
            });
            f.on('error', function (err) {
                alert(err);
            });

        }

        connectedPeers[requestedPeer] = 1; // Mark peer as connected

    });

    // Request peer's camera
    $('#call-button').click(function () {

        // For each active connection, send the message.
        var msg = "call-me";
        eachActiveConnection(function (c, $c) {
            if (c.label === 'call') {
                c.send(msg);
                $('.status-area').append('<div class="request">Requesting camera</div>');
            }
        });

    });

    // Shutter button animations & click handler
    $('#inner-shutter').mousedown(function () {
        $('#inner-shutter').fadeTo(20, 0);
    })

    $('#inner-shutter').mouseup(function () {
        $('#inner-shutter').fadeTo(20, 0.7);
    })

    $('#inner-shutter').click(function () {

        // For each active connection, send the message.
        var msg = "shutter";
        eachActiveConnection(function (c, $c) {
            if (c.label === 'call') {
                c.send(msg);
                shutter_sound.play();
                $('.status-area').append('<div class="request">Requesting photo</div>');
            }
        });

    });

    $('.custom-button').mouseenter(function () {
        $(this).fadeTo(50, 0.8);
    });

    $('.custom-button').mouseleave(function () {
        $(this).fadeTo(50, 0.5);
    });

    $('#inner-shutter').mouseenter(function () {

        $('#inner-shutter').fadeTo(100, 0.7);
        $('#outer-shutter').fadeTo(100, 0.3);

    });

    $('#inner-shutter').mouseleave(function () {

        $('#inner-shutter').fadeTo(100, 0.3);
        $('#outer-shutter').fadeTo(100, 0.1);

    });

    $('#status-button').click(function () {
        $('.status-area').css('visibility', 'visible');

        if ($('.status-area').css('opacity') == '0')
            $('.status-area').fadeTo(150, 0.6);
        else
            $('.status-area').fadeTo(150, 0);
        //$('.status-area').show();

    })

    // Close the connection
    $('#end-call-button').click(function () {

        eachActiveConnection(function (c) {
            c.close();
        });

        window.existingCall.close();

        $('.disconnected-ui').show();
        $('.disconnected-ui').fadeTo(300, 0.7);
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

});
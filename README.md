Remote Camera
=============

A simple web application utilising [SkyWay] (http://nttcom.github.io/skyway/en/) as a P2P communications framework.

The application is split into two separate web pages which are connected and communicate.
- One browser window displays a camera feed, which is broadcasted to the other page upon pairing.
- The second browser window (or device) acts as a viewfinder with a shutter button.
  - Pressing the button captures a photo on the camera's side, and transmits it at high resolution to the viewfinder webpage.

By opening the provided web pages on separate devices, it is possible to remotely view the camera feed of one device and capture photos.

Setup
=====

1. After cloning the repository, serve the files using a simple web server:

     `python -m SimpleHTTPServer 8000`

2. From one browser window/device, access the camera webpage (e.g. `localhost:8000/camera.html`)
 - (Be sure to allow the camera access to your webcam)

3. From another browser window, access the viewfinder webpage (e.g. `localhost:8000`)

Usage
=====

- After connecting the two webapps by entering the camera's ID into the viewfinder page, you can take photos using the viewfinder's shutter button.

- Photos are sent from the camera app to the viewfinder and displayed on the right hand side.

- By clicking on a photo, you can download the full-resolution version of the photo.

Note
====

- If forking or otherwise modifying the project, please replace the API key in `pc.js` and `camera.js` with a newly registered API key on the [SkyWay website] (https://skyway.io/ds/)
- The provided API key is intended for demonstration purposes only.

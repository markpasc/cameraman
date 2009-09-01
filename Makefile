all: build/cameraman.swf build/cameraman.js

build/cameraman.swf:
	mkdir -p build
	mxmlc src/CameraMan.as -output build/cameraman.swf

build/cameraman.js:
	mkdir -p build
	cp src/cameraman.js build/cameraman.js

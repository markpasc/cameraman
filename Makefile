all: swf/cameraman.swf

swf/cameraman.swf:
	mkdir -p swf
	mxmlc src/CameraMan.as -output swf/cameraman.swf

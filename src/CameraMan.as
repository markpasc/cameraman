package {
    import flash.display.Sprite;
    import flash.display.StageScaleMode;
    import flash.display.StageAlign;
    import flash.geom.Point;

    import flash.external.ExternalInterface;

    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.media.Camera;
    import flash.media.Video;
    import flash.utils.ByteArray;
    import mx.graphics.codec.JPEGEncoder;

    import flash.events.Event;
    import flash.events.HTTPStatusEvent;
    import flash.events.IOErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.net.URLLoader;
    import flash.net.URLRequest;

    public class CameraMan extends Sprite {

        private var videoface:Video;
        private var cam:Camera;
        private var photo:BitmapData;
        private var sendto:String;
        private var movieSize:Point;

        public function CameraMan() {
            stage.addEventListener(Event.RESIZE, configureCamera);
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;

            trace("START ME UP");
            sendto = this.loaderInfo.parameters.sendto;
            configureCamera(null);

            if (ExternalInterface.available) {
                ExternalInterface.addCallback("takePhoto", takePhoto);
                ExternalInterface.addCallback("sendPhoto", sendPhoto);
            }
        }

        public function awesome(event:Event) : void {
            trace("~~ AWESOME " + event.target.muted);
        }

        public function createCamera(event:Event) : void {
            cam = Camera.getCamera();
            cam.addEventListener("status", awesome);
            trace("got camera " + cam.name + ". muted: " + cam.muted
                + '. size: ' + cam.width + ',' + cam.height + '. fps: '
                + cam.currentFPS + '. max fps: ' + cam.fps + ' total cameras: ' + Camera.names.length);
            cam.setMode(stage.stageWidth, stage.stageHeight, 15);

            videoface = new Video(cam.width, cam.height);
            videoface.attachCamera(cam);
            this.addChild(videoface);
        }

        public function configureCamera(event:Event) : void {
            trace("o hai configure camera!!");

            if (stage.stageWidth == 0) {
                trace("stage is zero-width, so skip");
                return;
            }

            if (!cam)
                return this.createCamera(event);

            cam.setMode(stage.stageWidth, stage.stageHeight, 15);
            trace("Camera size is " + cam.width + ", " + cam.height);
            videoface.width = cam.width;
            videoface.height = cam.height;
        }

        public function takePhoto() : void {
            // freeze image
            try {
                photo = new BitmapData(videoface.videoWidth, videoface.videoHeight, false);
                photo.draw(videoface);

                // Swap the video for the captured bitmap.
                var bitty:Bitmap = new Bitmap(photo);
                this.addChild(bitty);
                this.removeChild(videoface);
            } catch(err:Error) {
                trace(err.name + " " + err.message);
            }

            if (ExternalInterface.available) {
                ExternalInterface.call('cameraman._tookPhoto');
            }
        }

        public function sendPhoto() : void {
            try {
                // produce image file
                var peggy:JPEGEncoder = new JPEGEncoder(75.0);
                var image:ByteArray = peggy.encode(photo);

                // send image file to server
                var req:URLRequest = new URLRequest();
                req.url = this.sendto;
                req.method = "POST";
                req.contentType = peggy.contentType;
                req.data = image;

                var http:URLLoader = new URLLoader();
                http.addEventListener("complete", sentPhoto);
                http.addEventListener("ioError", sendingIOError);
                http.addEventListener("securityError", sendingSecurityError);
                http.addEventListener("httpStatus", sendingHttpStatus);
                http.load(req);
            } catch(err:Error) {
                trace(err.name + " " + err.message);
            }
        }

        public function sendingHttpStatus(event:HTTPStatusEvent) : void {
            trace("HTTPStatus: " + event.status + " " + event.target);
        }

        public function sendingIOError(event:IOErrorEvent) : void {
            trace("IOError: " + event.type + " " + event.text + " " + event.target + " " + event.target.bytesLoaded);
        }

        public function sendingSecurityError(event:SecurityErrorEvent) : void {
            trace("SecurityError: " + event.text + " " + event.target);
        }

        public function sentPhoto(event:Event) : void {
            var url:String = event.target.data;
            if (ExternalInterface.available)
                ExternalInterface.call('cameraman._sentPhoto', url);
        }

    }
}

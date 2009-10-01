package {
    import flash.display.Sprite;
    import flash.display.StageScaleMode;
    import flash.display.StageAlign;
    import flash.geom.Point;

    import flash.external.ExternalInterface;

    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFormat;
    import flash.text.TextFormatAlign;
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

        private var nope:TextField;
        private var videoface:Video;
        private var cam:Camera;
        private var photo:Bitmap;
        private var cameraid:String;
        private var sendto:String;
        private var movieSize:Point;

        public function CameraMan() {
            stage.addEventListener(Event.RESIZE, configureCamera);
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;

            trace("START ME UP");
            sendto = this.loaderInfo.parameters.sendto;
            cameraid = this.loaderInfo.parameters.cameraid;
            configureCamera(null);

            if (ExternalInterface.available) {
                ExternalInterface.addCallback("takePhoto", takePhoto);
                ExternalInterface.addCallback("sendPhoto", sendPhoto);
                ExternalInterface.addCallback("dropPhoto", dropPhoto);
            }
        }

        public function awesome(event:Event) : void {
            trace("~~ AWESOME " + event.target.muted);
        }

        public function createCamera(event:Event) : void {
            nope = new TextField();
            nope.autoSize = TextFieldAutoSize.CENTER;
            nope.background = true;
            nope.backgroundColor = 0x000000;
            nope.textColor = 0xFFFFFF;
            nope.text = '⃠';
            this.addChild(nope);

            var nope_fmt:TextFormat = new TextFormat();
            nope_fmt.size = stage.stageHeight;
            nope_fmt.align = TextFormatAlign.CENTER;
            nope.setTextFormat(nope_fmt);

            nope.x = Math.floor(stage.stageWidth / 2) - Math.floor(nope.width / 2);
            nope.y = Math.floor(stage.stageHeight / 2) - Math.floor(nope.height / 2);

            trace('Stage size is ' + stage.stageWidth + ', ' + stage.stageHeight);
            trace('Nope size is ' + nope.width + ', ' + nope.height);
            trace('Nope size 2 is ' + nope.width + ', ' + nope.height);

            cam = Camera.getCamera();

            // TODO: handle a missing camera
            // TODO: handle a "dead" camera (fps = 0?)
            /* TODO: handle a muted camera? we'll only get an
             * unmuted camera to start with if they've chosen to
             * Remember Allow. If they haven't chosen Remember Deny,
             * they'll automatically get a dialog from attachCamera()
             * later.
             */

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

            nope.autoSize = TextFieldAutoSize.CENTER;
            var nope_fmt:TextFormat = new TextFormat();
            nope_fmt.size = stage.stageHeight;
            nope.setTextFormat(nope_fmt);
            nope.x = Math.floor(stage.stageWidth / 2) - Math.floor(nope.width / 2);
            nope.y = Math.floor(stage.stageHeight / 2) - Math.floor(nope.height / 2);

            cam.setMode(stage.stageWidth, stage.stageHeight, 15);
            trace("Camera size is " + cam.width + ", " + cam.height);
            videoface.width = cam.width;
            videoface.height = cam.height;
        }

        public function callback(eventname:String, ... args) : void {
            eventname = "cameraman.cameras['" + cameraid + "']._" + eventname;
            trace("Calling back to " + eventname + " with: " + args);
            args.unshift(eventname);
            if (ExternalInterface.available)
                ExternalInterface.call.apply(null, args);
        }

        public function takePhoto() : void {
            // freeze image
            try {
                var photobits:BitmapData = new BitmapData(videoface.videoWidth, videoface.videoHeight, false);
                photobits.draw(videoface);

                // Swap the video for the captured bitmap.
                photo = new Bitmap(photobits);
                this.addChild(photo);
                this.removeChild(videoface);
            } catch(err:Error) {
                trace(err.name + " " + err.message);
            }

            this.callback('tookPhoto');
        }

        public function dropPhoto() : void {
            // cancel the freezing
            try {
                this.removeChild(photo);
                photo = null;

                this.addChild(videoface);
            }
            catch (err:Error) {
                trace(err.name + " " + err.message);
            }

            this.callback('droppedPhoto');
        }

        public function sendPhoto() : void {
            try {
                // produce image file
                var peggy:JPEGEncoder = new JPEGEncoder(75.0);
                var image:ByteArray = peggy.encode(photo.bitmapData);

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
            this.callback('errorSending', 'IO error: ' + event.text);
        }

        public function sendingSecurityError(event:SecurityErrorEvent) : void {
            trace("SecurityError: " + event.text + " " + event.target);
            this.callback('errorSending', 'Security error: ' + event.text);
        }

        public function sentPhoto(event:Event) : void {
            var url:String = event.target.data;
            this.callback('sentPhoto', url);
        }

    }
}

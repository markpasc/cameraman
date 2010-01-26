package {
    import flash.display.Sprite;
    import flash.display.StageScaleMode;
    import flash.display.StageAlign;
    import flash.geom.Point;
    import flash.utils.Timer;
    import flash.events.TimerEvent;

    import flash.external.ExternalInterface;

    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFormat;
    import flash.text.TextFormatAlign;
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.media.Camera;
    import flash.media.Video;
    import flash.geom.Matrix;
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
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;
            stage.addEventListener(Event.RESIZE, configureCamera);

            trace("START ME UP");
            sendto = this.loaderInfo.parameters.sendto;
            cameraid = this.loaderInfo.parameters.cameraid;

            if (ExternalInterface.available) {
                ExternalInterface.addCallback("takePhoto", takePhoto);
                ExternalInterface.addCallback("sendPhoto", sendPhoto);
                ExternalInterface.addCallback("dropPhoto", dropPhoto);
            }

            var t:Timer = new Timer(0, 1);
            t.addEventListener(TimerEvent.TIMER_COMPLETE, initialCameraSetup);
            t.start();
        }

        public function awesome(event:Event) : void {
            trace("~~ AWESOME " + event.target.muted);
        }

        public function initialCameraSetup(event:Event) : void {
            this.configureCamera(null);
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

            // One would think we could try to get the default camera, then if
            // it doesn't really provide a stream, try each available video
            // source in turn until we find one that does provide a stream.
            // However, we can't try them here, because they all will report
            // sizes with a currentFPS of 0, and even when attached to the
            // Video, all the Video.videoWidths will still be 0. Instead,
            // blindly prefer the USB Video Class Video camera, since that's
            // the webcam on the Mac.
            var i:int = Camera.names.indexOf("USB Video Class Video");
            cam = Camera.getCamera(i == -1 ? null : String(i));

            if (cam == null) {
                trace("No camera found? Indeed, there are " + Camera.names.length + " cameras");
                return;
            }

            trace("got camera " + cam.name + ". muted: " + cam.muted
                + '. size: ' + cam.width + ',' + cam.height + '. fps: '
                + cam.currentFPS + '. max fps: ' + cam.fps + ' total cameras: ' + Camera.names.length);

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
            cam.setMode(stage.stageWidth, stage.stageHeight, 30);

            trace("after setting mode to stage " + stage.stageWidth + ',' + stage.stageHeight
                + ', size: ' + cam.width + ',' + cam.height + '. fps: '
                + cam.currentFPS + '. max fps: ' + cam.fps + ' total cameras: ' + Camera.names.length);

            videoface = new Video(stage.stageWidth, stage.stageHeight);
            videoface.attachCamera(cam);
            this.addChild(videoface);

            this.prepVideo();

            var t:Timer = new Timer(250, 10);
            t.addEventListener(TimerEvent.TIMER, checkCamera);
            t.addEventListener(TimerEvent.TIMER_COMPLETE, checkCameraLast);
            t.start();
        }

        public function checkCamera(event:Event) : void {
            trace("whilst checking camera " + cam.name + ". muted: " + cam.muted
                + '. size: ' + cam.width + ',' + cam.height + '. fps: '
                + cam.currentFPS + '. max fps: ' + cam.fps + ' total cameras: ' + Camera.names.length);
            if (cam.currentFPS > 0.0) {
                event.target.stop();
                this.callback('cameraReady');
            }
        }

        public function checkCameraLast(event:Event) : void {
            trace("whilst checking camera for last " + cam.name + ". muted: " + cam.muted
                + '. size: ' + cam.width + ',' + cam.height + '. fps: '
                + cam.currentFPS + '. max fps: ' + cam.fps + ' total cameras: ' + Camera.names.length);
            if (cam.currentFPS <= 0.0) {
                this.callback('cameraNotReady');
            }
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

            cam.setMode(stage.stageWidth, stage.stageHeight, 30);
            trace("Camera size is " + cam.width + ", " + cam.height + " (tried "
                + stage.stageWidth + "," + stage.stageHeight + ")");

            this.prepVideo();
        }

        public function prepVideo() : void {
            videoface.x = 0;
            videoface.y = 0;
            videoface.width = stage.stageWidth;
            videoface.height = stage.stageHeight;

            var mirror:Matrix = new Matrix();
            mirror.scale(-1, 1);
            mirror.translate(stage.stageWidth, 0);
            videoface.transform.matrix = mirror;
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
                var photobits:BitmapData = new BitmapData(stage.stageWidth, stage.stageHeight, false);
                var mirror:Matrix = new Matrix();
                mirror.scale(-1, 1);
                mirror.translate(stage.stageWidth, 0);
                photobits.draw(videoface, mirror);

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
                this.prepVideo();
                trace("Tried to size video to " + stage.stageWidth + ","
                    + stage.stageHeight + " when re-adding");
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

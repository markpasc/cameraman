var cameraman = null;

function CameraMan(opts) {
    var _self = this;
    this.options = opts;
    this.id = opts.id;

    this.getApp = function () {
        var name = _self.id;
        return (navigator.appName.indexOf ("Microsoft") != -1 ? window : document)[name];
    };

    this.takePhoto = function () {
        _self.getApp().takePhoto();
    };
    this.sendPhoto = function () {
        _self.getApp().sendPhoto();
    };

    this._tookPhoto = function () {
        if (_self.options.tookPhoto) {
            _self.options.tookPhoto.apply(_self);
        }
    };
    this._sentPhoto = function (url) {
        if (_self.options.sentPhoto) {
            _self.options.sentPhoto.apply(_self, url);
        }
    };
}

cameraman = new CameraMan();

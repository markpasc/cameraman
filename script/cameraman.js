var cameraman = null;

function CameraMan(id) {
    var _self = this;
    this.id = id;

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
        $('#' + _self.id).trigger('tookPhoto');
    };
    this._sentPhoto = function (url) {
        $('#' + _self.id).trigger('sentPhoto', url);
    };
}

cameraman = new CameraMan();

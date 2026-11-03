import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class CommManager {

    private var _view as IntrvlWatchView?;

    function initialize() {
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
    }

    function setView(view as IntrvlWatchView) as Void {
        _view = view;
    }

    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (data instanceof Dictionary) {
            if (_view != null) {
                var type = data.get("type");
                if ("workout_state".equals(type)) {
                    _view.updateState(data);
                    WatchUi.requestUpdate();
                }
            }
        }
    }

    function sendAction(action as String) as Void {
        var payload = {
            "type" => "user_action",
            "action" => action
        };
        Communications.transmit(payload, null, new MessageCallback());
    }
}

class MessageCallback extends Communications.ConnectionListener {
    function onComplete() as Void {
        System.println("OK");
    }
    function onError() as Void {
        System.println("ERR");
    }
}
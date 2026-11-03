import Toybox.WatchUi;
import Toybox.Lang;

class WorkoutInputDelegate extends WatchUi.InputDelegate {

    private var _view as IntrvlWatchView;
    private var _comm as CommManager;

    function initialize(view as IntrvlWatchView, comm as CommManager) {
        InputDelegate.initialize();
        _view = view;
        _comm = comm;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var y = coords[1];
        var h = 390;

        if (y < h * 0.25) {
            _comm.sendAction("next_block");
        } else {
            _comm.sendAction("pause");
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ESC) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }
        return false;
    }
}
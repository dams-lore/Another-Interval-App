import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class IntrvlWatchApp extends Application.AppBase {

    private var _view as IntrvlWatchView?;
    private var _commManager as CommManager?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        _commManager = new CommManager();
        _commManager.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        _view = new IntrvlWatchView();
        _commManager.setView(_view);
        var delegate = new WorkoutInputDelegate(_view, _commManager);
        return [_view, delegate];
    }

    function onStop(state as Dictionary?) as Void {
    }
}
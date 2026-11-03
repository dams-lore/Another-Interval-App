import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Sensor;

class IntrvlWatchView extends WatchUi.View {

    private var _blockName   as String  = "Waiting...";
    private var _blockType   as String  = "intervals";
    private var _elapsed     as Number  = 0;
    private var _duration    as Number  = 0;
    private var _round       as Number  = 0;
    private var _totalRounds as Number  = 0;
    private var _targetPace  as String  = "";
    private var _gpsSpeed    as Float   = 0.0f;
    private var _isPaused    as Boolean = false;
    private var _heartRate   as Number  = 0;

    function initialize() {
        View.initialize();
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Sensor.enableSensorEvents(method(:onSensor));
    }

    function onSensor(sensorInfo as Sensor.Info) as Void {
        if (sensorInfo.heartRate != null) {
            _heartRate = sensorInfo.heartRate as Number;
            WatchUi.requestUpdate();
        }
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function updateState(data as Dictionary) as Void {
        _blockName   = data.get("blockName")   != null ? data.get("blockName")   as String  : "–";
        _blockType   = data.get("blockType")   != null ? data.get("blockType")   as String  : "intervals";
        _elapsed     = data.get("elapsed")     != null ? data.get("elapsed")     as Number  : 0;
        _duration    = data.get("duration")    != null ? data.get("duration")    as Number  : 0;
        _round       = data.get("round")       != null ? data.get("round")       as Number  : 0;
        _totalRounds = data.get("totalRounds") != null ? data.get("totalRounds") as Number  : 0;
        _targetPace  = data.get("targetPace")  != null ? data.get("targetPace")  as String  : "";
        _gpsSpeed    = data.get("gpsSpeed")    != null ? data.get("gpsSpeed")    as Float   : 0.0f;
        _isPaused    = data.get("isPaused")    != null ? data.get("isPaused")    as Boolean : false;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        // Vivoactive 5 : écran rond 390x390px
        // Zone sûre bas (y=260-360) : x entre 55 et 335
        // Moitié gauche centre : x=97, moitié droite centre : x=293
        var w  = 390;
        var h  = 390;
        var cx = 195;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── Arc de progression ────────────────────────────────────────
        dc.setPenWidth(8);
        dc.setColor(0x2C2C2A, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cx, cx - 12, Graphics.ARC_CLOCKWISE, 210, 330);
        if (_duration > 0) {
            var progress = _elapsed.toFloat() / _duration.toFloat();
            if (progress > 1.0f) { progress = 1.0f; }
            var arcDegrees = (120 * progress).toNumber();
            if (arcDegrees > 0) {
                dc.setColor(0x7DB87A, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cx, cx - 12, Graphics.ARC_CLOCKWISE, 210, 210 - arcDegrees);
            }
        }
        dc.setPenWidth(1);

        // ── Round pill — y=55, bien dans le cadran ────────────────────
        if (_totalRounds > 0) {
            var roundStr = "Round " + _round.toString() + " / " + _totalRounds.toString();
            dc.setColor(0x1A3D1A, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(135, 55, 120, 22, 11);
            dc.setColor(0x7DB87A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(195, 66, Graphics.FONT_TINY, roundStr,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ── Chrono — centré à y=148 ───────────────────────────────────
        var remaining = _duration - _elapsed;
        var displayTime = _blockType.equals("elapsed") ? _elapsed : remaining;
        var timeStr = formatTime(displayTime);
        if (_isPaused) {
            dc.setColor(0xFAC775, Graphics.COLOR_TRANSPARENT);
        } else if (remaining <= 10 && _duration > 0) {
            dc.setColor(0xF09595, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(195, 148, Graphics.FONT_NUMBER_THAI_HOT, timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Nom du bloc — y=215 ───────────────────────────────────────
        dc.setColor(0x2A1F2E, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(110, 202, 160, 26, 13);
        dc.setColor(0xA793AC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(195, 215, Graphics.FONT_SMALL, _blockName,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Séparateur horizontal — y=255 ─────────────────────────────
        dc.setColor(0x2C2C2A, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(80, 255, 310, 255);

       
        // ── Séparateur vertical — x=195 ───────────────────────────────
        dc.drawLine(195, 260, 195, 345);

        // Colonnes : gauche centrée à x=130, droite à x=260
        // Zone sûre à y=270-340 : x min≈70, x max≈320
        // FONT_TINY = 41px hauteur, ~25px par caractère

        // ── TARGET (gauche) ───────────────────────────────────────────
        dc.setColor(0x888780, Graphics.COLOR_TRANSPARENT);
        dc.drawText(130, 270, Graphics.FONT_XTINY, "TARGET",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (!_targetPace.equals("")) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(130, 295, Graphics.FONT_XTINY, _targetPace + "/km",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(0x444441, Graphics.COLOR_TRANSPARENT);
            dc.drawText(130, 295, Graphics.FONT_XTINY, "--",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // ── GPS (gauche, sous TARGET) ─────────────────────────────────
        dc.setColor(0x888780, Graphics.COLOR_TRANSPARENT);
        dc.drawText(130, 318, Graphics.FONT_XTINY, "GPS",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(130, 341, Graphics.FONT_XTINY, _gpsSpeed.format("%.1f") + "km/h",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── BPM (droite) ──────────────────────────────────────────────
        dc.setColor(0xF09595, Graphics.COLOR_TRANSPARENT);
        dc.drawText(260, 270, Graphics.FONT_XTINY, "BPM",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var hrStr = _heartRate > 0 ? _heartRate.toString() : "--";
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(260, 305, Graphics.FONT_TINY, hrStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0xF09595, Graphics.COLOR_TRANSPARENT);
        dc.drawText(260, 341, Graphics.FONT_XTINY, "bpm",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Pause ─────────────────────────────────────────────────────
        if (_isPaused) {
            dc.setColor(0xFAC775, Graphics.COLOR_TRANSPARENT);
            dc.drawText(195, 368, Graphics.FONT_XTINY, "PAUSED",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function formatTime(seconds as Number) as String {
        if (seconds < 0) { seconds = 0; }
        var m = seconds / 60;
        var s = seconds % 60;
        return m.format("%d") + ":" + s.format("%02d");
    }
}
package timeslider;

import generated.timeslider.TimeSliderControlIdsGenerated;
import generated.timeslider.TimeSliderTracksGenerated;
import haxe.Json;
import worldofcake.ISequencerControl;
import worldofcake.SequencerCore;
import worldofcake.LocalPoint;

/**
    One lane. The model knows nothing about where a lane is drawn: its position is a value
    from 0 (bottom) to 1 (top), and each view maps that onto its own panel.
**/
class TimeSlider {
    public var uid:Int;
    /** Current position, 0 (bottom) .. 1 (top). */
    public var value:Float;
    /** Where the lane is heading, 0 .. 1. */
    public var target:Float;
    /** Change in value per second while moving (negative when heading down). */
    public var speed:Float;
    public var moving:Bool;

    /** Seconds to reach the target when sent with time fraction 0 (slow). */
    public var slowTravelTime:Float;
    /** Seconds to reach the target when sent with time fraction 1 (fast). */
    public var fastTravelTime:Float;

    public function new(uid:Int, slowTravelTime:Float, fastTravelTime:Float) {
        this.uid = uid;
        this.slowTravelTime = slowTravelTime;
        this.fastTravelTime = fastTravelTime;
        this.value = 0.5;
        this.target = value;
        this.moving = false;
        this.speed = 0;
    }

    /**
        Send the lane towards `targetValue` (0..1). `timeFraction` (0..1) chooses how long it
        takes, on a log scale: 0 is the slow travel time, 1 the fast one. Views pass a click's
        horizontal position within the lane as the time fraction and its height as the target.
    **/
    public function setDestination(timeFraction:Float, targetValue:Float):Void {
        var u = Math.max(0.001, Math.min(1.0, timeFraction));
        target = Math.max(0.0, Math.min(1.0, targetValue));
        var tFast = Math.max(1e-4, fastTravelTime);
        var tSlow = slowTravelTime <= tFast ? tFast * 2.0 : slowTravelTime;
        var timeToTarget = tSlow * Math.pow(tFast / tSlow, u);
        speed = (target - value) / timeToTarget;
        moving = true;
    }

    /** Advance by `delta` seconds; true when the value changed. */
    public function update(delta:Float):Bool {
        if (!moving) return false;
        var next = value + speed * delta;
        if ((speed >= 0 && next >= target) || (speed < 0 && next <= target)) {
            value = target;
            moving = false;
        } else {
            value = Math.max(0.0, Math.min(1.0, next));
        }
        return true;
    }
}

class TimeSliderSequencer extends SequencerCore implements ISequencerControl {
    public static inline var RESET_UID:Int = TimeSliderControlIdsGenerated.RESET;
    public static inline var PAUSE_UID:Int = TimeSliderControlIdsGenerated.PAUSE;
    /** Version of `exportStateJson`. v5 stores lane values 0..1; older versions stored panel pixels. */
    public static inline var STATE_VERSION:Int = 5;

    /** Control IDs of a lane's track, MIDI channel selector, CC number selector and label field. */
    public static inline function trackUid(lane:Int):Int return TimeSliderTracksGenerated.TRACK_UIDS[lane];
    public static inline function channelUid(lane:Int):Int return TimeSliderTracksGenerated.CHANNEL_UIDS[lane];
    public static inline function ccUid(lane:Int):Int return TimeSliderTracksGenerated.CC_UIDS[lane];
    public static inline function labelUid(lane:Int):Int return TimeSliderTracksGenerated.LABEL_UIDS[lane];

    private var sliders:Array<TimeSlider>;
    /** User's name for what each lane controls (saved with the state). */
    private var labels:Array<String>;
    private var slowTravelTime:Float;
    private var fastTravelTime:Float;

    /** The lane count is the target's (`:model :lanes`); travel times default to the app's. */
    public function new(?slowTravelTime:Float, ?fastTravelTime:Float) {
        super(true);
        bindLifecycleControls(PAUSE_UID);
        this.slowTravelTime = slowTravelTime == null ? TimeSliderTracksGenerated.MINIMUM_TRAVEL_TIME : slowTravelTime;
        this.fastTravelTime = fastTravelTime == null ? TimeSliderTracksGenerated.MAXIMUM_TRAVEL_TIME : fastTravelTime;
        sliders = buildSliders();
        labels = [for (_ in sliders) ""];
        // One control output per lane, in lane order; each carries its CC number and MIDI channel.
        declareControlOutputs(TimeSliderControlIdsGenerated.controlOutputs());
        publishTrackValues();
    }

    function buildSliders():Array<TimeSlider> {
        return TimeSliderTracksGenerated.buildTracks(slowTravelTime, fastTravelTime);
    }

    /** Resets the lanes' values and motion. Their labels, channels and CC numbers are kept. */
    public function reset():Void {
        resetTransport();
        sliders = buildSliders();
        publishTrackValues();
    }

    public function laneCount():Int return sliders.length;

    /** MIDI channel (1..16) of a lane's CC messages. */
    public function getChannel(index:Int):Int {
        return index < 0 || index >= controlOutputs.length ? 1 : controlOutputs[index].channel;
    }

    public function setChannel(index:Int, channel:Float):Void {
        if (index < 0 || index >= controlOutputs.length || !Math.isFinite(channel)) return;
        controlOutputs[index].setChannel(Math.round(channel));
        dirty = true;
    }

    /** CC number (0..127) a lane sends. */
    public function getCcNumber(index:Int):Int {
        return index < 0 || index >= controlOutputs.length ? 0 : controlOutputs[index].ccNumber;
    }

    public function setCcNumber(index:Int, ccNumber:Float):Void {
        if (index < 0 || index >= controlOutputs.length || !Math.isFinite(ccNumber)) return;
        controlOutputs[index].setCcNumber(Math.round(ccNumber));
        dirty = true;
    }

    /** The user's name for what a lane controls; empty when unnamed. */
    public function getLabel(index:Int):String {
        return index < 0 || index >= labels.length ? "" : labels[index];
    }

    public function setLabel(index:Int, label:String):Void {
        if (index < 0 || index >= labels.length) return;
        labels[index] = label == null ? "" : label;
        dirty = true;
    }

    /** Each lane's value is its control output. */
    function publishTrackValues():Void {
        for (i in 0...sliders.length) setControlOutput(i, sliders[i].value);
    }

    override function advanceModel(delta:Float):Bool {
        var changed = false;
        for (slider in sliders) {
            if (slider.update(delta)) {
                changed = true;
            }
        }
        if (changed) publishTrackValues();
        return changed;
    }

    public function exportStateJson():String {
        return Json.stringify({
            v: STATE_VERSION,
            kind: "timeslider",
            currentTime: currentTime,
            paused: paused,
            slowTravelTime: slowTravelTime,
            fastTravelTime: fastTravelTime,
            lanes: [for (i in 0...sliders.length) {
                value: sliders[i].value,
                target: sliders[i].target,
                speed: sliders[i].speed,
                moving: sliders[i].moving,
                channel: getChannel(i),
                ccNumber: getCcNumber(i),
                label: getLabel(i)
            }]
        });
    }

    /**
        Restore `exportStateJson`. A state with more lanes than this target has keeps the first
        ones; with fewer, the remaining lanes keep their defaults. States from before v5 stored
        pixel positions in their own panel and are converted.
    **/
    public function importStateJson(json:String):Void {
        if (json == null || json == "") {
            return;
        }
        try {
            var o:Dynamic = Json.parse(json);
            if (o == null || Reflect.field(o, "kind") != "timeslider") {
                return;
            }
            var version = Reflect.hasField(o, "v") ? Std.int(Reflect.field(o, "v")) : 0;
            if (version < 1) return;
            currentTime = number(o, "currentTime", 0);
            paused = Reflect.field(o, "paused") == true;
            var slow = number(o, version >= STATE_VERSION ? "slowTravelTime" : "minSpeed", slowTravelTime);
            var fast = number(o, version >= STATE_VERSION ? "fastTravelTime" : "maxSpeed", fastTravelTime);
            if (fast >= 0.01 && slow > fast) {
                slowTravelTime = slow;
                fastTravelTime = fast;
            }
            events = [];
            sliders = buildSliders();
            var saved:Array<Dynamic> = Reflect.field(o, version >= STATE_VERSION ? "lanes" : "sliders");
            if (saved != null) {
                for (i in 0...Std.int(Math.min(saved.length, sliders.length))) {
                    var e:Dynamic = saved[i];
                    var lane = sliders[i];
                    if (version >= STATE_VERSION) {
                        lane.value = clamp01(number(e, "value", lane.value));
                        lane.target = clamp01(number(e, "target", lane.value));
                        lane.speed = number(e, "speed", 0);
                    } else {
                        // Pixels from the top of a lane `height` tall; speed in pixels per millisecond.
                        var height = number(e, "height", 0);
                        if (height <= 0) continue;
                        lane.value = clamp01((height - number(e, "current", height / 2)) / height);
                        lane.target = clamp01((height - number(e, "destination", height / 2)) / height);
                        lane.speed = -number(e, "speed", 0) * 1000 / height;
                    }
                    lane.moving = Reflect.field(e, "moving") == true;
                    if (Reflect.hasField(e, "channel")) setChannel(i, number(e, "channel", 1));
                    if (Reflect.hasField(e, "ccNumber")) setCcNumber(i, number(e, "ccNumber", 0));
                    if (Reflect.hasField(e, "label")) setLabel(i, Std.string(Reflect.field(e, "label")));
                }
            }
            publishTrackValues();
            dirty = true;
        } catch (_:Dynamic) {}
    }

    static function number(o:Dynamic, field:String, fallback:Float):Float {
        if (!Reflect.hasField(o, field)) return fallback;
        var value = Std.parseFloat(Std.string(Reflect.field(o, field)));
        return Math.isFinite(value) ? value : fallback;
    }

    static inline function clamp01(value:Float):Float return Math.max(0.0, Math.min(1.0, value));

    /**
        A click on a lane, in that lane's own space: x from 0 (left) to 1 (right) chooses the
        travel time, y from 0 (bottom) to 1 (top) is the target value.
    **/
    public function mouseDown(uid:Int, point:LocalPoint):Void {
        for (slider in sliders) {
            if (slider.uid == uid) {
                slider.setDestination(point.x, point.y);
                dirty = true;
                return;
            }
        }
    }

    public function mouseDragged(uid:Int, point:LocalPoint):Void {}
    public function mouseUp(uid:Int, point:LocalPoint):Void {}
    public function textSubmitted(uid:Int, text:String):Void {
        var lane = TimeSliderTracksGenerated.LABEL_UIDS.indexOf(uid);
        if (lane >= 0) setLabel(lane, text);
    }
    public function newValue(uid:Int, value:Float):Void {
        if (applyLifecycleValue(uid, value)) return;
        // Channel and CC selectors send the number itself.
        var lane = TimeSliderTracksGenerated.CHANNEL_UIDS.indexOf(uid);
        if (lane >= 0) setChannel(lane, value);
        lane = TimeSliderTracksGenerated.CC_UIDS.indexOf(uid);
        if (lane >= 0) setCcNumber(lane, value);
    }
    public function buttonPressed(uid:Int):Void {
        if (uid == RESET_UID) reset();
    }
    public function keyPressed(uid:Int, key:String):Void {}

    public function getSliders():Array<TimeSlider> {
        return sliders;
    }
}

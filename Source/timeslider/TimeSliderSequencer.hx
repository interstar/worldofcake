package timeslider;

import generated.timeslider.TimeSliderControlIdsGenerated;
import generated.timeslider.TimeSliderTracksGenerated;
import haxe.Json;
import worldofcake.ISequencerControl;
import worldofcake.SequencerCore;
import worldofcake.LocalPoint;
import worldofcake.LocalRect;

class TimeSlider {
    public var uid:Int;
    /** Track rectangle in TimeSlider local play-area coordinates. */
    public var bounds:LocalRect;
    public var current:Float;
    public var destination:Float;
    public var speed:Float;
    public var moving:Bool;

    /** Seconds to cross vertically when clicking the **left** edge of this track (slow). */
    public var minSpeed:Float;
    /** Seconds when clicking the **right** edge (fast). */
    public var maxSpeed:Float;

    public function new(uid:Int, x:Float, y:Float, width:Float, height:Float, minSpeed:Float, maxSpeed:Float) {
        this.uid = uid;
        this.bounds = LocalRect.fromTopLeft(new LocalPoint(x, y), width, height);
        this.minSpeed = minSpeed;
        this.maxSpeed = maxSpeed;
        this.current = bounds.height() / 2;
        this.destination = current;
        this.moving = false;
        this.speed = 0;
    }

    public function hit(px:Float, py:Float):Bool {
        return bounds.contains(new LocalPoint(px, py));
    }

    /**
        Horizontal position sets **travel time** (seconds, full vertical crossing) on a **log** scale:
        left → `minSpeed` (slow, many seconds), right → `maxSpeed` (fast, ~1 s or less).
    **/
    public function setDestination(px:Float, py:Float):Void {
        setDestinationLocal(px - bounds.left, py - bounds.top);
    }

    /**
        Set destination from coordinates local to this track component.
    **/
    public function setDestinationLocal(px:Float, py:Float):Void {
        var u = px / bounds.width();
        if (u < 0.001) {
            u = 0.001;
        }
        if (u > 1.0) {
            u = 1.0;
        }

        var targetY = py;
        if (targetY < 0) {
            targetY = 0;
        }
        if (targetY > bounds.height()) {
            targetY = bounds.height();
        }

        destination = targetY;

        var tSlow = minSpeed;
        var tFast = maxSpeed;
        if (tFast < 1e-4) {
            tFast = 1e-4;
        }
        if (tSlow <= tFast) {
            tSlow = tFast * 2.0;
        }
        var timeToDestination = tSlow * Math.pow(tFast / tSlow, u);
        speed = (destination - current) / (timeToDestination * 1000);
        moving = true;
    }

    public function update(delta:Float):Bool {
        if (!moving) return false;

        var nextPos = current + speed * delta * 1000;
        if ((speed > 0 && nextPos > destination) || (speed < 0 && nextPos < destination)) {
            current = destination;
            moving = false;
            return true;
        }

        if (nextPos < 0) {
            current = 0;
            moving = false;
        } else if (nextPos > bounds.height()) {
            current = bounds.height();
            moving = false;
        } else {
            current = nextPos;
        }

        return true;
    }

    /** Position as a value from 0 (bottom of the track) to 1 (top). */
    public function normalizedValue():Float {
        return (bounds.height() - current) / bounds.height();
    }
}

class TimeSliderSequencer extends SequencerCore implements ISequencerControl {
    public static inline var RESET_UID:Int = TimeSliderControlIdsGenerated.RESET;
    public static inline var PAUSE_UID:Int = TimeSliderControlIdsGenerated.PAUSE;

    /** Control IDs of a track's MIDI channel selector, CC number selector and label field. */
    public static inline function channelUid(track:Int):Int return TimeSliderTracksGenerated.CHANNEL_UIDS[track];
    public static inline function ccUid(track:Int):Int return TimeSliderTracksGenerated.CC_UIDS[track];
    public static inline function labelUid(track:Int):Int return TimeSliderTracksGenerated.LABEL_UIDS[track];
    /** Four parallel tracks (OpenFL + Rack). */
    public static inline var SLIDER_COUNT:Int = 4;

    public var areaWidth:Int;
    public var areaHeight:Int;

    private var sliders:Array<TimeSlider>;
    /** User's name for what each track controls (saved with the state). */
    private var labels:Array<String>;
    /** Travel time (seconds) when clicking the **left** edge of a track (slow). */
    private var minSpeed:Float;
    /** Travel time (seconds) when clicking the **right** edge (fast). */
    private var maxSpeed:Float;
    public function new(width:Int, height:Int, minSpeed:Float, maxSpeed:Float) {
        super(true);
        bindLifecycleControls(PAUSE_UID);
        areaWidth = width;
        areaHeight = height;
        this.minSpeed = minSpeed;
        this.maxSpeed = maxSpeed;

        sliders = buildSliders();
        labels = [for (_ in sliders) ""];
        // One control output per track, in track order; each carries its CC number and MIDI channel.
        declareControlOutputs(TimeSliderControlIdsGenerated.controlOutputs());
        publishTrackValues();
    }

    /** Track geometry comes from the generated layout. */
    function buildSliders():Array<TimeSlider> {
        return TimeSliderTracksGenerated.buildTracks(minSpeed, maxSpeed);
    }

    /** Resets the tracks' positions and motion. Their labels, channels and CC numbers are kept. */
    public function reset():Void {
        resetTransport();
        sliders = buildSliders();
        publishTrackValues();
    }

    /** MIDI channel (1..16) of a track's CC messages. */
    public function getChannel(index:Int):Int {
        return index < 0 || index >= controlOutputs.length ? 1 : controlOutputs[index].channel;
    }

    public function setChannel(index:Int, channel:Float):Void {
        if (index < 0 || index >= controlOutputs.length || !Math.isFinite(channel)) return;
        controlOutputs[index].setChannel(Math.round(channel));
        dirty = true;
    }

    /** CC number (0..127) a track sends. */
    public function getCcNumber(index:Int):Int {
        return index < 0 || index >= controlOutputs.length ? 0 : controlOutputs[index].ccNumber;
    }

    public function setCcNumber(index:Int, ccNumber:Float):Void {
        if (index < 0 || index >= controlOutputs.length || !Math.isFinite(ccNumber)) return;
        controlOutputs[index].setCcNumber(Math.round(ccNumber));
        dirty = true;
    }

    /** The user's name for what a track controls; empty when unnamed. */
    public function getLabel(index:Int):String {
        return index < 0 || index >= labels.length ? "" : labels[index];
    }

    public function setLabel(index:Int, label:String):Void {
        if (index < 0 || index >= labels.length) return;
        labels[index] = label == null ? "" : label;
        dirty = true;
    }

    /** Each track's position is its control output. */
    function publishTrackValues():Void {
        for (i in 0...sliders.length) setControlOutput(i, sliders[i].normalizedValue());
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
        var sliderParts:Array<Dynamic> = [];
        for (i in 0...sliders.length) {
            var s = sliders[i];
            sliderParts.push({
                slot: sliderParts.length,
                x: s.bounds.left,
                y: s.bounds.top,
                width: s.bounds.width(),
                height: s.bounds.height(),
                channel: getChannel(i),
                ccNumber: getCcNumber(i),
                label: getLabel(i),
                minSpeed: s.minSpeed,
                maxSpeed: s.maxSpeed,
                current: s.current,
                destination: s.destination,
                moving: s.moving,
                speed: s.speed
            });
        }
        var out = new StringBuf(); out.add('{"v":4,"kind":"timeslider","currentTime":'); out.add(currentTime); out.add(',"paused":'); out.add(paused ? 'true' : 'false'); out.add(',"minSpeed":'); out.add(minSpeed); out.add(',"maxSpeed":'); out.add(maxSpeed); out.add(',"areaWidth":'); out.add(areaWidth); out.add(',"areaHeight":'); out.add(areaHeight); out.add(',"sliders":[');
        for (i in 0...sliderParts.length) { if (i > 0) out.add(','); var s:Dynamic=sliderParts[i]; out.add('{"slot":'); out.add(s.slot); out.add(',"x":'); out.add(s.x); out.add(',"y":'); out.add(s.y); out.add(',"width":'); out.add(s.width); out.add(',"height":'); out.add(s.height); out.add(',"channel":'); out.add(s.channel); out.add(',"ccNumber":'); out.add(s.ccNumber); out.add(',"label":'); out.add(Json.stringify(s.label)); out.add(',"minSpeed":'); out.add(s.minSpeed); out.add(',"maxSpeed":'); out.add(s.maxSpeed); out.add(',"current":'); out.add(s.current); out.add(',"destination":'); out.add(s.destination); out.add(',"moving":'); out.add(s.moving ? 'true' : 'false'); out.add(',"speed":'); out.add(s.speed); out.add('}'); }
        out.add(']}'); return out.toString();
    }

    public function importStateJson(json:String):Void {
        if (json == null || json == "") {
            return;
        }
        try {
            var o:Dynamic = Json.parse(json);
            if (o == null || Reflect.field(o, "kind") != "timeslider") {
                return;
            }
            var v = Reflect.field(o, "v");
            if (v == null || Std.int(v) < 1) {
                return;
            }
            var ver = Std.int(v);
            currentTime = Reflect.hasField(o, "currentTime") ? Std.parseFloat(Std.string(Reflect.field(o, "currentTime"))) : 0;
            paused = Reflect.hasField(o, "paused") && Reflect.field(o, "paused") == true;
            minSpeed = Reflect.hasField(o, "minSpeed") ? Std.parseFloat(Std.string(Reflect.field(o, "minSpeed"))) : minSpeed;
            maxSpeed = Reflect.hasField(o, "maxSpeed") ? Std.parseFloat(Std.string(Reflect.field(o, "maxSpeed"))) : maxSpeed;
            if (maxSpeed < 0.01) {
                minSpeed = 120;
                maxSpeed = 0.5;
            }
            if (minSpeed <= maxSpeed) {
                minSpeed = 120;
                maxSpeed = 0.5;
            }
            if (Reflect.hasField(o, "areaWidth")) {
                areaWidth = Std.int(Reflect.field(o, "areaWidth"));
            }
            if (Reflect.hasField(o, "areaHeight")) {
                areaHeight = Std.int(Reflect.field(o, "areaHeight"));
            }
            events = [];
            var arr:Array<Dynamic> = Reflect.field(o, "sliders");
            var layoutOk = ver >= 2 && arr != null && arr.length == SLIDER_COUNT;
            if (layoutOk) {
                var w0 = Std.parseFloat(Std.string(Reflect.field(arr[0], "width")));
                var minWide = (areaWidth * 1.0 - 48.0 - 36.0) / SLIDER_COUNT * 0.85;
                if (w0 < minWide) {
                    layoutOk = false;
                }
            }
            sliders = buildSliders();
            if (layoutOk) {
                for (i in 0...arr.length) {
                    var e = arr[i];
                    var slot = Reflect.hasField(e, "slot") ? Std.int(Reflect.field(e, "slot")) : i;
                    if (slot < 0 || slot >= sliders.length) {
                        continue;
                    }
                    var ts = sliders[slot];
                    ts.current = Reflect.hasField(e, "current") ? Std.parseFloat(Std.string(Reflect.field(e, "current"))) : ts.bounds.height() / 2;
                    ts.destination = Reflect.hasField(e, "destination") ? Std.parseFloat(Std.string(Reflect.field(e, "destination"))) : ts.current;
                    ts.moving = Reflect.hasField(e, "moving") && Reflect.field(e, "moving") == true;
                    ts.speed = Reflect.hasField(e, "speed") ? Std.parseFloat(Std.string(Reflect.field(e, "speed"))) : 0;
                    if (Reflect.hasField(e, "channel")) setChannel(slot, Std.parseFloat(Std.string(Reflect.field(e, "channel"))));
                    if (Reflect.hasField(e, "ccNumber")) setCcNumber(slot, Std.parseFloat(Std.string(Reflect.field(e, "ccNumber"))));
                    if (Reflect.hasField(e, "label")) setLabel(slot, Std.string(Reflect.field(e, "label")));
                }
            }
            for (s in sliders) {
                s.minSpeed = minSpeed;
                s.maxSpeed = maxSpeed;
            }
            publishTrackValues();
            dirty = true;
        } catch (_:Dynamic) {}
    }

    public function mouseDown(uid:Int, point:LocalPoint):Void {
        for (slider in sliders) {
            if (slider.uid == uid) {
                slider.setDestinationLocal(point.x, point.y);
                dirty = true;
                return;
            }
        }
    }

    public function mouseDragged(uid:Int, point:LocalPoint):Void {}
    public function mouseUp(uid:Int, point:LocalPoint):Void {}
    public function textSubmitted(uid:Int, text:String):Void {
        var track = TimeSliderTracksGenerated.LABEL_UIDS.indexOf(uid);
        if (track >= 0) setLabel(track, text);
    }
    public function newValue(uid:Int, value:Float):Void {
        if (applyLifecycleValue(uid, value)) return;
        // Channel and CC selectors send the number itself.
        var track = TimeSliderTracksGenerated.CHANNEL_UIDS.indexOf(uid);
        if (track >= 0) setChannel(track, value);
        track = TimeSliderTracksGenerated.CC_UIDS.indexOf(uid);
        if (track >= 0) setCcNumber(track, value);
    }
    public function buttonPressed(uid:Int):Void {
        if (uid == RESET_UID) reset();
    }
    public function keyPressed(uid:Int, key:String):Void {}

    public function getSliders():Array<TimeSlider> {
        return sliders;
    }
}

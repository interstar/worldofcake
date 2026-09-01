package timeslider;

import haxe.Json;
import worldofcake.Event;
import worldofcake.ISequencerControl;
import worldofcake.SequencerCore;
import worldofcake.LocalPoint;
import worldofcake.LocalRect;
import generated.timeslider.TimeSliderCompositionGenerated;

class TimeSlider {
    /** Track rectangle in TimeSlider local play-area coordinates. */
    public var bounds:LocalRect;
    public var channel:Int;
    public var ccNumber:Int;
    public var current:Float;
    public var destination:Float;
    public var speed:Float;
    public var moving:Bool;

    /** Seconds to cross vertically when clicking the **left** edge of this track (slow). */
    public var minSpeed:Float;
    /** Seconds when clicking the **right** edge (fast). */
    public var maxSpeed:Float;

    public function new(bounds:LocalRect, channel:Int, ccNumber:Int, minSpeed:Float, maxSpeed:Float) {
        this.bounds = bounds;
        this.channel = channel;
        this.ccNumber = ccNumber;
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
        var u = (px - bounds.left) / bounds.width();
        if (u < 0.001) {
            u = 0.001;
        }
        if (u > 1.0) {
            u = 1.0;
        }

        var targetY = py - bounds.top;
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

    public function getValue():Int {
        return Std.int((bounds.height() - current) / bounds.height() * 127);
    }
}

class TimeSliderSequencer extends SequencerCore implements ISequencerControl {
    public static inline var PLAY_AREA_UID:Int = 1;
    public static inline var CC_EVENT_TYPE:Int = 1;
    public static inline var BASE_CC:Int = 20;
    /** Four parallel tracks (OpenFL + Rack). */
    public static inline var SLIDER_COUNT:Int = TimeSliderCompositionGenerated.TRACK_COUNT;

    public var areaWidth:Int;
    public var areaHeight:Int;

    private var sliders:Array<TimeSlider>;
    /** Travel time (seconds) when clicking the **left** edge of a track (slow). */
    private var minSpeed:Float;
    /** Travel time (seconds) when clicking the **right** edge (fast). */
    private var maxSpeed:Float;
    public function new(width:Int, height:Int, minSpeed:Float, maxSpeed:Float) {
        super(true);
        areaWidth = width;
        areaHeight = height;
        this.minSpeed = minSpeed;
        this.maxSpeed = maxSpeed;

        sliders = buildSliders(width, height, minSpeed, maxSpeed);
    }

    static function buildSliders(width:Int, height:Int, minSpeed:Float, maxSpeed:Float):Array<TimeSlider> {
        return TimeSliderCompositionGenerated.buildTracks(minSpeed, maxSpeed);
    }

    public function reset():Void {
        resetTransport();
        sliders = buildSliders(areaWidth, areaHeight, minSpeed, maxSpeed);
    }

    override function advanceModel(delta:Float):Bool {
        var changed = false;
        for (slider in sliders) {
            if (slider.update(delta)) {
                changed = true;
            }
        }
        return changed;
    }

    public function exportStateJson():String {
        var sliderParts:Array<Dynamic> = [];
        for (s in sliders) {
            sliderParts.push({
                x: s.bounds.left,
                y: s.bounds.top,
                width: s.bounds.width(),
                height: s.bounds.height(),
                channel: s.channel,
                ccNumber: s.ccNumber,
                minSpeed: s.minSpeed,
                maxSpeed: s.maxSpeed,
                current: s.current,
                destination: s.destination,
                moving: s.moving,
                speed: s.speed
            });
        }
        var out = new StringBuf(); out.add('{"v":3,"kind":"timeslider","currentTime":'); out.add(currentTime); out.add(',"paused":'); out.add(paused ? 'true' : 'false'); out.add(',"minSpeed":'); out.add(minSpeed); out.add(',"maxSpeed":'); out.add(maxSpeed); out.add(',"areaWidth":'); out.add(areaWidth); out.add(',"areaHeight":'); out.add(areaHeight); out.add(',"sliders":[');
        for (i in 0...sliderParts.length) { if (i > 0) out.add(','); var s:Dynamic=sliderParts[i]; out.add('{"x":'); out.add(s.x); out.add(',"y":'); out.add(s.y); out.add(',"width":'); out.add(s.width); out.add(',"height":'); out.add(s.height); out.add(',"channel":'); out.add(s.channel); out.add(',"ccNumber":'); out.add(s.ccNumber); out.add(',"minSpeed":'); out.add(s.minSpeed); out.add(',"maxSpeed":'); out.add(s.maxSpeed); out.add(',"current":'); out.add(s.current); out.add(',"destination":'); out.add(s.destination); out.add(',"moving":'); out.add(s.moving ? 'true' : 'false'); out.add(',"speed":'); out.add(s.speed); out.add('}'); }
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
            if (!layoutOk) {
                sliders = buildSliders(areaWidth, areaHeight, minSpeed, maxSpeed);
            } else {
                var next:Array<TimeSlider> = [];
                for (e in arr) {
                    var sx = Std.parseFloat(Std.string(Reflect.field(e, "x")));
                    var sy = Std.parseFloat(Std.string(Reflect.field(e, "y")));
                    var sw = Std.parseFloat(Std.string(Reflect.field(e, "width")));
                    var sh = Std.parseFloat(Std.string(Reflect.field(e, "height")));
                    var ch = Std.int(Reflect.field(e, "channel"));
                    var ccn = Std.int(Reflect.field(e, "ccNumber"));
                    var ts = new TimeSlider(LocalRect.fromTopLeft(new LocalPoint(sx, sy), sw, sh), ch, ccn, minSpeed, maxSpeed);
                    ts.current = Reflect.hasField(e, "current") ? Std.parseFloat(Std.string(Reflect.field(e, "current"))) : sh / 2;
                    ts.destination = Reflect.hasField(e, "destination") ? Std.parseFloat(Std.string(Reflect.field(e, "destination"))) : ts.current;
                    ts.moving = Reflect.hasField(e, "moving") && Reflect.field(e, "moving") == true;
                    ts.speed = Reflect.hasField(e, "speed") ? Std.parseFloat(Std.string(Reflect.field(e, "speed"))) : 0;
                    next.push(ts);
                }
                sliders = next;
            }
            for (s in sliders) {
                s.minSpeed = minSpeed;
                s.maxSpeed = maxSpeed;
            }
            dirty = true;
        } catch (_:Dynamic) {}
    }

    public function mouseDown(uid:Int, point:LocalPoint):Void {
        if (uid != PLAY_AREA_UID) {
            return;
        }

        for (slider in sliders) {
            if (slider.hit(point.x, point.y)) {
                slider.setDestination(point.x, point.y);
                dirty = true;
                break;
            }
        }
    }

    public function mouseDragged(uid:Int, point:LocalPoint):Void {}
    public function mouseUp(uid:Int, point:LocalPoint):Void {}
    public function textSubmitted(uid:Int, text:String):Void {}
    public function newValue(uid:Int, value:Float):Void {}
    public function buttonPressed(uid:Int):Void {}
    public function keyPressed(uid:Int, key:String):Void {}

    public function generateEvents():Void {
        if (paused) {
            return;
        }
        for (slider in sliders) {
            if (slider.moving) {
                events.push(new Event(
                    currentTime,
                    CC_EVENT_TYPE,
                    slider.channel,
                    slider.ccNumber,
                    slider.getValue()
                ));
            }
        }
    }

    public function getSliders():Array<TimeSlider> {
        return sliders;
    }
}

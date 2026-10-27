package gbloink;

import openfl.display.Sprite;

/** Presentation-only rings. Elapsed wall time lets existing ripples fade on pause. */
class CollisionRippleView extends Sprite {
    private var active:Array<{cue:CollisionCue, born:Float}> = [];
    private var epoch:Int = -1;
    private var lastSerial:Int = 0;

    public function new() {
        super();
        mouseEnabled = mouseChildren = false;
    }

    public function update(cues:Array<CollisionCue>, nextEpoch:Int, modelTime:Float):Void {
        var now = haxe.Timer.stamp();
        var hadRings = active.length > 0;
        if (epoch != nextEpoch) {
            active = [];
            lastSerial = 0;
            epoch = nextEpoch;
        }
        var keep = 0;
        for (i in 0...active.length) if (now-active[i].born < 0.9) active[keep++] = active[i];
        while (active.length > keep) active.pop();
        for (cue in cues) {
            if (cue.serial <= lastSerial) continue;
            lastSerial = cue.serial;
            var age = Math.max(0, modelTime-cue.time);
            if (age >= 0.9) continue;
            if (active.length >= Gbloink.MAX_COLLISION_CUES) active.shift();
            active.push({cue:cue, born:now-age});
        }
        if (!hadRings && active.length == 0) return;
        graphics.clear();
        for (ripple in active) {
            var cue = ripple.cue;
            var pair = cue.kind == 2;
            var colour = cue.colour;
            if (pair) {
                var r = (colour >> 16) & 255, g = (colour >> 8) & 255, b = colour & 255;
                colour = (Std.int(r+(255-r)*0.25)<<16) | (Std.int(g+(255-g)*0.25)<<8) | Std.int(b+(255-b)*0.25);
            }
            for (ring in 0...3) {
                var phase = (now-ripple.born-ring*0.08)/0.7;
                if (phase <= 0 || phase >= 1) continue;
                graphics.lineStyle(pair ? 2.4 : 2, colour, (pair ? 0.9 : 0.65)*Math.min(1,(1-phase)*2.5));
                graphics.drawCircle(cue.x, cue.y, 120*cue.velocity/127*phase);
            }
        }
        graphics.lineStyle();
    }
}

package gbloink;

import openfl.display.Sprite;
import gbloink.Gbloink.Block;

/** Presentation-only rings. Elapsed wall time lets existing ripples fade on pause. */
class CollisionRippleView extends Sprite {
    private var active:Array<{cue:CollisionCue, born:Float}> = [];
    private var epoch:Int = -1;
    private var lastSerial:Int = 0;

    public function new() {
        super();
        mouseEnabled = mouseChildren = false;
    }

    public function update(cues:Array<CollisionCue>, nextEpoch:Int, modelTime:Float, blocks:Array<Block>):Void {
        var now = haxe.Timer.stamp();
        var hadRings = active.length > 0;
        if (epoch != nextEpoch) {
            active = [];
            lastSerial = 0;
            epoch = nextEpoch;
        }
        var keep = 0;
        for (i in 0...active.length) if (now-active[i].born < (active[i].cue.kind == 1 ? 1.8 : 0.7)) active[keep++] = active[i];
        while (active.length > keep) active.pop();
        for (cue in cues) {
            if (cue.serial <= lastSerial) continue;
            lastSerial = cue.serial;
            var age = Math.max(0, modelTime-cue.time);
            if (age >= (cue.kind == 1 ? 1.8 : 0.7)) continue;
            if (active.length >= Gbloink.MAX_COLLISION_CUES) active.shift();
            active.push({cue:cue, born:now-age});
        }
        if (!hadRings && active.length == 0) return;
        graphics.clear();
        // Overlaying the same block colour raises its existing 200/255 alpha to 1.
        for (block in blocks) {
            var boost = 0.0;
            for (ripple in active) if (ripple.cue.blockId == block.id) {
                var age = now-ripple.born;
                boost = Math.max(boost,Math.min(1,Math.max(0,(1.8-age)/0.3)));
            }
            if (boost <= 0) continue;
            graphics.beginFill(block.colour,boost);
            graphics.drawRect(block.bounds.left,block.bounds.top,block.bounds.width(),block.bounds.height());
            graphics.endFill();
        }
        for (ripple in active) {
            var cue = ripple.cue;
            var pair = cue.kind == 2;
            var colour = cue.colour;
            if (pair) {
                var r = (colour >> 16) & 255, g = (colour >> 8) & 255, b = colour & 255;
                colour = (Std.int(r+(255-r)*0.25)<<16) | (Std.int(g+(255-g)*0.25)<<8) | Std.int(b+(255-b)*0.25);
            }
            for (ring in 0...3) {
                var phase = (now-ripple.born-ring*0.064)/0.56;
                if (phase <= 0 || phase >= 1) continue;
                graphics.lineStyle(pair ? 2.4 : 2, colour, (pair ? 0.9 : 0.65)*Math.min(1,(1-phase)*2.5));
                graphics.drawCircle(cue.x, cue.y, 96*cue.velocity/127*phase);
            }
        }
        graphics.lineStyle();
    }
}

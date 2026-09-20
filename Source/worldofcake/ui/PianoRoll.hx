package worldofcake.ui;

import openfl.display.Sprite;
import worldofcake.SequenceSnapshot;

/** Platform-neutral score data rendered with simple OpenFL primitives. */
class PianoRoll extends Sprite {
    private var displayWidth:Float;
    private var displayHeight:Float;
    private var snapshot:Null<SequenceSnapshot>;
    private var positionTicks:Float;
    private var zoom:Float;

    public function new(width:Float, height:Float) {
        super();
        displayWidth = width;
        displayHeight = height;
        positionTicks = 0;
        zoom = 1.0;
        redraw();
    }

    public function setScore(value:SequenceSnapshot):Void {
        snapshot = value;
        redraw();
    }

    public function setPositionTicks(value:Float):Void {
        positionTicks = value;
        redraw();
    }

    public function setZoom(value:Float):Void {
        zoom = Math.max(1.0, value);
        redraw();
    }

    private function redraw():Void {
        graphics.clear();
        graphics.beginFill(0x12141A);
        graphics.drawRect(0, 0, displayWidth, displayHeight);
        graphics.endFill();
        if (snapshot == null) return;

        var lowest = 127;
        var highest = 0;
        for (note in snapshot.notes) {
            lowest = Std.int(Math.min(lowest, note.pitch));
            highest = Std.int(Math.max(highest, note.pitch));
        }
        var centre = (lowest + highest) * 0.5;
        var pitchSpan:Int = Std.int(Math.max(36, highest - lowest + 5));
        lowest = Std.int(Math.floor(centre - pitchSpan * 0.5));
        highest = lowest + pitchSpan - 1;
        if (lowest < 0) {
            lowest = 0;
            highest = pitchSpan - 1;
        }
        if (highest > 127) {
            highest = 127;
            lowest = highest - pitchSpan + 1;
        }
        var visibleLength = snapshot.loopLengthTicks / zoom;
        var windowStart = positionTicks - visibleLength * 0.25;
        var windowEnd = windowStart + visibleLength;
        for (note in snapshot.notes) {
            var firstCopy = Std.int(Math.floor(windowStart / snapshot.loopLengthTicks)) - 1;
            var lastCopy = Std.int(Math.floor(windowEnd / snapshot.loopLengthTicks)) + 1;
            for (copy in firstCopy...lastCopy + 1) {
                var noteStart = note.startTick + copy * snapshot.loopLengthTicks;
                var noteEnd = noteStart + note.durationTicks;
                if (noteEnd <= windowStart || noteStart >= windowEnd) continue;
                var x = (noteStart - windowStart) / visibleLength * displayWidth;
                var w = Math.max(2, note.durationTicks / visibleLength * displayWidth);
                if (x < 0) {
                    w += x;
                    x = 0;
                }
                if (x + w > displayWidth) w = displayWidth - x;
                if (w <= 0) continue;
            var y = displayHeight - ((note.pitch - lowest + 1) / pitchSpan * displayHeight);
            var h = Math.max(3, displayHeight / pitchSpan * 0.8);
            var colour = partColour(note.partId);
            graphics.beginFill(colour);
            graphics.drawRect(x, y, w, h);
            graphics.endFill();
            }
        }

        var playhead = (positionTicks - windowStart) / visibleLength * displayWidth;
        graphics.lineStyle(2, 0xF2F2F2, 0.8);
        graphics.moveTo(playhead, 0);
        graphics.lineTo(playhead, displayHeight);
    }

    private function partColour(partId:Int):Int {
        var colours = [
            0x55B7D9,
            0xE56B6F,
            0x76B947,
            0xC58BE8,
            0xF2B84B,
            0x5C8DDE,
            0xE78F55,
            0x63C7B2
        ];
        return colours[Std.int(Math.abs(partId)) % colours.length];
    }
}

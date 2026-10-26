package worldofcake.ui;

import openfl.display.Graphics;

/**
 * Draws an icon from the shared icon set (defined once in laylagen's
 * `icons.clj` and generated into compositions as a flat op list).
 *
 *   0 x y                 move to
 *   1 x y                 line to (stroked)
 *   2 cx cy r start end   arc, degrees, clockwise on screen (stroked)
 *   3 cx cy r             filled dot
 *
 * Coordinates are in a 16x16 box, drawn into a `size` square at (left, top).
 */
class IconPainter {
    public static inline var BOX:Float = 16;
    public static inline var STROKE:Float = 1.6;

    public static function draw(g:Graphics, ops:Array<Float>, left:Float, top:Float, size:Float, colour:Int):Void {
        var k = size / BOX;
        g.lineStyle(STROKE * k, colour, 1.0, false, null, openfl.display.CapsStyle.ROUND, openfl.display.JointStyle.ROUND);
        var i = 0;
        while (i < ops.length) {
            switch (Std.int(ops[i])) {
                case 0:
                    g.moveTo(left + ops[i + 1] * k, top + ops[i + 2] * k);
                    i += 3;
                case 1:
                    g.lineTo(left + ops[i + 1] * k, top + ops[i + 2] * k);
                    i += 3;
                case 2:
                    var cx = ops[i + 1], cy = ops[i + 2], r = ops[i + 3], start = ops[i + 4], end = ops[i + 5];
                    var steps = Std.int(Math.max(2, Math.ceil(Math.abs(end - start) / 15)));
                    for (step in 0...steps + 1) {
                        var a = (start + (end - start) * step / steps) * Math.PI / 180;
                        var px = left + (cx + r * Math.cos(a)) * k;
                        var py = top + (cy + r * Math.sin(a)) * k;
                        if (step == 0) g.moveTo(px, py) else g.lineTo(px, py);
                    }
                    i += 6;
                case 3:
                    g.lineStyle();
                    g.beginFill(colour);
                    g.drawCircle(left + ops[i + 1] * k, top + ops[i + 2] * k, ops[i + 3] * k);
                    g.endFill();
                    g.lineStyle(STROKE * k, colour, 1.0, false, null, openfl.display.CapsStyle.ROUND, openfl.display.JointStyle.ROUND);
                    i += 4;
                default:
                    throw 'Unknown icon opcode ${ops[i]}';
            }
        }
        g.lineStyle();
    }
}

package worldofcake.ui;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import worldofcake.CoordinateMapper;
import worldofcake.ISequencerControl;
import worldofcake.LocalPoint;
import worldofcake.PanelPoint;
import worldofcake.WindowPoint;

/** Exclusive semantic choice control with lightweight OpenFL presentations. */
class SemanticSelect extends Sprite implements IComponent {
    private var common:ComponentCommon;
    private var labels:Array<String>;
    private var values:Array<Float>;
    private var colours:Array<Int>;
    private var presentation:String;
    private var selectedIndex:Int;

    public function new(uid:Int, pos:PanelPoint, size:PanelPoint, mapper:CoordinateMapper,
                        sequencer:ISequencerControl, labels:Array<String>, values:Array<Float>,
                        colours:Array<Int>, defaultIndex:Int, presentation:String) {
        super();
        if (labels.length == 0 || labels.length != values.length || labels.length != colours.length)
            throw "SemanticSelect choice arrays must be non-empty and equal in length";
        common = new ComponentCommon(uid, pos, size, mapper, new LocalPoint(0, 0), new LocalPoint(size.x, size.y), sequencer);
        this.labels = labels; this.values = values; this.colours = colours;
        this.presentation = presentation; selectedIndex = clampIndex(defaultIndex);
        var p = panelToWindow(pos); x = p.x; y = p.y;
        redraw();
    }

    public function setSelectedIndex(index:Int):Void {
        var next = clampIndex(index);
        if (next != selectedIndex) { selectedIndex = next; redraw(); }
    }
    public function getSelectedIndex():Int return selectedIndex;

    /** Compact: a click steps one choice (left half back, right half on); a vertical drag scrolls through them. */
    private static inline var DRAG_PIXELS_PER_STEP:Float = 6;
    private var pressed:Bool = false;
    private var dragging:Bool = false;
    private var pressX:Float = 0;
    private var pressY:Float = 0;
    private var pressIndex:Int = 0;

    public function handleMouseDown(point:WindowPoint):Bool {
        if (!common.inBounds(point)) return false;
        var local = windowToLocal(point);
        if (presentation == "compact") {
            pressed = true;
            dragging = false;
            pressX = local.x;
            pressY = point.y;
            pressIndex = selectedIndex;
        } else {
            choose(Std.int(Math.floor(local.x / (common.getSize().x / labels.length))));
        }
        return true;
    }

    public function handleMouseDragged(point:WindowPoint):Bool {
        if (!pressed) return false;
        var rise = pressY - point.y;
        if (!dragging && Math.abs(rise) < DRAG_PIXELS_PER_STEP) return true;
        dragging = true;
        var steps = Std.int(rise / DRAG_PIXELS_PER_STEP);
        choose(Std.int(Math.max(0, Math.min(labels.length - 1, pressIndex + steps))));
        return true;
    }

    public function handleMouseUp(point:WindowPoint):Bool {
        if (pressed && !dragging) choose(selectedIndex + (pressX < common.getSize().x * 0.5 ? -1 : 1));
        pressed = false;
        dragging = false;
        return true;
    }

    /** Select a choice and tell the model its value. */
    private function choose(index:Int):Void {
        var next = clampIndex(index);
        if (next == selectedIndex) return;
        setSelectedIndex(next);
        common.sequencer.newValue(getUID(), values[selectedIndex]);
    }

    public function redraw():Void {
        graphics.clear(); while (numChildren > 0) removeChildAt(0);
        var size = common.getWindowSize();
        if (presentation == "compact") drawCompact(size.x, size.y); else drawSegmented(size.x, size.y);
    }

    /** One segment per choice in its colour: solid when selected, a light tint otherwise. */
    private function drawSegmented(width:Float, height:Float):Void {
        var itemWidth = width / labels.length;
        for (i in 0...labels.length) {
            var selected = i == selectedIndex;
            graphics.lineStyle(1, colours[i], selected ? 1.0 : 0.55);
            graphics.beginFill(colours[i], selected ? 1.0 : 0.16);
            graphics.drawRoundRect(i * itemWidth + 1, 0.5, itemWidth - 2, height - 1, Chrome.CORNER, Chrome.CORNER);
            graphics.endFill();
            addLabel(labels[i], i * itemWidth, 0, itemWidth, height, selected ? 0xFFFFFF : Chrome.TEXT, selected);
        }
        graphics.lineStyle();
    }

    /** Light face with the current choice and a chevron at each end (click a half to step). */
    private function drawCompact(width:Float, height:Float):Void {
        Chrome.drawFace(this, width, height, false, false);
        var chevron = Math.min(height * 0.18, 5);
        var margin = Math.min(height * 0.7, 18);
        chevronAt(margin * 0.6, height * 0.5, -chevron);
        chevronAt(width - margin * 0.6, height * 0.5, chevron);
        addLabel(labels[selectedIndex], margin, 0, width - 2 * margin, height, Chrome.TEXT, false);
    }

    private function chevronAt(cx:Float, cy:Float, half:Float):Void {
        graphics.lineStyle(1.6, Chrome.TEXT, 1.0, false, null, openfl.display.CapsStyle.ROUND, openfl.display.JointStyle.ROUND);
        graphics.moveTo(cx - half * 0.5, cy - Math.abs(half));
        graphics.lineTo(cx + half * 0.5, cy);
        graphics.lineTo(cx - half * 0.5, cy + Math.abs(half));
        graphics.lineStyle();
    }

    private function addLabel(text:String, px:Float, py:Float, width:Float, height:Float,
                              colour:Int = 0xFFFFFF, bold:Bool = true):Void {
        var field = new TextField();
        field.defaultTextFormat = new TextFormat("_sans", 12, colour, bold, null, null, null, null, "center");
        field.selectable = false; field.mouseEnabled = false; field.text = text;
        field.x = px; field.y = py + Math.max(0, (height - 18) * 0.5); field.width = width; field.height = 20;
        addChild(field);
    }

    private function clampIndex(index:Int):Int {
        var n = labels.length;
        return presentation == "compact" ? ((index % n) + n) % n : Std.int(Math.max(0, Math.min(n - 1, index)));
    }

    public function getUID():Int return common.uid;
    public function panelToWindow(p:PanelPoint):WindowPoint return common.panelToWindow(p);
    public function localToPanel(p:LocalPoint):PanelPoint return common.localToPanel(p);
    public function localToWindow(p:LocalPoint):WindowPoint return common.localToWindow(p);
    public function windowToLocal(p:WindowPoint):LocalPoint return common.windowToLocal(p);
    public function windowToPanel(p:WindowPoint):PanelPoint return common.windowToPanel(p);
    public function panelToLocal(p:PanelPoint):LocalPoint return common.panelToLocal(p);
    public function panelLengthToWindowLength(v:Float):Float return common.panelLengthToWindowLength(v);
    public function windowLengthToPanelLength(v:Float):Float return common.windowLengthToPanelLength(v);
    public function localLengthToWindowLength(v:Float):Float return common.localLengthToWindowLength(v);
    public function windowLengthToLocalLength(v:Float):Float return common.windowLengthToLocalLength(v);
    public function getPosition():PanelPoint return common.getPosition();
    public function getSize():PanelPoint return common.getSize();
    public function getMaxPoint():PanelPoint return common.getMaxPoint();
}

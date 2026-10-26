package worldofcake.ui;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import worldofcake.CoordinateMapper;
import worldofcake.ISequencerControl;
import worldofcake.LocalPoint;
import worldofcake.PanelPoint;
import worldofcake.WindowPoint;

class Knob extends Sprite implements IValueControl {
    private var common:ComponentCommon;
    private var label:String;
    private var showLabel:Bool;
    private var color:Int;
    private var min:Float;
    private var max:Float;
    private var value:Float;
    private var mapping:String;
    private var dragStartY:Float;
    private var dragStartValue:Float;

    public function new(uid:Int, panelPos:PanelPoint, panelSize:PanelPoint, windowToPanelMapper:CoordinateMapper,
                        sequencer:ISequencerControl, min:Float, max:Float, defaultValue:Float, label:String, color:Int,
                        mapping:String = "linear", showLabel:Bool = true) {
        super();
        common = new ComponentCommon(uid, panelPos, panelSize, windowToPanelMapper,
            new LocalPoint(0, 0), new LocalPoint(panelSize.x, panelSize.y), sequencer);
        this.min = min;
        this.max = max;
        this.value = clamp(defaultValue);
        this.mapping = mapping;
        this.label = label;
        this.showLabel = showLabel;
        this.color = color;
        var windowPos = panelToWindow(panelPos);
        x = windowPos.x;
        y = windowPos.y;
        redraw();
    }

    public function setValue(v:Float):Void {
        value = clamp(v);
        redraw();
    }

    public function handleMouseDown(point:WindowPoint):Bool {
        if (!common.inBounds(point)) return false;
        dragStartY = point.y;
        dragStartValue = value;
        updateFromPoint(point, true);
        return true;
    }

    public function handleMouseDragged(point:WindowPoint):Bool {
        var span = Math.max(1.0, common.getWindowSize().y);
        var normalized = valueToNormalized(dragStartValue) + ((dragStartY - point.y) / span);
        value = normalizedToValue(Math.max(0.0, Math.min(1.0, normalized)));
        common.sequencer.newValue(getUID(), value);
        redraw();
        return true;
    }

    public function handleMouseUp(point:WindowPoint):Bool return true;

    private function updateFromPoint(point:WindowPoint, notify:Bool):Void {
        var local = windowToLocal(point);
        var h = Math.max(1.0, common.getSize().y);
        value = normalizedToValue(Math.max(0.0, Math.min(1.0, 1.0 - local.y / h)));
        if (notify) common.sequencer.newValue(getUID(), value);
        redraw();
    }

    private function clamp(v:Float):Float return Math.max(min, Math.min(max, v));

    private function usesLogarithmicMapping():Bool {
        return mapping == "logarithmic" && min > 0.0 && max > min;
    }

    private function valueToNormalized(v:Float):Float {
        var clamped = clamp(v);
        return usesLogarithmicMapping()
            ? Math.log(clamped / min) / Math.log(max / min)
            : (clamped - min) / (max - min);
    }

    private function normalizedToValue(normalized:Float):Float {
        return usesLogarithmicMapping()
            ? min * Math.pow(max / min, normalized)
            : min + normalized * (max - min);
    }

    public static inline var SWEEP_START:Float = 135;
    public static inline var SWEEP:Float = 270;
    private static inline var LABEL_HEIGHT:Float = 16;

    public function redraw():Void {
        graphics.clear();
        while (numChildren > 0) removeChildAt(0);
        var size = common.getWindowSize();
        var labelSpace = showLabel ? LABEL_HEIGHT : 0;
        var diameter = Math.max(4, Math.min(size.x, size.y - labelSpace) - 4);
        var cx = size.x * 0.5;
        var cy = (size.y - labelSpace) * 0.5;
        var thickness = Math.max(2, diameter * 0.09);
        var radius = (diameter - thickness) * 0.5;
        arc(cx, cy, radius, SWEEP_START, SWEEP_START + SWEEP, thickness, Chrome.TRACK);
        var valueEnd = SWEEP_START + valueToNormalized(value) * SWEEP;
        arc(cx, cy, radius, SWEEP_START, valueEnd, thickness, color);
        graphics.lineStyle(1, Chrome.BORDER);
        graphics.beginFill(Chrome.FACE);
        graphics.drawCircle(cx, cy, radius * 0.55);
        graphics.endFill();
        graphics.lineStyle();
        if (showLabel) addLabel(size.x, size.y);
    }

    private function arc(cx:Float, cy:Float, r:Float, startDegrees:Float, endDegrees:Float, thickness:Float, colour:Int):Void {
        graphics.lineStyle(thickness, colour, 1.0, false, null, openfl.display.CapsStyle.ROUND);
        var steps = Std.int(Math.max(1, Math.ceil(Math.abs(endDegrees - startDegrees) / 6)));
        for (i in 0...steps + 1) {
            var a = (startDegrees + (endDegrees - startDegrees) * i / steps) * Math.PI / 180;
            if (i == 0) graphics.moveTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
            else graphics.lineTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
        }
    }

    private function addLabel(width:Float, height:Float):Void {
        var field = new TextField();
        field.defaultTextFormat = new TextFormat("_sans", 11, Chrome.TEXT, false, null, null, null, null, "center");
        field.selectable = false;
        field.mouseEnabled = false;
        field.text = label;
        field.x = 0;
        field.y = height - LABEL_HEIGHT;
        field.width = width;
        field.height = LABEL_HEIGHT + 2;
        addChild(field);
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

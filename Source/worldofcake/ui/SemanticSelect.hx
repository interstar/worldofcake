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

    public function handleMouseDown(point:WindowPoint):Bool {
        if (!common.inBounds(point)) return false;
        var local = windowToLocal(point);
        if (presentation == "compact") {
            setSelectedIndex(selectedIndex + (local.x < common.getSize().x * 0.5 ? -1 : 1));
        } else {
            setSelectedIndex(Std.int(Math.floor(local.x / (common.getSize().x / labels.length))));
        }
        common.sequencer.newValue(getUID(), values[selectedIndex]);
        return true;
    }
    public function handleMouseDragged(point:WindowPoint):Bool return false;
    public function handleMouseUp(point:WindowPoint):Bool return true;

    public function redraw():Void {
        graphics.clear(); while (numChildren > 0) removeChildAt(0);
        var size = common.getWindowSize();
        if (presentation == "compact") drawCompact(size.x, size.y); else drawSegmented(size.x, size.y);
    }

    private function drawSegmented(width:Float, height:Float):Void {
        var itemWidth = width / labels.length;
        for (i in 0...labels.length) {
            graphics.lineStyle(i == selectedIndex ? 3 : 1, i == selectedIndex ? 0xFFFFFF : 0x202020);
            graphics.beginFill(colours[i], i == selectedIndex ? 1.0 : 0.4);
            graphics.drawRect(i * itemWidth, 0, itemWidth, height); graphics.endFill();
            addLabel(labels[i], i * itemWidth, 0, itemWidth, height);
        }
    }

    private function drawCompact(width:Float, height:Float):Void {
        graphics.lineStyle(2, 0xFFFFFF); graphics.beginFill(0x242832);
        graphics.drawRect(0, 0, width, height); graphics.endFill();
        addLabel("<", 0, 0, width * 0.18, height);
        addLabel(labels[selectedIndex], width * 0.18, 0, width * 0.64, height);
        addLabel(">", width * 0.82, 0, width * 0.18, height);
    }

    private function addLabel(text:String, px:Float, py:Float, width:Float, height:Float):Void {
        var field = new TextField();
        field.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF, true, null, null, null, null, "center");
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

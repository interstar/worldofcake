package worldofcake.ui;

import openfl.display.Sprite;
import openfl.events.Event;
import worldofcake.CoordinateMapper;
import worldofcake.ISequencerControl;
import worldofcake.LocalPoint;
import worldofcake.PanelPoint;
import worldofcake.WindowPoint;

class Toggle extends Sprite implements IComponent {
    private var common:ComponentCommon;
    private var label:String;
    private var color:Int;
    /** Shared icon op list (see `IconPainter`), drawn instead of the label when present. */
    private var icon:Array<Float>;
    /** Used only for toggles whose value the model does not own (see `controlValue`). */
    private var localValue:Bool;
    /** Value last drawn; a render cache, never the source of truth. */
    private var drawnValue:Bool;

    public function new(uid:Int, panelPos:PanelPoint, panelSize:PanelPoint, windowToPanelMapper:CoordinateMapper,
                        sequencer:ISequencerControl, label:String, defaultValue:Bool, color:Int, ?icon:Array<Float>) {
        super();
        common = new ComponentCommon(uid, panelPos, panelSize, windowToPanelMapper,
            new LocalPoint(0, 0), new LocalPoint(panelSize.x, panelSize.y), sequencer);
        this.label = label;
        this.localValue = defaultValue;
        this.drawnValue = currentValue();
        this.color = color;
        this.icon = icon;
        var windowPos = panelToWindow(panelPos);
        x = windowPos.x;
        y = windowPos.y;
        redraw();
        // Model-backed values (e.g. pause/mute) can change without a click.
        addEventListener(Event.ENTER_FRAME, function(_) refresh());
    }

    public function setValue(v:Bool):Void {
        localValue = v;
        refresh();
    }

    private function currentValue():Bool {
        var modelValue = common.sequencer.controlValue(getUID());
        return modelValue == null ? localValue : modelValue > 0.5;
    }

    private function refresh():Void {
        var v = currentValue();
        if (v != drawnValue) {
            drawnValue = v;
            redraw();
        }
    }

    public function handleMouseDown(point:WindowPoint):Bool {
        if (!common.inBounds(point)) return false;
        localValue = !currentValue();
        common.sequencer.newValue(getUID(), localValue ? 1.0 : 0.0);
        refresh();
        return true;
    }

    public function handleMouseDragged(point:WindowPoint):Bool return false;
    public function handleMouseUp(point:WindowPoint):Bool return true;

    public function redraw():Void {
        graphics.clear();
        while (numChildren > 0) removeChildAt(0);
        var size = common.getWindowSize();
        Chrome.drawFace(this, size.x, size.y, drawnValue, false);
        Chrome.drawContent(this, size.x, size.y, label, icon, color);
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

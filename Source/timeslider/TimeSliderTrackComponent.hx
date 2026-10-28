package timeslider;

import openfl.display.Sprite;
import worldofcake.CoordinateMapper;
import worldofcake.ISequencerControl;
import worldofcake.LocalPoint;
import worldofcake.PanelPoint;
import worldofcake.WindowPoint;
import worldofcake.ui.ComponentCommon;
import worldofcake.ui.IComponent;

class TimeSliderTrackComponent extends Sprite implements IComponent {
    private var componentCommon:ComponentCommon;

    public function new(uid:Int, panelPos:PanelPoint, panelSize:PanelPoint, windowToPanelMapper:CoordinateMapper, sequencer:ISequencerControl) {
        super();
        // The lane's own space: x from 0 (left) to 1 (right), y from 1 (top) to 0 (bottom), so a
        // click reaches the model as (time fraction, target value) with no panel geometry.
        componentCommon = new ComponentCommon(
            uid,
            panelPos,
            panelSize,
            windowToPanelMapper,
            new LocalPoint(0, 1),
            new LocalPoint(1, 0),
            sequencer
        );

        var windowPos = panelToWindow(panelPos);
        this.x = windowPos.x;
        this.y = windowPos.y;
    }

    public function getUID():Int return componentCommon.uid;

    public function panelToWindow(p:PanelPoint):WindowPoint return componentCommon.panelToWindow(p);
    public function localToPanel(p:LocalPoint):PanelPoint return componentCommon.localToPanel(p);
    public function localToWindow(p:LocalPoint):WindowPoint return componentCommon.localToWindow(p);
    public function windowToLocal(p:WindowPoint):LocalPoint return componentCommon.windowToLocal(p);
    public function windowToPanel(p:WindowPoint):PanelPoint return componentCommon.windowToPanel(p);
    public function panelToLocal(p:PanelPoint):LocalPoint return componentCommon.panelToLocal(p);

    public function handleMouseDown(windowPoint:WindowPoint):Bool return componentCommon.handleMouseDown(windowPoint);
    public function handleMouseDragged(windowPoint:WindowPoint):Bool return componentCommon.handleMouseDragged(windowPoint);
    public function handleMouseUp(windowPoint:WindowPoint):Bool return componentCommon.handleMouseUp(windowPoint);

    public function panelLengthToWindowLength(l:Float):Float return componentCommon.panelLengthToWindowLength(l);
    public function windowLengthToPanelLength(l:Float):Float return componentCommon.windowLengthToPanelLength(l);
    public function localLengthToWindowLength(l:Float):Float return componentCommon.localLengthToWindowLength(l);
    public function windowLengthToLocalLength(l:Float):Float return componentCommon.windowLengthToLocalLength(l);

    public function getPosition():PanelPoint return componentCommon.getPosition();
    public function getSize():PanelPoint return componentCommon.getSize();
    public function getMaxPoint():PanelPoint return componentCommon.getMaxPoint();
}

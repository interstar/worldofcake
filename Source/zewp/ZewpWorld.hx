package zewp;

import generated.zewp.ZewpCompositionGenerated;
import worldofcake.BasePoint;
import worldofcake.CoordinateMapper;
import worldofcake.IControlPanelView;
import worldofcake.WindowPoint;
import worldofcake.ui.IFullApp;
import worldofcake.ui.IComponent;

class ZewpWorld implements IFullApp {
    private var sequencer:ZewpSequencer;
    private var view:ZewpView;
    private var components:Array<IComponent>;
    private var activeComponent:IComponent;
    private var windowToPanelMapper:CoordinateMapper;

    public function new() {
        windowToPanelMapper = new CoordinateMapper(
            new BasePoint(0, 0),
            new BasePoint(ZewpLayout.WINDOW_WIDTH, ZewpLayout.WINDOW_HEIGHT),
            new BasePoint(0, 0),
            new BasePoint(ZewpLayout.PANEL_WIDTH, ZewpLayout.PANEL_HEIGHT)
        );

        sequencer = new ZewpSequencer(Std.int(ZewpLayout.PLAY_AREA_WIDTH), Std.int(ZewpLayout.PLAY_AREA_HEIGHT));
        view = new ZewpView(sequencer, windowToPanelMapper);
        components = ZewpCompositionGenerated.build(sequencer, windowToPanelMapper, view);
    }

    public function handleMouseDown(windowPoint:WindowPoint):Void {
        for (component in components) {
            if (component.handleMouseDown(windowPoint)) {
                activeComponent = component;
                return;
            }
        }
    }

    public function handleMouseDrag(windowPoint:WindowPoint):Void {
        if (activeComponent != null) {
            activeComponent.handleMouseDragged(windowPoint);
        }
    }

    public function handleMouseUp(windowPoint:WindowPoint):Void {
        if (activeComponent != null) {
            activeComponent.handleMouseUp(windowPoint);
            activeComponent = null;
        }
    }

    public function handleKeyPressed(key:String):Void {
        sequencer.keyPressed(ZewpSequencer.PLAY_AREA_UID, key);
    }

    public function getView():IControlPanelView {
        return view;
    }

    public function resize(width:Float, height:Float):Void {
        windowToPanelMapper = new CoordinateMapper(
            new BasePoint(0, 0),
            new BasePoint(width, height),
            new BasePoint(0, 0),
            new BasePoint(ZewpLayout.PANEL_WIDTH, ZewpLayout.PANEL_HEIGHT)
        );
    }

    public function getSequencer():ZewpSequencer {
        return sequencer;
    }
}

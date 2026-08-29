package gbloink;

import generated.gbloink.GbloinkCompositionGenerated;
import worldofcake.PanelPoint;
import worldofcake.LocalPoint;
import worldofcake.IControlPanelView;
import worldofcake.ui.IFullApp;
import worldofcake.CoordinateMapper;
import worldofcake.WindowPoint;
import worldofcake.BasePoint;
import worldofcake.ui.IComponent;

class GbloinkWorld implements IFullApp {
    private var sequencer:Gbloink;
    private var view:GbloinkView;
    private var components:Array<IComponent>;
    private var activeComponent:IComponent;
    private var windowToPanelMapper:CoordinateMapper;

    public function new() {
        windowToPanelMapper = new CoordinateMapper(
            new BasePoint(0, 0),
            new BasePoint(GbloinkLayout.WINDOW_WIDTH, GbloinkLayout.WINDOW_HEIGHT),
            new BasePoint(0, 0),
            new BasePoint(GbloinkLayout.PANEL_WIDTH, GbloinkLayout.PANEL_HEIGHT)
        );

        sequencer = new Gbloink(new LocalPoint(GbloinkLayout.LOCAL_WIDTH, GbloinkLayout.LOCAL_HEIGHT));
        view = new GbloinkView(sequencer, windowToPanelMapper);
        components = GbloinkCompositionGenerated.build(sequencer, windowToPanelMapper, view);
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
        if (activeComponent != null) activeComponent.handleMouseDragged(windowPoint);
    }

    public function handleMouseUp(windowPoint:WindowPoint):Void {
        if (activeComponent != null) {
            activeComponent.handleMouseUp(windowPoint);
            activeComponent = null;
        }
    }

    public function getView():IControlPanelView return view;

    public function resize(width:Float, height:Float):Void {
        windowToPanelMapper = new CoordinateMapper(
            new BasePoint(0, 0), new BasePoint(width, height),
            new BasePoint(0, 0), new BasePoint(GbloinkLayout.PANEL_WIDTH, GbloinkLayout.PANEL_HEIGHT)
        );
    }

    public function getSequencer():Gbloink return sequencer;

    public function handleKeyPressed(key:String):Void {
        sequencer.keyPressed(Gbloink.PLAY_AREA_UID, key);
    }
}

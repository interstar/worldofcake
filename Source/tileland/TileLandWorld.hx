package tileland;

import generated.tileland.TileLandCompositionGenerated;
import worldofcake.BasePoint;
import worldofcake.CoordinateMapper;
import worldofcake.IControlPanelView;
import worldofcake.WindowPoint;
import worldofcake.ui.IComponent;
import worldofcake.ui.IFullApp;

class TileLandWorld implements IFullApp {
    private var sequencer:TileLandSequencer;
    private var view:TileLandView;
    private var components:Array<IComponent>;
    private var activeComponent:IComponent;
    private var windowToPanelMapper:CoordinateMapper;

    public function new() {
        windowToPanelMapper = createMapper(TileLandLayout.WINDOW_WIDTH, TileLandLayout.WINDOW_HEIGHT);
        sequencer = new TileLandSequencer();
        view = new TileLandView(sequencer, windowToPanelMapper);
        components = TileLandCompositionGenerated.build(sequencer, windowToPanelMapper, view);
    }

    private function createMapper(width:Float, height:Float):CoordinateMapper {
        return new CoordinateMapper(
            new BasePoint(0, 0), new BasePoint(width, height),
            new BasePoint(0, 0), new BasePoint(TileLandLayout.PANEL_WIDTH, TileLandLayout.PANEL_HEIGHT)
        );
    }

    public function handleMouseDown(point:WindowPoint):Void {
        for (component in components) {
            if (component.handleMouseDown(point)) {
                activeComponent = component;
                return;
            }
        }
    }

    public function handleMouseDrag(point:WindowPoint):Void {
        if (activeComponent != null) activeComponent.handleMouseDragged(point);
    }

    public function handleMouseUp(point:WindowPoint):Void {
        if (activeComponent != null) {
            activeComponent.handleMouseUp(point);
            activeComponent = null;
        }
    }

    public function handleKeyPressed(key:String):Void sequencer.keyPressed(TileLandSequencer.PLAY_AREA_UID, key);
    public function getView():IControlPanelView return view;
    public function resize(width:Float, height:Float):Void windowToPanelMapper = createMapper(width, height);
    public function getSequencer():TileLandSequencer return sequencer;
}

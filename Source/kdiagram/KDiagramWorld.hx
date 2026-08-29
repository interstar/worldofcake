package kdiagram;

import generated.kdiagram.KDiagramCompositionGenerated;
import worldofcake.BasePoint;
import worldofcake.CoordinateMapper;
import worldofcake.IControlPanelView;
import worldofcake.WindowPoint;
import worldofcake.ui.IComponent;
import worldofcake.ui.IFullApp;

class KDiagramWorld implements IFullApp {
    private var sequencer:KDiagramSequencer;
    private var view:KDiagramView;
    private var components:Array<IComponent>;
    private var activeComponent:IComponent;
    private var windowToPanelMapper:CoordinateMapper;

    public function new() {
        windowToPanelMapper = createMapper(KDiagramLayout.WINDOW_WIDTH, KDiagramLayout.WINDOW_HEIGHT);
        sequencer = new KDiagramSequencer();
        view = new KDiagramView(sequencer, windowToPanelMapper);
        components = KDiagramCompositionGenerated.build(sequencer, windowToPanelMapper, view);
    }

    private function createMapper(width:Float, height:Float):CoordinateMapper {
        return new CoordinateMapper(
            new BasePoint(0, 0), new BasePoint(width, height),
            new BasePoint(0, 0), new BasePoint(KDiagramLayout.PANEL_WIDTH, KDiagramLayout.PANEL_HEIGHT)
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

    public function handleKeyPressed(key:String):Void sequencer.keyPressed(KDiagramSequencer.PLAY_AREA_UID, key);
    public function getView():IControlPanelView return view;
    public function resize(width:Float, height:Float):Void windowToPanelMapper = createMapper(width, height);
    public function getSequencer():KDiagramSequencer return sequencer;
}

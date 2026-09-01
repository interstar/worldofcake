package worldofcake.ui;

import worldofcake.BasePoint;
import worldofcake.CoordinateMapper;
import worldofcake.IControlPanelView;
import worldofcake.ISequencer;
import worldofcake.WindowPoint;

class ComponentWorldBase implements ISequencerWorld {
    private var view:IControlPanelView;
    private var components:Array<IComponent>;
    private var activeComponent:IComponent;
    private var windowToPanelMapper:CoordinateMapper;
    private var panelWidth:Float;
    private var panelHeight:Float;

    public function new(initialWindowWidth:Float, initialWindowHeight:Float, panelWidth:Float, panelHeight:Float) {
        this.panelWidth = panelWidth;
        this.panelHeight = panelHeight;
        this.components = [];
        this.windowToPanelMapper = createMapper(initialWindowWidth, initialWindowHeight);
    }

    private function createMapper(width:Float, height:Float):CoordinateMapper {
        return new CoordinateMapper(
            new BasePoint(0, 0), new BasePoint(width, height),
            new BasePoint(0, 0), new BasePoint(panelWidth, panelHeight)
        );
    }

    private function getWindowToPanelMapper():CoordinateMapper {
        return windowToPanelMapper;
    }

    private function setView(view:IControlPanelView):Void {
        this.view = view;
    }

    private function setComponents(components:Array<IComponent>):Void {
        this.components = components;
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

    public function handleKeyPressed(key:String):Void {}

    public function getView():IControlPanelView {
        return view;
    }

    public function getSequencer():ISequencer {
        throw "ComponentWorldBase.getSequencer must be overridden";
    }

    public function resize(width:Float, height:Float):Void {
        windowToPanelMapper = createMapper(width, height);
    }
}

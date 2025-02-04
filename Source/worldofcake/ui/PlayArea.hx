package worldofcake.ui;

import worldofcake.ISequencerControl;
import worldofcake.IControlPanel;
import worldofcake.CoordinateMapper;
import worldofcake.PanelPoint;
import worldofcake.BasePoint;
import worldofcake.LocalPoint;
import openfl.display.Sprite;

class PlayArea extends Sprite implements IComponent {
    private var componentCommon:BaseComponent;
    
    public function new(uid:Int, x:Float, y:Float, width:Float, height:Float,
                       mapper:CoordinateMapper, 
                       localMinPoint:LocalPoint, localMaxPoint:LocalPoint,
                       sequencer:ISequencerControl) {
        super();
        componentCommon = new BaseComponent(uid, x, y, width, height, mapper,
                                          localMinPoint, localMaxPoint, sequencer);
                                          
        var windowPos = panelToWindow(new PanelPoint(x, y));
        this.x = windowPos.x;
        this.y = windowPos.y;
    }
    
    // Implement IComponent by delegating to componentCommon
    public function getUID():Int return componentCommon.uid;
    
    public function panelToWindow(p:PanelPoint):WindowPoint return componentCommon.panelToWindow(p);
    public function localToPanel(p:LocalPoint):PanelPoint return componentCommon.localToPanel(p);
    public function localToWindow(p:LocalPoint):WindowPoint return componentCommon.localToWindow(p);
    public function windowToLocal(p:WindowPoint):LocalPoint return componentCommon.windowToLocal(p);
    public function windowToPanel(p:WindowPoint):PanelPoint return componentCommon.windowToPanel(p);
    public function panelToLocal(p:PanelPoint):LocalPoint return componentCommon.panelToLocal(p);
    
    public function handleMouseDown(p:WindowPoint):Bool return componentCommon.handleMouseDown(p);
    public function handleMouseDrag(p:WindowPoint):Bool return componentCommon.handleMouseDrag(p);
    public function handleMouseUp(p:WindowPoint):Bool return componentCommon.handleMouseUp(p);
    
    public function panelLengthToWindowLength(l:Float):Float return componentCommon.panelLengthToWindowLength(l);
    public function windowLengthToPanelLength(l:Float):Float return componentCommon.windowLengthToPanelLength(l);
    
    public function localLengthToWindowLength(l:Float):Float return componentCommon.localLengthToWindowLength(l);
    public function windowLengthToLocalLength(l:Float):Float return componentCommon.windowLengthToLocalLength(l);
    
    private function onLocalMouseDown(point:PanelPoint):Bool {
        componentCommon.sequencer.mouseDown(componentCommon.uid, panelToLocal(point));
        return true;
    }
    
    private function onLocalMouseDrag(point:PanelPoint):Bool {
        componentCommon.sequencer.mouseDragged(componentCommon.uid, panelToLocal(point));
        return true;
    }
    
    private function onLocalMouseUp(point:PanelPoint):Bool {
        componentCommon.sequencer.mouseUp(componentCommon.uid, panelToLocal(point));
        return true;
    }
    
} 
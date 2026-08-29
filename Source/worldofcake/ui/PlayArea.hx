package worldofcake.ui;

import worldofcake.ISequencerControl;
import worldofcake.IControlPanel;
import worldofcake.CoordinateMapper;
import worldofcake.PanelPoint;
import worldofcake.BasePoint;
import worldofcake.LocalPoint;
import openfl.display.Sprite;
import openfl.geom.Rectangle;

class PlayArea extends Sprite implements IComponent {
    private var componentCommon:ComponentCommon;
    
    public function new(uid:Int, pos:PanelPoint, size:PanelPoint,
                       mapper:CoordinateMapper, 
                       localMinPoint:LocalPoint, localMaxPoint:LocalPoint,
                       sequencer:ISequencerControl) {
        super();
        componentCommon = new ComponentCommon(uid, pos, size, mapper,
                                          localMinPoint, localMaxPoint, sequencer);
                                          
        var windowPos = panelToWindow(pos);
        this.x = windowPos.x;
        this.y = windowPos.y;
        // OpenFL sprites do not clip their graphics to a nominal component size.
        // Keep every custom renderer inside the generated play-area rectangle.
        this.scrollRect = new Rectangle(
            0, 0,
            componentCommon.panelLengthToWindowLength(size.x),
            componentCommon.panelLengthToWindowLength(size.y)
        );
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
    public function handleMouseDragged(p:WindowPoint):Bool return componentCommon.handleMouseDragged(p);
    public function handleMouseUp(p:WindowPoint):Bool return componentCommon.handleMouseUp(p);
    
    public function panelLengthToWindowLength(l:Float):Float return componentCommon.panelLengthToWindowLength(l);
    public function windowLengthToPanelLength(l:Float):Float return componentCommon.windowLengthToPanelLength(l);
    
    public function localLengthToWindowLength(l:Float):Float return componentCommon.localLengthToWindowLength(l);
    public function windowLengthToLocalLength(l:Float):Float return componentCommon.windowLengthToLocalLength(l);
    
    public function getPosition():PanelPoint {
        return componentCommon.getPosition();
    }
    
    public function getSize():PanelPoint {
        return componentCommon.getSize();
    }
    
    public function getMaxPoint():PanelPoint {
        return componentCommon.getMaxPoint();
    }
    
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

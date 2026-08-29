package worldofcake.ui;

import worldofcake.ISequencerControl;
import worldofcake.CoordinateMapper;
import worldofcake.WindowPoint;
import worldofcake.PanelPoint;
import worldofcake.ComposedCoordinateMapper;
import worldofcake.BasePoint;
import worldofcake.LocalPoint;

class ComponentCommon {
    public var uid:Int;
    public var x:Float;
    public var y:Float;
    public var width:Float;
    public var height:Float;
    
    public var sequencer:ISequencerControl;
    private var windowToPanelMapper:CoordinateMapper;
    private var panelToLocalMapper:CoordinateMapper;
    private var windowToLocalMapper:CoordinateMapper;
    
    public function new(uid:Int, 
                       panelPos:PanelPoint,      // Position in panel space
                       panelSize:PanelPoint,     // Width/height in panel space
                       windowToPanelMapper:CoordinateMapper,
                       localMin:LocalPoint, localMax:LocalPoint,  // Local space bounds
                       sequencer:ISequencerControl) {
        trace('BaseComponent constructor start for ${uid}');
        this.uid = uid;
        this.x = panelPos.x;
        this.y = panelPos.y;
        this.width = panelSize.x;
        this.height = panelSize.y;
        this.windowToPanelMapper = windowToPanelMapper;
        this.sequencer = sequencer;
        
        trace('  windowToPanelMapper = ${windowToPanelMapper != null}');
        
        // Create the component's coordinate mappers
        panelToLocalMapper = new CoordinateMapper(
            new BasePoint(x, y),                    
            new BasePoint(x + width, y + height),   
            localMin, localMax);                    
        windowToLocalMapper = new ComposedCoordinateMapper(windowToPanelMapper, panelToLocalMapper);
        trace('BaseComponent constructor end for ${uid}');
    }
    
    
    public function handleMouseDown(point:WindowPoint):Bool {
        if (inBounds(point)) {
            sequencer.mouseDown(uid, windowToLocal(point));
            return true;
        }
        return false;
    }
    
    public function handleMouseDragged(windowPoint:WindowPoint):Bool {
        if (inBounds(windowPoint)) {
            sequencer.mouseDragged(uid, windowToLocal(windowPoint));
            return true;
        }
        return false;
    }
        
    public function handleMouseUp(windowPoint:WindowPoint):Bool {
        if (inBounds(windowPoint)) {
            sequencer.mouseUp(uid, windowToLocal(windowPoint));
            return true;
        }
        return false;
    }
    
    
    public function panelToWindow(panelPoint:PanelPoint):WindowPoint {
        // Convert directly from panel to window using windowToPanelMapper
        var windowPos = windowToPanelMapper.backward(panelPoint.x, panelPoint.y);
        return new WindowPoint(windowPos.x, windowPos.y);
    }

    public function localToPanel(localPoint:LocalPoint):PanelPoint {
        // Convert directly from local to panel using panelToLocalMapper
        var panelPos = panelToLocalMapper.backward(localPoint.x, localPoint.y);
        return new PanelPoint(panelPos.x, panelPos.y);
    }

    public function localToWindow(localPoint:LocalPoint):WindowPoint {
        // Convert directly from local to window using windowToLocalMapper
        var windowPos = windowToLocalMapper.backward(localPoint.x, localPoint.y);
        return new WindowPoint(windowPos.x, windowPos.y);
    }

    public function windowToLocal(windowPoint:WindowPoint):LocalPoint {
        // Convert directly from window to local using windowToLocalMapper
        var localPos = windowToLocalMapper.forward(windowPoint.x, windowPoint.y);
        return new LocalPoint(localPos.x, localPos.y);
    }

    public function windowToPanel(windowPoint:WindowPoint):PanelPoint {
        // Convert directly from window to panel using windowToPanelMapper
        var panelPos = windowToPanelMapper.forward(windowPoint.x, windowPoint.y);
        return new PanelPoint(panelPos.x, panelPos.y);
    }

    public function panelToLocal(panelPoint:PanelPoint):LocalPoint {
        // Convert directly from panel to local using panelToLocalMapper
        var localPos = panelToLocalMapper.forward(panelPoint.x, panelPoint.y);
        return new LocalPoint(localPos.x, localPos.y);
    }


    public function getWindowSize():WindowPoint {
        // Convert component's dimensions (panel space) to window space
        var windowSize = windowToPanelMapper.backward(width, height);
        return new WindowPoint(windowSize.x, windowSize.y);
    }

    public function inBounds(windowPoint:WindowPoint):Bool {
        var panelPoint = windowToPanel(windowPoint);
        return panelPoint.x >= x && panelPoint.x <= x + width &&
               panelPoint.y >= y && panelPoint.y <= y + height;
    }

    public function panelLengthToWindowLength(panelLength:Float):Float {
        return windowToPanelMapper.lengthBackward(panelLength);
    }

    public function windowLengthToPanelLength(windowLength:Float):Float {
        return windowToPanelMapper.lengthForward(windowLength);
    }

    public function localLengthToWindowLength(localLength:Float):Float {
        return windowToLocalMapper.lengthBackward(localLength);
    }

    public function windowLengthToLocalLength(l:Float):Float {
        return windowToLocalMapper.lengthForward(l);
    }

    public function getPosition():PanelPoint {
        return new PanelPoint(x, y);
    }

    public function getSize():PanelPoint {
        return new PanelPoint(width, height);
    }

    public function getMaxPoint():PanelPoint {
        return new PanelPoint(x + width, y + height);
    }

} 
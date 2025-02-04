package worldofcake.ui;

import worldofcake.ISequencerControl;
import worldofcake.CoordinateMapper;
import worldofcake.WindowPoint;
import worldofcake.PanelPoint;
import worldofcake.ComposedCoordinateMapper;
import worldofcake.BasePoint;
import worldofcake.LocalPoint;

class BaseComponent {
    public var uid:Int;
    public var x:Float;
    public var y:Float;
    public var width:Float;
    public var height:Float;
    
    public var sequencer:ISequencerControl;
    private var windowToPanelMapper:CoordinateMapper;
    private var panelToLocalMapper:CoordinateMapper;
    private var windowToLocalMapper:CoordinateMapper;
    
    public function new(uid:Int, x:Float, y:Float, width:Float, height:Float, 
                       windowToPanelMapper:CoordinateMapper,
                       localMinPoint:LocalPoint, localMaxPoint:LocalPoint, 
                       sequencer:ISequencerControl) {
        trace('BaseComponent constructor start for ${uid}');
        this.uid = uid;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.windowToPanelMapper = windowToPanelMapper;
        this.sequencer = sequencer;
        
        trace('  windowToPanelMapper = ${windowToPanelMapper != null}');
        
        // Create the component's coordinate mappers
        panelToLocalMapper = new CoordinateMapper(
            new BasePoint(0,0),
            new BasePoint(width,height),
            localMinPoint, localMaxPoint);
        windowToLocalMapper = new ComposedCoordinateMapper(windowToPanelMapper, panelToLocalMapper);
        trace('BaseComponent constructor end for ${uid}');
    }
    
    
    public function handleMouseDown(point:WindowPoint):Bool {
        var panelPoint = windowToPanel(point);
        // Test if point is in panel bounds
        if (inBounds(panelPoint)) {
            sequencer.mouseDown(uid, panelToLocal(panelPoint));
            return true;
        }
        return false;
    }
    
    public function handleMouseDrag(windowPoint:WindowPoint):Bool {
        if (!hitTest(windowPoint)) return false;
        
        var panelPoint = PanelPoint.fromMap(
            windowToPanelMapper.space1ToSpace2(windowPoint.x, windowPoint.y)
        );
        return onLocalMouseDrag(panelPoint);
    }
    
    public function handleMouseUp(windowPoint:WindowPoint):Bool {
        if (!hitTest(windowPoint)) return false;
        
        var panelPoint = PanelPoint.fromMap(
            windowToPanelMapper.space1ToSpace2(windowPoint.x, windowPoint.y)
        );
        return onLocalMouseUp(panelPoint);
    }
    
    // Protected methods that subclasses override - these receive panel coordinates
    private function onLocalMouseDown(point:PanelPoint):Bool { return false; }
    private function onLocalMouseDrag(point:PanelPoint):Bool { return false; }
    private function onLocalMouseUp(point:PanelPoint):Bool { return false; }
    
    public function hitTest(windowPoint:WindowPoint):Bool {
        // Convert window coordinates to panel space before hit testing
        var panelPos = windowToPanelMapper.space1ToSpace2(windowPoint.x, windowPoint.y);
        
        // Now test against panel-space bounds
        var hit = (panelPos.x >= x && panelPos.x < x + width &&
                  panelPos.y >= y && panelPos.y < y + height    );
                    
        trace('  HitTest component ${uid}:');
        trace('    Window pos: ${windowPoint.x},${windowPoint.y}');
        trace('    Panel pos: ${panelPos.x},${panelPos.y}');
        trace('    Component bounds: x=${x},y=${y} w=${width},h=${height}');
        trace('    Hit: ${hit}');
        return hit;
    }

    public function panelToWindow(panelPoint:PanelPoint):WindowPoint {
        // Convert directly from panel to window using windowToPanelMapper
        var windowPos = windowToPanelMapper.space2ToSpace1(panelPoint.x, panelPoint.y);
        return new WindowPoint(windowPos.x, windowPos.y);
    }

    public function localToPanel(localPoint:LocalPoint):PanelPoint {
        // Convert directly from local to panel using panelToLocalMapper
        var panelPos = panelToLocalMapper.space2ToSpace1(localPoint.x, localPoint.y);
        return new PanelPoint(panelPos.x, panelPos.y);
    }

    public function localToWindow(localPoint:LocalPoint):WindowPoint {
        // Convert directly from local to window using windowToLocalMapper
        var windowPos = windowToLocalMapper.space2ToSpace1(localPoint.x, localPoint.y);
        return new WindowPoint(windowPos.x, windowPos.y);
    }

    public function windowToLocal(windowPoint:WindowPoint):LocalPoint {
        // Convert directly from window to local using windowToLocalMapper
        var localPos = windowToLocalMapper.space1ToSpace2(windowPoint.x, windowPoint.y);
        return new LocalPoint(localPos.x, localPos.y);
    }

    public function windowToPanel(windowPoint:WindowPoint):PanelPoint {
        // Convert directly from window to panel using windowToPanelMapper
        var panelPos = windowToPanelMapper.space1ToSpace2(windowPoint.x, windowPoint.y);
        return new PanelPoint(panelPos.x, panelPos.y);
    }

    public function panelToLocal(panelPoint:PanelPoint):LocalPoint {
        // Convert directly from panel to local using panelToLocalMapper
        var localPos = panelToLocalMapper.space1ToSpace2(panelPoint.x, panelPoint.y);
        return new LocalPoint(localPos.x, localPos.y);
    }


    public function getWindowSize():WindowPoint {
        // Convert component's local dimensions to window space
        var windowSize = windowToLocalMapper.space2ToSpace1(width, height);
        return new WindowPoint(windowSize.x, windowSize.y);
    }

    private function inBounds(point:PanelPoint):Bool {
        return point.x >= x && point.x <= x + width &&
               point.y >= y && point.y <= y + height;
    }

    public function panelLengthToWindowLength(panelLength:Float):Float {
        return windowToPanelMapper.length2To1(panelLength);
    }

    public function windowLengthToPanelLength(windowLength:Float):Float {
        return windowToPanelMapper.length1To2(windowLength);
    }

    public function localLengthToWindowLength(localLength:Float):Float {
        return windowToLocalMapper.length2To1(localLength);
    }

    public function windowLengthToLocalLength(windowLength:Float):Float {
        return windowToLocalMapper.length1To2(windowLength);
    }

} 
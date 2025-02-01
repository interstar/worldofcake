package worldofcake.ui;

import worldofcake.ISequencerControl;
import worldofcake.CoordinateMapper;

class BaseComponent {
    public var uid:Int;
    public var x:Float;
    public var y:Float;
    public var width:Float;
    public var height:Float;
    public var visible:Bool;
    
    public var windowToPanelMapper:CoordinateMapper;  // Window -> Panel space
    public var panelToLocalMapper:CoordinateMapper;   // Panel -> Component local space
    private var sequencer:ISequencerControl;
    
    public function new(uid:Int, x:Float, y:Float, width:Float, height:Float,
                       windowMapper:CoordinateMapper, sequencer:ISequencerControl) {
        this.uid = uid;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.visible = true;
        this.windowToPanelMapper = windowMapper;
        this.sequencer = sequencer;
        
        // Create mapper for panel->local space
        this.panelToLocalMapper = new CoordinateMapper(
            x, x + width,       // space1: panel x range
            y, y + height,      // space1: panel y range
            0, width,           // space2: local x range
            0, height          // space2: local y range
        );
    }
    
    public function handleMouseDown(screenX:Float, screenY:Float):Bool {
        if (!hitTest(screenX, screenY)) return false;
        
        // Map through coordinate spaces: window -> panel -> local
        var panelPos = windowToPanelMapper.space1ToSpace2(screenX, screenY);
        var localPos = panelToLocalMapper.space1ToSpace2(panelPos.x, panelPos.y);
        return onLocalMouseDown(localPos.x, localPos.y);
    }
    
    public function handleMouseDrag(screenX:Float, screenY:Float):Bool {
        var panelPos = windowToPanelMapper.space1ToSpace2(screenX, screenY);
        var localPos = panelToLocalMapper.space1ToSpace2(panelPos.x, panelPos.y);
        return onLocalMouseDrag(localPos.x, localPos.y);
    }
    
    public function handleMouseUp(screenX:Float, screenY:Float):Bool {
        var panelPos = windowToPanelMapper.space1ToSpace2(screenX, screenY);
        var localPos = panelToLocalMapper.space1ToSpace2(panelPos.x, panelPos.y);
        return onLocalMouseUp(localPos.x, localPos.y);
    }
    
    private function onLocalMouseDown(relX:Float, relY:Float):Bool { return false; }
    private function onLocalMouseDrag(relX:Float, relY:Float):Bool { return false; }
    private function onLocalMouseUp(relX:Float, relY:Float):Bool { return false; }
    
    public function hitTest(vx:Float, vy:Float):Bool {
        // Convert window coordinates to panel space before hit testing
        var panelPos = windowToPanelMapper.space1ToSpace2(vx, vy);
        
        // Now test against panel-space bounds
        var hit = panelPos.x >= x && panelPos.x <= x + width && 
                  panelPos.y >= y && panelPos.y <= y + height;
                  
        trace('  HitTest component ${uid}:');
        trace('    Window pos: ${vx},${vy}');
        trace('    Panel pos: ${panelPos.x},${panelPos.y}');
        trace('    Component bounds: x=${x},y=${y} w=${width},h=${height}');
        trace('    Hit: ${hit}');
        
        return hit;
    }

    public function mapToWindow(x:Float, y:Float):{x:Float, y:Float} {
        // Reverse the mapping chain:
        // First local->panel, then panel->window
        var panelPos = panelToLocalMapper.space1ToSpace2(x, y);
        return windowToPanelMapper.space1ToSpace2(panelPos.x, panelPos.y);
    }

    public function getWindowDimensions():{width:Float, height:Float} {
        var panelDims = panelToLocalMapper.space1ToSpace2(width, height);
        var windowDims = windowToPanelMapper.space1ToSpace2(panelDims.x, panelDims.y);
        return {width: windowDims.x, height: windowDims.y};
    }
} 
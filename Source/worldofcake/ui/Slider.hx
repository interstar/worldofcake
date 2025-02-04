package worldofcake.ui;

import lime.system.Locale;
import worldofcake.CoordinateMapper;
import worldofcake.ISequencerControl;
import worldofcake.OneDMapper;
import worldofcake.WindowPoint;
import worldofcake.ComposedCoordinateMapper;
import worldofcake.BasePoint;
import worldofcake.LocalPoint;
import worldofcake.PanelPoint;
import openfl.display.Sprite;
import worldofcake.ui.IComponent;

class Slider extends Sprite implements IComponent {
    public var value:Float; 
    public var min:Float;
    public var max:Float;
    private var vertical:Bool;
    public var localToValuesMapper:OneDMapper;  // Changed from CoordinateMapper
    private var componentCommon:BaseComponent;
    private var color:Int;
    
    public function new(uid:Int, x:Float, y:Float, width:Float, height:Float,
                       mapper:CoordinateMapper, 
                       sequencer:ISequencerControl,
                       min:Float, max:Float, vertical:Bool, color:Int) {
        super();
        trace('Slider constructor start for ${uid}');
        componentCommon = new BaseComponent(uid, x, y, width, height, mapper, 
                                          new LocalPoint(0,0), new LocalPoint(width,height),
                                          sequencer);
        trace('Slider super() complete for ${uid}');
        this.min = min;
        this.max = max;
        this.value = min;
        this.vertical = vertical;
        this.color = color;
        
        // Create mapper from local coordinates to value range
        this.localToValuesMapper = new OneDMapper(
            0, vertical ? height : width,  // local space range (0 -> 150)
            vertical ? max : min,          // value range start (80 for vertical)
            vertical ? min : max           // value range end (1 for vertical)
        );
        
        trace('Created Slider ${uid}:');
        trace('  Local space: 0 -> ${vertical ? height : width}');
        trace('  Value space: ${vertical ? max : min} -> ${vertical ? min : max}');
        trace('Slider constructor end for ${uid}');
        
        // Position sprite at window coordinates
        var windowPos = panelToWindow(new PanelPoint(x, y));
        this.x = windowPos.x;
        this.y = windowPos.y;
        
        redraw();
    }
    
    // Implement IComponent by delegating to componentCommon
    public var uid(get, never):Int;
    private function get_uid():Int return componentCommon.uid;
    
    public function panelToWindow(p:PanelPoint):WindowPoint return componentCommon.panelToWindow(p);
    public function localToPanel(p:LocalPoint):PanelPoint return componentCommon.localToPanel(p);
    public function localToWindow(p:LocalPoint):WindowPoint return componentCommon.localToWindow(p);
    public function windowToLocal(p:WindowPoint):LocalPoint return componentCommon.windowToLocal(p);
    public function windowToPanel(p:WindowPoint):PanelPoint return componentCommon.windowToPanel(p);
    public function panelToLocal(p:PanelPoint):LocalPoint return componentCommon.panelToLocal(p);
    
    public function handleMouseDown(p:WindowPoint):Bool return componentCommon.handleMouseDown(p);
    public function handleMouseDrag(p:WindowPoint):Bool return componentCommon.handleMouseDrag(p);
    public function handleMouseUp(p:WindowPoint):Bool return componentCommon.handleMouseUp(p);
    
    private function onLocalMouseDown(point:PanelPoint):Bool {
        trace('Slider ${uid} click handling:');
        trace('  Panel click at (${point.x},${point.y})');
        trace('  Slider panel bounds: (${x},${y}) -> (${x+width},${y+height})');
        
        var localPos = panelToLocal(point);
        trace('  Mapped to local: (${localPos.x},${localPos.y})');
        
        // Then convert local coordinates to slider value
        var localValue = vertical ? height - localPos.y : localPos.x;
        trace('  Local value coordinate: ${localValue}');
        
        var value = vertical ? 
            localToValuesMapper.space1ToSpace2(height - localPos.y) :
            localToValuesMapper.space1ToSpace2(localPos.x);
        
        trace('  Final value: ${value} (valid range: ${min} -> ${max})');
        componentCommon.sequencer.newValue(componentCommon.uid, value);
        return true;
    }
    
    private function onLocalMouseDrag(point:PanelPoint):Bool {
        return onLocalMouseDown(point);  // Same behavior as mouseDown
    }
    
    
    // Add helper to map value back to local coordinate
    public function valueToLocal(value:Float):{x:Float, y:Float} {
        var localValue = localToValuesMapper.space2ToSpace1(value);  // Only pass one value
        // Put the mapped value in the correct dimension
        var result = {
            x: vertical ? 0 : localValue,
            y: vertical ? localValue : 0
        };
        trace('  valueToLocal: value ${value} -> local (${result.x},${result.y})');
        return result;
    }
    
    public function valueToWindowPoint(value:Float):WindowPoint {
        trace('Slider ${uid} valueToWindowPoint: value=${value}');
        // Convert value to local coordinates
        var localPos = valueToLocal(value);
        trace('  local pos: (${localPos.x},${localPos.y})');
        
        // Map directly from local to window space using composed mapper
        var windowPos = localToWindow(new LocalPoint(localPos.x, localPos.y));
        trace('  window pos: (${windowPos.x},${windowPos.y})');
        return windowPos;
    }
    
    public function redraw():Void {
        graphics.clear();
        
        var windowDims = componentCommon.getWindowSize();
        
        // Draw background
        graphics.lineStyle(1, 0x000000);
        graphics.beginFill(0xEEEEEE);
        graphics.drawRect(0, 0, windowDims.x, windowDims.y);
        graphics.endFill();
        
        // Draw value bar
        graphics.beginFill(color);
        
        var barPos = valueToWindowPoint(value);
        
        if (vertical) {
            var barHeight = windowDims.y - (barPos.y - y);
            graphics.drawRect(0, windowDims.y - barHeight, windowDims.x, barHeight);
        } else {
            var barWidth = barPos.x - x;
            graphics.drawRect(0, 0, barWidth, windowDims.y);
        }
        graphics.endFill();
    }

    public function getUID():Int { return componentCommon.uid; }

    public function panelLengthToWindowLength(l:Float):Float return componentCommon.panelLengthToWindowLength(l);
    public function windowLengthToPanelLength(l:Float):Float return componentCommon.windowLengthToPanelLength(l);
    public function localLengthToWindowLength(l:Float):Float return componentCommon.localLengthToWindowLength(l);
    public function windowLengthToLocalLength(l:Float):Float return componentCommon.windowLengthToLocalLength(l);
} 
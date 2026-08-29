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
    private var componentCommon:ComponentCommon;
    private var color:Int;
    
    public function new(uid:Int, 
                       panelPos:PanelPoint,      // Position in panel space
                       panelSize:PanelPoint,     // Width/height in panel space
                       windowToPanelMapper:CoordinateMapper,
                       sequencer:ISequencerControl,
                       min:Float, max:Float, defaultValue:Float,
                       vertical:Bool, color:Int) {
        super();
        trace('Slider constructor start for ${uid}');
        componentCommon = new ComponentCommon(
            uid, 
            panelPos, panelSize,
            windowToPanelMapper,
            new LocalPoint(0, 0),
            new LocalPoint(panelSize.x, panelSize.y),  // Local space same size as panel
            sequencer
        );
        trace('Slider super() complete for ${uid}');
        this.min = min;
        this.max = max;
        this.value = defaultValue;
        this.vertical = vertical;
        this.color = color;
        
        var length = vertical ? panelSize.y : panelSize.x;
        // Create mapper from local coordinates to value range
        this.localToValuesMapper = new OneDMapper(
            0, length,   
            vertical ? max : min, vertical ? min : max  
        );
                
        // Position sprite at window coordinates
        var windowPos = panelToWindow(panelPos);
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
    
    private function calculateValue(windowPoint:WindowPoint):Float {
        var localPos = windowToLocal(windowPoint);
        trace('  In calculateValue:');
        trace(' windowPoint = (${windowPoint.x},${windowPoint.y})');
        trace(' Mapped to local: (${localPos.x},${localPos.y})');
        trace(' vertical = ${vertical}');
        trace(' x mapping = ${localToValuesMapper.forward(localPos.x)}');
        trace(' y mapping = ${localToValuesMapper.forward(localPos.y)}');
        
        // Convert local coordinates to slider value 
        var value = vertical ? 
            localToValuesMapper.forward(localPos.y) :
            localToValuesMapper.forward(localPos.x);
        
        trace('  Final value: ${value} (valid range: ${min} -> ${max})');
        return value;
    }

    public function handleMouseDown(windowPoint:WindowPoint):Bool {
        if (!componentCommon.inBounds(windowPoint)) return false;
        
        value = calculateValue(windowPoint);
        componentCommon.sequencer.newValue(getUID(), value);
        redraw();
        return true;
    }
    
    public function handleMouseDragged(windowPoint:WindowPoint):Bool {
        if (!componentCommon.inBounds(windowPoint)) return false;
        
        value = calculateValue(windowPoint);
        componentCommon.sequencer.newValue(getUID(), value);
        redraw();
        return true;
    }
    
    public function handleMouseUp(p:WindowPoint):Bool { return true; }
    
    // Add helper to map value back to local coordinate
    public function valueToLocal(value:Float):LocalPoint {
        var localValue = localToValuesMapper.backward(value);
        return new LocalPoint(vertical ? 0 : localValue, vertical ? localValue : 0);
    }
    
    public function valueToWindowPoint(value:Float):WindowPoint {
        var localPos = valueToLocal(value);
        var windowPos = localToWindow(localPos);
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
    public function windowLengthToLocalLength(l:Float):Float {
        return componentCommon.windowLengthToLocalLength(l);
    }
    
    public function getPosition():PanelPoint {
        return componentCommon.getPosition();
    }
    
    public function getSize():PanelPoint {
        return componentCommon.getSize();
    }
    
    public function getMaxPoint():PanelPoint {
        return componentCommon.getMaxPoint();
    }
} 
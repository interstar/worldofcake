package worldofcake.ui;

import openfl.display.Sprite;
import worldofcake.ui.Slider;

class SliderView extends Sprite {
    private var component:Slider;
    private var vertical:Bool;
    private var color:Int;
    
    public function new(component:Slider, vertical:Bool, color:Int) {
        super();
        this.component = component;
        this.vertical = vertical;
        this.color = color;
        
        // Correct order - panel coordinates to window coordinates
        var windowPos = component.windowToPanelMapper.space2ToSpace1(component.x, component.y);
        var windowDims = component.windowToPanelMapper.space2ToSpace1(component.width, component.height);
        
        this.x = windowPos.x;
        this.y = windowPos.y;
        
        trace('Slider ${component.uid}:');
        trace('  Panel space: x=${component.x}, y=${component.y}, w=${component.width}, h=${component.height}');
        trace('  Window space: x=${windowPos.x}, y=${windowPos.y}, w=${windowDims.x}, h=${windowDims.y}');
        
        // Debug coordinate mapping for min/mid/max values
        if (vertical) {
            var minY = windowPos.y + windowDims.y;  // Bottom
            var midY = windowPos.y + (windowDims.y / 2);  // Middle
            var maxY = windowPos.y;  // Top
            trace('  Value mapping (vertical):');
            trace('    min (${component.min}): y=${minY}');
            trace('    mid (${(component.min + component.max)/2}): y=${midY}');
            trace('    max (${component.max}): y=${maxY}');
        } else {
            var minX = windowPos.x;  // Left
            var midX = windowPos.x + (windowDims.x / 2);  // Middle
            var maxX = windowPos.x + windowDims.x;  // Right
            trace('  Value mapping (horizontal):');
            trace('    min (${component.min}): x=${minX}');
            trace('    mid (${(component.min + component.max)/2}): x=${midX}');
            trace('    max (${component.max}): x=${maxX}');
        }
        
        redraw();
    }
    
    private function valueToWindowCoords(value:Float):{x:Float, y:Float} {
        trace('valueToWindowCoords for value ${value}:');
        trace('  value range: ${component.min} -> ${component.max}');
        
        // value -> local
        var localPos = component.valueToLocal(value);
        trace('  1. value ${value} -> local (${localPos.x}, ${localPos.y})');
        trace('     local range: 0 -> ${vertical ? component.height : component.width}');
        
        // local -> panel
        var panelPos = component.panelToLocalMapper.space2ToSpace1(localPos.x, localPos.y);
        trace('  2. local (${localPos.x}, ${localPos.y}) -> panel (${panelPos.x}, ${panelPos.y})');
        trace('     panel bounds: x=${component.x}, y=${component.y}, w=${component.width}, h=${component.height}');
        
        // panel -> window
        var windowPos = component.windowToPanelMapper.space2ToSpace1(panelPos.x, panelPos.y);
        trace('  3. panel (${panelPos.x}, ${panelPos.y}) -> window (${windowPos.x}, ${windowPos.y})');
        
        return windowPos;
    }
    
    public function redraw():Void {
        graphics.clear();
        
        // Get window coordinates for drawing
        var windowPos = component.windowToPanelMapper.space2ToSpace1(component.x, component.y);
        var windowDims = component.windowToPanelMapper.space2ToSpace1(component.width, component.height);
        
        // Position sprite
        this.x = windowPos.x;
        this.y = windowPos.y;
        
        // Draw background
        graphics.lineStyle(1, 0x000000);
        graphics.beginFill(0xEEEEEE);
        graphics.drawRect(0, 0, windowDims.x, windowDims.y);
        graphics.endFill();
        
        // Draw value bar
        graphics.beginFill(color);
        
        var barPos = valueToWindowCoords(component.value);
        
        if (vertical) {
            // Draw from bottom up to value position
            var barHeight = windowDims.y - (barPos.y - windowPos.y);
            graphics.drawRect(0, windowDims.y - barHeight, windowDims.x, barHeight);
        } else {
            graphics.drawRect(0, 0, barPos.x - windowPos.x, windowDims.y);
        }
        graphics.endFill();
    }
    
    public function handleMouseDown(screenX:Float, screenY:Float):Bool {
        // Debug coordinate chain when clicked
        trace('SliderView ${component.uid} clicked at (${screenX}, ${screenY}):');
        trace('  Current value: ${component.value}');
        var localPos = component.valueToLocal(component.value);
        trace('  Local pos: ${localPos.x},${localPos.y}');
        var panelPos = component.panelToLocalMapper.space2ToSpace1(localPos.x, localPos.y);
        trace('  Panel pos: ${panelPos.x},${panelPos.y}');
        var windowBarPos = component.windowToPanelMapper.space2ToSpace1(panelPos.x, panelPos.y);
        trace('  Window pos: ${windowBarPos.x},${windowBarPos.y}');
        
        return component.handleMouseDown(screenX, screenY);
    }
    
    public function handleMouseDrag(screenX:Float, screenY:Float):Bool {
        return component.handleMouseDrag(screenX, screenY);
    }
    
    public function handleMouseUp(screenX:Float, screenY:Float):Bool {
        return component.handleMouseUp(screenX, screenY);
    }
} 
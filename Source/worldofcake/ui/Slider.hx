package worldofcake.ui;

import worldofcake.CoordinateMapper;
import worldofcake.ISequencerControl;
import worldofcake.ui.IValueControl;
import worldofcake.OneDMapper;

class Slider extends BaseComponent implements IValueControl {
    public var value:Float;
    public var min:Float;
    public var max:Float;
    private var vertical:Bool;
    public var localToValuesMapper:OneDMapper;  // Changed from CoordinateMapper
    
    public function new(uid:Int, x:Float, y:Float, width:Float, height:Float,
                       mapper:CoordinateMapper, sequencer:ISequencerControl,
                       min:Float, max:Float, vertical:Bool) {
        super(uid, x, y, width, height, mapper, sequencer);
        this.min = min;
        this.max = max;
        this.value = min;
        this.vertical = vertical;
        
        // Create mapper from local coordinates to value range
        this.localToValuesMapper = new OneDMapper(
            0, vertical ? height : width,  // local space range (0 -> 150)
            vertical ? max : min,          // value range start (80 for vertical)
            vertical ? min : max           // value range end (1 for vertical)
        );
        
        trace('Created Slider ${uid}:');
        trace('  Local space: 0 -> ${vertical ? height : width}');
        trace('  Value space: ${vertical ? max : min} -> ${vertical ? min : max}');
    }
    
    override private function onLocalMouseDown(localX:Float, localY:Float):Bool {
        var coord = vertical ? localY : localX;
        var value = localToValuesMapper.space1ToSpace2(coord);
        
        trace('Slider ${uid} value calculation:');
        trace('  Local coords: (${localX}, ${localY})');
        trace('  Selected coord: ${coord}');
        trace('  Mapped to value: ${value}');
        
        this.value = value;
        sequencer.newValue(uid, value);
        return true;
    }
    
    override private function onLocalMouseDrag(localX:Float, localY:Float):Bool {
        return onLocalMouseDown(localX, localY);  // Same behavior as mouseDown
    }
    
    private function updateValue(rel:Float):Void {
        var oldValue = value;
        value = Math.max(min, Math.min(max, min + (max - min) * (vertical ? (1 - rel) : rel)));
        trace('Slider ${uid}: rel=${rel} -> calculated value=${value} (was ${oldValue}) [min=${min}, max=${max}]');
        sequencer.newValue(uid, value);
    }
    
    public function onValueChange(newValue:Float):Void {
        value = newValue;
    }
    
    // Add helper to map value back to local coordinate
    public function valueToLocal(value:Float):{x:Float, y:Float} {
        var localValue = localToValuesMapper.space2ToSpace1(value);  // Only pass one value
        // Put the mapped value in the correct dimension
        return {
            x: vertical ? 0 : localValue,
            y: vertical ? localValue : 0
        };
    }
} 
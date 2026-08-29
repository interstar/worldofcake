package worldofcake;

// Maps between two coordinate spaces
class CoordinateMapper {
    private var xMapper:OneDMapper;
    private var yMapper:OneDMapper;
    
    public function new(space1Min:BasePoint, space1Max:BasePoint,
                       space2Min:BasePoint, space2Max:BasePoint) {
        trace('Creating CoordinateMapper:');
        trace('  Space1: (${space1Min.x},${space1Min.y}) -> (${space1Max.x},${space1Max.y})');
        trace('  Space2: (${space2Min.x},${space2Min.y}) -> (${space2Max.x},${space2Max.y})');
        
        xMapper = new OneDMapper(space1Min.x, space1Max.x, space2Min.x, space2Max.x);
        yMapper = new OneDMapper(space1Min.y, space1Max.y, space2Min.y, space2Max.y);
    }
    
    public function forward(x:Float, y:Float):{x:Float, y:Float} {
        var result = {
            x: xMapper.forward(x),
            y: yMapper.forward(y)
        };
        return result;
    }
    
    public function backward(x:Float, y:Float):{x:Float, y:Float} {
        return {
            x: xMapper.backward(x),
            y: yMapper.backward(y)
        };
    }

    // Map a length/distance from space1 to space2
    public function lengthForward(length:Float):Float {        
        var space1Range = xMapper.getSpace1Range();
        var space2Range = xMapper.getSpace2Range();
        return (length / space1Range) * space2Range;
    }

    // Map a length/distance from space2 to space1
    public function lengthBackward(length:Float):Float {        
        var space1Range = xMapper.getSpace1Range();
        var space2Range = xMapper.getSpace2Range();
        return (length / space2Range) * space1Range;
    }

    public function getSpacesDescription():String {
        return 'space1: (${xMapper.space1Min},${yMapper.space1Min}) -> ' +
               '(${xMapper.space1Max},${yMapper.space1Max}), ' +
               'space2: (${xMapper.space2Min},${yMapper.space2Min}) -> ' +
               '(${xMapper.space2Max},${yMapper.space2Max})';
    }
} 
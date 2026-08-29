package worldofcake;

class ComposedCoordinateMapper extends CoordinateMapper {
    private var first:CoordinateMapper;
    private var second:CoordinateMapper;
    
    public function new(first:CoordinateMapper, second:CoordinateMapper) {
        // Use dummy values for base class since we're overriding the methods
        super(
            new BasePoint(0, 0),
            new BasePoint(1, 1),
            new BasePoint(0, 0),
            new BasePoint(1, 1)
        );
        this.first = first;
        this.second = second;
    }
    
    override public function forward(x:Float, y:Float):{x:Float, y:Float} {
        var intermediate = first.forward(x, y);
        return second.forward(intermediate.x, intermediate.y);
    }

    override public function backward(x:Float, y:Float):{x:Float, y:Float} {
        var intermediate = second.backward(x, y);
        return first.backward(intermediate.x, intermediate.y);
    }
    
    
    override public function getSpacesDescription():String {
        return 'composed: first[${first.getSpacesDescription()}] ' +
               'second[${second.getSpacesDescription()}]';
    }

    override public function lengthForward(length:Float):Float {
        // Map through first mapper's spaces, then second mapper's spaces
        var intermediateLength = first.lengthForward(length);
        return second.lengthForward(intermediateLength);
    }

    override public function lengthBackward(length:Float):Float {
        // Map backwards through second mapper's spaces, then first mapper's spaces
        var intermediateLength = second.lengthBackward(length);
        return first.lengthBackward(intermediateLength);
    }
} 
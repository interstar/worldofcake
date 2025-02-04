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
    
    override public function space1ToSpace2(x:Float, y:Float):{x:Float, y:Float} {
        var intermediate = first.space1ToSpace2(x, y);
        return second.space1ToSpace2(intermediate.x, intermediate.y);
    }

    override public function space2ToSpace1(x:Float, y:Float):{x:Float, y:Float} {
        var intermediate = second.space2ToSpace1(x, y);
        return first.space2ToSpace1(intermediate.x, intermediate.y);
    }
    
    
    override public function getSpacesDescription():String {
        return 'composed: first[${first.getSpacesDescription()}] ' +
               'second[${second.getSpacesDescription()}]';
    }
} 
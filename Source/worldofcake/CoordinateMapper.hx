package worldofcake;

// Maps between two coordinate spaces
class CoordinateMapper {
    private var xMapper:OneDMapper;
    private var yMapper:OneDMapper;
    
    public function new(space1MinX:Float, space1MaxX:Float,
                       space1MinY:Float, space1MaxY:Float,
                       space2MinX:Float, space2MaxX:Float,
                       space2MinY:Float, space2MaxY:Float) {
        xMapper = new OneDMapper(space1MinX, space1MaxX, space2MinX, space2MaxX);
        yMapper = new OneDMapper(space1MinY, space1MaxY, space2MinY, space2MaxY);
    }
    
    public function space1ToSpace2(x:Float, y:Float):{x:Float, y:Float} {
        return {
            x: xMapper.space1ToSpace2(x),
            y: yMapper.space1ToSpace2(y)
        };
    }
    
    public function space2ToSpace1(x:Float, y:Float):{x:Float, y:Float} {
        return {
            x: xMapper.space2ToSpace1(x),
            y: yMapper.space2ToSpace1(y)
        };
    }
} 
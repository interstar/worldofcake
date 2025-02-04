package worldofcake;

class OneDMapper {
    public var space1Min:Float;
    public var space1Max:Float;
    public var space2Min:Float;
    public var space2Max:Float;
    
    public function new(space1Min:Float, space1Max:Float, 
                       space2Min:Float, space2Max:Float) {
        this.space1Min = space1Min;
        this.space1Max = space1Max;
        this.space2Min = space2Min;
        this.space2Max = space2Max;
    }
    
    public function space1ToSpace2(value:Float):Float {
        return space2Min + (value - space1Min) * (space2Max - space2Min) / (space1Max - space1Min);
    }
    
    public function space2ToSpace1(value:Float):Float {
        var proportion = (value - space2Min) / (space2Max - space2Min);
        var result = space1Min + proportion * (space1Max - space1Min);
        return result;
    }

    public function getSpace1Range():Float {
        return space1Max - space1Min;
    }

    public function getSpace2Range():Float {
        return space2Max - space2Min;
    }
} 
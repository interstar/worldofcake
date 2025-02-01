package worldofcake;

class OneDMapper {
    private var space1Min:Float;
    private var space1Max:Float;
    private var space2Min:Float;
    private var space2Max:Float;
    
    public function new(space1Min:Float, space1Max:Float, 
                       space2Min:Float, space2Max:Float) {
        this.space1Min = space1Min;
        this.space1Max = space1Max;
        this.space2Min = space2Min;
        this.space2Max = space2Max;
    }
    
    public function space1ToSpace2(value:Float):Float {
        var proportion = (value - space1Min) / (space1Max - space1Min);
        return space2Min + proportion * (space2Max - space2Min);
    }
    
    public function space2ToSpace1(value:Float):Float {
        var proportion = (value - space2Min) / (space2Max - space2Min);
        return space1Min + proportion * (space1Max - space1Min);
    }
} 
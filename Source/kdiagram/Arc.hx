package kdiagram;

class Arc {
    public var count:Int;
    public var destination:Int;
    public var length1:Int;
    public var length2:Int;
    
    public function new(destination:Int, length1:Int, length2:Int) {
        this.count = 0;
        this.destination = destination;
        this.length1 = length1;
        this.length2 = length2;
    }
} 
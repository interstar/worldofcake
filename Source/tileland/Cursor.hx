package tileland;

class Cursor {
    public var x:Float;
    public var y:Float;
    public var tileX:Int;
    public var tileY:Int;
    public var direction:Direction;
    public var channel:Int;
    public var color:Int;
    public var speed:Float;
    
    // Add progress through current tile (0.0 to 1.0)
    public var progress:Float;
    
    // Add grid dimensions as private fields
    private var maxRows:Int;
    private var maxCols:Int;
    
    public function new(tileX:Int, tileY:Int, direction:Direction, channel:Int, color:Int) {
        this.tileX = tileX;
        this.tileY = tileY;
        this.direction = direction;
        this.channel = channel;
        this.color = color;
        this.progress = 0.0;
        this.speed = 16.0;
    }
    
    public function updatePosition(tile:Tile, delta:Float, rows:Int, cols:Int):Void {
        // Store grid dimensions
        this.maxRows = rows;
        this.maxCols = cols;
        
        // Move along curve
        progress += delta * speed;
        
        if (progress >= 1.0) {
            progress = 0.0;
            var exitDirection = getNextDirection(tile.type, direction);
            var next = getNextTile(exitDirection);
            tileX += next.nextTileX;
            tileY += next.nextTileY;
            direction = next.entryDirection;
            return;
        }
        
        // Calculate position along curve based on progress (0 to 1)
        var startX:Float = 0;
        var startY:Float = 0;
        var controlX:Float = 0;
        var controlY:Float = 0;
        var endX:Float = 0;
        var endY:Float = 0;
        
        // Set points to match exactly how curves are drawn in TileLandView
        switch [tile.type, direction] {
            case [1, North]: // Moving from top to left
                startX = tile.x + tile.size/2;
                startY = tile.y;
                controlX = tile.x + tile.size/2;
                controlY = tile.y + tile.size/2;
                endX = tile.x;
                endY = tile.y + tile.size/2;
                
            case [1, South]: // Moving from bottom to right
                startX = tile.x + tile.size/2;
                startY = tile.y + tile.size;
                controlX = tile.x + tile.size/2;
                controlY = tile.y + tile.size/2;
                endX = tile.x + tile.size;
                endY = tile.y + tile.size/2;
                
            case [1, East]: // Moving from right to bottom
                startX = tile.x + tile.size;
                startY = tile.y + tile.size/2;
                controlX = tile.x + tile.size/2;
                controlY = tile.y + tile.size/2;
                endX = tile.x + tile.size/2;
                endY = tile.y + tile.size;
                
            case [1, West]: // Moving from left to top
                startX = tile.x;
                startY = tile.y + tile.size/2;
                controlX = tile.x + tile.size/2;
                controlY = tile.y + tile.size/2;
                endX = tile.x + tile.size/2;
                endY = tile.y;
                
            case [2, North]: // Moving from top to right
                startX = tile.x + tile.size/2;
                startY = tile.y;
                controlX = tile.x + tile.size/2;
                controlY = tile.y + tile.size/2;
                endX = tile.x + tile.size;
                endY = tile.y + tile.size/2;
                
            case [2, South]: // Moving from bottom to left
                startX = tile.x + tile.size/2;
                startY = tile.y + tile.size;
                controlX = tile.x + tile.size/2;
                controlY = tile.y + tile.size/2;
                endX = tile.x;
                endY = tile.y + tile.size/2;
                
            case [2, East]: // Moving from right to top
                startX = tile.x + tile.size;
                startY = tile.y + tile.size/2;
                controlX = tile.x + tile.size/2;
                controlY = tile.y + tile.size/2;
                endX = tile.x + tile.size/2;
                endY = tile.y;
                
            case [2, West]: // Moving from left to bottom
                startX = tile.x;
                startY = tile.y + tile.size/2;
                controlX = tile.x + tile.size/2;
                controlY = tile.y + tile.size/2;
                endX = tile.x + tile.size/2;
                endY = tile.y + tile.size;
                
            case _:
                x = tile.x + tile.size/2;
                y = tile.y + tile.size/2;
                return;
        }
        
        // Quadratic Bézier formula to match curveTo in TileLandView
        var t = progress;
        var mt = 1 - t;
        x = mt*mt*startX + 2*mt*t*controlX + t*t*endX;
        y = mt*mt*startY + 2*mt*t*controlY + t*t*endY;
    }
    
    private function getNextDirection(tileType:Int, currentDir:Direction):Direction {
        return switch [tileType, currentDir] {
            // Type 1: curves connect top-left and bottom-right
            case [1, North]: West;   // Entering from top, curve left
            case [1, South]: East;   // Entering from bottom, curve right
            case [1, East]: South;   // Entering from right, curve down
            case [1, West]: North;   // Entering from left, curve up
            
            // Type 2: curves connect top-right and bottom-left
            case [2, North]: East;   // Entering from top, curve right
            case [2, South]: West;   // Entering from bottom, curve left
            case [2, East]: North;   // Entering from right, curve up
            case [2, West]: South;   // Entering from left, curve down
            
            case _: currentDir;
        }
    }
    
    private function getNextTile(exitDirection:Direction):{
        nextTileX:Int,
        nextTileY:Int,
        entryDirection:Direction
    } {
        // First check if we're at a boundary
        if ((exitDirection == Direction.North && tileY == 0) ||
            (exitDirection == Direction.South && tileY == maxRows - 1) ||
            (exitDirection == Direction.East && tileX == maxCols - 1) ||
            (exitDirection == Direction.West && tileX == 0)) {
            
            // At boundary - stay in same tile but enter from exit point
            return {
                nextTileX: 0,
                nextTileY: 0,
                entryDirection: exitDirection  // Re-enter from same point we hit
            };
        }
        
        // Normal tile transition
        return switch (exitDirection) {
            case North: { nextTileX: 0, nextTileY: -1, entryDirection: South };
            case South: { nextTileX: 0, nextTileY: 1, entryDirection: North };
            case East:  { nextTileX: 1, nextTileY: 0, entryDirection: West };
            case West:  { nextTileX: -1, nextTileY: 0, entryDirection: East };
        }
    }
} 
package tileland;

// Constants defining the virtual and physical layout of TileLand
class TileLandLayout {
    // Control panel virtual space (the entire window content)
    public static inline var PANEL_WIDTH:Int = 800;
    public static inline var PANEL_HEIGHT:Int = 600;
    public static inline var PANEL_OFFSET_X:Int = 0;  // Panel is at origin of window
    public static inline var PANEL_OFFSET_Y:Int = 0;
    
    // Play area dimensions and position within panel
    public static inline var PLAY_AREA_WIDTH:Int = 600;
    public static inline var PLAY_AREA_HEIGHT:Int = 600;
    public static inline var PLAY_AREA_OFFSET_X:Int = 20;  // Offset from panel origin
    public static inline var PLAY_AREA_OFFSET_Y:Int = 20;
    
    // Grid/Tile dimensions
    public static inline var TILE_SIZE:Int = 50;  // Each tile is 50x50
    public static inline var GRID_ROWS:Int = Std.int(PLAY_AREA_HEIGHT / TILE_SIZE);  // 12 rows
    public static inline var GRID_COLS:Int = Std.int(PLAY_AREA_WIDTH / TILE_SIZE);   // 12 cols
    
    // Control area (right side panel)
    public static inline var CONTROL_AREA_OFFSET_X:Int = PLAY_AREA_OFFSET_X + PLAY_AREA_WIDTH + 20;  // 640
    public static inline var CONTROL_AREA_WIDTH:Int = PANEL_WIDTH - CONTROL_AREA_OFFSET_X - 20;  // 120
    
    // Slider positions (in virtual coordinates)
    public static inline var SPEED_SLIDER_START_X:Int = 640;
    public static inline var SPEED_SLIDER_Y:Int = 50;
    public static inline var SPEED_SLIDER_WIDTH:Int = 30;
    public static inline var SPEED_SLIDER_HEIGHT:Int = 150;
    public static inline var SPEED_SLIDER_SPACING:Int = 40;
    
    // Channel slider position
    public static inline var CHANNEL_SLIDER_X:Int = 640;
    public static inline var CHANNEL_SLIDER_Y:Int = 250;
    public static inline var CHANNEL_SLIDER_WIDTH:Int = 120;
    public static inline var CHANNEL_SLIDER_HEIGHT:Int = 30;
} 
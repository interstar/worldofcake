package tileland;

import generated.tileland.TileLandLayoutGenerated;

// Maintained compatibility facade. Geometry is generated from layouts/openfl/tileland.layla.
class TileLandLayout {
    public static inline var PANEL_WIDTH:Int = Std.int(TileLandLayoutGenerated.PANEL_WIDTH);
    public static inline var PANEL_HEIGHT:Int = Std.int(TileLandLayoutGenerated.PANEL_HEIGHT);
    public static inline var PANEL_OFFSET_X:Int = 0;
    public static inline var PANEL_OFFSET_Y:Int = 0;
    public static inline var WINDOW_WIDTH:Int = Std.int(TileLandLayoutGenerated.WINDOW_WIDTH);
    public static inline var WINDOW_HEIGHT:Int = Std.int(TileLandLayoutGenerated.WINDOW_HEIGHT);
    public static inline var PLAY_AREA_X:Float = TileLandLayoutGenerated.PLAYAREA_X;
    public static inline var PLAY_AREA_Y:Float = TileLandLayoutGenerated.PLAYAREA_Y;
    public static inline var PLAY_AREA_WIDTH:Float = TileLandLayoutGenerated.PLAYAREA_WIDTH;
    public static inline var PLAY_AREA_HEIGHT:Float = TileLandLayoutGenerated.PLAYAREA_HEIGHT;
    public static inline var TILE_SIZE:Int = 50;
    public static inline var GRID_ROWS:Int = Std.int(PLAY_AREA_HEIGHT / TILE_SIZE);
    public static inline var GRID_COLS:Int = Std.int(PLAY_AREA_WIDTH / TILE_SIZE);
    public static inline var CONTROL_AREA_OFFSET_X:Int = Std.int(TileLandLayoutGenerated.REDSPEED_X);
    public static inline var CONTROL_AREA_WIDTH:Int = Std.int(TileLandLayoutGenerated.CONTROLTOP_WIDTH);
    public static inline var SPEED_SLIDER_START_X:Int = Std.int(TileLandLayoutGenerated.REDSPEED_X);
    public static inline var SPEED_SLIDER_Y:Int = Std.int(TileLandLayoutGenerated.REDSPEED_Y);
    public static inline var SPEED_SLIDER_WIDTH:Int = Std.int(TileLandLayoutGenerated.REDSPEED_WIDTH);
    public static inline var SPEED_SLIDER_HEIGHT:Int = Std.int(TileLandLayoutGenerated.REDSPEED_HEIGHT);
    public static inline var SPEED_SLIDER_SPACING:Int = Std.int(TileLandLayoutGenerated.GREENSPEED_X - TileLandLayoutGenerated.REDSPEED_X);
    public static inline var SPEED_SLIDER_X1:Float = TileLandLayoutGenerated.REDSPEED_X;
}

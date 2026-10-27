package worldofcake.visuals;

/** Embeds the same GLSL function that the native renderer includes as a C++ literal. */
class TrailShaderSource {
    public static macro function decay():haxe.macro.Expr.ExprOf<String> {
        var path = haxe.macro.Context.resolvePath("worldofcake/visuals/TrailDecay.glsl.inc");
        haxe.macro.Context.registerModuleDependency(haxe.macro.Context.getLocalModule(), path);
        var source = sys.io.File.getContent(path);
        var start = source.indexOf("(") + 1;
        var end = source.lastIndexOf(')WOCGLSL"');
        if (start <= 0 || end < start) haxe.macro.Context.error("Invalid shared GLSL literal", haxe.macro.Context.currentPos());
        return macro $v{source.substring(start, end)};
    }
}

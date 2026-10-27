R"WOCGLSL(
vec3 wocTrailDecay(vec3 history, float retention) {
    return mix(vec3(18.0, 20.0, 26.0) / 255.0, history, retention);
}
)WOCGLSL"

package worldofcake.visuals;

import openfl.display.DisplayObjectShader;

/** Decay towards the play-area background, preserving an opaque history surface. */
class TrailDecayShader extends DisplayObjectShader {
    public function new() {
        super();
        glFragmentSource = '
            varying vec2 openfl_TextureCoordv;
            uniform sampler2D openfl_Texture;
            uniform float retention;
        ' + TrailShaderSource.decay() + '
            void main() {
                vec3 history = texture2D(openfl_Texture, openfl_TextureCoordv).rgb;
                gl_FragColor = vec4(wocTrailDecay(history, retention), 1.0);
            }
        ';
        data.retention.value = [0.0];
    }
}

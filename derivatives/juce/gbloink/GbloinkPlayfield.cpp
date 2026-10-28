#include "GbloinkPlayfield.h"
#include "WocJuceCoordinateMapper.h"
#include "WocJuceEditorSupport.h"
#include <cmath>

namespace {
double seconds() { return juce::Time::getMillisecondCounterHiRes() * 0.001; }
juce::Colour colour(int rgb) { return juce::Colour(0xff000000u | static_cast<juce::uint32>(rgb)); }
const char* decay =
#include "../../../Source/worldofcake/visuals/TrailDecay.glsl.inc"
;
}

GbloinkPlayfield::GbloinkPlayfield() {
    setInterceptsMouseClicks(false, false);
    context.setRenderer(this);
    context.setComponentPaintingEnabled(true);
    context.setContinuousRepainting(false);
    context.attachTo(*this);
}
GbloinkPlayfield::~GbloinkPlayfield() { context.detach(); }

void GbloinkPlayfield::update(const worldofcake::bridge::GbloinkVisualSnapshot& next) {
    const auto now = seconds();
    const bool reset = epoch != next.collisionEpoch || revision != next.stateRevision
        || next.collisionModelTime < previousModelTime;
    if (reset) { impacts.clear(); lastSerial = 0; }
    if (next.muted) impacts.clear();
    epoch = next.collisionEpoch;
    revision = next.stateRevision;
    previousModelTime = next.collisionModelTime;
    snapshot = next;
    impacts.erase(std::remove_if(impacts.begin(), impacts.end(), [now](const Impact& i) {
        return now-i.born >= (i.cue.kind == 1 ? 1.8 : 0.7);
    }), impacts.end());
    for (int i = 0; i < next.collisionCount; ++i) {
        const auto& cue = next.collisions[static_cast<std::size_t>(i)];
        if (cue.serial <= lastSerial) continue;
        lastSerial = cue.serial;
        if (next.muted) continue;
        const auto age = std::max(0.0, next.collisionModelTime-cue.time);
        if (age >= (cue.kind == 1 ? 1.8 : 0.7)) continue;
        if (impacts.size() == 32) impacts.erase(impacts.begin());
        impacts.push_back({cue, now-age});
    }
    {
        std::lock_guard<std::mutex> lock(packetMutex);
        if (reset) ++packet.reset;
        packet.balls = next.balls;
        packet.modelTime = next.collisionModelTime;
        packet.moving = next.modelReady && !next.paused;
        packet.trails = effectsEnabled;
    }
    repaint();
    context.triggerRepaint();
}

void GbloinkPlayfield::paint(juce::Graphics& g) {
    if (!gpuReady.load()) g.fillAll(worldofcake::jucehost::chrome::playArea);
    const worldofcake::jucehost::WocJuceCoordinateMapper map(700, 500, getLocalBounds());
    const auto now = seconds();
    for (const auto& block : snapshot.blocks) {
        double boost = 0;
        if (effectsEnabled) for (const auto& i : impacts)
            if (i.cue.blockId == block.id) boost = std::max(boost, juce::jlimit(0.0, 1.0, (1.8-(now-i.born))/0.3));
        g.setColour(colour(block.colour).withAlpha(static_cast<float>((200+55*boost)/255.0)));
        g.fillRect(map.toView(block.left, block.top, block.right-block.left, block.bottom-block.top));
    }
    for (const auto& ball : snapshot.balls) {
        g.setColour(colour(ball.colour));
        g.fillEllipse(map.toView(ball.x-ball.radius, ball.y-ball.radius, ball.radius*2, ball.radius*2));
    }
    if (effectsEnabled) for (const auto& i : impacts) {
        const bool pair = i.cue.kind == 2;
        auto c = colour(i.cue.colour);
        if (pair) c = c.interpolatedWith(juce::Colours::white, 0.25f);
        for (int ring = 0; ring < 3; ++ring) {
            const auto phase = (now-i.born-ring*0.064)/0.56;
            if (phase <= 0 || phase >= 1) continue;
            const auto radius = 96*i.cue.velocity/127.0*phase;
            g.setColour(c.withAlpha(static_cast<float>((pair ? 0.9 : 0.65)*std::min(1.0,(1-phase)*2.5))));
            const auto stroke = map.toView(0, 0, pair ? 2.4 : 2.0, 0).getWidth();
            g.drawEllipse(map.toView(i.cue.x-radius,i.cue.y-radius,radius*2,radius*2), std::max(1.5f,stroke));
        }
    }
}

void GbloinkPlayfield::setEffectsEnabled(bool enabled) {
    effectsEnabled = enabled;
    { std::lock_guard<std::mutex> lock(packetMutex); ++packet.reset; }
    update(snapshot);
}
void GbloinkPlayfield::newOpenGLContextCreated() {
    using namespace juce::gl;
    shader = std::make_unique<juce::OpenGLShaderProgram>(context);
    const juce::String vertex = "attribute vec2 position; varying vec2 uv; void main(){uv=position*0.5+0.5;gl_Position=vec4(position,0.0,1.0);}";
    const juce::String fragment = juce::String("varying vec2 uv; uniform sampler2D history; uniform float retention,marks; uniform vec3 ball0,ball1,ball2,colour0,colour1,colour2;\n")
        + decay + "\nvec3 mark(vec3 c,vec2 p,vec3 b,vec3 col){float a=(1.0-smoothstep(b.z-0.6,b.z+0.6,length(p-b.xy)))*0.65*marks;return mix(c,col,a);}"
        + "void main(){vec3 c=wocTrailDecay(texture2D(history,uv).rgb,retention);vec2 p=vec2(uv.x,1.0-uv.y)*vec2(700.0,500.0);"
          "c=mark(c,p,ball0,colour0);c=mark(c,p,ball1,colour1);c=mark(c,p,ball2,colour2);gl_FragColor=vec4(c,1.0);}";
    if (!shader->addVertexShader(juce::OpenGLHelpers::translateVertexShaderToV3(vertex))
        || !shader->addFragmentShader(juce::OpenGLHelpers::translateFragmentShaderToV3(fragment)) || !shader->link()) {
        juce::Logger::writeToLog("Gbloink GPU trails: " + shader->getLastError());
        shader.reset(); return;
    }
    position = context.extensions.glGetAttribLocation(shader->getProgramID(), "position");
    const float quad[] = {-1,-1,1,-1,-1,1,1,1};
    context.extensions.glGenBuffers(1, &vertices);
    context.extensions.glBindBuffer(GL_ARRAY_BUFFER, vertices);
    context.extensions.glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);
    context.extensions.glBindBuffer(GL_ARRAY_BUFFER, 0);
    lastFrameTime = seconds();
}

void GbloinkPlayfield::clearHistory() {
    using namespace juce::gl;
    for (auto& buffer : history) {
        buffer.makeCurrentRenderingTarget();
        glClearColor(18.f/255,20.f/255,26.f/255,1);
        glClear(GL_COLOR_BUFFER_BIT);
    }
}
void GbloinkPlayfield::drawQuad() {
    using namespace juce::gl;
    context.extensions.glBindBuffer(GL_ARRAY_BUFFER, vertices);
    context.extensions.glEnableVertexAttribArray(static_cast<GLuint>(position));
    context.extensions.glVertexAttribPointer(static_cast<GLuint>(position),2,GL_FLOAT,GL_FALSE,0,nullptr);
    glDrawArrays(GL_TRIANGLE_STRIP,0,4);
    context.extensions.glDisableVertexAttribArray(static_cast<GLuint>(position));
    context.extensions.glBindBuffer(GL_ARRAY_BUFFER,0);
}
void GbloinkPlayfield::renderOpenGL() {
    using namespace juce::gl;
    Packet p;
    { std::lock_guard<std::mutex> lock(packetMutex); p = packet; }
    const auto now = seconds();
    const auto dt = std::max(0.0,now-lastFrameTime);
    lastFrameTime = now;
    GLint target = 0, viewport[4];
    glGetIntegerv(GL_FRAMEBUFFER_BINDING,&target);
    glGetIntegerv(GL_VIEWPORT,viewport);
    glDisable(GL_BLEND); glDisable(GL_DEPTH_TEST); glDisable(GL_SCISSOR_TEST);
    glClearColor(18.f/255,20.f/255,26.f/255,1); glClear(GL_COLOR_BUFFER_BIT);
    if (!shader) return;
    if (!p.trails) { gpuReady.store(true); return; }
    const int width = 350, height = 250;
    if (textureWidth != width) {
        gpuReady.store(false);
        history[0].release(); history[1].release(); textureWidth = 0;
        if (!history[0].initialise(context,width,height) || !history[1].initialise(context,width,height)) {
            context.extensions.glBindFramebuffer(GL_FRAMEBUFFER,static_cast<GLuint>(target));
            glViewport(viewport[0],viewport[1],viewport[2],viewport[3]);
            return;
        }
        textureWidth = width; clearHistory();
    }
    if (renderedReset != p.reset) clearHistory();
    renderedReset = p.reset;
    context.extensions.glActiveTexture(GL_TEXTURE0);
    shader->use();
    shader->setUniform("history",0);
    shader->setUniform("retention",static_cast<float>(std::exp2(-dt/0.22)));
    shader->setUniform("marks", p.trails && p.moving && p.modelTime != renderedModelTime ? 1.f : 0.f);
    for (int i = 0; i < 3; ++i) {
        const auto& b = p.balls[static_cast<std::size_t>(i)];
        const auto c = colour(b.colour);
        shader->setUniform(("ball"+juce::String(i)).toRawUTF8(),static_cast<float>(b.x),static_cast<float>(b.y),static_cast<float>(b.radius));
        shader->setUniform(("colour"+juce::String(i)).toRawUTF8(),c.getFloatRed(),c.getFloatGreen(),c.getFloatBlue());
    }
    history[1-current].makeCurrentRenderingTarget();
    glViewport(0,0,width,height);
    glBindTexture(GL_TEXTURE_2D,history[current].getTextureID());
    drawQuad(); current = 1-current; renderedModelTime = p.modelTime;
    context.extensions.glBindFramebuffer(GL_FRAMEBUFFER,static_cast<GLuint>(target));
    glViewport(viewport[0],viewport[1],viewport[2],viewport[3]);
    shader->setUniform("retention",1.f); shader->setUniform("marks",0.f);
    glBindTexture(GL_TEXTURE_2D,history[current].getTextureID()); drawQuad();
    glBindTexture(GL_TEXTURE_2D,0);
    context.extensions.glUseProgram(0);
    gpuReady.store(true);
}
void GbloinkPlayfield::openGLContextClosing() {
    gpuReady.store(false);
    history[0].release(); history[1].release(); textureWidth = 0;
    shader.reset();
    if (vertices) context.extensions.glDeleteBuffers(1,&vertices);
    vertices = 0; renderedModelTime = -1;
}

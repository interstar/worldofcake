#include "GbloinkTrails.hpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <stdexcept>
#include <string>

namespace {
using Clock = std::chrono::steady_clock;
const char* decayFunction =
#include "../../../../Source/worldofcake/visuals/TrailDecay.glsl.inc"
;

// Rack's GL2 widget uses a compatibility context. No VBO/VAO bindings are changed.
struct GlState {
    GLint program, framebuffer, activeTexture;
    GlState() {
        glGetIntegerv(GL_CURRENT_PROGRAM, &program);
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &framebuffer);
        glGetIntegerv(GL_ACTIVE_TEXTURE, &activeTexture);
        glPushAttrib(GL_ALL_ATTRIB_BITS);
        glActiveTexture(GL_TEXTURE0);
    }
    ~GlState() {
        glUseProgram(program);
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        glPopAttrib();
        glActiveTexture(activeTexture);
    }
};

GLuint compile(GLenum type, const std::string& source) {
    GLuint shader = glCreateShader(type);
    const char* text = source.c_str();
    glShaderSource(shader, 1, &text, nullptr);
    glCompileShader(shader);
    GLint ok = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[2048] = {};
        glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
        glDeleteShader(shader);
        throw std::runtime_error(std::string("Trail shader: ") + log);
    }
    return shader;
}

void quad() {
    glBegin(GL_TRIANGLE_STRIP);
    glTexCoord2f(0.f, 0.f); glVertex2f(-1.f, -1.f);
    glTexCoord2f(1.f, 0.f); glVertex2f(1.f, -1.f);
    glTexCoord2f(0.f, 1.f); glVertex2f(-1.f, 1.f);
    glTexCoord2f(1.f, 1.f); glVertex2f(1.f, 1.f);
    glEnd();
}
}

struct GbloinkTrailWidget::Impl {
    std::shared_ptr<GbloinkTrailSettings> settings;
    GLuint program = 0, textures[2] = {}, framebuffers[2] = {}, queries[2] = {};
    bool pending[2] = {}, timerSupported = false, broken = false;
    int width = 0, height = 0, current = 0, frameCount = 0;
    GLint historyLocation = -1, retentionLocation = -1, marksLocation = -1;
    GLint ballLocations[3] = {}, colourLocations[3] = {};
    std::uint64_t revision = 0;
    double logicalTime = -1, lastGpuMs = -1, submitTotalMs = 0;
    Clock::time_point lastFrame{}, lastReport{};
    explicit Impl(std::shared_ptr<GbloinkTrailSettings> s) : settings(std::move(s)) {}

    void release() {
        if (program) glDeleteProgram(program);
        if (framebuffers[0] || framebuffers[1]) glDeleteFramebuffers(2, framebuffers);
        if (textures[0] || textures[1]) glDeleteTextures(2, textures);
        if (queries[0]) glDeleteQueries(2, queries);
        program = 0;
        for (int i = 0; i < 2; ++i) { textures[i] = framebuffers[i] = queries[i] = 0; pending[i] = false; }
        width = height = current = frameCount = 0;
        logicalTime = -1;
        revision = 0;
        lastFrame = lastReport = Clock::time_point{};
        lastGpuMs = -1;
        submitTotalMs = 0;
    }

    void initialize() {
        const std::string vertex = "#version 120\nvarying vec2 uv; void main(){ uv=gl_MultiTexCoord0.xy; gl_Position=gl_Vertex; }";
        const std::string fragment = std::string("#version 120\nvarying vec2 uv; uniform sampler2D history; uniform float retention; uniform float marks;\n")
            + "uniform vec3 ball0, ball1, ball2, colour0, colour1, colour2;\n" + decayFunction
            + "vec3 mark(vec3 c, vec2 p, vec3 ball, vec3 colour){ float a=(1.0-smoothstep(ball.z-0.6,ball.z+0.6,length(p-ball.xy)))*0.65*marks; return mix(c,colour,a); }\n"
            + "void main(){vec3 c=wocTrailDecay(texture2D(history,uv).rgb,retention);vec2 p=vec2(uv.x,1.0-uv.y)*vec2(700.0,500.0);"
            + "c=mark(c,p,ball0,colour0);c=mark(c,p,ball1,colour1);c=mark(c,p,ball2,colour2);gl_FragColor=vec4(c,1.0);}";
        GLuint vs = compile(GL_VERTEX_SHADER, vertex);
        GLuint fs = 0;
        try { fs = compile(GL_FRAGMENT_SHADER, fragment); }
        catch (...) { glDeleteShader(vs); throw; }
        program = glCreateProgram();
        glAttachShader(program, vs); glAttachShader(program, fs); glLinkProgram(program);
        glDeleteShader(vs); glDeleteShader(fs);
        GLint ok = 0;
        glGetProgramiv(program, GL_LINK_STATUS, &ok);
        if (!ok) {
            char log[2048] = {};
            glGetProgramInfoLog(program, sizeof(log), nullptr, log);
            throw std::runtime_error(std::string("Trail program: ") + log);
        }
        historyLocation = glGetUniformLocation(program, "history");
        retentionLocation = glGetUniformLocation(program, "retention");
        marksLocation = glGetUniformLocation(program, "marks");
        for (int i = 0; i < 3; ++i) {
            ballLocations[i] = glGetUniformLocation(program, ("ball" + std::to_string(i)).c_str());
            colourLocations[i] = glGetUniformLocation(program, ("colour" + std::to_string(i)).c_str());
        }
        timerSupported = GLEW_VERSION_3_3 || GLEW_ARB_timer_query;
        if (timerSupported) glGenQueries(2, queries);
        INFO("Gbloink trails GL: %s / %s; timer queries %s", glGetString(GL_VENDOR), glGetString(GL_RENDERER), timerSupported ? "available" : "unavailable");
    }

    void allocate(int w, int h) {
        glDeleteFramebuffers(2, framebuffers);
        glDeleteTextures(2, textures);
        glGenTextures(2, textures); glGenFramebuffers(2, framebuffers);
        for (int i = 0; i < 2; ++i) {
            glBindTexture(GL_TEXTURE_2D, textures[i]);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
            glBindFramebuffer(GL_FRAMEBUFFER, framebuffers[i]);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textures[i], 0);
            if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
                throw std::runtime_error("Trail framebuffer incomplete");
            glClearColor(18.f/255.f,20.f/255.f,26.f/255.f,1.f);
            glClear(GL_COLOR_BUFFER_BIT);
        }
        width = w; height = h; current = 0;
        lastFrame = Clock::time_point{};
        INFO("Gbloink trails: allocated two %dx%d history textures", w, h);
    }

    int beginTimer() {
        if (!timerSupported || !settings->diagnostics) return -1;
        for (int i = 0; i < 2; ++i) if (pending[i]) {
            GLint available = 0;
            glGetQueryObjectiv(queries[i], GL_QUERY_RESULT_AVAILABLE, &available);
            if (available) {
                GLuint64 ns = 0;
                glGetQueryObjectui64v(queries[i], GL_QUERY_RESULT, &ns);
                lastGpuMs = ns / 1000000.0;
                pending[i] = false;
            }
        }
        if (frameCount % 30) return -1;
        GLint active = 0;
        glGetQueryiv(GL_TIME_ELAPSED, GL_CURRENT_QUERY, &active);
        if (active) return -1;
        for (int i = 0; i < 2; ++i) if (!pending[i]) { glBeginQuery(GL_TIME_ELAPSED, queries[i]); return i; }
        return -1;
    }
};

GbloinkTrailWidget::GbloinkTrailWidget(std::shared_ptr<GbloinkTrailSettings> settings)
    : impl(new Impl(std::move(settings))) {}
GbloinkTrailWidget::~GbloinkTrailWidget() { impl->release(); }
bool GbloinkTrailWidget::failed() const { return impl->broken; }

void GbloinkTrailWidget::onContextCreate(const ContextCreateEvent& e) {
    impl->broken = false;
    OpenGlWidget::onContextCreate(e);
}
void GbloinkTrailWidget::onContextDestroy(const ContextDestroyEvent& e) {
    impl->release();
    OpenGlWidget::onContextDestroy(e);
}

void GbloinkTrailWidget::drawFramebuffer() {
    GlState state;
    const auto started = Clock::now();
    const auto size = getFramebufferSize();
    glDisable(GL_SCISSOR_TEST); glDisable(GL_BLEND); glDisable(GL_DEPTH_TEST);
    glDisable(GL_STENCIL_TEST); glDisable(GL_CULL_FACE);
    glColorMask(GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE);
    if (!snapshot || impl->broken) {
        glClearColor(18.f/255.f,20.f/255.f,26.f/255.f,1.f);
        glClear(GL_COLOR_BUFFER_BIT);
        return;
    }
    try {
        if (!impl->program) impl->initialize();
        const int w = impl->settings->halfResolution ? 350 : 700;
        const int h = impl->settings->halfResolution ? 250 : 500;
        if (impl->width != w || impl->height != h || impl->revision != snapshot->stateRevision || snapshot->logicalTime < impl->logicalTime)
            impl->allocate(w,h);
        const double elapsed = impl->lastFrame == Clock::time_point{} ? 0.0 : std::chrono::duration<double>(started-impl->lastFrame).count();
        impl->lastFrame = started;
        const int query = impl->beginTimer();
        const int next = 1-impl->current;
        glUseProgram(impl->program);
        glUniform1i(impl->historyLocation, 0);
        glUniform1f(impl->retentionLocation, std::pow(0.5, elapsed / std::max(0.01f,impl->settings->halfLife)));
        glUniform1f(impl->marksLocation, !snapshot->paused && snapshot->logicalTime != impl->logicalTime ? 1.f : 0.f);
        for (int i = 0; i < 3; ++i) {
            const auto& ball = snapshot->balls[i];
            glUniform3f(impl->ballLocations[i],ball.x,ball.y,ball.radius);
            glUniform3f(impl->colourLocations[i],((ball.colour>>16)&255)/255.f,((ball.colour>>8)&255)/255.f,(ball.colour&255)/255.f);
        }
        glBindFramebuffer(GL_FRAMEBUFFER, impl->framebuffers[next]);
        glViewport(0,0,w,h);
        glBindTexture(GL_TEXTURE_2D,impl->textures[impl->current]);
        quad();
        // Composite current history to Rack's framebuffer in this same callback.
        glBindFramebuffer(GL_FRAMEBUFFER,state.framebuffer);
        glViewport(0,0,static_cast<int>(size.x),static_cast<int>(size.y));
        glUniform1f(impl->retentionLocation,1.f);
        glUniform1f(impl->marksLocation,0.f);
        glBindTexture(GL_TEXTURE_2D,impl->textures[next]);
        quad();
        if (query >= 0) { glEndQuery(GL_TIME_ELAPSED); impl->pending[query] = true; }
        impl->current = next;
        impl->logicalTime = snapshot->logicalTime;
        impl->revision = snapshot->stateRevision;
        impl->frameCount++;
        impl->submitTotalMs += std::chrono::duration<double,std::milli>(Clock::now()-started).count();
        if (impl->lastReport == Clock::time_point{}) impl->lastReport = started;
        const double reportSeconds = std::chrono::duration<double>(started-impl->lastReport).count();
        if (reportSeconds >= 5.0) {
            if (impl->settings->diagnostics)
                INFO("Gbloink trails: %dx%d, %.1f renders/s, CPU submit %.3f ms, latest GPU update+copy %.3f ms",w,h,impl->frameCount/reportSeconds,impl->submitTotalMs/std::max(1,impl->frameCount),impl->lastGpuMs);
            impl->lastReport = started; impl->submitTotalMs = 0; impl->frameCount = 0;
        }
    } catch (const std::exception& e) {
        WARN("Gbloink trails disabled; classic renderer retained: %s",e.what());
        impl->release(); impl->broken = true;
        glBindFramebuffer(GL_FRAMEBUFFER,state.framebuffer);
        glClearColor(18.f/255.f,20.f/255.f,26.f/255.f,1.f);
        glClear(GL_COLOR_BUFFER_BIT);
    }
}

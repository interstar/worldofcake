#include "NoteOutputScheduler.h"

#include <cstdio>
#include <vector>

using worldofcake::bridge::NoteOutputScheduler;
using worldofcake::bridge::PreparedEvent;

namespace
{
    int failures = 0;

    void check(bool condition, const char* message)
    {
        if (!condition) {
            std::printf("FAIL: %s\n", message);
            ++failures;
        }
    }

    PreparedEvent note(int type, int channel, int pitch)
    {
        PreparedEvent e;
        e.type = type;
        e.channel = channel;
        e.data2 = pitch;
        e.data3 = type == NoteOutputScheduler::kNoteOn ? 100 : 0;
        return e;
    }

    struct Emitted
    {
        double time;
        PreparedEvent event;
    };

    struct Collector
    {
        std::vector<Emitted> out;
        void operator()(double time, const PreparedEvent& e)
        {
            out.push_back({time, e});
        }
    };
} // namespace

int main()
{
    {
        NoteOutputScheduler s;
        Collector c;
        s.schedule(0.05, note(NoteOutputScheduler::kNoteOff, 1, 60));
        s.schedule(0.00, note(NoteOutputScheduler::kNoteOn, 1, 60));
        s.emitDue(0.01, c);
        check(c.out.size() == 1 && c.out[0].event.type == NoteOutputScheduler::kNoteOn, "only due events are emitted");
        check(s.soundingNotes(1) == 1, "emitted note-on is sounding");
        s.emitDue(1.0, c);
        check(c.out.size() == 2 && c.out[1].event.type == NoteOutputScheduler::kNoteOff, "note-off follows in time order");
        check(s.soundingNotes(1) == 0, "note-off ends the note");
    }
    {
        NoteOutputScheduler s;
        Collector c;
        s.schedule(0.5, note(NoteOutputScheduler::kNoteOff, 2, 64));
        s.schedule(0.5, note(NoteOutputScheduler::kNoteOn, 2, 64));
        s.schedule(0.2, note(NoteOutputScheduler::kNoteOn, 2, 64));
        s.emitDue(0.5, c);
        check(c.out.size() == 3 && c.out[1].event.type == NoteOutputScheduler::kNoteOff &&
                  c.out[2].event.type == NoteOutputScheduler::kNoteOn,
              "equal times keep arrival order (retrigger: off before on)");
        check(s.soundingNotes(2) == 1, "retriggered note is sounding once");
        check(s.noteOnCount(2) == 2, "every note-on is counted, so a gate can retrigger");
    }
    {
        NoteOutputScheduler s;
        Collector c;
        s.emitDue(10.0, c);
        s.schedule(1.0, note(NoteOutputScheduler::kNoteOn, 3, 50));
        s.emitDue(10.0, c);
        s.schedule(2.0, note(NoteOutputScheduler::kNoteOff, 3, 50));
        s.emitDue(10.0, c);
        check(c.out.size() == 2 && s.soundingNotes(3) == 0, "late events are emitted immediately");
    }
    {
        NoteOutputScheduler s;
        Collector c;
        for (std::size_t i = 0; i < NoteOutputScheduler::kCapacity; ++i)
            s.schedule(1.0 + static_cast<double>(i), note(NoteOutputScheduler::kNoteOn, 4, 60));
        s.schedule(0.5, note(NoteOutputScheduler::kNoteOff, 4, 61));
        check(s.pendingCount() == NoteOutputScheduler::kCapacity, "full queue stays at capacity");
        check(s.droppedEvents() == 1, "a note-on was discarded to keep the note-off");
        s.schedule(0.5, note(NoteOutputScheduler::kNoteOn, 4, 62));
        check(s.droppedEvents() == 2, "a note-on is dropped when full");
    }
    {
        NoteOutputScheduler s;
        Collector c;
        s.schedule(0.0, note(NoteOutputScheduler::kNoteOn, 1, 60));
        s.schedule(0.0, note(NoteOutputScheduler::kNoteOn, 1, 67));
        s.schedule(0.1, note(NoteOutputScheduler::kNoteOff, 1, 60));
        s.emitDue(0.0, c);
        c.out.clear();
        s.releaseAll(0.05, c);
        check(c.out.size() == 2 && s.soundingNotes(1) == 0 && s.pendingCount() == 0, "releaseAll ends sounding notes");
        s.schedule(0.1, note(NoteOutputScheduler::kNoteOff, 1, 60));
        s.emitDue(1.0, c);
        check(c.out.size() == 2, "a note-off for a released note is not repeated");
    }

    if (failures == 0)
        std::printf("All NoteOutputScheduler tests passed\n");
    return failures == 0 ? 0 : 1;
}

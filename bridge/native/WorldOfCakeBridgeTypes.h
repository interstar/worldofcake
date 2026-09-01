#pragma once

#include <array>
#include <cmath>
#include <cstdint>
#include <stdexcept>
#include <vector>

namespace worldofcake
{
    struct BasePoint
    {
        double x = 0.0;
        double y = 0.0;

        BasePoint() = default;
        BasePoint(double x_, double y_) : x(x_), y(y_)
        {
        }
    };

    struct ScreenPoint : BasePoint
    {
        ScreenPoint() = default;
        ScreenPoint(double x_, double y_) : BasePoint(x_, y_)
        {
        }
    };

    struct PanelPoint : BasePoint
    {
        PanelPoint() = default;
        PanelPoint(double x_, double y_) : BasePoint(x_, y_)
        {
        }
    };

    struct LocalPoint : BasePoint
    {
        LocalPoint() = default;
        LocalPoint(double x_, double y_) : BasePoint(x_, y_)
        {
        }
    };

    class CoordinateMapper
    {
      public:
        CoordinateMapper(BasePoint space1Min, BasePoint space1Max, BasePoint space2Min, BasePoint space2Max)
            : x_(space1Min.x, space1Max.x, space2Min.x, space2Max.x),
              y_(space1Min.y, space1Max.y, space2Min.y, space2Max.y)
        {
        }

        BasePoint forward(double x, double y) const
        {
            return {x_.forward(x), y_.forward(y)};
        }

        BasePoint backward(double x, double y) const
        {
            return {x_.backward(x), y_.backward(y)};
        }

        double lengthForward(double length) const
        {
            return length / x_.space1Range() * x_.space2Range();
        }

        double lengthBackward(double length) const
        {
            return length / x_.space2Range() * x_.space1Range();
        }

      private:
        struct OneDMapper
        {
            double a = 0.0;
            double b = 0.0;
            double c = 0.0;
            double d = 0.0;

            OneDMapper(double a_, double b_, double c_, double d_) : a(a_), b(b_), c(c_), d(d_)
            {
                if (a == b || c == d) {
                    throw std::invalid_argument("CoordinateMapper requires non-zero ranges");
                }
            }

            double forward(double v) const
            {
                return c + (v - a) * (d - c) / (b - a);
            }

            double backward(double v) const
            {
                return a + (v - c) * (b - a) / (d - c);
            }

            double space1Range() const
            {
                return b - a;
            }
            double space2Range() const
            {
                return d - c;
            }
        };

        OneDMapper x_;
        OneDMapper y_;
    };
} // namespace worldofcake

namespace worldofcake
{
    namespace bridge
    {
        enum class CommandKind : std::uint8_t
        {
            playAreaClick,
            setValue,
            playAreaDrag,
            playAreaRelease
        };

        struct ControlCommand
        {
            CommandKind kind = CommandKind::playAreaClick;
            std::uint64_t sequence = 0;
            int controlId = 0;
            double x = 0.0;
            double y = 0.0;
            double value = 0.0;
        };

        struct PreparedEvent
        {
            double timestamp = 0.0;
            int type = -1;
            int channel = 0;
            int data2 = 0;
            int data3 = 0;
        };

        struct BallSnapshot
        {
            double x = 0.0;
            double y = 0.0;
            double radius = 0.0;
            int colour = 0xffffff;
        };

        struct GbloinkBlockSnapshot
        {
            double left = 0.0;
            double top = 0.0;
            double right = 0.0;
            double bottom = 0.0;
            int colour = 0x888888;
        };

        struct GbloinkVisualSnapshot
        {
            std::uint64_t generation = 0;
            double logicalTime = 0.0;
            std::array<BallSnapshot, 3> balls{};
            std::vector<GbloinkBlockSnapshot> blocks;
            bool paused = false;
            bool edgeNotes = false;
            int scaleIndex = 0;
        };

        struct TimeSliderValueSnapshot
        {
            double x = 0.0;
            double y = 0.0;
            double width = 0.0;
            double height = 0.0;
            double current = 0.0;
            double destination = 0.0;
            int midiValue = 0;
        };

        struct TimeSliderControlSnapshot
        {
            std::uint64_t generation = 0;
            double logicalTime = 0.0;
            bool paused = false;
            std::array<TimeSliderValueSnapshot, 4> sliders{};
        };

        struct TileLandCursorSnapshot
        {
            double x = 0.0;
            double y = 0.0;
            int colour = 0;
            double speed = 0.0;
        };

        struct TileLandControlSnapshot
        {
            std::uint64_t generation = 0;
            double logicalTime = 0.0;
            /** X/Y pairs for cursors 1..3, normalized to MIDI-style 0..127. */
            std::array<int, 6> values{};
        };

        enum class TileOrientation : std::uint8_t
        {
            A = 1,
            B = 2
        };
        struct TileVisual
        {
            TileOrientation orientation = TileOrientation::A;
            operator int() const noexcept
            {
                return orientation == TileOrientation::A ? 1 : 0;
            }
        };
        struct TileLandVisualSnapshot
        {
            std::uint64_t generation = 0;
            double logicalTime = 0.0;
            bool paused = false;
            int rows = 0;
            int cols = 0;
            std::array<TileVisual, 144> tileTypes{};
            std::array<TileLandCursorSnapshot, 3> cursors{};
        };

        struct KDiagramControlSnapshot
        {
            std::uint64_t generation = 0;
            double logicalTime = 0.0;
            /** X/Y pairs for three cursors, normalized from -1..1 to 0..127. */
            std::array<int, 6> values{};
        };

        struct KDiagramNodeSnapshot
        {
            double x = 0.0;
            double y = 0.0;
        };
        struct KDiagramArcSnapshot
        {
            int source = -1;
            int destination = -1;
        };
        struct KDiagramCursorSnapshot
        {
            double x = 0.0, y = 0.0, targetX = 0.0, targetY = 0.0;
            double speed = 0.0;
            int colour = 0, channel = 1;
            bool moving = false;
        };
        struct KDiagramVisualSnapshot
        {
            std::uint64_t generation = 0;
            double logicalTime = 0.0;
            bool paused = false;
            double radius = 0.9;
            int selectedCursor = 0;
            int scaleIndex = 0;
            std::vector<KDiagramNodeSnapshot> nodes;
            std::vector<KDiagramArcSnapshot> arcs;
            std::array<KDiagramCursorSnapshot, 3> cursors{};
        };

        struct ZewpAgentSnapshot
        {
            double x = 0.0, y = 0.0, angle = 0.0, length = 0.0;
            int colour = 0, channel = 1, ccNumber = 0;
        };
        struct ZewpBlockSnapshot
        {
            double x = 0.0, y = 0.0, width = 0.0, height = 0.0;
            int colour = 0;
        };
        struct ZewpControlSnapshot
        {
            std::uint64_t generation = 0;
            double logicalTime = 0.0;
            // Six fixed Zewp slots × (X CV, Y CV, gate). Unpopulated slots publish zero.
            std::array<int, 18> values{};
        };
        struct ZewpVisualSnapshot
        {
            std::uint64_t generation = 0;
            double logicalTime = 0.0;
            bool paused = false;
            int population = 0;
            double speedMultiplier = 1.0;
            std::vector<ZewpAgentSnapshot> agents;
            std::vector<ZewpBlockSnapshot> blocks;
        };
    } // namespace bridge
} // namespace worldofcake

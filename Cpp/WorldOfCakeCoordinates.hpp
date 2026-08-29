#pragma once

#include <cmath>
#include <stdexcept>

namespace worldofcake {

/** Coordinate value types used by the WorldOfCake UI/model vocabulary. */
struct BasePoint { double x; double y; BasePoint(double x_=0.0,double y_=0.0):x(x_),y(y_){} };
struct ScreenPoint : BasePoint { ScreenPoint() = default; ScreenPoint(double x_, double y_) { x=x_; y=y_; } };
struct PanelPoint  : BasePoint { PanelPoint() = default; PanelPoint(double x_, double y_) { x=x_; y=y_; } };
struct LocalPoint  : BasePoint { LocalPoint() = default; LocalPoint(double x_, double y_) { x=x_; y=y_; } };

/** Affine mapping between two rectangular coordinate spaces. */
class CoordinateMapper {
public:
    CoordinateMapper(BasePoint space1Min, BasePoint space1Max,
                     BasePoint space2Min, BasePoint space2Max)
        : x_(space1Min.x, space1Max.x, space2Min.x, space2Max.x),
          y_(space1Min.y, space1Max.y, space2Min.y, space2Max.y) {}

    BasePoint forward(double x, double y) const { return {x_.forward(x), y_.forward(y)}; }
    BasePoint backward(double x, double y) const { return {x_.backward(x), y_.backward(y)}; }
    double lengthForward(double length) const { return length / x_.space1Range() * x_.space2Range(); }
    double lengthBackward(double length) const { return length / x_.space2Range() * x_.space1Range(); }

private:
    struct OneDMapper {
        double a,b,c,d;
        OneDMapper(double a_,double b_,double c_,double d_) : a(a_),b(b_),c(c_),d(d_) {
            if (a == b || c == d) throw std::invalid_argument("CoordinateMapper requires non-zero ranges");
        }
        double forward(double v) const { return c + (v-a) * (d-c) / (b-a); }
        double backward(double v) const { return a + (v-c) * (b-a) / (d-c); }
        double space1Range() const { return b-a; }
        double space2Range() const { return d-c; }
    };
    OneDMapper x_, y_;
};

} // namespace worldofcake

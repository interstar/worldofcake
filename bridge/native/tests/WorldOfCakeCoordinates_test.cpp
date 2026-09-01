#include "../WorldOfCakeBridgeTypes.h"
#include <cassert>
#include <cmath>
int main()
{
    using namespace worldofcake;
    CoordinateMapper m(ScreenPoint(10, 20), ScreenPoint(110, 220), PanelPoint(0, 0), PanelPoint(1, 1));
    auto p = m.forward(60, 120);
    assert(std::abs(p.x - .5) < 1e-9 && std::abs(p.y - .5) < 1e-9);
    auto q = m.backward(.25, .75);
    assert(std::abs(q.x - 35) < 1e-9 && std::abs(q.y - 170) < 1e-9);
    assert(std::abs(m.lengthForward(50) - .5) < 1e-9);
    assert(std::abs(m.lengthBackward(.5) - 50) < 1e-9);
    LocalPoint local(3, 4);
    assert(local.x == 3 && local.y == 4);
}

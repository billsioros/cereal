
#pragma once

#include <iosfwd>

class Point
{
    float x, y;

public:

    Point();

    Point(float, float);

    Point(const Point& other);

    Point(Point&& other) noexcept;

    Point& operator=(const Point& other);

    Point& operator=(Point&& other) noexcept;

    friend std::ostream& operator<<(std::ostream&, const Point&);
};

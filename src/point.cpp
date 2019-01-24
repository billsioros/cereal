
#include <point.hpp>

#include <utility>
#include <fstream>

Point::Point() : x(0.0f), y(0.0f)
{
}

Point::Point(float x, float y) : x(x), y(y)
{
}

Point::Point(const Point& other) : x(other.x), y(other.y)
{
}

Point::Point(Point&& other) noexcept : x(std::move(other.x)), y(std::move(other.y))
{
}

Point& Point::operator=(const Point& other)
{
    x = other.x; y = other.y; return *this;
}

Point& Point::operator=(Point&& other) noexcept
{
    x = std::move(other.x); y = std::move(other.y); return *this;
}

std::ostream& operator<<(std::ostream& os, const Point& point)
{
    return os
    << "[ " << point.x
    << ", " << point.y
    << " ]";
}

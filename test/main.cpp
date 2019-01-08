
#include <point.hpp>

#include <vector>
#include <iostream>

#if defined (__ARBITARY__)
    #include <cstdlib>
    #include <ctime>

    #define rand01 (static_cast<float>(std::rand()) / static_cast<float>(RAND_MAX))
    
    #define frand(min, max) ((max - min) * rand01 + min)
#endif

#define SIZE (10UL)

int main()
{
    std::vector<Point> points;

    #if defined (__ARBITARY__)
        std::srand(static_cast<unsigned>(std::time(nullptr)));

        for (std::size_t i = 0UL; i < SIZE; i++)
            points.emplace_back(frand(-10.0f, 10.0f), frand(-10.0f, 10.0f));
    #else
        for (std::size_t i = 0UL; i < SIZE; i++)
            points.emplace_back(0.0f, 0.0f);
    #endif

    for (const auto& point : points)
        std::cout << point << std::endl;

    return 0;
}

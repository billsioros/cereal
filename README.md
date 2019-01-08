
# cpp-build

A simple bash script to make your life easier when building cpp applications. cpp-build offers makefile generation and build automation tools as well as a macro definition shortcut system

## Installation

```bash
wget https://raw.githubusercontent.com/billsioros/cpp-build/master/cpp-build.sh;

sudo mv -i ./cpp-build.sh /usr/local/bin/cpp-build;
```

## Programmatic usage

```cpp
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
```

The makefile generated after running the script with the "--makefile" flag:

```bash
CC = g++
CCFLAGS = -Wall -Wextra -std=c++17 -g3

LIBS = -lpthread

PATH_SRC = ./src
PATH_INC = ./inc
PATH_BIN = ./bin
PATH_TEST = ./test

.PHONY: all
all:
	mkdir -p $(PATH_BIN)
	@echo
	@echo "*** Compiling object files ***"
	@echo "***"
	make $(OBJS)
	@echo "***"

.PHONY: clean
clean:
	@echo
	@echo "*** Purging binaries ***"
	@echo "***"
	rm -rvf $(PATH_BIN)
	@echo "***"


POINT_DEP = $(addprefix $(PATH_INC)/, point.hpp) $(PATH_SRC)/point.cpp


$(PATH_BIN)/point.o: $(POINT_DEP)
	$(CC) -I $(PATH_INC) $(DEFINED) $(CCFLAGS) $(PATH_SRC)/point.cpp -c -o $(PATH_BIN)/point.o


OBJS = $(addprefix $(PATH_BIN)/,  point.o)

$(PATH_BIN)/%.exe: $(PATH_TEST)/%.cpp $(OBJS)
	$(CC) -I $(PATH_INC) $(DEFINED) $(CCFLAGS) $< $(OBJS) $(LIBS) -o $@
```

The result of running the script with the "--help" flag:

    # Options:
    # -u, --unit-define      Define a macro in a test unit
    # -g, --global-define    Define a macro globally
    # -x, --executable       Compile the specified executable
    # -r, --rebuild          Recompile library / executable

    # Shortcuts:
    # -a, -u __ARBITARY__

    # Usage:
    # cpp-build.sh -u [MACRO]
    # cpp-build.sh -g [MACRO]
    # cpp-build.sh -x [name]
    # cpp-build.sh -r

    # Example: cpp-build.sh -r -u __BENCHMARK__ -u __QUIET__ -g __CACHE_SIZE__=32768

If we now want to compile our program with the "\_\_ARBITARY\_\_" flag enabled we can simply run the script with the "-a" flag

## Notice

* The configuration file must be located in the current working directory
* For the makefile generation to work properly, the extension of every header file must be either .h or .hpp
* For the macro shortcut system to work properly, the macros must be of the format "\_\_.*\_\_", for example "\_\_VERBOSE\_\_"
* When using the "--executable" flag the directory and the extension
of the executable need not be specified

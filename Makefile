
CC = g++
CCFLAGS = -Wall -Wextra -std=c++17 -g3

LIBS = 

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

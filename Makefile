# makefile for OMORI-Controller-Rumble
# makefile by pliplupp, original program made by sierra

PLATFORM_INCLUDE 	:=

# library path stuff
CXXFLAGS += -L./dependencies 

# platformslop
ifeq ($(OS),Windows_NT)
	EXE_EXTENSION := .exe
    # hacky workaround to get it to detect SDL headers for windows builds without having to install SDL a specific way
	CXXFLAGS += -lSDL3 -lws2_32 -I./include
else
	UNAME_S := $(shell uname -s)
	EXE_EXTENSION := 

	ifeq ($(UNAME_S),Linux)
		CXXFLAGS += -lSDL3
	endif

    # had to do random extra stuff for macos because the default compiler doesn't include headers from homebrew or macports packages
	ifeq ($(UNAME_S),Darwin)
		CXXFLAGS += -lSDL3 
		ifneq ("$(wildcard /opt/homebrew/include/SDL3)", "")
			CXXFLAGS += -I /opt/homebrew/include
		else
			ifneq ("$(wildcard /opt/local/include/SDL3)", "")
				CXXFLAGS += -I /opt/local/include
			endif
		endif
	endif
endif

all: main.cpp 
	mkdir -p build
	$(CXX) $^ -o build/RumbleBridge$(EXE_EXTENSION) $(CXXFLAGS)

clean: 
	rm -rf build
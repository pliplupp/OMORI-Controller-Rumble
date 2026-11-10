# makefile for OMORI-Controller-Rumble
# makefile by pliplupp, original program made by sierra

PLATFORM_INCLUDE 	:=

# library path stuff
CXXFLAGS += -L./dependencies -lsdl3

# platformslop
ifeq ($(OS),Windows_NT)
	EXE_EXTENSION := ".exe"
else
	UNAME_S := $(shell uname -s)
	EXE_EXTENSION := 

    # had to do random extra stuff for macos because the default compiler doesn't include headers from homebrew or macports packages
	ifeq ($(UNAME_S),Darwin)
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
	$(CXX) $(CXXFLAGS) $^ -o build/RumbleBridge$(EXE_EXTENSION)

clean: 
	rm -rf build
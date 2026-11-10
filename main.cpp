


// Standard C/C++ includes
#include <iostream>
#include <fstream>
#include <thread>
#include <atomic>
#include <cstdlib>
#include <stdio.h>

// SDL includes
#include <SDL3/SDL.h>
#include <SDL3/SDL_joystick.h>
#include <SDL3/SDL_gamepad.h>
#include <SDL3/SDL_hints.h>


// Cross-platform socket header 
// Public domain, by Sophie Eccles - big thanks to her :)
// Source: https://gist.github.com/sophec/3ba0741143b573b74b1c0a7aea2bdb40
#include "include/sockets.h"

// Platform-specific headers, libraries, etc
#ifdef _WIN32 
    // Windows headers and libraries
    // Used if the target is... well, Windows
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    //#include <Xinput.h>
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #pragma comment(lib, "SDL3.lib")
    #pragma comment(lib, "ws2_32.lib")

    #define closeSocket(x) closesocket(x)
#else
    // Linux/Unix/POSIX headers
    // Used if target is Linux, MacOS, or just "not windows"
    #include <sys/socket.h>
    #include <sys/socketvar.h>
    #include <sys/types.h>

    // Aliases for windows library names
    #define SOCKET_ERROR -1
    #define Sleep(x) sleep(x)

    // using "close()" as a macro on windows messes with c++ ofstream stuff 
    #define closeSocket(x) close(x)

    // Defines Windows WORD and DWORD types 
    // i was too lazy to change these in the code
    #define WORD uint32_t
    #define DWORD uint64_t
#endif

// custom struct that replaces XINPUT_VIBRATION
// SDL uses 16-bit integers for rumble intensity
struct omoControllerRumbleVibration {
    uint16_t wLeftMotorSpeed;
    uint16_t wRightMotorSpeed;
};

// Atomic flag to instantly kill active rumbles when a 0.00 command arrives
std::atomic<bool> abortRumble(false);

// We don't need this because "gamepad" replaces it lmao
//DWORD activeController = 0xFFFFFFFF;

// Global log file stream
std::ofstream logFile;

// SDL structs
SDL_Event sdlEvent;
SDL_Gamepad *gamepad = NULL;

void ExecuteRumble(float intensity, int time, int fade) {
    abortRumble = false;
    omoControllerRumbleVibration vibration;

    if (fade == 1 && time > 20) {
        int elapsed = 0;
        int tickMs = 10;
        float startIntensity = intensity;

        while (elapsed < time) {
            if (abortRumble) break; 

            float progress = (float)elapsed / (float)time;
            float currentIntensity = startIntensity * (1.0f - progress);
            uint16_t motor = (uint16_t)(currentIntensity * 255.0f);

            vibration.wLeftMotorSpeed = motor;
            vibration.wRightMotorSpeed = motor;

            // Unlike XInput's rumble system, SDL_RumbleGamepad takes a "time" argument (in ms)
            // Looking through this code, it seems like you intended each "tick" of controller rumble to last 10 ms
            // Because of this, I passed 10 as the time argument for controller rumble.
            // (yes, i know this comment sounds like it came from claude or something, i assure you no ai was used here)
            if (!(SDL_RumbleGamepad(gamepad, vibration.wLeftMotorSpeed, vibration.wRightMotorSpeed, 10))) {
                if (logFile.is_open()) logFile << "[ERROR] Controller vibration returned error.\n" << std::flush;
            }
            SDL_UpdateJoysticks();

            Sleep(tickMs);
            elapsed += tickMs;
        }
    }
    else {
        if (time > 0) {
            uint16_t motor = (uint16_t)(intensity * 255.0f);
            vibration.wLeftMotorSpeed = motor;
            vibration.wRightMotorSpeed = motor;

            if (!(SDL_RumbleGamepad(gamepad, vibration.wLeftMotorSpeed, vibration.wRightMotorSpeed, 10))) {
                if (logFile.is_open()) logFile << "[ERROR] Controller vibration returned error.\n" << std::flush;
            }
            SDL_UpdateJoysticks();

            int ticks = time / 10;
            for (int i = 0; i < ticks; i++) {
                if (abortRumble) break;
                Sleep(10);
            }
        }
    }

    vibration.wLeftMotorSpeed = 0;
    vibration.wRightMotorSpeed = 0;
    if (!(SDL_RumbleGamepad(gamepad, vibration.wLeftMotorSpeed, vibration.wRightMotorSpeed, 10))) {
        if (logFile.is_open()) logFile << "[ERROR] Controller vibration returned error.\n" << std::flush;
    }
    SDL_UpdateJoysticks();
}

int main() {
    // Open log file directly in the current directory (overwrites old logs)
    logFile.open("bridge_log.txt", std::ios::out | std::ios::trunc);
    if (logFile.is_open()) {
        logFile << "=============================================================\n" << std::flush;
        logFile << "               OMORI RUNTIME CONTROLLER BRIDGE               \n" << std::flush;
        logFile << "=============================================================\n" << std::flush;
    }

    // Allow the program to detect controller input in the background
    if (!(SDL_SetHintWithPriority(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1", SDL_HINT_OVERRIDE))) {
        if (logFile.is_open()) logFile << "[ERROR] SDL failed to set hint\n" << std::flush;
        system("pause"); return 1;
    }

    // SDL Init, with the "gamepad" flag
    if (!(SDL_Init(SDL_INIT_GAMEPAD))) {
        if (logFile.is_open()) logFile << "[ERROR] SDL Initialization failed\n" << std::flush;
        system("pause"); return 1;
    }

    // Checks if a gamepad is actually detected
    if (!SDL_HasGamepad()) {
        if (logFile.is_open()) logFile << "[ERROR] No gamepads detected on system.\n" << std::flush;
        system("pause"); return 1;
    }

    // gamepad connection, loops until gamepad event is detected
    // this is a failsafe in case some event is detected BEFORE the gamepad
    while (!gamepad) {
        SDL_PollEvent(&sdlEvent);
        if (sdlEvent.type == SDL_EVENT_GAMEPAD_ADDED) {
            gamepad = SDL_OpenGamepad(sdlEvent.gdevice.which);
            if (!gamepad) {
                if (logFile.is_open()) logFile << "[ERROR] Gamepad initialization failed. ID: " << (unsigned int)sdlEvent.gdevice.which << "\nERR: " << SDL_GetError() << "\n" << std::flush;
                system("pause"); return 1;
            }
            else {
                if (logFile.is_open()) logFile << "[HARDWARE] Controller Detected with ID: " << (unsigned int)sdlEvent.gdevice.which << "\n" << std::flush;
            };
        }
    }

    // for (DWORD i = 0; i < 4; i++) {
    //     XINPUT_STATE state{};
    //     if (XInputGetState(i, &state) != NULL) {
    //         activeController = i;
    //         if (logFile.is_open()) logFile << "[HARDWARE] XInput Controller Detected on Index: " << i << "\n" << std::flush;
    //         break;
    //     }
    // }

    
   // WSADATA wsa;
   // WSA init replaced with sock_init() from sockets.h
    if (sock_init() != 0) {
        if (logFile.is_open()) logFile << "[ERROR] socket initialization failed.\n" << std::flush;
        system("pause"); return 1;
    }

    socket_t server = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(9002);
    addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(server, (sockaddr*)&addr, sizeof(addr)) == SOCKET_ERROR || listen(server, 1) == SOCKET_ERROR) {
        if (logFile.is_open()) logFile << "[ERROR] Port 9002 bind/listen failed.\n" << std::flush;
        system("pause"); return 1;
    }

    if (logFile.is_open()) logFile << "[NETWORK] Operational! Waiting for OMORI process...\n" << std::flush;
    socket_t client = accept(server, NULL, NULL);
    if (client == INVALID_SOCKET) {
        if (logFile.is_open()) logFile << "[ERROR] Connection handshake failed.\n" << std::flush;
        system("pause"); return 1;
    }
    if (logFile.is_open()) logFile << "[NETWORK] Connected! Tracking execution sequences...\n\n" << std::flush;

    char buffer[128];
    while (true) {
        int len = recv(client, buffer, sizeof(buffer) - 1, 0);
        if (len <= 0) {
            if (logFile.is_open()) logFile << "\n[NETWORK] Game disconnected.\n" << std::flush;
            break;
        }
        buffer[len] = 0;

        float intensity = 0.5f;
        int time = 120;
        int fade = 0;

        // sscanf_s() replaced with sscanf() for the sake of cross-platform interoperability
        sscanf(buffer, "%f %d %d", &intensity, &time, &fade);

        if (intensity < 0.0f) intensity = 0.0f;
        if (intensity > 1.0f) intensity = 1.0f;

        if (logFile.is_open()) {
            logFile << "[SIGNAL] Intensity: " << intensity 
                    << " | Duration: " << time << "ms" 
                    << " | Fade: " << (fade ? "YES" : "NO") << "\n" << std::flush;
        }

        if (intensity == 0.0f) {
            abortRumble = true;
            Sleep(15); 
        }

        std::thread(ExecuteRumble, intensity, time, fade).detach();
    }

    closeSocket(client); closeSocket(server); sock_cleanup();
    if (logFile.is_open()) logFile.std::ofstream::close();
    
    return 0;
}
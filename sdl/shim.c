// File:    shim.c
// Purpose: C ABI bridge between skink-game's sdl package and SDL2.
//          Single-window model: skinkgm_open creates one window +
//          renderer; drawing is immediate-mode fillrects; events are
//          polled as (type, code) pairs. All state lives here so the
//          Skink side only needs extern fns.
//
//          Build: handled by skink.toml's [link] section — needs
//          system SDL2 (libsdl2-dev / SDL2-devel / brew sdl2).
#include <SDL2/SDL.h>
#include <stdlib.h>
#include <string.h>

static SDL_Window*   g_win = NULL;
static SDL_Renderer* g_ren = NULL;

// skinkgm_open creates a window + accelerated renderer.
// Returns 0 on success.
int skinkgm_open(const char* title, int w, int h) {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) != 0)
        return -1;
    g_win = SDL_CreateWindow(title, SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED, w, h, SDL_WINDOW_SHOWN);
    if (!g_win) { SDL_Quit(); return -2; }
    g_ren = SDL_CreateRenderer(g_win, -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!g_ren) { SDL_DestroyWindow(g_win); SDL_Quit(); return -3; }
    return 0;
}

// skinkgm_close tears down the window.
void skinkgm_close(void) {
    if (g_ren) SDL_DestroyRenderer(g_ren);
    if (g_win) SDL_DestroyWindow(g_win);
    g_ren = NULL; g_win = NULL;
    SDL_Quit();
}

// skinkgm_poll pulls one event: returns the key scancode for keydown,
// -1 for none, -2 for quit. Call in a loop until -1.
int skinkgm_poll(void) {
    SDL_Event e;
    if (!SDL_PollEvent(&e)) return -1;
    if (e.type == SDL_QUIT) return -2;
    if (e.type == SDL_KEYDOWN) return (int)e.key.keysym.scancode;
    return -3; /* other event */
}

// skinkgm_keyname returns the scancode's name (for debugging/menus).
int skinkgm_keydown_pending(void) {
    return SDL_HasEvents(SDL_KEYDOWN, SDL_KEYDOWN) ? 1 : 0;
}

// skinkgm_clear clears to a color; skinkgm_rect fills a rect;
// skinkgm_present flips.
void skinkgm_clear(int r, int g, int b) {
    if (!g_ren) return;
    SDL_SetRenderDrawColor(g_ren, (Uint8)r, (Uint8)g, (Uint8)b, 255);
    SDL_RenderClear(g_ren);
}

void skinkgm_rect(int x, int y, int w, int h, int r, int g, int b) {
    if (!g_ren) return;
    SDL_Rect rc = { x, y, w, h };
    SDL_SetRenderDrawColor(g_ren, (Uint8)r, (Uint8)g, (Uint8)b, 255);
    SDL_RenderFillRect(g_ren, &rc);
}

void skinkgm_present(void) {
    if (g_ren) SDL_RenderPresent(g_ren);
}

void skinkgm_delay(int ms) {
    SDL_Delay((Uint32)ms);
}

// scancode constants surfaced to Skink (arrows + WASD + space/esc).
int skinkgm_scancode_up(void)    { return SDL_SCANCODE_UP; }
int skinkgm_scancode_down(void)  { return SDL_SCANCODE_DOWN; }
int skinkgm_scancode_left(void)  { return SDL_SCANCODE_LEFT; }
int skinkgm_scancode_right(void) { return SDL_SCANCODE_RIGHT; }
int skinkgm_scancode_space(void) { return SDL_SCANCODE_SPACE; }
int skinkgm_scancode_esc(void)   { return SDL_SCANCODE_ESCAPE; }
int skinkgm_scancode_w(void)     { return SDL_SCANCODE_W; }
int skinkgm_scancode_a(void)     { return SDL_SCANCODE_A; }
int skinkgm_scancode_s(void)     { return SDL_SCANCODE_S; }
int skinkgm_scancode_d(void)     { return SDL_SCANCODE_D; }

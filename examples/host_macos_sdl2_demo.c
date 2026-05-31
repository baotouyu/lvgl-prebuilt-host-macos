#include "lvgl.h"
#include "src/drivers/sdl/lv_sdl_keyboard.h"
#include "src/drivers/sdl/lv_sdl_mouse.h"
#include "src/drivers/sdl/lv_sdl_window.h"
#include <SDL2/SDL.h>

int main(void)
{
    lv_init();

    lv_display_t * display = lv_sdl_window_create(480, 320);
    if(display == NULL) {
        lv_deinit();
        return 1;
    }

    lv_sdl_window_set_title(display, "LVGL host macOS SDL2");
    lv_sdl_mouse_create();
    lv_sdl_keyboard_create();

    lv_obj_t * label = lv_label_create(lv_screen_active());
    lv_label_set_text(label, "LVGL host macOS SDL2");
    lv_obj_center(label);

    for(int frame = 0; frame < 30; frame++) {
        lv_timer_handler();
        SDL_Delay(16);
    }

    lv_deinit();
    return 0;
}

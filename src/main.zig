const std = @import("std");
const math = @import("std").math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const time = @cImport(@cInclude("time.h"));
const cstd = @cImport(@cInclude("stdlib.h"));

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

const TARGET_WIDTH = 100;
const TARGET_HEIGHT = 20;
const TARGET_CAP = 18;

const Target = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    color: Color,
    broken: bool,
};

var targets_pool: [TARGET_CAP]Target = undefined;
var targets_pool_count: usize = 0;

const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const FPS: i32 = 60;
const DELTA_TIME_SEC: f32 = 1.0 / @as(f32, @floatFromInt(FPS));

const BAR_LEN = 100;
const BAR_THICCNESS = 10;
const BAR_Y = WINDOW_HEIGHT - BAR_THICCNESS - 108;
const BAR_SPEED: f32 = 300;

var bar_dx: f32 = 0;

var bar_x: f32 = (WINDOW_WIDTH - BAR_LEN) / 2;

const proj_size = 18;
var proj_x: f32 = (WINDOW_WIDTH - proj_size) / 2;
var proj_y: f32 = BAR_Y - 18;

const PROJ_SPEED: f32 = 250;

var sign_x: f32 = 1;
var sign_y: f32 = 1;

const background = Color{ .r = 18, .g = 18, .b = 18, .a = 255 };
const proj_color = Color{ .r = 208, .g = 208, .b = 208, .a = 255 };

fn proj_rect(x: f32, y: f32) c.SDL_Rect {
    return c.SDL_Rect{
        .x = @intFromFloat(x),
        .y = @intFromFloat(y),
        .w = proj_size,
        .h = proj_size,
    };
}

fn bar_rect() c.SDL_Rect {
    return c.SDL_Rect{
        .x = @intFromFloat(bar_x),
        .y = BAR_Y,
        .w = BAR_LEN,
        .h = BAR_THICCNESS,
    };
}

fn generate_target(x: i32, y: i32) void {
    const target = Target{
        .x = x,
        .y = y,
        .width = TARGET_WIDTH,
        .height = TARGET_HEIGHT,
        .color = Color{ .r = @as(u8, @intCast(@rem(cstd.rand(), 256))), .g = @as(u8, @intCast(@rem(cstd.rand(), 256))), .b = @as(u8, @intCast(@rem(cstd.rand(), 256))), .a = 255 },
        .broken = false,
    };
    if (targets_pool_count < TARGET_CAP) {
        targets_pool[targets_pool_count] = target;
        targets_pool_count += 1;
    }
}

const TARGET_PADDING = 10;
const TARGET_BASE = (WINDOW_WIDTH - (TARGET_WIDTH) * number_of_bars) / 2 - 2 * TARGET_PADDING;
const number_of_bars = 6;

fn initialize_targets() void {
    for (1..12) |_| {
        const row = @as(i32, @intCast(@divTrunc(targets_pool_count, number_of_bars)));
        const col = @as(i32, @intCast(@rem(targets_pool_count, number_of_bars)));
        generate_target(TARGET_BASE + (TARGET_WIDTH + TARGET_PADDING) * col + TARGET_PADDING, (TARGET_HEIGHT + TARGET_PADDING) * row + TARGET_PADDING);
    }
}

fn render(renderer: *c.SDL_Renderer) void {
    _ = c.SDL_SetRenderDrawColor(renderer, background.r, background.g, background.b, background.a);
    _ = c.SDL_RenderClear(renderer);
    _ = c.SDL_SetRenderDrawColor(renderer, proj_color.r, proj_color.g, proj_color.b, proj_color.a);
    _ = c.SDL_RenderFillRect(renderer, &proj_rect(proj_x, proj_y));
    _ = c.SDL_RenderFillRect(renderer, &bar_rect());
    for (targets_pool) |target| {
        if (!target.broken) {
            _ = c.SDL_SetRenderDrawColor(renderer, target.color.r, target.color.g, target.color.b, target.color.a);
            _ = c.SDL_RenderFillRect(renderer, &c.SDL_Rect{
                .x = target.x,
                .y = target.y,
                .w = target.width,
                .h = target.height,
            });
        }
    }
    c.SDL_RenderPresent(renderer);
}

fn update(dt: f32) void {
    const keyboard = c.SDL_GetKeyboardState(null);
    bar_dx = 0;
    if (keyboard[c.SDL_SCANCODE_A] != 0) {
        bar_dx -= 1;
    }
    if (keyboard[c.SDL_SCANCODE_D] != 0) {
        bar_dx += 1;
    }
    bar_x = math.clamp(bar_x + bar_dx * BAR_SPEED * dt, 0, WINDOW_WIDTH - BAR_LEN);

    proj_x += sign_x * PROJ_SPEED * dt;
    proj_y += sign_y * PROJ_SPEED * dt;

    var nx: f32 = proj_x + sign_x * PROJ_SPEED * dt;
    var ny: f32 = proj_y + sign_y * PROJ_SPEED * dt;
    if (nx > WINDOW_WIDTH - proj_size or nx < 0 or c.SDL_HasIntersection(&proj_rect(proj_x, proj_y), &bar_rect()) != 0) sign_x = -sign_x;
    if (ny > WINDOW_HEIGHT - proj_size or ny < 0) sign_y = -sign_y;
    if (c.SDL_HasIntersection(&proj_rect(proj_x, proj_y), &bar_rect()) != 0) {
        if (bar_dx == 0) {
            sign_y = -sign_y;
        } else {
            sign_y = -sign_y;
            sign_x = bar_dx;
        }
    }
    for (&targets_pool) |*target| {
        if (!target.broken and c.SDL_HasIntersection(&proj_rect(proj_x, proj_y), &c.SDL_Rect{
            .x = target.x,
            .y = target.y,
            .w = target.width,
            .h = target.height,
        }) != 0) {
            target.broken = true;
            sign_y = -sign_y;
        }
    }
    ny = proj_y + sign_y * PROJ_SPEED * dt;
    nx = proj_x + sign_x * PROJ_SPEED * dt;

    proj_x = nx;
    proj_y = ny;
}

pub fn main() anyerror!void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Breakout", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, c.SDL_WINDOW_RESIZABLE) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    initialize_targets();

    var quit: bool = false;
    var pause: bool = true;

    initialize_targets();
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                c.SDL_KEYDOWN => {
                    if (event.key.keysym.sym == 'q' or event.key.keysym.sym == c.SDLK_ESCAPE) {
                        quit = true;
                    }
                    if (event.key.keysym.sym == c.SDLK_SPACE) {
                        pause = !pause;
                    }
                },
                else => {},
            }
        }

        if (!pause) {
            update(DELTA_TIME_SEC);
        }

        render(renderer);

        c.SDL_Delay(1000 / FPS);
    }
}

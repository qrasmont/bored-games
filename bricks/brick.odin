package bricks

import rl "vendor:raylib"
import la "core:math/linalg"
import "core:fmt"

WINDOW_SIZE :: 640
SCREEN_SIZE :: 320
TARGET_FPS :: 200
WINDOW_NAME :: "bricks"

score: int

State :: enum {
    Started,
    Running,
}
state: State

paddle_x: f32
PADDLE__Y :: 260
PADDLE_WIDTH :: 40
PADDLE_HEIGHT :: 8
PADDLE_SPEED :: 300

ball_pos: rl.Vector2
ball_dir: rl.Vector2
BALL_SPEED :: 300
BALL_RADIUS :: 5
BALL_START_Y :: 160

BRICK_WIDTH :: 28
BRICK_HEIGHT :: 10
NUM_BRICKS_X :: 10
NUM_BRICKS_Y :: 8
bricks: [NUM_BRICKS_X][NUM_BRICKS_Y]bool

BG_COLOR :: rl.Color{255, 248, 222, 255}
PADDLE_COLOR :: rl.Color{50, 89, 158, 255}
BALL_COLOR :: rl.Color{227, 86, 86, 255}
TEXT_COLOR :: rl.Color{0, 0, 0, 255}

BrickColor :: enum {
    Yellow,
    Orange,
    Purple,
    Red,
}

row_colors := [NUM_BRICKS_Y]BrickColor {
    .Red,
    .Red,
    .Purple,
    .Purple,
    .Orange,
    .Orange,
    .Yellow,
    .Yellow,
}

brick_color_values := [BrickColor]rl.Color {
    .Yellow = {255, 228, 24, 255},
    .Orange = {255, 149, 25, 255},
    .Purple = {232, 21, 119, 255},
    .Red = {255, 77, 41, 255},
}

brick_color_score := [BrickColor]int {
    .Yellow = 1,
    .Orange = 5,
    .Purple = 10,
    .Red = 20,
}

reflect :: proc (dir, normal: rl.Vector2) -> rl.Vector2{
    return la.normalize(la.reflect(dir, la.normalize(normal)))
}

calc_brick :: proc (x, y: int) -> rl.Rectangle{

    return {
        f32(20 + x * BRICK_WIDTH),
        f32(40 + y * BRICK_HEIGHT),
        BRICK_WIDTH,
        BRICK_HEIGHT
    }
}

brick_exist :: proc(x, y: int) -> bool {
    if x < 0 || y < 0 || x >= NUM_BRICKS_X || y >= NUM_BRICKS_Y {
        return false
    }

    return bricks[x][y]
}

update_paddle :: proc(dt: f32) {
    paddle_velocity: f32

    if rl.IsKeyDown(.LEFT) {
        paddle_velocity -= PADDLE_SPEED
    }

    if rl.IsKeyDown(.RIGHT) {
        paddle_velocity += PADDLE_SPEED
    }

    paddle_x += paddle_velocity * dt
    paddle_x = clamp(paddle_x, 0, SCREEN_SIZE - PADDLE_WIDTH)
}

update_ball :: proc(dt: f32) {
    ball_velocity := BALL_SPEED * ball_dir
    ball_pos += ball_velocity * dt

    if ball_pos.x + BALL_RADIUS > SCREEN_SIZE {
        ball_pos.x = SCREEN_SIZE - BALL_RADIUS
        ball_dir = reflect(ball_dir, {-1, 0})
    }

    if ball_pos.x - BALL_RADIUS < 0 {
        ball_pos.x = BALL_RADIUS
        ball_dir = reflect(ball_dir, {1, 0})
    }

    if ball_pos.y - BALL_RADIUS < 0 {
        ball_pos.y = BALL_RADIUS
        ball_dir = reflect(ball_dir, {0, 1})
    }

    if ball_pos.y > SCREEN_SIZE + BALL_RADIUS * 10 {
        restart()
    }
}

paddle: rl.Rectangle

update :: proc() {
    dt: f32

    switch state {
    case .Started:
        if (rl.IsKeyPressed(.SPACE)) {
            paddle_middle := rl.Vector2 {paddle_x + PADDLE_WIDTH/2, PADDLE__Y}
            ball_2_paddle := paddle_middle - ball_pos
            ball_dir = la.normalize0(ball_2_paddle)

            state = .Running
        }
    case .Running:
        dt = rl.GetFrameTime()
    }

    prev_ball_pos := ball_pos

    update_paddle(dt)
    update_ball(dt)

    paddle = rl.Rectangle { paddle_x, PADDLE__Y, PADDLE_WIDTH, PADDLE_HEIGHT }

    if rl.CheckCollisionCircleRec(ball_pos, BALL_RADIUS, paddle) {
        collision_norm: rl.Vector2

        if prev_ball_pos.y < paddle.y + paddle.height {
            collision_norm += {0, -1}
            ball_pos.y = paddle.y - BALL_RADIUS
        }

        if prev_ball_pos.y > paddle.y + paddle.height {
            collision_norm += {0, 1}
            ball_pos.y = paddle.y + paddle.height + BALL_RADIUS
        }

        if prev_ball_pos.x < paddle.x {
            collision_norm += {-1, 0}
        }

        if prev_ball_pos.x > paddle.x + paddle.width {
            collision_norm += {1, 0}
        }

        if collision_norm != 0 {
            ball_dir = reflect(ball_dir, collision_norm)
        }
    }

    brick_x_loop: for x in 0..<NUM_BRICKS_X {
        for y in 0..<NUM_BRICKS_Y {
            if !bricks[x][y] {
                continue
            }

            brick := calc_brick(x,y)

            if rl.CheckCollisionCircleRec(ball_pos, BALL_RADIUS, brick) {
                collision_norm: rl.Vector2

                if prev_ball_pos.y < brick.y {
                    collision_norm += {0, -1}
                }

                if prev_ball_pos.y > brick.y + brick.height {
                    collision_norm += {0, 1}
                }

                if prev_ball_pos.x < brick.x {
                    collision_norm += {-1, 0}
                }

                if prev_ball_pos.x > brick.x + brick.width {
                    collision_norm += {1, 0}
                }

                if brick_exist(x + int(collision_norm.x), y) {
                    collision_norm.x = 0
                }

                if brick_exist(x, y + int(collision_norm.y)) {
                    collision_norm.y = 0
                }

                if collision_norm != 0 {
                    ball_dir = reflect(ball_dir, collision_norm)
                }

                bricks[x][y] = false
                score += brick_color_score[row_colors[y]]
                break brick_x_loop
            }
        }
    }
}

draw :: proc() {
    rl.DrawRectangleRec(paddle, PADDLE_COLOR)
    rl.DrawCircleV(ball_pos, BALL_RADIUS, BALL_COLOR)

    for x in 0..<NUM_BRICKS_X {
        for y in 0..<NUM_BRICKS_Y {
            if !bricks[x][y] {
                continue
            }

            brick := calc_brick(x, y)

            top_left := rl.Vector2 {
                brick.x, brick.y
            }

            top_right := rl.Vector2 {
                brick.x + BRICK_WIDTH, brick.y
            }

            bottom_left := rl.Vector2 {
                brick.x, brick.y + BRICK_HEIGHT
            }

            bottom_right := rl.Vector2 {
                brick.x + BRICK_WIDTH, brick.y + BRICK_HEIGHT
            }

            rl.DrawRectangleRec(brick, brick_color_values[row_colors[y]])

            rl.DrawLineEx(top_left, top_right, 1, {242, 242, 242, 100})
            rl.DrawLineEx(top_left, bottom_left, 1, {242, 242, 242, 100})
            rl.DrawLineEx(top_right, bottom_right, 1, {74, 74, 74, 100})
            rl.DrawLineEx(bottom_left, bottom_right, 1, {74, 74, 74, 100})
        }
    }

    score_str := fmt.ctprint(score)
    score_str_width := rl.MeasureText(score_str, 20)
    rl.DrawText(score_str, i32(SCREEN_SIZE/2 - score_str_width/2), 5, 20, TEXT_COLOR)
}

restart :: proc() {
    paddle_x = SCREEN_SIZE/2 - PADDLE_WIDTH/2
    ball_pos = { SCREEN_SIZE/3, BALL_START_Y }
    state = .Started
    score = 0

    for x in 0..<NUM_BRICKS_X {
        for y in 0..<NUM_BRICKS_Y {
            bricks[x][y] = true
        }
    }
}

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, WINDOW_NAME)
    rl.SetTargetFPS(TARGET_FPS)

    restart()

    for !rl.WindowShouldClose() {
        update()

        rl.BeginDrawing()
        rl.ClearBackground(BG_COLOR)

        camera := rl.Camera2D {
            zoom = f32(rl.GetScreenHeight() / SCREEN_SIZE)
        }

        rl.BeginMode2D(camera)

        draw()

        rl.EndMode2D()
        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    rl.CloseWindow()
}

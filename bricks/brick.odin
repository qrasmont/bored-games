package bricks

import rl "vendor:raylib"
import la "core:math/linalg"
import "core:fmt"
import "core:math"

WINDOW_SIZE :: 640
SCREEN_SIZE :: 320
TARGET_FPS :: 200
WINDOW_NAME :: "bricks"

PADDLE__Y :: 260
PADDLE_WIDTH :: 40
PADDLE_HEIGHT :: 8
PADDLE_SPEED :: 300

BALL_SPEED :: 300
BALL_RADIUS :: 5
BALL_START_Y :: 160

BRICK_WIDTH :: 28
BRICK_HEIGHT :: 10
NUM_BRICKS_X :: 10
NUM_BRICKS_Y :: 8

BG_COLOR :: rl.Color{255, 248, 222, 255}
PADDLE_COLOR :: rl.Color{50, 89, 158, 255}
BALL_COLOR :: rl.Color{194, 84, 82, 255}
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
    .Yellow = {244, 196, 123, 255},
    .Orange = {234, 154, 39, 255},
    .Purple = {128, 62, 97, 255},
    .Red = {242, 120, 85, 255},
}

brick_color_score := [BrickColor]int {
    .Yellow = 1,
    .Orange = 5,
    .Purple = 10,
    .Red = 20,
}

Modifier :: enum {
    BigBar,
    TinyBar,
    SpeedyBall,
    None,
}

Status :: enum {
    Started,
    Running,
    Won,
    Over,
}

BallState :: struct {
    pos: rl.Vector2,
    dir: rl.Vector2,
    render_pos: rl.Vector2,
    speed: f32,
}

PaddleState :: struct {
    x: f32,
    render_x: f32,
    width: f32,
}

State :: struct {
    accumulated_time: f32,
    score: int,
    status: Status,
    bricks: [NUM_BRICKS_X][NUM_BRICKS_Y]int,
    modifier: Modifier,
    ball: BallState,
    paddle: PaddleState,
}

over_sound: rl.Sound
start_sound: rl.Sound
mute: bool = true

bg_texture: rl.Texture
paddle_texture: rl.Texture

reflect :: proc (dir, normal: rl.Vector2) -> rl.Vector2 {
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

brick_exist :: proc(x, y: int, brick: int) -> bool {
    if x < 0 || y < 0 || x >= NUM_BRICKS_X || y >= NUM_BRICKS_Y {
        return false
    }

    return brick > 0
}

update_paddle :: proc(dt: f32, state: ^State) {
    paddle_velocity: f32

    if rl.IsKeyDown(.LEFT) {
        paddle_velocity -= PADDLE_SPEED
    }

    if rl.IsKeyDown(.RIGHT) {
        paddle_velocity += PADDLE_SPEED
    }

    state.paddle.x += paddle_velocity * dt
    state.paddle.x = clamp(state.paddle.x, 0, SCREEN_SIZE - state.paddle.width)
}

update_ball :: proc(dt: f32, ball: ^BallState, status: ^Status) {
    ball_velocity := ball.speed * ball.dir
    ball.pos += ball_velocity * dt

    if ball.pos.x + BALL_RADIUS > SCREEN_SIZE {
        ball.pos.x = SCREEN_SIZE - BALL_RADIUS
        ball.dir = reflect(ball.dir, {-1, 0})
    }

    if ball.pos.x - BALL_RADIUS < 0 {
        ball.pos.x = BALL_RADIUS
        ball.dir = reflect(ball.dir, {1, 0})
    }

    if ball.pos.y - BALL_RADIUS < 0 {
        ball.pos.y = BALL_RADIUS
        ball.dir = reflect(ball.dir, {0, 1})
    }

    if ball.pos.y > SCREEN_SIZE + BALL_RADIUS * 10 {
        if !mute {
            rl.PlaySound(over_sound)
        }
        status^ = .Over
    }
}

update :: proc(state: ^State) {
    DT :: 1.0 / 60.0

    prev_ball_pos := state.ball.pos
    prev_paddle_x := state.paddle.x

    switch state.status {
    case .Started:
        if (rl.IsKeyPressed(.SPACE)) {
            paddle_middle := rl.Vector2 {state.paddle.x + state.paddle.width/2, PADDLE__Y}
            ball_2_paddle := paddle_middle - state.ball.pos
            state.ball.dir = la.normalize0(ball_2_paddle)

            if !mute {
                rl.PlaySound(start_sound)
            }
            state.status = .Running
        }
    case .Won:
        fallthrough
    case .Over:
        if (rl.IsKeyPressed(.SPACE)) {
            restart(state);
        }
    case .Running:
        state.accumulated_time += rl.GetFrameTime()

        for state.accumulated_time >= DT {
            update_paddle(DT, state)
            update_ball(DT, &state.ball, &state.status)

            paddle := rl.Rectangle { state.paddle.x, PADDLE__Y, state.paddle.width, PADDLE_HEIGHT }

            if rl.CheckCollisionCircleRec(state.ball.pos, BALL_RADIUS, paddle) {
                collision_norm: rl.Vector2

                if prev_ball_pos.y < paddle.y + paddle.height {
                    collision_norm += {0, -1}
                    state.ball.pos.y = paddle.y - BALL_RADIUS
                }

                if prev_ball_pos.y > paddle.y + paddle.height {
                    collision_norm += {0, 1}
                    state.ball.pos.y = paddle.y + paddle.height + BALL_RADIUS
                }

                if prev_ball_pos.x < paddle.x {
                    collision_norm += {-1, 0}
                }

                if prev_ball_pos.x > paddle.x + paddle.width {
                    collision_norm += {1, 0}
                }

                if collision_norm != 0 {
                    state.ball.dir = reflect(state.ball.dir, collision_norm)
                }
            }

            broken_bricks := 0
            brick_x_loop: for x in 0..<NUM_BRICKS_X {
                for y in 0..<NUM_BRICKS_Y {
                    if state.bricks[x][y] == 0 {
                        broken_bricks += 1
                        continue
                    }

                    brick := calc_brick(x,y)

                    if rl.CheckCollisionCircleRec(state.ball.pos, BALL_RADIUS, brick) {
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

                        if brick_exist(x + int(collision_norm.x), y, state.bricks[x][y]) {
                            collision_norm.x = 0
                        }

                        if brick_exist(x, y + int(collision_norm.y), state.bricks[x][y]) {
                            collision_norm.y = 0
                        }

                        if collision_norm != 0 {
                            state.ball.dir = reflect(state.ball.dir, collision_norm)
                        }

                        state.bricks[x][y] -= 1
                        state.score += brick_color_score[row_colors[y]]
                        break brick_x_loop
                    }
                }
            }

            if broken_bricks >= NUM_BRICKS_X * NUM_BRICKS_Y {
                state.status = .Won
            }

            state.accumulated_time -= DT
        }

        blend := state.accumulated_time / DT
        state.ball.render_pos = math.lerp(prev_ball_pos, state.ball.pos, blend)
        state.paddle.render_x = math.lerp(prev_paddle_x, state.paddle.x, blend)
    }

    if (rl.IsKeyPressed(.M)) {
        mute = !mute
    }

}

draw :: proc(state: ^State) {
    rl.DrawTexture(bg_texture, 0, 0, rl.WHITE)

    paddle_rec := rl.Rectangle { state.paddle.render_x, PADDLE__Y, state.paddle.width, PADDLE_HEIGHT }
    rl.DrawTextureRec(paddle_texture, paddle_rec, {state.paddle.render_x, PADDLE__Y}, rl.WHITE)
    rl.DrawCircleV(state.ball.render_pos, BALL_RADIUS, BALL_COLOR)

    for x in 0..<NUM_BRICKS_X {
        for y in 0..<NUM_BRICKS_Y {
            if state.bricks[x][y] == 0 {
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

    if mute {
        mute_str := fmt.ctprint("muted")
        rl.DrawText(mute_str, 5, 5, 10, TEXT_COLOR)
    }

    switch state.status {
    case .Started:
        title_str := fmt.ctprint("BRICKS")
        title_str_width := rl.MeasureText(title_str, 50)
        press_str := fmt.ctprint("Press [space]")
        press_str_width := rl.MeasureText(fmt.ctprint(press_str), 20)
        rl.DrawText(title_str, i32(SCREEN_SIZE/2 - title_str_width/2), SCREEN_SIZE/2 - 50, 50, TEXT_COLOR)
        rl.DrawText(press_str, i32(SCREEN_SIZE/2 - press_str_width/2), SCREEN_SIZE/2, 20, TEXT_COLOR)

    case .Won:
        fallthrough
    case .Over:
        rec_color: rl.Color = state.status == .Won ? {0, 255, 0, 100} : {255, 0, 0, 100}
        rl.DrawRectangle(0, 0, SCREEN_SIZE, SCREEN_SIZE, rec_color)

        over_str := state.status == .Won ? fmt.ctprint("You win!") : fmt.ctprint("Game Over")
        over_str_width := rl.MeasureText(over_str, 50)
        score_str := fmt.ctprint("Score ", state.score)
        score_str_width := rl.MeasureText(score_str, 20)
        press_str := fmt.ctprint("Press [space]")
        press_str_width := rl.MeasureText(fmt.ctprint(press_str), 10)
        rl.DrawText(over_str, i32(SCREEN_SIZE/2 - over_str_width/2), SCREEN_SIZE/2 - 50, 50, TEXT_COLOR)
        rl.DrawText(score_str, i32(SCREEN_SIZE/2 - score_str_width/2), SCREEN_SIZE/2, 20, TEXT_COLOR)
        rl.DrawText(press_str, i32(SCREEN_SIZE/2 - press_str_width/2), SCREEN_SIZE/2 + 20, 10, TEXT_COLOR)

    case .Running:
        score_str := fmt.ctprint(state.score)
        score_str_width := rl.MeasureText(score_str, 20)
        rl.DrawText(score_str, i32(SCREEN_SIZE/2 - score_str_width/2), 5, 20, TEXT_COLOR)
    }
}

restart :: proc(state: ^State) {
    state.accumulated_time = 0
    state.ball.speed = BALL_SPEED
    state.paddle.width = PADDLE_WIDTH
    state.paddle.x = SCREEN_SIZE/2 - state.paddle.width/2
    state.ball.pos = { SCREEN_SIZE/3, BALL_START_Y }
    state.status = .Started
    state.score = 0
    state.ball.render_pos = state.ball.pos
    state.paddle.render_x = state.paddle.x
    state.modifier = .None

    for x in 0..<NUM_BRICKS_X {
        for y in 0..<NUM_BRICKS_Y {
            state.bricks[x][y] = 1
        }
    }
}

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, WINDOW_NAME)
    rl.InitAudioDevice()
    rl.SetTargetFPS(TARGET_FPS)

    state: State

    bg_texture = rl.LoadTexture("bg.png")
    paddle_texture = rl.LoadTexture("paddle.png")

    start_sound = rl.LoadSound("start.wav")
    over_sound = rl.LoadSound("over.wav")

    restart(&state)

    for !rl.WindowShouldClose() {
        update(&state)

        rl.BeginDrawing()

        camera := rl.Camera2D {
            zoom = f32(rl.GetScreenHeight() / SCREEN_SIZE)
        }

        rl.BeginMode2D(camera)

        draw(&state)

        rl.EndMode2D()
        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    rl.CloseAudioDevice()
    rl.CloseWindow()
}

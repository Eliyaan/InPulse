import net
import gg
import os
import time

const img = false
const bg_color = gg.Color{222, 222, 222, 255}
const ip = '0.0.0.0:40001' // 93.23.129.134


union Fbytes {
  f f32
  b [4]u8
}

struct App {
mut:
	gg     &gg.Context = unsafe { nil }
	buf    []u8        = []u8{len: 100}
	send_x f32
	send_y f32
	player_nb int
	c      &net.TcpConn = unsafe { nil }
	win_height int
	win_width int
	white_ball gg.Image
	black_ball gg.Image
	field gg.Image
	game bool
	first_frame int = 5
}

fn main() {
	mut app := &App{}
	defer {
		println('Connection closed')
		app.c.close() or { panic(err) }
	}
	app.gg = gg.new_context(
		create_window: true
		window_title: '- Application -'
		user_data: app
		bg_color: bg_color
		frame_fn: on_frame
		event_fn: on_event
		sample_count: 2
	)
	if img {
		app.white_ball = app.gg.create_image(os.resource_abs_path('white.png'))!
		app.black_ball = app.gg.create_image(os.resource_abs_path('black.png'))!
		app.field = app.gg.create_image(os.resource_abs_path('field.png'))!
	}
	
	app.gg.run()
}

fn on_frame(mut app App) {
	// Draw
	size := gg.window_size()
	app.win_height = size.height
	app.win_width = size.width
	if app.first_frame > 0 {
		app.first_frame -= 1
		app.gg.begin()
		app.gg.draw_circle_filled(app.win_width/2, app.win_height/2, 300, couleur(5))
		coords := [-128, 128]
		for i in 0 .. coords.len { 
			app.gg.draw_circle_filled(coords[i] + app.win_width/2, app.win_height/2, 20, couleur(i))
		}
		if img {
			app.gg.draw_image(- 128 - 20, app.win_height/2 - 20, 40, 40, app.white_ball)
			app.gg.draw_image(128 + app.win_width/2 - 20, app.win_height/2 - 20, 40, 40, app.black_ball)
		}
		app.gg.end()
	} else {
		app.gg.begin()
				
		app.gg.draw_circle_filled(app.win_width/2, app.win_height/2, 300, couleur(5))
		if app.game {
			read := app.c.read(mut app.buf) or {
				println('Timed out')
				app.game = false
				app.first_frame = 5
				app.c.close() or {panic(err)}
				return
			}
			if app.buf[0] == 255 {
				println('Other player disconnected')
				app.game = false
				app.first_frame = 5
			} else if app.buf[0] == 254 {
				println('You win')
				app.game = false
				app.first_frame = 5
			} else if app.buf[0] == 253 {
				println('You lost')
				app.game = false
				app.first_frame = 5
			} else {
				app.player_nb = app.buf[0]
				
				if img {
					app.gg.draw_image(app.win_width/2 - 370, app.win_height/2 - 370, 740, 740, app.field)
				}
				
				mut coords := []f32{}
				for i in 0 .. (read - 1) / 4 { // pour chaque joueur (code + coos de chaque joueur)
					mut fourbytes := [4]u8{}
					for h in 0..4 {
						fourbytes[h] = app.buf[i*4 + 1 + h]
					}
					co := Fbytes{b:fourbytes}
					coords << unsafe{co.f}
				}
				for i in 0 .. coords.len/2 { 
					app.gg.draw_circle_filled(coords[i * 2] + app.win_width/2, coords[i * 2 + 1] + app.win_height/2, 20, couleur(i))
				}
				if img {
					app.gg.draw_image(coords[0] + app.win_width/2 - 20, coords[1] + app.win_height/2 - 20, 40, 40, app.white_ball)
					app.gg.draw_image(coords[2] + app.win_width/2 - 20, coords[3] + app.win_height/2 - 20, 40, 40, app.black_ball)
				}

				mut packet := []u8{}
				co_x := Fbytes{f:app.send_x - app.win_width/2} //remove half screen
				for h in 0..4 {
					packet << unsafe{co_x.b[h]}
				}
				co_y := Fbytes{f:app.send_y - app.win_height/2} //remove half screen
				for h in 0..4 {
					packet << unsafe{co_y.b[h]}
				}

				app.c.write(packet) or {
					println('connection closed write')
					app.game = false
					app.first_frame = 5
					app.c.close() or {panic(err)}
				}
			}
		}
		app.gg.end()
		if !app.game {
			println("Attempt connection")
			app.c = net.dial_tcp(ip) or { panic(err) }
			app.c.set_read_timeout(2 * time.second)
			app.game = true
			// lancement du programme/de la fenêtre
			app.c.read(mut app.buf) or {
				println('Timed out')
				app.game = false
				app.first_frame = 5
				app.c.close() or {panic(err)}
				return
			}
			if app.buf[0] == 254 {
				println('In queue')
			} else {
				panic("Not the right packet")
			}
			println("Waiting for validation")
			app.c.read(mut app.buf) or {
				println('Timed out')
				app.game = false
				app.first_frame = 5
				app.c.close() or {panic(err)}
				return
			}
			if app.buf[0] == 255 {
				println("Game launching!")
			} else {
				panic("Not the right packet")
			}
			app.c.write([u8(101)]) or {
				println('Connection closed write')
				app.game = false
				app.first_frame = 5
				app.c.close() or {panic(err)}
				return
			}
		}
	}
}

fn on_event(e &gg.Event, mut app App) {
	app.send_x, app.send_y = e.mouse_x, e.mouse_y
	match e.typ {
		.key_down {
			match e.key_code {
				.escape { app.gg.quit() }
				else {}
			}
		}
		else {}
	}
}

fn couleur(nb int) gg.Color {
	return match nb {
		0 { gg.Color{255, 0, 0, 255} }
		1 { gg.Color{0, 255, 0, 255} }
		2 { gg.Color{0, 0, 255, 255} }
		3 { gg.Color{255, 255, 0, 255} }
		4 { gg.Color{255, 0, 255, 255} }
		5 { gg.Color{255, 255, 255, 255} }
		else { gg.Color{127, 127, 127, 255} }
	}
}


import net
import gg

const bg_color = gg.Color{}

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
	c      &net.TcpConn = net.dial_tcp('0.0.0.0:40001') or { panic(err) } // 93.23.129.134
	win_height int
	win_width int
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

	// lancement du programme/de la fenêtre
	app.c.read(mut app.buf) or {
		println('Timed out')
		app.gg.quit()
		return
	}
	if app.buf[0] == 254 {
		println('In queue')
	} else {
		panic("Not the right packet")
	}
	app.c.read(mut app.buf) or {
		println('Timed out')
		app.gg.quit()
		return
	}
	if app.buf[0] == 255 {
		println("Game launching!")
	} else {
		panic("Not the right packet")
	}
	app.c.write([u8(101)]) or {
		println('Connection closed write')
		return
	}
	app.gg.run()
}

fn on_frame(mut app App) {
	// Draw
	size := gg.window_size()
	app.win_height = size.height
	app.win_width = size.width
	read := app.c.read(mut app.buf) or {
		println('Timed out')
		app.gg.quit()
		return
	}
	if app.buf[0] == 255 {
		println('Other player disconnected')
		app.gg.quit()
	} else if app.buf[0] == 254 {
		println('You win')
		app.gg.quit()
	} else if app.buf[0] == 253 {
		println('You lost')
		app.gg.quit()
	} else {
		app.player_nb = app.buf[0]
		app.gg.begin()
		app.gg.draw_circle_filled(app.win_width/2, app.win_height/2, 300, couleur(5))
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
		app.gg.end()


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
			app.gg.quit()
		}
	}
}

fn on_event(e &gg.Event, mut app App) {
	
	app.send_x, app.send_y = e.mouse_x, e.mouse_y
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


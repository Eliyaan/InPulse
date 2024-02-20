import net
import math
import time

const bounce = 2.0
const p_size = 20

type MayCon = bool | net.TcpConn

union Fbytes {
mut:
  f f32
  b [4]u8
}

struct Player {
mut:
	pcx f32 //pos_currentx
	pcy f32
	pox f32 //pos old x
	poy f32
	ax f32  // acceleration x
	ay f32
}

fn (mut p Player) update_pos(dt f32) {
	vel_x := (p.pcx - p.pox)*0.96
	vel_y := (p.pcy - p.poy)*0.96
	p.pox = p.pcx
	p.poy = p.pcy
	// Verlet Integration
	p.pcx = p.pcx + vel_x + p.ax * dt * dt
	p.pcy = p.pcy + vel_y + p.ay * dt * dt
	// reset acc
	p.ax = 0
	p.ay = 0
}

fn (mut p Player) accelerate(ax f32, ay f32) {
	p.ax += ax
	p.ay += ay
}

fn main() {
	mut server := net.listen_tcp(.ip, ':40001')!
	laddr := server.addr()!
	eprintln('Listen on ${laddr} ...')
	mut cs := []net.TcpConn{}
	mut coords := []f32{}
	for {
		println('_____Waiting for new game___________')
		cs = []net.TcpConn{}
		coords = []f32{}
		for i in 0 .. 2 {
			println('Waiting for player ${i}')
			cs << server.accept()!
			cs[i].write([u8(254)]) or { panic(err) } // in queue
			if i == 0 {
				coords << [f32(-128), 0]
			} else if i == 1 {
				coords << [f32(128), 0]
				mut buf := []u8{len: 10}
				cs[0].write([u8(255)]) or { panic(err) } // validation packet
				println("Waiting for player 0's validation")
				cs[0].read(mut buf) or {
					println(err)
					cs.delete(0)
					println("Player 0 disconnected")
					break
				}
				println("Player 0 validated")
				if buf != [u8(101), 0, 0, 0, 0, 0, 0, 0, 0, 0] {
					cs.delete(0)
					println("Player 0 disconnected")
					break
				}
			} else {
				panic('strange i=${i}')
			}
			println('Player ${i} connected')
		}
		mut buf := []u8{len: 10}
		if cs.len == 2 {
			cs[1].write([u8(255)]) or { panic(err) } // validation packet
			println("Waiting for player 1's validation")
			cs[1].read(mut buf) or { 
				println(err)
				cs.delete(1)
				println("Player 1 disconnected")	
			}
			if cs.len == 2 {
				println("Player 1 validated")
			}
		}
		if cs.len == 2 {
			if buf != [u8(101), 0, 0, 0, 0, 0, 0, 0, 0, 0] {
				cs.delete(1)
				println("Player 1 disconnected")
			}
			if cs.len == 2 {
				spawn game(cs, coords)
			}
		}
	}
}

fn game(connections []net.TcpConn, coordinates []f32) {
	println('Game Created\n ----------------- ')
	mut cs := connections.clone()
	mut coords := coordinates.clone()
	mut p := [Player{pcx:coords[0], pcy:coords[1], pox:coords[0], poy:coords[1]}, Player{pcx:coords[2], pcy:coords[3], pox:coords[2], poy:coords[3]}]

	// game loop

	mut buf := []u8{len: 8}
	mut lost := -1
	time.sleep(1_000_000_000)
	game: for {
		for i, mut c in cs {
			mut packet := [u8(i)]
			// Add the 2 positions to the packet
			
			mut co := Fbytes{f:p[0].pcx}
			for h in 0..4 {
				packet << unsafe{co.b[h]}
			}
			co = Fbytes{f:p[0].pcy}
			for h in 0..4 {
				packet << unsafe{co.b[h]}
			}
			co = Fbytes{f:p[1].pcx}
			for h in 0..4 {
				packet << unsafe{co.b[h]}
			}
			co = Fbytes{f:p[1].pcy}
			for h in 0..4 {
				packet << unsafe{co.b[h]}
			}
			
			c.write(packet) or {
				cs.delete(i)
				break game
			}
			_ := c.read(mut buf) or {
				cs.delete(i)
				break game
			}

			mut co_x := Fbytes{f:0.0}
			for h in 0..4 {
				unsafe{co_x.b[h] = buf[h]}
			}
			mut co_y := Fbytes{f:0.0}
			for h in 0..4 {
				unsafe{co_y.b[h] = buf[h + 4]}
			}

			m_x := unsafe{co_x.f}
			m_y := unsafe{co_y.f}
			vec_len := math.sqrt((p[i].pcx - m_x)*(p[i].pcx - m_x)+(p[i].pcy - m_y)*(p[i].pcy - m_y))
			if vec_len > p_size-5 {
				p[i].accelerate(f32((m_x - p[i].pcx)/vec_len*2), f32((m_y - p[i].pcy)/vec_len*2))
			}
			for _ in 0..1 {
				p[i].update_pos(0.6)
				solve_coll(mut p[i], mut p[(i+1)%2])
			}
			

			if p[i].pcx*p[i].pcx + p[i].pcy*p[i].pcy > 300*300 {
				lost = i
				break game
			}
		}
	}
	if lost == -1 {
		for mut c in cs {
			c.write([u8(255)]) or {}
		}
	} else {
		for i, mut c in cs {
			if i == lost {
				c.write([u8(253)]) or {} // lost
			} else {
				c.write([u8(254)]) or {} // won
			}
		}
	}
	println("Game ended")
}

fn solve_coll(mut p1 Player, mut p2 Player) {
	coll_axis_x := p1.pcx - p2.pcx
	coll_axis_y := p1.pcy - p2.pcy
	mut dist := coll_axis_x*coll_axis_x + coll_axis_y*coll_axis_y
	if dist < (p_size+p_size)*(p_size+p_size) {
		dist = f32(math.sqrt(dist))
		n_x := coll_axis_x / dist // normalised
		n_y := coll_axis_y / dist // normalised
		delta := f32(1.0)//(p_size+p_size) - dist

		vel1_x := (p1.pcx - p1.pox)
		vel1_y := (p1.pcy - p1.poy)
		vel1 := (vel1_x*vel1_x + vel1_y*vel1_y)/15.0

		p1.pcx += bounce * delta * n_x 
		p1.pcy += bounce * delta * n_y 
		p2.pcx -= bounce * delta * n_x * vel1
		p2.pcy -= bounce * delta * n_y * vel1
	}
}

/*
fn handle_client(mut socket net.TcpConn) {
	client_addr := socket.peer_addr() or { return }
	defer {
		println("socket closed ${client_addr} ${time.now()}")
		socket.close() or { panic(err) }
	}
	eprintln('> new client: ${client_addr} ${time.now()}')
	mut x := 100
	mut y := 100
	mut buf := []u8{len:2}
	for {
		socket.write([u8(x), u8(y)]) or { return }
		_ := socket.read(mut buf) or {return}
		x = buf[0]
		y = buf[1]
	}


	/*
	for {
		mut buf := []u8{len:100}
		println("reading")
		read := socket.read(mut buf) or {println("socket closed ${time.now()}"); return}
		dump(buf[..read])
		println('client ${client_addr}: ${buf[..read]}')
		socket.write(buf[..read]) or {println("no mo"); return }
	}
	*/
}*/

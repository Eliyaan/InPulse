import net
import math
import time

// when the first player of a 1player party quits and then  a new player  arrives it will say 'other player disconnected'

type MayCon = bool | net.TcpConn

union Fbytes {
mut:
  f f32
  b [4]u8
}


fn main() {
	mut server := net.listen_tcp(.ip, ':40001')!
	laddr := server.addr()!
	eprintln('Listen on ${laddr} ...')
	mut cs := []net.TcpConn{}
	mut coords := []f32{}
	mut new_con := MayCon(false)
	for {
		println('Waiting for new game')
		if new_con is bool {
			cs = []net.TcpConn{}
			coords = []f32{}
		} else {
			cs = [new_con as net.TcpConn]
			new_con = false
			coords = [f32(-128), 0]
		}
		for i in cs.len .. 2 {
			println('Waiting for player ${i}')
			cs << server.accept()!
			cs[i].write([u8(254)]) or { panic(err) } // in queue
			if i == 0 {
				coords << [f32(-128), 0]
			} else if i == 1 {
				coords << [f32(128), 0]
				mut buf := []u8{len: 10}
				cs[0].write([u8(255)]) or { panic(err) } // validation packet
				cs[0].read(mut buf) or {
					println(err)
					new_con = cs[1]
					println("Player 0 disconnected")
					break
				}
				assert buf == [u8(101), 0, 0, 0, 0, 0, 0, 0, 0, 0]
			} else {
				panic('strange i=${i}')
			}
			println('Player ${i} connected')
		}
		if new_con is bool {
			mut buf := []u8{len: 10}
			cs[1].write([u8(255)]) or { panic(err) } // validation packet
			cs[1].read(mut buf) or { 
				println(err)
				new_con = cs[0]
				println("Player 1 disconnected")	
			}
			assert buf == [u8(101), 0, 0, 0, 0, 0, 0, 0, 0, 0]
		}
		if new_con is bool {
			spawn game(cs, coords)
		}
	}
}

fn game(connections []net.TcpConn, coordinates []f32) {
	println('Game Created\n ----------------- ')
	mut cs := connections.clone()
	mut coords := coordinates.clone()

	// game loop

	mut buf := []u8{len: 8}
	mut lost := -1
	time.sleep(1_000_000_000)
	game: for {
		for i, mut c in cs {
			mut packet := [u8(i)]
			for coo in coords {
				co := Fbytes{f:coo}
				for h in 0..4 {
					packet << unsafe{co.b[h]}
				}
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
			vec_len := math.sqrt((coords[i * 2] - m_x)*(coords[i * 2] - m_x)+(coords[i * 2 + 1] - m_y)*(coords[i * 2 + 1] - m_y))
			if vec_len > 5 {
				//coords[i * 2] += f32((m_x - coords[i * 2])/vec_len*2)
				//coords[i * 2 + 1] += f32((m_y - coords[i * 2 + 1])/vec_len*2)
			}

			if coords[i * 2]*coords[i * 2] + coords[i * 2 + 1]*coords[i * 2 + 1] > 200*200 {
				lost = i
				//break game
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

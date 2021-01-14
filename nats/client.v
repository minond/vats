module nats

import net { dial_tcp }
import strconv { atoi }
import sync

type MsgHandler = fn(Msg)

struct Client {
	conn net.TcpConn

mut:
	connected bool
	subscriptions map[string]MsgHandler

	mux &sync.Mutex
	buffer []string
}

pub fn make_client(server_url string) ?Client {
	conn := dial_tcp("localhost:4222") or {
		return error("unable to connect to $server_url")
	}

	return Client{
		conn: conn,
		mux: &sync.Mutex{},
	}
}

fn (mut client Client) write_line(str string) {
	client.write("$str\r\n")
}

fn (mut client Client) write(str string) {
	if client.connected {
		client.conn.write_str(str)
	} else {
		client.buffer << str
	}
}

fn (mut client Client) flush() {
	client.mux.m_lock()
	buffer := client.buffer
	client.buffer = []
	client.mux.unlock()

	for str in buffer {
		client.conn.write_str(str)
	}
}

pub fn (mut client Client) read() {
	for {
		res := client.conn.read_line()

		if res == "" {
			continue
		}

		match res.substr(0, 3) {
			"INF" { client.handle_info(res) }
			"MSG" { client.handle_msg(res) }
			"PIN" { client.handle_ping() }
			"PON" { client.handle_pong() }
			"+OK" { continue }
			"-ER" { client.handle_err(res) }
			else { println("unknown message: $res") }
		}
	}
}

fn (mut client Client) handle_info(res string) {
	println("connection established to server")
	client.connected = true
	client.flush()
}

fn (mut client Client) handle_msg(res string) {
	msg := parse_msg(res, client.conn.read_line()) or { return }
	if msg.sid in client.subscriptions {
		client.subscriptions[msg.sid](msg)
	}
}

fn (client Client) handle_err(res string) {
	println("error: $res")
}

fn (mut client Client) handle_ping() {
	client.write_line("pong")
}

fn (mut client Client) handle_pong() {
	client.write_line("ping")
}

pub fn (mut client Client) subscribe(subject string, handler MsgHandler) {
	sid := make_sid()
	client.write_line("sub $subject $sid")
	client.subscriptions[sid] = handler
}

pub fn (mut client Client) queue_subscribe(subject string, queue string, handler MsgHandler) {
	sid := make_sid()
	client.write_line("sub $subject $queue $sid")
	client.subscriptions[sid] = handler
}

pub fn (mut client Client) publish(subject string, payload []byte) {
	client.write_line("pub $subject $payload.len")
	client.write_line("$payload.bytestr()")
}

pub fn (mut client Client) request(subject string, reply_to string, payload []byte) {
	client.write_line("pub $subject $reply_to $payload.len")
	client.write_line("$payload.bytestr()")
}

module nats

import net { dial_tcp }
import strconv { atoi }

type MsgHandler = fn(Msg)

struct Client {
	conn net.TcpConn

mut:
	connected bool
	buffer []string
	subscriptions map[string][]MsgHandler
}

pub fn make_client(server_url string) ?Client {
	conn := dial_tcp("localhost:4222") or {
		return error("unable to connect to $server_url")
	}

	return Client{conn: conn}
}

fn (mut client Client) write(str string) {
	if !client.connected {
		client.buffer << str
		return
	}

	client.conn.write_str(str)
}

fn (mut client Client) flush() {
	for str in client.buffer {
		client.conn.write_str(str)
	}

	client.buffer = []
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
	for subscription in client.subscriptions[msg.sid] {
		subscription(msg)
	}
}

fn (client Client) handle_err(res string) {
	println("error: $res")
}

fn (mut client Client) handle_ping() {
	println("ping/pong")
	client.write("pong")
}

fn (mut client Client) handle_pong() {
	println("pong/ping")
	client.write("ping")
}

pub fn (mut client Client) subscribe(subject string, handler MsgHandler) bool {
	sid := make_sid()
	println("subscribing to $subject [$sid]")
	client.write("sub $subject $sid\n")
	client.subscriptions[sid] << handler
	return true
}

pub fn (mut client Client) queue_subscribe(subject string, queue string, handler MsgHandler) bool {
	sid := make_sid()
	println("subscribing to $subject (queue: $queue) [$sid]")
	client.write("sub $subject $queue $sid\n")
	client.subscriptions[sid] << handler
	return true
}

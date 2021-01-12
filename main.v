import nats { make_client }

fn wait_until(stop chan bool) {
	for {
		select {
			_ := <- stop {
				return
			}
		}
	}
}

fn main() {
	mut client := make_client("localhost:4222") or {
		println(err)
		return
	}

	go (&client).read()

	client.queue_subscribe("foo", "foo", fn (msg nats.Msg) {
		println("GOT A MSG $msg")
	})


	stop := chan bool{}
	wait_until(stop)
}

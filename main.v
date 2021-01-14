import nats { make_client }
import time { sleep_ms }

fn wait_until(stop chan bool) {
	for {
		select {
			_ := <- stop {
				return
			}
		}
	}
}

fn publish_data(mut client nats.Client, wait_time_ms int) {
	for {
		client.publish("foo", "hello from V!".bytes())
		sleep_ms(wait_time_ms)
	}
}

fn main() {
	mut client := make_client("localhost:4222") or {
		println(err)
		return
	}

	go (&client).read()

	client.queue_subscribe("foo", "foo", fn (msg nats.Msg) {
		println("[$time.now().unix_time_milli()] payload: $msg.payload.bytestr()")
	})

	go publish_data(mut &client, 10)

	stop := chan bool{}
	wait_until(stop)
}

module nats

import rand

fn make_sid() string {
	return rand.string(16)
}

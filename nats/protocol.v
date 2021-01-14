module nats

import strconv { atoi }

// Syntax: MSG <subject> <sid> [reply-to] <#bytes>\r\n[payload]\r\n
struct Msg {
pub:
	subject string
	sid string
	reply_to string
	content_length int
	payload []byte
}

fn parse_msg(res string, body string) ?Msg {
	parts := res.trim_space().fields()
	subject := parts[1]
	sid := parts[2]

	content_length := atoi(parts.last()) or {
		return error("unable to parse int")
	}

	mut reply_to := ""
	if parts.len == 5 {
		reply_to = parts[3]
	}

	payload := body.limit(content_length).bytes()

	return Msg {
		subject: subject,
		sid: sid,
		reply_to: reply_to,
		content_length: content_length,
		payload: payload,
	}
}

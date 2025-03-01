--!strict

-- Main purpose of this is to replace Promise debug info

type message = {
	msg: string,
}

local Message = {}
Message.__index = Message

function Message.new(message: string): message
	return setmetatable({
		msg = message,
	}, Message) :: any
end

function Message.__tostring(self: message)
	return self.msg
end

return Message

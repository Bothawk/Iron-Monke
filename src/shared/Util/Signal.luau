--!strict
-- A tiny event: other code connects handlers, the owner fires it.
-- Each handler runs in its own thread, so one erroring handler can't break the others.

export type Signal = {
	Connect: (self: Signal, handler: (...any) -> ()) -> () -> (),
	Fire: (self: Signal, ...any) -> (),
}

local Signal = {}

function Signal.new(): Signal
	local handlers: { (...any) -> () } = {}
	local signal = {}

	-- Returns a function that disconnects the handler.
	function signal.Connect(_self: Signal, handler: (...any) -> ()): () -> ()
		table.insert(handlers, handler)
		return function()
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end
	end

	function signal.Fire(_self: Signal, ...: any)
		for _, handler in table.clone(handlers) do
			task.spawn(handler, ...)
		end
	end

	return signal :: any
end

return Signal

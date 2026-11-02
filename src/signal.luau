--!strict

local module = {}

--[=[
    A connection between a signal and a callback.
]=]
export type Connection = {
    --[=[
        Whether the callback is still connected.
    ]=]
    Connected: boolean,
    --[=[
        Disconnect the callback.
    ]=]
    Disconnect: (self: Connection) -> (),
}

--[=[
    An event that callbacks can connect to.
]=]
export type Signal<T> = {
    --[=[
        Connect a callback.
    ]=]
    Connect: (self: Signal<T>, callback: (value: T) -> ()) -> Connection,
}

--[=[
    Create a signal, using a `BindableEvent` where Roblox APIs are available.

    @return The signal, and the function that fires it.
]=]
function module.new<T>(): (Signal<T>, (value: T) -> ())
    if Instance ~= nil then
        local event = Instance.new("BindableEvent")
        -- selene: allow(multiple_statements)
        local function fireEvent(value: T) event:Fire(value) end
        return event.Event :: any, fireEvent
    end

    local callbacks: { (value: T) -> () } = {}

    local signal: Signal<T> = {
        Connect = function(_, callback: (value: T) -> ()): Connection
            table.insert(callbacks, callback)

            local connection: Connection = {
                Connected = true,
                Disconnect = function(self: Connection)
                    if not self.Connected then return end
                    self.Connected = false

                    local index = table.find(callbacks, callback)
                    if index == nil then return end
                    table.remove(callbacks, index)
                end,
            }
            return connection
        end,
    }

    local function fire(value: T)
        for _, callback in table.clone(callbacks) do
            local thread = coroutine.create(callback)
            local success, message = coroutine.resume(thread, value)
            if success then continue end
            warn(message)
        end
    end

    return signal, fire
end

return module

--!strict

export type Task = RBXScriptConnection | Instance | Tween | (() -> ())

local Maid = {}
Maid.__index = Maid

export type Maid = {
	_tasks: { Task },
	_destroyed: boolean,
	Give: (self: Maid, task: Task) -> Task,
	Destroy: (self: Maid) -> (),
}

function Maid.new(): Maid
	return setmetatable({ _tasks = {}, _destroyed = false }, Maid) :: any
end

local function clean(task: Task)
	if type(task) == "function" then
		task()
	elseif typeof(task) == "RBXScriptConnection" then
		task:Disconnect()
	elseif typeof(task) == "Instance" then
		task:Destroy()
	elseif typeof(task) == "Tween" then
		task:Cancel()
	end
end

function Maid:Give(task: Task): Task
	if self._destroyed then
		clean(task)
		return task
	end
	table.insert(self._tasks, task)
	return task
end

function Maid:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	for i = #self._tasks, 1, -1 do
		clean(self._tasks[i])
		self._tasks[i] = nil :: any
	end
end

return Maid

--[[
    Copyright 2020 Lucas Schwiderski

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
--]]

local mod = get_mod("remove_hanging_corpses")

-- The number of units to check per frame.
-- Sort of a magic number. Seems to be a good balance where the checks
-- are finished before the intro cutscene stops, but not too many units per frame
-- so that the game still feels smooth-ish (and doesn't trigger the 15sec timeout).
local CHECKS_PER_FRAME = 200

-- IDs of units to be removed.
local CORPSE_IDS = {
    "fd0b58751b110ece",
    "a1585c6b36c93f6d",
    "ecfe78f460261b5d",
    "07929ad52758eaab",
}

local function get_unit_hash(unit)
    local unit_name = tostring(unit)
	local id = string.gsub(unit_name, "%[Unit '#ID%[", "")
    return string.gsub(id, "%]'%]", "")
end

CorpseDeleteHandler = class(CorpseDeleteHandler)

function CorpseDeleteHandler:init()
    self.index = 0
    self.state = "init"
end

function CorpseDeleteHandler:destroy()
    self.index = 0
    self.state = "done"
    self.units = nil
end

function CorpseDeleteHandler:update()
    local state = self.state

    if state == "init" then
        -- First, we need a list of every unit in the level

        local world = Managers.world:world("level_world")

        if world then
            local units = World.units(world)
            local num_units = #units

            if num_units > 0 then
                self.units = units
                self.num_units = num_units
                self.index = 1

                self.state = "check"
            else
                self.state = "done"
            end
        end
        mod:debug("Initialized CorpseDeleteHandler with %s units.", self.num_units)
    elseif state == "check" then
        -- Once we have the list, we need to iterate over it
        -- and remove every unit that matches one of our pre-defined hashes
        -- However, doing that in a single frame would stall too long and
        -- trigger the 15sec timeout.
        -- So instead we only check a slice of the list

        local num_units = self.num_units

        -- Start of the slice
        local index = self.index
        -- End of the slice. Either as many units as allowed per frame or
        -- the remaining ones, if less.
        local last_index = math.min(index + CHECKS_PER_FRAME, num_units)

        for i = index, last_index do
            local unit = self.units[i]
            local h = get_unit_hash(unit)

            for _, hash in ipairs(CORPSE_IDS) do
                if h == hash then
                    -- Hide the unit, but keeps its physics interactions
                    -- `false` == invisible
                    Unit.set_unit_visibility(unit, false)
                end
            end
        end

        -- If there are still units to check, we continue the next time this function is called
        if last_index >= num_units then
            mod:debug("Reached end of units to check")
            self.state = "done"
        else
            self.index = last_index + 1
        end
    end
end

local delete_handler

-- Skip `GameModeManager._set_flow_object_set_unit_enabled` when the unit doesn't exist anymore.
-- Unit indices as used by `stingray.Level` don't seem to change when a unit is removed,
-- so the other indices stored by `GameModeManager` are still correct.
mod:hook(GameModeManager, "_set_flow_object_set_unit_enabled", function(func, self, level, index)
    local unit = Level.unit_by_index(level, index)

    if not unit then
        return
    end

    return func(self, level, index)
end)

-- Patch `GameModeManager._set_flow_object_set_enabled` so skip units that have been removed.
-- Similar to `GameModeManager._set_flow_object_set_unit_enabled`, except this needs a `hook_origin`,
-- so it might break in the future.
mod:hook_origin(GameModeManager, "_set_flow_object_set_enabled", function(self, set, enable, set_name)
    if set.flow_set_enabled == enable then
		return
	end

	local level = LevelHelper:current_level(self._world)
	set.flow_set_enabled = enable
	local data = self._flow_set_data
	local buffer = data.ring_buffer
	local write_index = data.write_index
	local read_index = data.read_index
	local size = data.size
	local max_size = data.max_size
	local set_units = set.units
	local new_units_size = #set_units
	local new_size = size + new_units_size
	local overflow = new_size - max_size

	if overflow > 0 then
		local amount_to_remove = math.min(overflow, size)

		for i = 1, amount_to_remove, 1 do
			local unit_index = buffer[read_index]

			self:_set_flow_object_set_unit_enabled(level, unit_index)

			read_index = read_index % max_size + 1
			size = size - 1
		end

		data.read_index = read_index
	end

	local object_set_size_overflow = new_units_size - max_size

    for i, unit_index in ipairs(set_units) do
        repeat
            local unit = Level.unit_by_index(level, unit_index)

            if not unit then
                break
            end

            local refs = Unit.get_data(unit, "flow_object_set_references") or 1

            if enable then
                refs = refs + 1
            else
                refs = math.max(refs - 1, 0)
            end

            Unit.set_data(unit, "flow_object_set_references", refs)

            if i <= object_set_size_overflow then
                self:_set_flow_object_set_unit_enabled(level, unit_index)
            else
                buffer[write_index] = unit_index
                write_index = write_index % max_size + 1
                size = size + 1
            end
        until true
	end

	data.write_index = write_index
	data.size = size
end)

mod:hook_safe(StateInGameRunning, "on_enter", function()
    delete_handler = CorpseDeleteHandler:new()
end)

mod:hook_safe(StateInGameRunning, "on_exit", function()
    if delete_handler then
        delete_handler:destroy()
        delete_handler = nil
    end
end)

mod:hook_safe(StateInGameRunning, "update", function(self, dt)
    if delete_handler then
        delete_handler:update(dt)

        if delete_handler.state == "done" then
            delete_handler:destroy()
            delete_handler = nil
        end
    end
end)
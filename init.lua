-- This is a configuration for Hammerspoon:
-- Modification Keys: Cmd + Ctrl (⌘ + ⌃)
-- 1. Currently support window layout management:
--   - ⌘ ⌃ + H, Toggle current window to left/restore;
--   - ⌘ ⌃ + L, Toggle current window to right/restore;
--   - ⌘ ⌃ + M, Toggle current window to maximize/restore;
-- 2. Currently support audio output device swith:
--   - ⌘ ⌃ + ], Switch to previous audio output device;
--   - ⌘ ⌃ + [, Switch to next audio output device;
--   - ⌘ ⌃ + C, Show current audio output device;
--   - ⌘ ⌃ + T, Toggle latest two output devices;
-- 3. Eject all devices:
--   - ⌘ ⌃ + J, Eject all removalbe drives;

hs.window.animationDuration = 0
previousFrameSizes = {}
audioDeviceQueue = {
	old = hs.audiodevice.defaultOutputDevice(),
	new = hs.audiodevice.defaultOutputDevice()
}
modificationKeys = {"cmd", "ctrl"}

-- hs.hotkey.bind(modificationKeys, "T", function()
-- 	local curWin = hs.window.focusedWindow()
-- 	hs.alert.show(test[curWin.__tostring])
-- end)

hs.hotkey.bind(modificationKeys, "R", function()
	hs.reload()
	hs.notify.new({title="Hammerspoon", informativeText="Config Reloaded"}):send()
end)

function isAlmostEqualToCurWinFrame(geo)
	local epsilon = 5
	local curWin = hs.window.focusedWindow()
	local curWinFrame = curWin:frame()
	if math.abs(curWinFrame.x - geo.x) < epsilon and
		math.abs(curWinFrame.y - geo.y) < epsilon and
		math.abs(curWinFrame.w - geo.w) < epsilon and
		math.abs(curWinFrame.h - geo.h) < epsilon then
		return true
	else
		return false
	end
end

function getMaxWinFrame()
	local curWin = hs.window.focusedWindow()
	return curWin:screen():frame()
end

function getFillLeftWinFrame()
	local curWin = hs.window.focusedWindow()
	local curWinFrame = curWin:frame()
	local maxFrame = curWin:screen():frame()
	curWinFrame.x = maxFrame.x
	curWinFrame.y = maxFrame.y
	curWinFrame.w = maxFrame.w / 2
	curWinFrame.h = maxFrame.h
	return curWinFrame
end

function getFillRightWinFrame()
	local curWin = hs.window.focusedWindow()
	local curWinFrame = curWin:frame()
	local maxFrame = curWin:screen():frame()
	curWinFrame.x = maxFrame.x + maxFrame.w / 2
	curWinFrame.y = maxFrame.y
	curWinFrame.w = maxFrame.w / 2
	curWinFrame.h = maxFrame.h
	return curWinFrame
end

function isPredefinedWinFrameSize()
	if isAlmostEqualToCurWinFrame(getMaxWinFrame()) or
		isAlmostEqualToCurWinFrame(getFillLeftWinFrame()) or
		isAlmostEqualToCurWinFrame(getFillRightWinFrame()) then
		return true
	else
		return false
	end
end

function bindResizeAndRestoreToKeys(key, resize_frame_fn)
	hs.hotkey.bind(modificationKeys, key, function()
		local curWin = hs.window.focusedWindow()
		local curWinFrame = curWin:frame()
		local targetFrame = resize_frame_fn()

		if isPredefinedWinFrameSize() and not isAlmostEqualToCurWinFrame(targetFrame) then
			curWin:setFrame(targetFrame)
		elseif previousFrameSizes[curWin:id()] then
			curWin:setFrame(previousFrameSizes[curWin:id()])
			previousFrameSizes[curWin:id()] = nil
		else
			previousFrameSizes[curWin:id()] = curWinFrame
			curWin:setFrame(targetFrame)
		end
	end)
end

function bindAudioDeviceKeys(key, get_output_dev_fn)
	hs.hotkey.bind(modificationKeys, key, function()
		local outputDevice = get_output_dev_fn()
		if not outputDevice then
			hs.notify.new({title="Output Device:", informativeText="No Next Output Device Found."}):send()
		else
			outputDevice:setDefaultOutputDevice()
			hs.notify.new({title="Output Device:", informativeText=hs.audiodevice.defaultOutputDevice():name()}):send()
		end
	end)
end

function pushPopAudioDeviceQueue(newAudioDevice)
	local popedDevice = audioDeviceQueue.old
	audioDeviceQueue.old = audioDeviceQueue.new
	audioDeviceQueue.new = newAudioDevice
	return popedDevice
end

function audioDeviceEventHandler(event)
	if event == "dOut" then
		if hs.audiodevice.defaultOutputDevice():uid() ~= audioDeviceQueue.new:uid() then
			pushPopAudioDeviceQueue(hs.audiodevice.defaultOutputDevice())
		end
	end
end

function getNextOutputDevice(inc)
	local currentOutputDevice = hs.audiodevice.defaultOutputDevice()
	local allOutputDevices = hs.audiodevice.allOutputDevices()
	local currentOutputDeviceIndex = nil

	for i = 1, #allOutputDevices do
		if allOutputDevices[i]:uid() == currentOutputDevice:uid() then
			currentOutputDeviceIndex = i
			break
		end
	end

	if not inc then
		inc = 1
	end

	if currentOutputDeviceIndex then
		return allOutputDevices[(currentOutputDeviceIndex + inc - 1) % #allOutputDevices + 1]
	else
		return nil
	end
end

function ejectAllVolumes()
	local allVolumes = hs.fs.volume.allVolumes()
	local n = 0

	for path, volume in pairs(allVolumes) do
		if volume.NSURLVolumeIsInternalKey == false then
			hs.notify.new({title="Eject Drive:", informativeText=volume.NSURLVolumeNameKey}):send()
			hs.fs.volume.eject(path)
			n = n + 1
		end
	end

	if n == 0 then
		hs.notify.new({title="Eject Drive:", informativeText="No Removable Disk Detected."}):send()
	end
end


bindResizeAndRestoreToKeys("M", getMaxWinFrame)
bindResizeAndRestoreToKeys("H", getFillLeftWinFrame)
bindResizeAndRestoreToKeys("L", getFillRightWinFrame)

bindAudioDeviceKeys("[", function() return getNextOutputDevice(1) end)
bindAudioDeviceKeys("]", function() return getNextOutputDevice(-1) end)
bindAudioDeviceKeys("C", function() return hs.audiodevice.defaultOutputDevice() end)
bindAudioDeviceKeys("T", function()
	local targetAudioDevice = audioDeviceQueue.old
	pushPopAudioDeviceQueue(targetAudioDevice)
	return targetAudioDevice
end)

-- hs.hotkey.bind({"ctrl"}, "[", function () hs.eventtap.keyStroke({}, "escape") end)
hs.hotkey.bind(modificationKeys, "J", ejectAllVolumes)

hs.audiodevice.watcher.setCallback(audioDeviceEventHandler)
hs.audiodevice.watcher.start()

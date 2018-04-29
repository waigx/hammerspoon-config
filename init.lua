hs.window.animationDuration = 0
previousFrameSizes = {}
modificationKeys = {"cmd", "ctrl"}

hs.hotkey.bind(modificationKeys, "T", function()
	local curWin = hs.window.focusedWindow()
	hs.alert.show(test[curWin.__tostring])
end)

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
			hs.notify.new({title="Output Device:", "No Next Output Device Found."}):send()
		else
			outputDevice:setDefaultOutputDevice()
			hs.notify.new({title="Output Device:", informativeText=hs.audiodevice.defaultOutputDevice():name()}):send()
		end
	end)
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

bindResizeAndRestoreToKeys("M", getMaxWinFrame)
bindResizeAndRestoreToKeys("H", getFillLeftWinFrame)
bindResizeAndRestoreToKeys("L", getFillRightWinFrame)

bindAudioDeviceKeys("[", function() return getNextOutputDevice(1) end)
bindAudioDeviceKeys("]", function() return getNextOutputDevice(-1) end)
bindAudioDeviceKeys("A", function() return hs.audiodevice.defaultOutputDevice() end)

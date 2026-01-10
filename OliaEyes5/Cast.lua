local Jungle, jungle = ...

local Cast = {}
function Cast:new(_spell, _target, pix)
	local self = {}
	self._spell = _spell
	self._target = _target
	self.pix = pix
	self.color = jungle.Color:new()
	self.cast = function()
		if 
		not UnitExists('focus') or not UnitIsUnit('focus', self._target)
			then
			local trgColor = self.color:makeColor(self._target)
			local pixel = jungle.Pixel:new(trgColor, self.pix)
			return pixel:set() 
		elseif 
		UnitIsUnit('focus', self._target)
			then
			local spColor = self.color:makeColor(self._spell)
			local pixel = jungle.Pixel:new(spColor, self.pix)
			return pixel:set()
		end
	end
	self.reset = function()
		local defColor
		if UnitExists('focus') then
		defColor = self.color:makeColor('clearfocus')
		local pixel = jungle.Pixel:new(defColor, self.pix)
			return pixel:set()
		else
		defColor = self.color:makeColor('dummyColor')
		local pixel = jungle.Pixel:new(defColor, self.pix)
			return pixel:set()
		end
	end
	return self
end
jungle.Cast = Cast

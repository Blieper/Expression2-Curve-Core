-- Made by KrypteK
E2Lib.RegisterExtension("curves", false, "Adds 'curves' to E2")

registerType("curve", "xcr", { {0, 0, 0} },
    nil,
    nil,
    function(retval)
        if not (type(retval) == "xcr") then error("Return value is not a curve, but a "..type(retval).."!",0) end
    end,
    function(v)
        return not (type(retval) == "xcr")
    end
)

registerOperator("ass", "xcr", "xcr", function(self, args)
	local op1, op2, scope = args[2], args[3], args[4]
	local      rv2 = op2[1](self, op2)
	self.Scopes[scope][op1] = rv2
    self.Scopes[scope].vclk[op1] = true

	return rv2
end)

local cvar_equidistant = CreateConVar( "wire_expression2_curves_mindistance", "5", FCVAR_ARCHIVE )
local cvar_maxsteps = CreateConVar( "wire_expression2_curves_maxsteps", "100", FCVAR_ARCHIVE )

--------------------------------------------------------------------------------
-- Calculates a point on a quadratic bezier curve
local function BezierQuadratic(t, p0, p1, p2)
	return Vector(
		(1-t)^2 * p0[1] + (2 * (1-t) * t * p1[1]) + t^2 * p2[1],
		(1-t)^2 * p0[2] + (2 * (1-t) * t * p1[2]) + t^2 * p2[2],
		(1-t)^2 * p0[3] + (2 * (1-t) * t * p1[3]) + t^2 * p2[3]
	)
end

-- Calculates a point on a cubic bezier curve
local function BezierCubic(t, p0, p1, p2, p3)
	return Vector(
        (((1-t)^3) * p0[1]) + (3*t*((1-t)^2) * p1[1]) + ((3*(t^2)*(1-t)) * p2[1]) + ((t^3) * p3[1]),
		(((1-t)^3) * p0[2]) + (3*t*((1-t)^2) * p1[2]) + ((3*(t^2)*(1-t)) * p2[2]) + ((t^3) * p3[2]),
		(((1-t)^3) * p0[3]) + (3*t*((1-t)^2) * p1[3]) + ((3*(t^2)*(1-t)) * p2[3]) + ((t^3) * p3[3])
    )
end

-- Calculates a point on a NURBS curve
local function Nurbs (t, ...) 
    local Data = {}
    local Depth = #arg
    
    for i = 1,Depth do
        table.insert(Data, arg[i])
    end
    
    while Depth do
        for i = 1,Depth-1 do              
            local Pos = Vector(
                Data[i][1] * (1-t) + Data[i + 1][1] * t,
                Data[i][2] * (1-t) + Data[i + 1][2] * t,
                Data[i][3] * (1-t) + Data[i + 1][3] * t               
            )
            
            Data[i] = Pos
        end            
        
        Depth = Depth - 1
    end
    
    return Data[1]      
end

-- Dynamically calculates a point on a curve, based on how many points that curve has
local function point (t, curve) 
    local Pos = Vector(0,0,0)

    if #curve == 3 then 
        Pos = BezierQuadratic(t, curve[1], curve[2], curve[3])
    elseif #curve == 4 then
        Pos = BezierCubic(t, curve[1], curve[2], curve[3], curve[4])
    elseif #curve > 4 then
        Pos = Nurbs(t, curve)
    end

    return Pos
end

-- Returns a tangent at t on the given curve
local function tangent (t, curve) 
    local p0 = point(t, curve)
    local p1 = point(t + 0.000001, curve)

    local tan = p1 - p0

    return tan
end

-- Returns the length of a curve
local function length (curve, p) 
    local t = 0
    local v1 = curve[1]
    local distance = 0

    p = math.Clamp(p,0,cvar_maxsteps:GetInt())

    while t < 1 do
        t = t + 1/p
        t = math.Clamp(t,0,1)

        local v2 = point(t, curve)
        distance = distance + v1:Distance(v2)
        v1 = v2
    end

    return distance
end

-- Returns a table containing points on the curve
local function getLUT (curve, steps) 
    local LUT = {}
    local i = 0

    steps = math.Clamp(steps,0,cvar_maxsteps:GetInt())

    while i < steps do
        local t = i / steps
        table.insert(LUT, point(t, curve))

        i = i + 1
    end

    return LUT
end

-- Returns a table containing tangent points on the curve
local function getTangentLUT (curve, steps) 
    local LUT = {}
    local i = 0

    steps = math.Clamp(steps,0,cvar_maxsteps:GetInt())

    while i < steps do
        local t = i / steps
        table.insert(LUT, tangent(t, curve))

        i = i + 1
    end

    return LUT
end

-- Returns a table containing points every 'distance' units on the curve
local function equidistantLUT (curve, distance, precision, clamped) 
    if distance < cvar_equidistant:GetFloat() then distance = cvar_equidistant:GetFloat()  end

    local LUT = {}
    local t = 0
    local p0 = curve[1]
    table.insert(LUT, p0)

    while t < 1 do
        local try = 0
        local d = 0
        local p1 = p0

        while try < precision and d < distance do 
            try = try + 1
            t = t + ((distance-d)/distance) * (1/precision)

            if clamped == 1 then t = math.Clamp(t, 0, 1) end

            p0 = point(t, curve)

            d = (p0 - p1):Length()
        end

        table.insert(LUT, p0)
    end

    return LUT
end

-- Returns a table containing tangent points every 'distance' units on the curve
local function equidistantTangentLUT (curve, distance, precision, clamped) 
    if distance < cvar_equidistant:GetFloat() then distance = cvar_equidistant:GetFloat()  end

    precision = math.Clamp(precision,0,cvar_maxsteps:GetInt())

    local LUT = {}
    local t = 0
    local p0 = curve[1]
    table.insert(LUT, tangent(0, curve))

    while t < 1 do
        local try = 0
        local d = 0
        local p1 = p0

        while try < precision and d < distance do 
            try = try + 1
            t = t + ((distance-d)/distance) * (1/precision)

            if clamped == 1 then t = math.Clamp(t, 0, 1) end

            p0 = point(t, curve)

            d = (p0 - p1):Length()
        end

        table.insert(LUT, tangent(t, curve))
    end

    return LUT
end

-- Returns the closest point in 3d space to the given curve
local function closestPoint (curve, p1, p) 
    local t = 0
    local cd = 100000000000000000000000000000
    local cp = Vector(0,0,0)

    p = math.Clamp(p,0,cvar_maxsteps:GetInt())

    while t < 1 do
        local p0 = point(t, curve)
        local d = (p0 - p1):Length()

        if (d < cd) then
            cd = d
            cp = p0
        end

        t = t + 1/p
        t = math.Clamp(t,0,1)
    end

    return cp
end

-- Returns an offset position to the curve
local function getOffset(curve, t, offset, norm) 
    local p = point(t, curve)
    local tan = tangent(t, curve):GetNormalized()
    local side = tan:Cross(Vector(norm[1],norm[2],norm[3]))

    return p + side * offset
end

--------------------------------------------------------------------------------
__e2setcost(2)

e2function curve curveCreate(vector p0, vector p1, vector p2)
	return { p0, p1 ,p2 }
end

e2function curve curveCreate(vector p0, vector p1, vector p2, vector p3)
	return { p0, p1 ,p2 ,p3 }
end

__e2setcost(1)

e2function vector curve:end()
	return this[#this]
end

e2function vector curve:start()
	return this[1]
end

__e2setcost(25)

e2function number curve:length()
	return length(this, 100)
end

e2function number curve:length(number p)
	return length(this, p)
end

__e2setcost(15)

e2function vector curve:tangent(number t)
	return tangent(t, this)
end

__e2setcost(2)

e2function vector curve:get(number i)
    if this[i] == nil then return Vector(0,0,0) end
	return this[i]
end

e2function void curve:set(number i, vector pos)
    if this[i] == nil then return end

    this[i] = pos
end

__e2setcost(10)

e2function vector curve:point(number t)
	return point(t, this)
end

__e2setcost(25)

e2function vector curve:closestPoint(vector t)
	return closestPoint(this, t, 100)
end

e2function vector curve:closestPoint(vector t, number p)
	return closestPoint(this, t, p)
end

e2function array curve:getLUT(number steps)
	return getLUT(this, steps)
end

e2function array curve:equidistantLUT(number d)
	return equidistantLUT(this, d, 25, 1)
end

e2function array curve:equidistantLUT(number d, number p)
	return equidistantLUT(this, d, p, 1)
end

e2function array curve:equidistantLUT(number d, number p, number c)
	return equidistantLUT(this, d, p, c)
end

e2function array curve:getTangentLUT(number steps)
	return getTangentLUT(this, steps)
end

e2function array curve:equidistantTangentLUT(number d)
	return equidistantTangentLUT(this, d, 25, 1)
end

e2function array curve:equidistantTangentLUT(number d, number p)
	return equidistantTangentLUT(this, d, p, 1)
end

e2function array curve:equidistantTangentLUT(number d, number p, number c)
	return equidistantTangentLUT(this, d, p, c)
end

__e2setcost(10)

e2function vector curve:getOffset(number t, number offset, vector norm)
	return getOffset(this, t, offset, norm) 
end

e2function vector curve:getOffset(number t, number offset)
	return getOffset(this, t, offset, Vector(0,0,1)) 
end

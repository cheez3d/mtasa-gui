local name = "GuiObject";

local super = GuiBase2D;

local func = setmetatable({}, { __index = function(tbl, key) return super.func[key] end });
local get  = setmetatable({}, { __index = function(tbl, key) return super.get[key]  end });
local set  = setmetatable({}, { __index = function(tbl, key) return super.set[key]  end });

local event = setmetatable({}, { __index = function(tbl, key) return super.event[key] end });

local private  = setmetatable({}, { __index = function(tbl, key) return super.private[key]  end });
local readOnly = setmetatable({}, { __index = function(tbl, key) return super.readOnly[key] end });



local RT_ADDITIONAL_MARGIN = 1; -- added so that rt can be properly anti-aliased when rotated

local MAX_BORDER_SIZE = 100;

local ROT_NEAR_Z_PLANE        = -1000;
local ROT_ACTUAL_NEAR_Z_PLANE = -900;
local ROT_FAR_Z_PLANE         =  9000;

local ROT_PIVOT_DEPTH_UNIT = 1000;


local SHADER = dxCreateShader("shaders/nothing.fx"); -- TODO: add check for successful creation (dxSetTestMode)



local function new(obj)
    super.new(obj);
    
    
    obj.guiIndex = nil; -- index in guiChildren array of parent
    
    set.clipsDescendants(obj, true);
    
    set.bgColor3(obj, Color3.new(255, 255, 255));
    set.bgTransparency(obj, 0);
    
    set.borderColor3(obj, Color3.new(27, 42, 53));
    set.borderSize(obj, 1);
    set.borderTransparency(obj, 0);
    
    obj.size = nil;
    obj.pos = nil;
    set.posOrigin(obj, UDim2.new());
    
    set.rot(obj, Vector3.new());
    set.rotPivot(obj, UDim2.new(0.5, 0, 0.5, 0));
    set.rotPivotDepth(obj, 0);
    set.rotPerspective(obj, obj.rotPivot);
    
    set.visible(obj, true);
end



function func.update_isRotated(obj)
    if (obj.rot.x%180 == 0 and (obj.rot.x == obj.rot.y and obj.rot.y == obj.rot.z)) then
        obj.isRotated = false;
    elseif (obj.rot.x%360 == 0 and obj.rot.y%360 == 0 and obj.rot.z%360 == 0) then
        obj.isRotated = false;
    else
        obj.isRotated = true;
    end
end

function func.update_isRotated3D(obj)
    if (obj.isRotated) then
        if ((obj.rot.x%180 == 0 and obj.rot.y%180 == 0) and obj.rotPivotDepth == 0) then
            obj.isRotated3D = false;
        elseif (obj.rot.x%180 == 0 and (obj.rot.x == obj.rot.y)) then
            obj.isRotated3D = false;
        else
            obj.isRotated3D = true;
        end
    else
        obj.isRotated3D = false;
    end
end


function func.update_absRotPivot(obj, descend)
    if (obj.rootGui) then
        obj.absRotPivot = Vector3.new(
            math.floor(obj.absPos.x + (obj.rotPivot.x.offset + obj.absSize.x*obj.rotPivot.x.scale)),
            math.floor(obj.absPos.y + (obj.rotPivot.y.offset + obj.absSize.y*obj.rotPivot.y.scale)),
            
            math.floor(obj.rotPivotDepth)
        );
    else
        obj.absRotPivot = nil;
    end
    
    
    if (descend) then
        for i = 1, #obj.guiChildren do
            func.update_absRotPivot(obj.guiChildren[i], true);
        end
    end
end

function func.update_absRotPerspective(obj, descend)
    if (obj.rootGui) then
        obj.absRotPerspective = Vector2.new(
            math.floor(obj.absPos.x + (obj.rotPerspective.x.offset + obj.absSize.x*obj.rotPerspective.x.scale)),
            math.floor(obj.absPos.y + (obj.rotPerspective.y.offset + obj.absSize.y*obj.rotPerspective.y.scale))
        );
    else
        obj.absRotPerspective = nil;
    end
    
    
    if (descend) then
        for i = 1, #obj.guiChildren do
            func.update_absRotPerspective(obj.guiChildren[i], true);
        end
    end
end


function func.update_containerRotPivot(obj, descend)
    if (obj.rootGui and #obj.guiChildren > 0 and obj.isRotated) then
        obj.containerRotPivot = Vector3.new(
            2*(-obj.containerSize.x/2 + obj.absRotPivot.x-obj.containerPos.x),
            2*(-obj.containerSize.y/2 + obj.absRotPivot.y-obj.containerPos.y),
            
            2*(obj.absRotPivot.z/GuiObject.ROT_PIVOT_DEPTH_UNIT)
        )/obj.parent.containerSize;
    else
        obj.containerRotPivot = nil;
    end
    
    
    if (descend) then
        for i = 1, #obj.guiChildren do
            func.update_containerRotPivot(obj.guiChildren[i], true);
        end
    end
end

function func.update_containerRotPerspective(obj, descend)
    if (obj.rootGui and #obj.guiChildren > 0 and obj.isRotated3D) then
        obj.containerRotPerspective = Vector2.new(
            2*(-obj.containerSize.x/2 + obj.absRotPerspective.x-obj.containerPos.x),
            2*(-obj.containerSize.y/2 + obj.absRotPerspective.y-obj.containerPos.y)
        )/obj.parent.containerSize;
    else
        obj.containerRotPerspective = nil;
    end
    
    
    if (descend) then
        for i = 1, #obj.guiChildren do
            func.update_containerRotPerspective(obj.guiChildren[i], true);
        end
    end
end


function func.update_rtPos(obj, descend)
    if (obj.rootGui) then
        obj.rtPos = Vector2.new(
            obj.absPos.x - (RT_ADDITIONAL_MARGIN + obj.borderSize),
            obj.absPos.y - (RT_ADDITIONAL_MARGIN + obj.borderSize)
        );
    else
        obj.rtPos = nil;
    end
    
    
    if (descend) then
        for i = 1, #obj.guiChildren do
            func.update_rtPos(obj.guiChildren[i], true);
        end
    end
end

function func.update_rt(obj, descend)
    if (obj.rootGui) then
        local rtSize = Vector2.new(
            RT_ADDITIONAL_MARGIN + obj.borderSize + obj.absSize.x + obj.borderSize + RT_ADDITIONAL_MARGIN,
            RT_ADDITIONAL_MARGIN + obj.borderSize + obj.absSize.y + obj.borderSize + RT_ADDITIONAL_MARGIN
        );
        
        if (rtSize ~= obj.rtSize) then
            if (obj.rt and isElement(obj.rt)) then
                destroyElement(obj.rt);
            end
            
            obj.rtSize = rtSize;
            obj.rt = dxCreateRenderTarget(rtSize.x, rtSize.y, true);
        end
    else
        if (obj.rt and isElement(obj.rt)) then
            destroyElement(obj.rt);
        end
        
        obj.rtSize = nil;
        obj.rt = nil;
    end
    
    
    if (descend) then
        for i = 1, #obj.guiChildren do
            func.update_rt(obj.guiChildren[i], true);
        end
    end
end

function func.update_rtRotPivot(obj, descend)
    if (obj.rootGui and obj.isRotated) then
        obj.rtRotPivot = Vector3.new(
            2*(-obj.rtSize.x/2 + obj.absRotPivot.x-obj.rtPos.x),
            2*(-obj.rtSize.y/2 + obj.absRotPivot.y-obj.rtPos.y),
            
            2*(obj.absRotPivot.z/ROT_PIVOT_DEPTH_UNIT)
        )/obj.parent.containerSize;
    else
        obj.rtRotPivot = nil;
    end
    
    
    if (descend) then
        for i = 1, #obj.guiChildren do
            func.update_rtRotPivot(obj.guiChildren[i], true);
        end
    end
end

function func.update_rtRotPerspective(obj, descend)
    if (obj.rootGui and obj.isRotated3D) then
        obj.rtRotPerspective = Vector2.new(
            2*(-obj.rtSize.x/2 + obj.absRotPerspective.x-obj.rtPos.x),
            2*(-obj.rtSize.y/2 + obj.absRotPerspective.y-obj.rtPos.y)
        )/obj.parent.containerSize;
    else
        obj.rtRotPerspective = nil;
    end
    
    
    if (descend) then
        for i = 1, #obj.guiChildren do
            func.update_rtRotPerspective(obj.guiChildren[i], true);
        end
    end
end


function func.draw(obj, descend)
    local success, result = pcall(super.func.draw, obj, descend);
    if (not success) then error(result, 2) end
    
    
    if (obj.rootGui) then
        if (obj.rt) then
            dxSetBlendMode("add");
            
            dxSetRenderTarget(obj.rt, true);
            
            if (obj.debug) then
                dxDrawRectangle(0, 0, obj.rtSize.x, obj.rtSize.y, tocolor(255, 0, 255, 127.5));
            end
            
            -- border
            dxDrawRectangle(
                GuiObject.RT_ADDITIONAL_MARGIN, GuiObject.RT_ADDITIONAL_MARGIN,
                
                obj.absSize.x+2*obj.borderSize, obj.absSize.y+2*obj.borderSize,
                
                tocolor(obj.borderColor3.r, obj.borderColor3.g, obj.borderColor3.b, 255*(1-obj.borderTransparency))
            );
            
            -- background
            dxSetBlendMode("overwrite");
            
            dxDrawRectangle(
                GuiObject.RT_ADDITIONAL_MARGIN+obj.borderSize,
                GuiObject.RT_ADDITIONAL_MARGIN+obj.borderSize,
                
                obj.absSize.x, obj.absSize.y,
                
                tocolor(obj.bgColor3.r, obj.bgColor3.g, obj.bgColor3.b, 255*(1-obj.bgTransparency))
            );
            
            -- children
            dxSetBlendMode("add");
            
            dxSetRenderTarget(obj.container);
            
            for i = 1, #obj.guiChildren do
                local child = obj.children[i];
                
                if (child.rt) then
                    if (child.isRotated) then
                        dxSetShaderTransform(
                            GuiObject.SHADER,
                            
                            child.rot.y, child.rot.x, child.rot.z,
                            
                            child.rtRotPivot.x, child.rtRotPivot.y, child.rtRotPivot.z, false,
                            
                            child.isRotated3D and child.rtRotPerspective.x or 0,
                            child.isRotated3D and child.rtRotPerspective.y or 0,
                            not child.isRotated3D
                        );
                        
                        dxSetShaderValue(GuiObject.SHADER, "image", child.rt);
                    end
                    
                    dxDrawImage(
                        child.rtPos.x-obj.containerPos.x, child.rtPos.y-obj.containerPos.y,
                        
                        child.rtSize.x, child.rtSize.y,
                        
                        child.isRotated and GuiObject.SHADER or child.rt
                    );
                end
                
                if (child.container) then
                    if (child.isRotated) then
                        dxSetShaderTransform(
                            GuiObject.SHADER,
                            
                            child.rot.y, child.rot.x, child.rot.z,
                            
                            child.containerRotPivot.x, child.containerRotPivot.y, child.containerRotPivot.z, false,
                            
                            child.isRotated3D and child.containerRotPerspective.x or 0,
                            child.isRotated3D and child.containerRotPerspective.y or 0,
                            not child.isRotated3D
                        );
                        
                        dxSetShaderValue(GuiObject.SHADER, "image", child.container);
                    end
                    
                    dxDrawImage(
                        child.containerPos.x-obj.containerPos.x, child.containerPos.y-obj.containerPos.y,
                        
                        child.containerSize.x, child.containerSize.y,
                        
                        child.isRotated and GuiObject.SHADER or child.container
                    );
                end
            end
            
            dxSetRenderTarget();
            
            dxSetBlendMode("blend");
        end
    end
end



function set.parent(obj, parent, prev)
    local success, result = pcall(super.set.parent, obj, parent, prev);
    if (not success) then error(result, 2) end
    
    
    if (prev and Instance.func.isA(prev, "GuiBase2D")) then
        local childrenCount = #prev.guiChildren;
        
        for i = obj.guiIndex+1, childrenCount do
            local child = prev.guiChildren[i];
            
            child.guiIndex = child.guiIndex-1;
            prev.guiChildren[i-1] = child;
        end
        
        prev.guiChildren[childrenCount] = nil;
        
        obj.guiIndex = nil;
        
        
        prev.class.func.update_containerPos(prev);
        prev.class.func.update_container(prev);
        
        
        prev.class.func.draw(prev);
        prev.class.func.propagate(prev);
    end
    
    
    if (parent and Instance.func.isA(parent, "GuiBase2D")) then
        obj.guiIndex = #parent.guiChildren+1;
        parent.guiChildren[obj.guiIndex] = obj;
        
        
        parent.class.func.update_containerPos(parent);
        parent.class.func.update_container(parent);
    end
    
    
    func.update_rootGui(obj, true);
    
    func.update_clipperGui(obj, true);
    
    func.update_absSize(obj, true);
    func.update_absPos(obj, true);
    
    func.update_absRotPivot(obj, true);
    func.update_absRotPerspective(obj, true);
    
    func.update_containerPos(obj, true);
    func.update_container(obj, true);
    func.update_containerRotPivot(obj, true);
    func.update_containerRotPerspective(obj, true);
    
    func.update_rtPos(obj, true);
    func.update_rt(obj, true);
    func.update_rtRotPivot(obj, true);
    func.update_rtRotPerspective(obj, true);
    
    
    func.draw(obj, true);
    func.propagate(obj);
end


function set.clipsDescendants(obj, clipsDescendants)
    local clipsDescendants_t = type(clipsDescendants);
    
    if (clipsDescendants_t ~= "boolean") then
        error("bad argument #1 to 'clipsDescendants' (boolean expected, got " ..clipsDescendants_t.. ")", 2);
    end
    
    
    obj.clipsDescendants = clipsDescendants;
    
    
    func.update_clipperGui(obj, true);
    
    func.update_containerPos(obj, true);
    func.update_container(obj, true);
    func.update_containerRotPivot(obj, true);
    func.update_containerRotPerspective(obj, true);
    
    
    for i = 1, #obj.guiChildren do
        local child = obj.guiChildren[i];
        
        func.update_rtRotPivot(child, true);
        func.update_rtRotPerspective(child, true);
    end
    
    
    func.draw(obj, true);
    func.propagate(obj);
end


function set.bgColor3(obj, bgColor3)
    local bgColor3_t = type(bgColor3);
    
    if (bgColor3_t ~= "Color3") then
        error("bad argument #1 to 'bgColor3' (Color3 expected, got " ..bgColor3_t.. ")", 2);
    end
    
    
    obj.bgColor3 = bgColor3;
    
    
    func.draw(obj);
    func.propagate(obj);
end

function set.bgTransparency(obj, bgTransparency)
    local bgTransparency_t = type(bgTransparency);
    
    if (bgTransparency_t ~= "number") then
        error("bad argument #1 to 'bgTransparency' (number expected, got " ..bgTransparency_t.. ")", 2);
    elseif (bgTransparency < 0) or (bgTransparency > 1) then
        error("bad argument #1 to 'bgTransparency' (value out of bounds)", 2);
    end
    
    
    obj.bgTransparency = bgTransparency;
    
    
    func.draw(obj);
    func.propagate(obj);
end


function set.borderColor3(obj, borderColor3)
    local borderColor3_t = type(borderColor3);
    
    if (borderColor3_t ~= "Color3") then
        error("bad argument #1 to 'borderColor3' (Color3 expected, got " ..borderColor3_t.. ")", 2);
    end
    
    
    obj.borderColor3 = borderColor3;
    
    
    func.draw(obj);
    func.propagate(obj);
end

function set.borderSize(obj, borderSize)
    local borderSize_t = type(borderSize);
    
    if (borderSize_t ~= "number") then
        error("bad argument #1 to 'borderSize' (number expected, got " ..borderSize_t.. ")", 2);
    elseif (borderSize < 0) or (borderSize > MAX_BORDER_SIZE) then
        error("bad argument #1 to 'borderSize' (value out of bounds)", 2);
    end
    
    
    obj.borderSize = math.floor(borderSize);
    
    
    func.update_rtPos(obj, true);
    func.update_rt(obj, true);
    func.update_rtRotPivot(obj, true);
    func.update_rtRotPerspective(obj, true);
    
    
    func.draw(obj, true);
    func.propagate(obj);
end

function set.borderTransparency(obj, borderTransparency)
    local borderTransparency_t = type(borderTransparency);
    
    if (borderTransparency_t ~= "number") then
        error("bad argument #1 to 'borderTransparency' (number expected, got " ..borderTransparency_t.. ")", 2);
    elseif (borderTransparency < 0) or (borderTransparency > 1) then
        error("bad argument #1 to 'borderTransparency' (invalid value)", 2);
    end
    
    
    obj.borderTransparency = borderTransparency;
    
    
    func.draw(obj);
    func.propagate(obj);
end


function set.size(obj, size, prev)
    local size_t = type(size);
    
    if (size_t ~= "UDim2") then
        error("bad argument #1 to 'size' (UDim2 expected, got " ..size_t.. ")", 2);
    end
    
    
    obj.size = size;
    
    
    func.update_absSize(obj, true);
    func.update_absPos(obj, true);
    
    func.update_absRotPivot(obj, true);
    func.update_absRotPerspective(obj, true);
    
    func.update_containerPos(obj, true);
    func.update_container(obj, true);
    func.update_containerRotPivot(obj, true);
    func.update_containerRotPerspective(obj, true);
    
    func.update_rtPos(obj, true);
    func.update_rt(obj, true);
    func.update_rtRotPivot(obj, true);
    func.update_rtRotPerspective(obj, true);
    
    
    func.draw(obj, true);
    func.propagate(obj);
end


function set.pos(obj, pos)
    local pos_t = type(pos);
    
    if (pos_t ~= "UDim2") then
        error("bad argument #1 to 'pos' (UDim2 expected, got " ..pos_t.. ")", 2);
    end
    
    
    obj.pos = pos;
    
    
    func.update_absPos(obj, true);
    
    func.update_absRotPivot(obj, true);
    func.update_absRotPerspective(obj, true);
    
    func.update_containerPos(obj, true);
    func.update_containerRotPivot(obj, true);
    func.update_containerRotPerspective(obj, true);
    
    func.update_rtPos(obj, true);
    func.update_rtRotPivot(obj, true);
    func.update_rtRotPerspective(obj, true);
    
    
    func.draw(obj, true);
    func.propagate(obj);
end

function set.posOrigin(obj, posOrigin)
    local posOrigin_t = type(posOrigin);
    
    if (posOrigin_t ~= "UDim2") then
        error("bad argument #1 to 'pos' (UDim2 expected, got " ..posOrigin_t.. ")", 2);
    end
    
    
    obj.posOrigin = posOrigin;
    
    
    func.update_absPos(obj, true);
    
    func.update_absRotPivot(obj, true);
    func.update_absRotPerspective(obj, true);
    
    func.update_rtPos(obj, true);
    func.update_rtRotPivot(obj, true);
    func.update_rtRotPerspective(obj, true);
    
    if (obj.clipperGui == obj) then
        func.update_containerPos(obj, true);
    end
    
    
    func.draw(obj, true);
    func.propagate(obj);
end


function set.rot(obj, rot, prev)
    local rot_t = type(rot);
    
    if (rot_t ~= "Vector3") then
        error("bad argument #1 to 'rot' (Vector3 expected, got " ..rot_t.. ")", 2);
    end
    
    
    obj.rot = rot;
    
    
    func.update_isRotated(obj);
    func.update_isRotated3D(obj);
    
    func.update_containerRotPivot(obj, true);
    func.update_containerRotPerspective(obj, true);
    
    func.update_rtRotPivot(obj, true);
    func.update_rtRotPerspective(obj, true);
    
    
    func.draw(obj);
    func.propagate(obj);
end

function set.rotPivot(obj, rotPivot, prev)
    local rotPivot_t = type(rotPivot);
    
    if (rotPivot_t ~= "UDim2") then
        error("bad argument #1 to 'rotPivot' (UDim2 expected, got " ..rotPivot_t.. ")", 2);
    end
    
    obj.rotPivot = rotPivot;
    
    
    func.update_absRotPivot(obj, true);
    
    func.update_rtRotPivot(obj, true);
    
    func.update_containerRotPivot(obj, true);
    
    
    func.draw(obj);
    func.propagate(obj);
end

function set.rotPivotDepth(obj, rotPivotDepth, prev)
    local rotPivotDepth_t = type(rotPivotDepth);
    
    if (rotPivotDepth_t ~= "number") then
        error("bad argument #1 to 'rotPivotDepth' (number expected, got " ..rotPivotDepth_t.. ")", 2);
    elseif (rotPivotDepth <= ROT_ACTUAL_NEAR_Z_PLANE/2 or rotPivotDepth > ROT_FAR_Z_PLANE/2) then
        error("bad argument #1 to 'rotPivotDepth' (value out of bounds)", 2);
    end
    
    obj.rotPivotDepth = rotPivotDepth;
    
    
    func.update_isRotated3D(obj);
    
    func.update_absRotPivot(obj, true);
    
    func.update_rtRotPivot(obj, true);
    
    func.update_containerRotPivot(obj, true);
    
    
    func.draw(obj);
    func.propagate(obj);
end

function set.rotPerspective(obj, rotPerspective, prev)
    local rotPerspective_t = type(rotPerspective);
    
    if (rotPerspective_t ~= "UDim2") then
        error("bad argument #1 to 'rotPerspective' (UDim2 expected, got " ..rotPerspective_t.. ")", 2);
    end
    
    
    obj.rotPerspective = rotPerspective;
    
    
    func.update_absRotPerspective(obj, true);
    
    func.update_containerRotPerspective(obj, true);
    
    func.update_rtRotPerspective(obj);
    
    
    func.draw(obj);
    func.propagate(obj);
end


function set.visible(obj, visible, prev)
    local visible_t = type(visible);
    
    if (visible_t ~= "boolean") then
        error("bad argument #1 to 'visible' (boolean expected, got " ..visible_t.. ")", 2);
    end
    
    
    obj.visible = visible;
    
    
    func.update_rt(obj, true);
    
    func.update_container(obj, true);
    
    
    func.draw(obj, true);
    func.propagate(obj);
end



GuiObject = {
    name = name,
    
    super = super,
    
    func = func,
    get  = get,
    set  = set,
    
    event = event,
    
    private  = private,
    readOnly = readOnly,
    
    new = new,
    
    
    RT_ADDITIONAL_MARGIN = RT_ADDITIONAL_MARGIN,
    
    MAX_BORDER_SIZE = MAX_BORDER_SIZE,

    ROT_NEAR_Z_PLANE        = ROT_NEAR_Z_PLANE,
    ROT_ACTUAL_NEAR_Z_PLANE = ROT_ACTUAL_NEAR_Z_PLANE,
    ROT_FAR_Z_PLANE         = ROT_FAR_Z_PLANE,

    ROT_PIVOT_DEPTH_UNIT = ROT_PIVOT_DEPTH_UNIT,
    
    SHADER = SHADER,
}

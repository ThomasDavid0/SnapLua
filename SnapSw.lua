
-- This script handles some snap switching logic that I couldn't figure out how to do with the 

-- The switches selected are stored in a table indexed by switch IDs
local LTRIG = 0
local RTRIG = 1
local LTYPE = 2
local RTYPE = 3
local inputs = {}

local input_names = {[0]="ltrig","rtrig","ltype","rtype"}
local input_descriptions = {[0]="left snap trigger","right snap trigger","left snap type","right snap type"}

-- the values of the switches are stored as individual variables for convenience
local l, r, lp, rp 
local pl=0.0
local pr=0.0

local inputsready = false

-- The main snap states normal, armed, break and autorotation
local NORM = 0
local ARM = 1
local BRK = 2
local AUTO = 3
local state = NORM  -- default state is normal (not snapping)

local lastTime -- time at which the last autorotation finished

-- these variables are setup to track the output controls to display on the form
local snapstate = 0 -- snap, -1=break, 1=autorototate, 0=nothing
local posneg = 0  -- posneg, -1=neg, 1=pos
local direction = 0 -- direction, -1=left, 1=right


local function changeInput(id, value)
    inputs[id] = value
    system.pSave(input_names[id], value)
end


-- TODO this is just debugging information, to be removed or moved to the form
local statenames = {[0]="norm","arm","brk","auto"}  
local actionnames = {[0]="nothing",[-1]="release",[1]="pull"}

local extstatenames = {[-1]="break",[0]='normal',[1]='autorotate'}
local typenames = {[-1]="negative",[0]='none',[1]='positive'}
local directionnames = {[-1]="left",[0]='none',[1]='right'}

local function initForm()
    for i = 0, 3, 1
    do
        form.addRow(2)
        form.addLabel({label=input_descriptions[i]})
        form.addInputbox(inputs[i], true, function(value) changeInput(i, value) end)       
    end
end


local function getSnapSwitchValues()
    if not inputsready then return false else 
        l, r, lp, rp = system.getInputsVal(inputs[0],inputs[1],inputs[2],inputs[3])
        return true
    end
end

local function printForm()
    
    lcd.drawText(10,90,"»internal state« " .. statenames[state], FONT_MINI)
    lcd.drawText(10,100,"»external state« " .. extstatenames[snapstate], FONT_MINI)
    lcd.drawText(10,110,"»direction«      " .. directionnames[direction], FONT_MINI)
    lcd.drawText(10,120,"»type«           " .. typenames[posneg], FONT_MINI)
    inputsready = #inputs == 3
end


local function getAction()
    -- returns 1 for a pull, -1 for a release, default nil
    -- whichever trigger was pulled defines the snap type and direction
    
    if l~=pl then
        posneg=lp
        system.setControl(2, lp, 0, 0) -- posneg, -1=neg, 1=pos
        direction = -1
        system.setControl(3, -1, 0, 0) -- direction, -1=left, 1=right
        pl=l
        return l
    elseif r~=pr then
        posneg=rp
        system.setControl(2, rp, 0, 0) -- posneg, -1=neg, 1=pos
        direction = 1
        system.setControl(3, 1, 0, 0) -- direction, -1=left, 1=right
        pr=r
        return r
    end
    
end


local function arm()
    snapstate=0
    state = ARM
end


local function brk()
    state = BRK 
    snapstate=-1
    system.setControl(1, -1, 0, 0) -- snap, -1=break, 1=autorototate, 0=nothing
end

local function autorotate()
    state = AUTO
    snapstate=1
    system.setControl(1, 1, 0, 0) -- snap, -1=break, 1=autorototate, 0=nothing
end

local function stop()
    state = NORM
    snapstate=0
    lastTime = system.getTimeCounter()
    system.setControl(1, 0, 0, 0) -- snap, -1=break, 1=autorototate, 0=nothing
end

local actions = {
    [1]=function(dt) 
        -- a snap trigger has been pulled
        if state == NORM  then
            if dt <= 1000 then
                autorotate()
            else
                arm()
            end
        elseif state == BRK then
            autorotate()
        end
    
        --what happens if the other trigger is currently pulled?
    
    end,
    [-1]=function(dt)
        -- a snap trigger has been released
        if l + r == -2.0 then
            -- both triggers should be released
            if state == AUTO then
                stop()
            elseif state == ARM then
                brk()
            end
        else
            
            --what happens if the other trigger is currently pulled?
        end
    end
}


local function loop()
    
    if getSnapSwitchValues() then
        action = getAction()
        if action then
            actions[action](system.getTimeCounter() - lastTime)
        end
    end
    
    collectgarbage()
end

local function setupInputs()
    for i = 0, 3, 1
    do
        inputs[i] = system.pLoad(input_names[i], nil)
    end
    
    getSnapSwitchValues()
    pl, pr = l, r   -- initialise the previous values for the triggers

    inputsready = #inputs == 3
end

local function init()
    setupInputs()

    system.registerForm(1,MENU_MAIN,"SnapSwitch - Input form",initForm, nil, printForm)
    
    system.registerControl(1,"snap","SC1"); system.setControl(1, 0, 0, 0) -- snap, -1=break, 1=autorototate, 0=nothing
    system.registerControl(2,"posneg","SC2"); system.setControl(2, 0, 0, 0) -- posneg, -1=neg, 1=pos
    system.registerControl(3,"direction","SC3"); system.setControl(3, 0, 0, 0) -- direction, -1=left, 1=right
    
    lastTime = system.getTimeCounter()

end
--------------------------------------------------------------------------------
return {init=init, loop=loop, author="Tom David", version="1.0"}
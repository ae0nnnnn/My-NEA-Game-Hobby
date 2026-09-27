local StateMachine  = {}
StateMachine.__index =  StateMachine


export type StateDef = {
    Enter: ((obj:any) -> ())?,
    Update:((obj:any, dt:number) -> string?)?,
    Exit: ((obj:any) -> ())?,

}

export type StateMachine = {
    States: {[string]: StateDef},
    Current: string,
    TimeInState: number,
    Object: any,
    _new: boolean,
    GetState: (self: StateMachine) -> string,
    Update: (self: StateMachine, dt: number) -> (),
    TransitionTo: (self: StateMachine, nextState: string) -> (),
}



function StateMachine.new(states:{[string]:StateDef},initial:string, obj:any) : StateMachine
    assert(states[initial]~= nil, "[StateMachine] initial state '" .. tostring(initial) .. "' not found")

    local self = setmetatable({
        States = states,
        Current = initial,
        TimeInState = 0,
        Object = obj,
        _new = true
    }, StateMachine) :: any

    local def = states[initial]

    if def.Enter then
        def.Enter(obj)
    end
    self._new = false
    return self :: StateMachine
end

function StateMachine:GetState(): string
    return self.Current
end

function StateMachine:TransitionTo(nextState: string)
    local curDef = self.States[self.Current]

    if curDef and curDef.Exit then
        curDef.Exit(self.Object)
    end

    local prev = self.Current
    self.Current = nextState
    self.TimeInState = 0
    self._new = true

    --- Debug for testing
    print(("[StateMachine] %s -> %s"):format(prev,nextState))
    local nextDef = self.States[nextState]
    assert(nextDef ~= nil, "[StateMachine] unknown state '" .. tostring(nextState) .. "'")

    if nextDef.Enter then
        nextDef.Enter(self.Object)
    end

    self._new = false
end

function StateMachine:Update(deltaT: number)
    self.TimeInState += deltaT
    local def = self.States[self.Current]
    if not def or not def.Update then return end 
    local nextState = def.Update(self.Object, deltaT)
    if nextState and nextState ~= self.Current then
        self:TransitionTo(nextState)
    end
end


return StateMachine
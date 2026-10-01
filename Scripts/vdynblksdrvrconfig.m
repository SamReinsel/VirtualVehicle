function [varargout]= vdynblksdrvrconfig(varargin)
%
%   Copyright 2018-2026 The MathWorks, Inc.

block = varargin{1};
varargout{1} = {};
model=bdroot(block);
simStopped = autoblkschecksimstopped(block) && ~(strcmp(get_param(model,'SimulationStatus'),'initializing'));
driverType = get_param(block,'driverType');

% @todo update the usage of edit-time filter filterOutInactiveVariantSubsystemChoices()
% instead use the post-compile filter activeVariants() - g2598330
if simStopped
    switch driverType
        case 'Longitudinal Driver'
            check=VirtualAssembly.getVDBInfo(model);
            if ~check
                set_param([model,'/Driver Commands/Driver Commands'],'LabelModeActiveChoice',driverType);
            else
                set_param([model,'/Driver Commands/Driver Commands'],'LabelModeActiveChoice',[driverType,' VDB']);
            end
            SwitchInport(block,'Steer','Ground',[]);
            SwitchInport(block,'Accel','Ground',[]);
            SwitchInport(block,'Brake','Ground',[]);
            SwitchInport(block,'Gear','Ground',[]);
        case 'Predictive Driver'
            set_param([block,'/Driver Commands'],'LabelModeActiveChoice',driverType);
            SwitchInport(block,'Steer','Ground',[]);
            SwitchInport(block,'Accel','Ground',[]);
            SwitchInport(block,'Brake','Ground',[]);
            SwitchInport(block,'Gear','Ground',[]);
        case 'Open Loop'
            set_param([block,'/Driver Commands'],'LabelModeActiveChoice',driverType);
            SwitchInport(block,'Steer','Inport',[]);
            SwitchInport(block,'Accel','Inport',[]);
            SwitchInport(block,'Brake','Inport',[]);
            SwitchInport(block,'Gear','Inport',[]);
        otherwise
            set_param([block,'/Driver Commands'],'LabelModeActiveChoice',driverType);
    end
end
end
function SwitchInport(Block, PortName, UsePort,Param)
%% Switch inport
InportOption  = {'built-in/Constant', [PortName 'Constant'];...
    'built-in/Inport', PortName;...
    'simulink/Sinks/Terminator',[PortName 'Terminator'];...
    'simulink/Sinks/Out1', PortName;...
    'built-in/Ground',[PortName 'Ground']};
switch UsePort
    case 'Constant'
        Newblock = autoblksreplaceblock(Block, InportOption, 1);
        set_param(Newblock, 'Value',Param);
    case 'Terminator'
        autoblksreplaceblock(Block, InportOption, 3);
    case 'Outport'
        autoblksreplaceblock(Block, InportOption, 4);
    case 'Inport'
        autoblksreplaceblock(Block, InportOption, 2);
    case 'Ground'
        autoblksreplaceblock(Block, InportOption, 5);
end

end

function autoblkVVCOpenScnMask()

%   Copyright 2024-2026 The MathWorks, Inc.

block=gcb;
simstopped = autoblkschecksimstopped(block);
if ~simstopped
    return;
end
VehSys=bdroot(block);
maskobj = Simulink.Mask.get(block);
maneuver=maskobj.Parameters(2);

check=VirtualAssembly.getVDBInfo(VehSys);

switch maneuver.Value
    case 'Drive Cycle'
        if ~check
            path=[VehSys,'/Scenarios/Reference Generator/Drive Cycle/Drive Cycle Source'];
        else
            path=[VehSys,'/Scenarios/Reference Generator/Drive Cycle VDB/Drive Cycle Source'];
        end
    case 'Wide Open Throttle'
        if ~check
            path=[VehSys,'/Scenarios/Reference Generator/WOT/Drive Cycle Source'];
        else
            path=[VehSys,'/Scenarios/Reference Generator/WOT VDB/Drive Cycle Source'];
        end
    otherwise
        path=[VehSys,'/Scenarios/Reference Generator/',maneuver.Value,'/',maneuver.Value];
end

open_system(path, 'mask');
end
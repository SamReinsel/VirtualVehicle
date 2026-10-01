function varargout = GenerateMappedEngineCalibrations(varargin)
%% Setup

% Copyright 2018-2025 The MathWorks, Inc.
Block = varargin{1};
if nargin>2
    vvcflag=varargin{3};
    fig=varargin{4};
else
    vvcflag=false;
    fig=[];
end
isMBCInstalled = CheckMBCLicense(Block);
varargout{1} = 0;
if isMBCInstalled || strcmp('SpreadsheetFileNameSelect', varargin{2})
    switch varargin{2}
        case 'SpreadsheetFileNameSelect'
            SpreadsheetFileNameSelect(Block);
        case 'GenMappedEngCalButton'
            varargout{1}= GenMappedEngCalButton(Block,vvcflag,fig);
        case 'CheckMBCLicense'
            CheckMBCLicense(Block);
        case 'OpenMBCFiles'
            OpenMBCFiles(Block);
        case 'Init'
            CheckMBCLicense(Block);
        case 'EnableCalToolButton'
            EnableCalToolButton(Block);
    end
end
end

function SetGenMappedEngCalButton(Block,status)
maskObj = Simulink.Mask.get(Block);
GenMappedEngCalButton = maskObj.getDialogControl('GenMappedEngCalButton');
if status
    GenMappedEngCalButton.Enabled='on';
else
    GenMappedEngCalButton.Enabled='off';
end
end



%% ExcelFileNameSelect
function SpreadsheetFileNameSelect(Block)
try
    [~,~,~] = fileparts(get_param(Block,'DataFile'));
catch
    warndlg('Calibration file may not be in current folder', ...
        'Input file warning','replace')
end
[file,path] = uigetfile({'*.xlsx;*.xls;*.csv'});
dataFile = [path,file];
if ~ischar(file)
    return;
end
if exist(dataFile,'file') == 2
    set_param(Block,'DataFile',dataFile)
    [~,nam,ext] = fileparts(dataFile);
    set_param(Block,'SpreadsheetFileName',[nam,ext])
else
    warndlg('The specified Excel file does not exist.', 'File Not Found');
end

end

function PlotCalibratedMap(Block,mbcfuncnam)
%get buttonlist of the block and evaluate button callback functions
maskObj = Simulink.Mask.get(Block);
buttonlist = autosharedicon(mbcfuncnam,Block,'ButtonList');

for j=2:numel(buttonlist)
    ctl=maskObj.getDialogControl(buttonlist{j});
    callback=ctl.Callback;
    newCall = replace(callback,'gcb,','Block,');
    eval(newCall);
    drawnow();
end
end


%% GenMappedEngCalButton
function BlockParams=GenMappedEngCalButton(Block,vvcflag,fig)
try
    dynamometerpath=pwd;
    [datafilepath,~,~] = fileparts(get_param(Block,'DataFile'));
    cd(datafilepath);
catch ME
    warndlg('Calibration file may not be in current folder', ...
        'Input file warning','replace')
end
MaskObj = get_param([bdroot(Block),'/Subsystem5'],'MaskObject');
MappedEngMdlRefName = MaskObj.getParameter('MappedEngMdlRefName').Value;
isSI = strcmp(MappedEngMdlRefName, 'SiMappedEngine');
dataFile = MaskObj.getParameter('DataFile').Value;
wkspvarnam = MaskObj.getParameter('MbcTaskList').Value;
engsys = [bdroot(Block),'/Engine System'];
engplant = [engsys,'/Engine Plant/Engine'];

if ~isSI
    trqOrFuel=get_param([engplant,'/CI Mapped Engine/Mapped CI Engine'],'InputCmdPopup');
end

if isSI
    mbcfuncnam = 'autolibsimappedengine';
    mapengblk = 'Mapped SI Engine';
    engfile = 'SiMappedEngine';
else
    mbcfuncnam = 'autolibcimappedengine';
    mapengblk = 'Mapped CI Engine';
    engplant = [engsys,'/Engine Plant/Engine'];
    sw=[engplant,'/CI Mapped Engine/Engine Load Source Switch'];
    if bdIsLoaded('EngineDynamometer')
        engsys = [bdroot(Block),'/Engine System'];        
        trqOrFuel = ...
            get_param([engplant,'/CI Mapped Engine/Mapped CI Engine'], ...
            'InputCmdPopup');
        %set switch for fuel mass mode
        if strcmp(trqOrFuel,'Torque')
            set_param(sw,'sw','1');
        else
            set_param(sw,'sw','0');
        end
    else
        trqOrFuel = 'Torque';
        set_param(sw,'sw','1');
    end

    engfile = 'CiMappedEngine';
end

% Set mapped engine variant
if isSI && ~strcmp(get_param(engplant,'ActiveVariant'),'SI Mapped Engine')
    set_param(engplant,'LabelModeActiveChoice','SI Mapped Engine')
end
if ~isSI && ~strcmp(get_param(engplant,'ActiveVariant'),'CI Mapped Engine')
    set_param(engplant,'LabelModeActiveChoice','CI Mapped Engine')
end

% Start cal from data app
MappedEngineBlock=[engplant,'/',get_param(engplant,'ActiveVariant'),'/',mapengblk];

if ~vvcflag
    hwb = waitbar(0,'Calibrating from data, please wait');
    waitbar(0.1,hwb);
else
    hwb = uiprogressdlg(fig,'Title','Please wait',...
        'Message','Calibrating from data');
    hwb.Value = .1;
end

% Apply mask changes
blockh = get_param(Block,'Handle');
dialgs = DAStudio.ToolRoot.getOpenDialogs;
for i=1:length(dialgs)
    if class(dialgs(i).getSource) == "Simulink.SLDialogSource"
        if blockh == dialgs(i).getSource.getBlock.Handle
            dialgs(i).apply;
        end
    end
end

try
    CalibrationTasks = autosharedicon(mbcfuncnam,MappedEngineBlock, ...
        'CalMapsButtonCallback',true);
    if ~isSI
        CalibrationTasks=CalibrationTasks.ChildTasks;
    end
catch ME
    errordlg(ME.message,'Run MBC error','replace');
    return;
end

TaskList=CalibrationTasks.ChildTasks;
TaskList(end).BaseMbcProject.WorkDir=datafilepath;
TaskList(end).BaseCageProject.WorkDir=datafilepath;
assignin('base',wkspvarnam,TaskList)

TaskComplete=zeros(1,length(TaskList));
ChildrenTaskList={'Importing Firing Data','Importing NonFiring Data', ...
    'Generating Response Models','Generating Calibration', ...
    'Updating Block Parameters'};

for i=1:length(TaskList)
    try
        if ~vvcflag
            waitbar(0.2*i,hwb,ChildrenTaskList{i});
        else
            hwb.Value=0.15*i;
            hwb.Message=ChildrenTaskList{i};
        end

        if i<3
            TaskList(i).TaskFcn(dataFile);
            TaskList(i).GetStatusFcn();
        elseif i==length(TaskList)
            DataOut=TaskList(i).TaskFcn();
            TaskList(i).GetStatusFcn();
            TaskList(i).Completed=1;

            %Update steady-state testing torque and speed ranges for new
            %to cover the range of the new mapped engine calibration
            DdObj = Simulink.data.dictionary.open('EngineDynamometer.sldd');
            DdSection = DdObj.getSection('Design Data');

            if isSI
                [~,spdind]=intersect(DataOut.ParamNames,'f_tbrake_n_bpt');
                SiDynoSSSpdCmdVect=linspace(0,max(DataOut.ParamValues{spdind}(:)),15);
                [~,tqind]=intersect(DataOut.ParamNames,'f_tbrake');
                SiDynoSSTrqCmdVect=linspace(0,max(DataOut.ParamValues{tqind}(:)),15);
                [SiDynoSSSpdCmd,SiDynoSSTrqCmd]=meshgrid(SiDynoSSSpdCmdVect,SiDynoSSTrqCmdVect);
                DdSection.assignin('SiDynoSSSpdCmd',SiDynoSSSpdCmd)
                DdSection.assignin('SiDynoSSTrqCmd',SiDynoSSTrqCmd)
            else
                [~,tqind]=intersect(DataOut.ParamNames,'f_tbrake');
                CiDynoSSTrqCmdVect=linspace(0,max(DataOut.ParamValues{tqind}(:)),15);
                [~,spdind]=intersect(DataOut.ParamNames,'f_tbrake_n_bpt');
                CiDynoSSSpdCmdVect=linspace(0,max(DataOut.ParamValues{spdind}(:)),15);
                [CiDynoSSSpdCmd,CiDynoSSTrqCmd]=meshgrid(CiDynoSSSpdCmdVect,CiDynoSSTrqCmdVect);
                DdSection.assignin('CiDynoSSSpdCmd',CiDynoSSSpdCmd)
                DdSection.assignin('CiDynoSSTrqCmd',CiDynoSSTrqCmd)
            end

            cd(dynamometerpath);

        else
            TaskList(i).TaskFcn();
            TaskList(i).GetStatusFcn();
        end


        if ~TaskList(i).Completed || ~isempty(TaskList(i).ErrorMsg) || ...
                ~isempty(TaskList(i).WarningMsg)
            TaskComplete(i)=0;
            break;
        else
            TaskComplete(i)=1;
        end

    catch ME
        cd(dynamometerpath);
        errordlg(ME.message,'Run MBC Tasks error','replace');
        close(hwb);
        break;
    end

end

if all(TaskComplete)
    BlockParams=DataOut;

    for i=1:length(BlockParams.ParamNames)
        pname=get_param(MappedEngineBlock,BlockParams.ParamNames{i});
        BlockParams.ParamNames{i}=pname;
    end

    % Mapped by MBC Tagging
    set_param(MappedEngineBlock, 'Tag', 'MappedEngCalByMBC')
    set_param(engsys,'Position',get_param(engsys,'Position'))

    % Run simulation
    if ~vvcflag
        if isSI
            DynamometerStart(gcb, 'SteadyState');
        else
            if strcmp(trqOrFuel,'Torque')
                DynamometerStart(gcb, 'SteadyState');
            else
                DynamometerStart(gcb,'CalCtrl');
            end
        end
    else
        % VVC workflow
        hwb.Value=0.8;
        hwb.Message='Rebuilding models...';
        StdyStBlk=[bdroot(Block),'/Dynamometer Control/Steady State/'];
        if isSI
            BlockParams.ParamNames{end+1}='SiDynoSSSpdCmd';
            BlockParams.ParamNames{end+1}='SiDynoSSTrqCmd';
            BlockParams.ParamValues{end+1}=SiDynoSSSpdCmd;
            BlockParams.ParamValues{end+1}=SiDynoSSTrqCmd;

            if ~strcmp(get_param(StdyStBlk,'ssWait'),'SiDynoSSWaitLim')
                set_param(StdyStBlk,'ssWait','SiDynoSSWaitLim');
            end
            if ~strcmp(get_param(StdyStBlk,'engSpdCmd'),'SiDynoSSSpdCmd')
                set_param(StdyStBlk,'engSpdCmd','SiDynoSSSpdCmd');
            end
            if ~strcmp(get_param(StdyStBlk,'trqCmd'),'SiDynoSSTrqCmd')
                set_param(StdyStBlk,'trqCmd','SiDynoSSTrqCmd');
            end

            DynamometerStart(gcb, 'SteadyStateNoMsk');
        else

            BlockParams.ParamNames{end+1}='CiDynoSSSpdCmd';
            BlockParams.ParamNames{end+1}='CiDynoSSTrqCmd';
            BlockParams.ParamValues{end+1}=CiDynoSSSpdCmd;
            BlockParams.ParamValues{end+1}=CiDynoSSTrqCmd;

            if ~strcmp(get_param(StdyStBlk,'ssWait'),'CiDynoSSWaitLim')
                set_param(StdyStBlk,'ssWait','CiDynoSSWaitLim');
            end
            if ~strcmp(get_param(StdyStBlk,'engSpdCmd'),'CiDynoSSSpdCmd')
                set_param(StdyStBlk,'engSpdCmd','CiDynoSSSpdCmd');
            end
            if ~strcmp(get_param(StdyStBlk,'trqCmd'),'CiDynoSSTrqCmd')
                set_param(StdyStBlk,'trqCmd','CiDynoSSTrqCmd');
            end


            if strcmp(trqOrFuel,'Torque')
                DynamometerStart(gcb, 'SteadyStateNoMsk');
            else
                DynamometerStart(gcb,'CalCtrlNoMsk');
            end
        end
    end

    save_system(engfile,'OverwriteIfChangedOnDisk',true, ...
        'SaveDirtyReferencedModels',true);

    PlotCalibratedMap(MappedEngineBlock,mbcfuncnam);
    EnableCalToolButton(Block);
else
    index=find(~TaskComplete);
    if index(1)==1
        msg='Please select engine data compatible with firing mode.';
    elseif index(1)==2
        msg='Please select engine data compatible with non-firing mode.';
    else
        msg=[ChildrenTaskList{index(1)} ' failed!'];
    end

    errordlg(msg);
end

if ~vvcflag
    waitbar(1,hwb);
else
    hwb.Value=1;
end
close(hwb);

end

%% OpenMBCFiles
function OpenMBCFiles(Block)
startingdir=pwd;
MaskObj = Simulink.Mask.get(Block);
wkspvarnam = MaskObj.getParameter('MbcTaskList').Value;
inappname='f_tbrake';
isthere = evalin('base',['exist(','''',wkspvarnam,''',''var'') == 1']);
if isthere
    TaskList = evalin('base',['',wkspvarnam,'']);
else
    warning('No MBC task list in base workspace!');
    return;
end
try
    if ~isempty(TaskList(end).BaseMbcProject.WorkDir)
        cd(TaskList(end).BaseMbcProject.WorkDir);
    end
    TaskList(end-2).ViewChildInApp(inappname);
catch
    warning('Invalid MBCMODEL project!');
end
try
    if ~isempty(TaskList(end).BaseCageProject.WorkDir)
        cd(TaskList(end).BaseCageProject.WorkDir);
    end
    TaskList(end-1).ViewChildInApp(inappname);
catch
    warning('Invalid CAGE project!');
end
cd(startingdir);
end

function SetCalToolButton(Block,status)
MaskObj = Simulink.Mask.get(Block);
OpenCalToolButton = MaskObj.getDialogControl('OpenCalToolButton');
if status
    OpenCalToolButton.Enabled = 'on';
else
    OpenCalToolButton.Enabled = 'off';
end
end

%% EnableCalToolButton
function EnableCalToolButton(Block)
MaskObj = Simulink.Mask.get(Block);
wkspvarnam = MaskObj.getParameter('MbcTaskList').Value;
isthere = evalin('base',['exist(','''',wkspvarnam,''',''var'') == 1']);
if isthere
    SetCalToolButton(Block,true);
else
    SetCalToolButton(Block,false);
end
end

%% CheckMBCLicense
function isMBCInstalled = CheckMBCLicense(Block)
MaskObj = Simulink.Mask.get(Block);
MBCIconImg = MaskObj.getDialogControl('MBCIconImg');

if license('test', 'MBC_Toolbox')
    MBCIconImg.Enabled = 'on';
    MBCIconImg.Visible = 'on';
    isMBCInstalled = true;
    SetGenMappedEngCalButton(Block,true);
else
    MBCIconImg.Enabled = 'off';
    MBCIconImg.Visible = 'off';
    isMBCInstalled = false;
    SetCalToolButton(Block,false);
    SetGenMappedEngCalButton(Block,false);
end
end

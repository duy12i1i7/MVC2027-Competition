function build_tcs_reference(model, Vehicle, Wheel, Motor, Sim)
% Public experimental TCS/ABS reference; no contest-specific road preview.
% Preserve upstream steering, yaw control and d-axis current logic.
meso = [model '/Energy Management & Motion Control Strategy'];
assert(getSimulinkBlockHandle(meso)>0,'MESO not found');
src = [meso '/Switch'];
dst = [meso '/Demux'];
sensor = [meso '/Sensor'];
assert(getSimulinkBlockHandle(src)>0 && getSimulinkBlockHandle(dst)>0 && getSimulinkBlockHandle(sensor)>0,'Unexpected MESO layout');
pSrc = get_param(src,'PortHandles');
pDst = get_param(dst,'PortHandles');
pSensor = get_param(sensor,'PortHandles');
line = get_param(pDst.Inport(1),'Line');
assert(line ~= -1 && get_param(line,'SrcPortHandle') == pSrc.Outport(1),'Unexpected original torque wiring');

% Delay only allowed sensor signals by one simulation sample to break direct
% feedthrough. Stateless limiter inherits the upstream torque update rate.
delay = [meso '/Public TCS Sensor Delay'];
limiter = [meso '/Public Reference TCS'];
add_block('simulink/Discrete/Unit Delay',delay,'SampleTime',num2str(Sim.Ts,17),...
    'InitialCondition','0','Position',[100 140 150 175]);
add_block('simulink/User-Defined Functions/MATLAB Function',limiter,...
    'Position',[175 325 245 390]);
chart = find(sfroot,'-isa','Stateflow.EMChart','Path',limiter);
assert(isscalar(chart),'MATLAB Function chart not found');
template = fileread(fullfile(fileparts(mfilename('fullpath')),'tcs_reference.txt'));
chart.Script = sprintf(template,Wheel.R,Vehicle.d,Vehicle.lf,Vehicle.lr,Motor.Tmax_f,Motor.Tmax_r);
pDelay = get_param(delay,'PortHandles');
pLim = get_param(limiter,'PortHandles');
assert(numel(pLim.Inport)==2 && numel(pLim.Outport)==1,'Incorrect limiter port count');
delete_line(meso,'Switch/1','Demux/1');
add_line(meso,pSrc.Outport(1),pLim.Inport(1),'autorouting','on');
add_line(meso,pSensor.Outport(1),pDelay.Inport(1),'autorouting','on');
add_line(meso,pDelay.Outport(1),pLim.Inport(2),'autorouting','on');
add_line(meso,pLim.Outport(1),pDst.Inport(1),'autorouting','on');
end

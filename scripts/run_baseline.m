% MVC2027 public benchmark harness. Runs in base workspace like main.m.
% Do not submit this harness; upstream model and scoring files are unmodified.
strategy_id = str2double(getenv('MVC_STRATEGY'));
wind_id = str2double(getenv('MVC_WIND'));
road_id = str2double(getenv('MVC_ROAD'));
assert(ismember(strategy_id,[1 2]) && ismember(wind_id,[0 1]) && ismember(road_id,[0 1]), 'Invalid benchmark case');
assert(strcmp(version('-release'),'2022b'),'R2022b required');
source_dir = getenv('MVC_SOURCE');
output_dir = getenv('MVC_OUTPUT');
assert(isfolder(source_dir) && ~isempty(output_dir),'Missing source/output path');
if ~isfolder(output_dir), mkdir(output_dir); end
diary(fullfile(output_dir,'matlab.log'));
set(groot,'defaultFigureVisible','off');
cd(source_dir);
flag.wind = wind_id;
flag.road = road_id;
control_strategy = strategy_id;
sim_para;
driving_condition;
meso_para;
sigma = [1 60 3 10];
close all;
timer_start = tic;
simout = sim('MVC27_Sim.slx');
elapsed_seconds = toc(timer_start);
scoring;
copyfile(filename, fullfile(output_dir,'official_score.txt'));

% Evaluation-only diagnostics. These signals are NOT controller inputs.
t = simout.time(:);
vx = simout.Vx(:);
vref = simout.Vx_ref(:);
posx = simout.Pos_X(:);
posy = simout.Pos_Y(:);
accy = simout.ay(:);
power = simout.P_in(:);
efficiency = simout.DWPT_efficient(:);
slip = [simout.lambda_FR(:),simout.lambda_FL(:),simout.lambda_RR(:),simout.lambda_RL(:)];
assert(numel(t)>1 && all(diff(t)>=0),'Invalid simulation time');
assert(all(isfinite([t,vx,vref,posx,posy,accy,power,efficiency,slip]),'all'),'Non-finite logged signal');
assert(all(isfinite([Phi1 Phi2 Phi3 Phi4 Phi])),'Non-finite official score');
assert(abs(Phi - [Phi1 Phi2 Phi3 Phi4]*sigma(:)) < 1e-7*max(1,abs(Phi)), 'Score mismatch');
metrics = struct();
metrics.upstream_sha = getenv('MVC_UPSTREAM_SHA');
metrics.release = version('-release');
metrics.matlab_version = version;
metrics.strategy = strategy_id;
metrics.wind = wind_id;
metrics.road = road_id;
metrics.Phi1 = Phi1;
metrics.Phi2 = Phi2;
metrics.Phi3 = Phi3;
metrics.Phi4 = Phi4;
metrics.Phi = Phi;
metrics.elapsed_seconds = elapsed_seconds;
metrics.sample_count = numel(t);
metrics.final_time_s = t(end);
metrics.expected_time_s = Sim.Tsim;
metrics.reached_simulation_end = t(end) >= Sim.Tsim - 2*Sim.Ts;
metrics.max_abs_y_m = max(abs(posy));
metrics.lateral_limit_pass = metrics.max_abs_y_m <= 5;
metrics.final_x_m = posx(end);
metrics.reference_distance_m = trapz(t,vref);
metrics.distance_error_m = metrics.final_x_m - metrics.reference_distance_m;
metrics.final_vx_mps = vx(end);
metrics.speed_rmse_mps = sqrt(mean((vx-vref).^2));
metrics.slip_peak_FR_FL_RR_RL = max(abs(slip),[],1);
metrics.slip_rms_FR_FL_RR_RL = sqrt(mean(slip.^2,1));
metrics.time_outside_dwpt_lateral_s = sum(abs(posy)>0.07)*Sim.Ts;
metrics.dwpt_received_Wh = sum(simout.DWPT_power(:))*Sim.Ts/3600;
metrics.ay_rms_mps2 = sqrt(mean(accy.^2));
fid = fopen(fullfile(output_dir,'metrics.json'),'w');
assert(fid>=0,'Cannot write metrics');
fprintf(fid,'%s\n',jsonencode(metrics,'PrettyPrint',true));
fclose(fid);
% Full-resolution diagnostic signals, compressed in MAT format.
save(fullfile(output_dir,'signals.mat'),'t','vx','vref','posx','posy','accy','power','efficiency','slip','-v7');
% Plotting data at approximately 100 Hz, with final sample retained.
idx = unique([1:50:numel(t),numel(t)]);
trace = table(t(idx),vx(idx),vref(idx),posx(idx),posy(idx),accy(idx),power(idx),efficiency(idx),slip(idx,1),slip(idx,2),slip(idx,3),slip(idx,4),...
    'VariableNames',{'time_s','vx_mps','vref_mps','x_m','y_m','ay_mps2','power_W','dwpt_pct','slip_FR','slip_FL','slip_RR','slip_RL'});
writetable(trace,fullfile(output_dir,'trace.csv'));
try
    fig = figure('Visible','off','Position',[100 100 1200 900]);
    tiledlayout(3,2);
    nexttile; plot(t(idx),[vref(idx),vx(idx)]); legend('Reference','Actual'); ylabel('Speed (m/s)'); grid on;
    nexttile; plot(t(idx),slip(idx,:)); legend('FR','FL','RR','RL'); ylabel('Slip ratio'); grid on;
    nexttile; plot(t(idx),posy(idx)); hold on; yline(0.07,'--'); yline(-0.07,'--'); ylabel('Lateral position (m)'); grid on;
    nexttile; plot(t(idx),accy(idx)); ylabel('Lateral acceleration (m/s^2)'); grid on;
    nexttile; plot(t(idx),power(idx)); ylabel('Drivetrain power (W)'); xlabel('Time (s)'); grid on;
    nexttile; plot(t(idx),efficiency(idx)); ylabel('DWPT efficiency (%)'); xlabel('Time (s)'); grid on;
    exportgraphics(fig,fullfile(output_dir,'diagnostics.png'),'Resolution',120);
    close(fig);
catch plot_error
    warning('Diagnostic plot failed: %s',plot_error.message);
end
disp(jsonencode(metrics));
diary off;
assert(metrics.reached_simulation_end,'Simulation ended before requested time');
assert(metrics.lateral_limit_pass,'Lateral displacement exceeds 5 m');
% Reaching the simulation end is NOT proof of completing the driving cycle.

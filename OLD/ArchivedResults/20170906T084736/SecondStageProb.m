%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Scramjet Flight Optimiser
% By Sholto Forbes-Spyratos
% Utilises the DIDO proprietary optimisation software
% startup.m must be run before this file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all;
clc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Set Globals %%==========================================================
global interp
global Stage1
global Stage2
global Stage3

% Counts iterations of DIDO
global iterative_V
iterative_V = [];
global iterative_t
iterative_t = [];
global iteration
iteration = 1;
global iterative_V_f
iterative_V_f = [];

%% Atmosphere Data %%======================================================
interp.Atmosphere = dlmread('atmosphere.txt');

%% Import Vehicle and trajectory Config Data %%============================
addpath('../')
run VehicleConfig.m
run TrajectoryConfig50kPa.m

%%
% Copy the current setting to archive
% This saves the entire problem file every time the program is run. 

Timestamp = datestr(now,30)
mkdir('../ArchivedResults', sprintf(Timestamp))
copyfile('SecondStageProb.m',sprintf('../ArchivedResults/%s/SecondStageProb.m',Timestamp))
copyfile('SecondStageCost.m',sprintf('../ArchivedResults/%s/SecondStageCost.m',Timestamp))

%%
% =========================================================================
% SET RUN MODE
% =========================================================================
% Change const to set the target of the simulation. Much of the problem
% definition changes with const.

% const = 1x: No end constraint, used for optimal trajectory calculation
% const = 1: 50kPa limit, 12: 55 kPa limit, 13: 45 kPa limit, 14: 50kPa limit & 10% additional drag

% const = 3: Fuel mass is constrained at end point, used for constant
% dynamic pressure calculation (50kPa constrained)
% const = 31: simple model for guess calc 
% 32: Higher velocity

global const
const = 14

%% Aerodynamic Data - Communicator %%======================================
% Take inputs of aerodynamic communicator matrices, these should be .txt files 
% This is used for forward simulation. 
communicator = importdata('communicator.txt');
communicator_trim = importdata('communicator_trim.txt');

interp.flapdeflection_spline = scatteredInterpolant(communicator_trim(:,1),communicator_trim(:,2),communicator_trim(:,4),communicator_trim(:,3));
interp.flapdrag_spline = scatteredInterpolant(communicator_trim(:,1),communicator_trim(:,2),communicator_trim(:,4),communicator_trim(:,5));
interp.flaplift_spline = scatteredInterpolant(communicator_trim(:,1),communicator_trim(:,2),communicator_trim(:,4),communicator_trim(:,6));

[MList,AOAList] = ndgrid(unique(communicator(:,1)),unique(communicator(:,2)));
Cl_Grid = reshape(communicator(:,3),[length(unique(communicator(:,2))),length(unique(communicator(:,1)))]).';
Cd_Grid = reshape(communicator(:,4),[length(unique(communicator(:,2))),length(unique(communicator(:,1)))]).';
pitchingmoment_Grid = reshape(communicator(:,11),[length(unique(communicator(:,2))),length(unique(communicator(:,1)))]).';

interp.Cl_spline = griddedInterpolant(MList,AOAList,Cl_Grid,'spline','linear');
interp.Cd_spline = griddedInterpolant(MList,AOAList,Cd_Grid,'spline','linear');
interp.pitchingmoment_spline = griddedInterpolant(MList,AOAList,pitchingmoment_Grid,'spline','linear');

%% Vehicle Aerodynamics - Liftarray %%=====================================
% This produces interp interpolants which can calculate the vehicle
% settings required for trim at any flight conditions
% This is used in the optimisation routine.

liftarray = dlmread('liftarray'); % read array generated by LiftForceMAT.m

[vList,altList,liftList] = ndgrid(unique(liftarray(:,1)),unique(liftarray(:,2)),unique(liftarray(:,3)));

AoA_Grid = permute(reshape(liftarray(:,4),[length(unique(liftarray(:,3))),length(unique(liftarray(:,2))),length(unique(liftarray(:,1)))]),[3 2 1]);
interp.AoA = griddedInterpolant(vList,altList,liftList,AoA_Grid,'spline','linear');

flapdeflection_Grid = permute(reshape(liftarray(:,5),[length(unique(liftarray(:,3))),length(unique(liftarray(:,2))),length(unique(liftarray(:,1)))]),[3 2 1]);
interp.flapdeflection = griddedInterpolant(vList,altList,liftList,flapdeflection_Grid,'spline','linear');

Drag_Grid = permute(reshape(liftarray(:,6),[length(unique(liftarray(:,3))),length(unique(liftarray(:,2))),length(unique(liftarray(:,1)))]),[3 2 1]);
interp.drag = griddedInterpolant(vList,altList,liftList,Drag_Grid,'spline','linear');

Flap_pitchingmoment_Grid = permute(reshape(liftarray(:,7),[length(unique(liftarray(:,3))),length(unique(liftarray(:,2))),length(unique(liftarray(:,1)))]),[3 2 1]);
interp.flap_pm = griddedInterpolant(vList,altList,liftList,Flap_pitchingmoment_Grid,'spline','linear');

interp.flap_def = scatteredInterpolant(communicator_trim(:,1),communicator_trim(:,2),communicator_trim(:,4),communicator_trim(:,3));
interp.flap_D = scatteredInterpolant(communicator_trim(:,1),communicator_trim(:,2),communicator_trim(:,4),communicator_trim(:,5));
interp.pm = scatteredInterpolant(communicator(:,1),communicator(:,2),communicator(:,11));

clear liftarray % liftarray can be very large, clear from memory





%% Conical Shock Data %%===================================================
% Import conical shock data and create interpolation splines 
shockdata = dlmread('ShockMat');
[MList,AOAList] = ndgrid(unique(shockdata(:,1)),unique(shockdata(:,2)));
M1_Grid = reshape(shockdata(:,3),[length(unique(shockdata(:,2))),length(unique(shockdata(:,1)))]).';
pres_Grid = reshape(shockdata(:,4),[length(unique(shockdata(:,2))),length(unique(shockdata(:,1)))]).';
temp_Grid = reshape(shockdata(:,5),[length(unique(shockdata(:,2))),length(unique(shockdata(:,1)))]).';
interp.M1gridded = griddedInterpolant(MList,AOAList,M1_Grid,'spline','linear');
interp.presgridded = griddedInterpolant(MList,AOAList,pres_Grid,'spline','linear');
interp.tempgridded = griddedInterpolant(MList,AOAList,temp_Grid,'spline','linear');


%% Engine Data %%==========================================================
% Import engine data
interp.engine_data = dlmread('ENGINEDATA.txt');  % reads four columns; Mach no after conical shock, temp after conical shock, Isp, max equivalence ratio
engine_data = interp.engine_data;

% Create uniform grid of Mach no. and temperature values. 
M_englist = unique(sort(engine_data(:,1))); % create unique list of Mach numbers from engine data
M_eng_interp = unique(sort(engine_data(:,1)));

T_englist = unique(sort(engine_data(:,2))); % create unique list of angle of attack numbers from engine data
T_eng_interp = unique(sort(engine_data(:,2)));

[grid.Mgrid_eng,grid.T_eng] =  ndgrid(M_eng_interp,T_eng_interp);

% Set the equivalence ratio interpolation region %-------------------------
% VERY IMPORTANT

% The interpolators have trouble with equivalence ratio because its equal
% to 1 over a certain Mach no. (causes error in interpolator, as the
% interpolator will find values of equivalence ratio < 1 where they should
% not exist)

% This makes anything outside of the region where it is actually changing
% extrapolate to over 1 (which is then set to 1 by RESTM12int)

% the the maximum of this to around where equivalence ratio stops changing,
% and check the end results

eq_data = [];
j=1;
for i = 1: length(engine_data(:,1))
    if engine_data(i,1) < 5.
        eq_data(j,:) = engine_data(i,:);
        j=j+1;
    end
end

interp.equivalence = scatteredInterpolant(eq_data(:,1),eq_data(:,2),eq_data(:,4), 'linear');
grid.eq_eng = interp.equivalence(grid.Mgrid_eng,grid.T_eng);
interp.eqGridded = griddedInterpolant(grid.Mgrid_eng,grid.T_eng,grid.eq_eng,'linear','linear');

% Load the interpolated Isp data %-----------------------------------------

% gridIsp_eng is the spline interpolated data set created by
% engineint.m and engineinterpolator.exe

load gridIsp_eng
grid.Isp_eng = gridIsp_eng;

% gridIsp_eng may have sections at which the Isp is 0. The following finds
% these, and fills them in with linearly intepolated values.
Isp_interpolator = scatteredInterpolant(engine_data(:,1),engine_data(:,2),engine_data(:,3));

for i = 1:30 % must match engineint.m
    for j= 1:30
        % grid.Isp_eng(i,j) = polyvaln(p,[grid.Mgrid_eng(i,j) grid.T_eng(i,j)]);
        if any(grid.Isp_eng(i,j)) == false
            grid.Isp_eng(i,j) = Isp_interpolator(grid.Mgrid_eng(i,j), grid.T_eng(i,j));
        end
    end
end

interp.IspGridded = griddedInterpolant(grid.Mgrid_eng,grid.T_eng,grid.Isp_eng,'spline','spline');


%% Import Payload Data %%==================================================

% Import third stage data as arrays. the third stage data should be in thirdstage.dat
% columns: Altitude (m) , Trajectory angle (rad) , velocity (m/s) , payload-to-orbit (kg)

% The PS routine must be able to search over a relatively large solution
% space for all primal variables end states, so there must be a
% payload-to-orbit solution at every possible end state.

ThirdStageData = dlmread('thirdstage.dat'); %Import Third Stage Data Raw 
ThirdStageData = sortrows(ThirdStageData);

% Interpolate for Missing Third Stage Points %-----------------------------
% Be careful with this. 
[VGrid,gammaGrid,vGrid] = ndgrid(unique(ThirdStageData(:,3)),unique(ThirdStageData(:,4)),unique(ThirdStageData(:,5))); % must match the data in thirdstage.dat

PayloadDataInterp = scatteredInterpolant(ThirdStageData(:,3),ThirdStageData(:,4),ThirdStageData(:,5),ThirdStageData(:,6)); % interpolate for missing third stage points

PayloadData = PayloadDataInterp(VGrid,gammaGrid,vGrid);
global PayloadGrid
PayloadGrid = griddedInterpolant(VGrid,gammaGrid,vGrid,PayloadData,'spline','linear');

%% Import Bounds %%========================================================
% Primal Bounds
bounds.lower.states = [Stage2.Bounds.Alt(1); Stage2.Bounds.v(1); Stage2.Bounds.gamma(1); Stage2.Bounds.mFuel(1); Stage2.Bounds.gammadot(1); Stage2.Bounds.zeta(1)];
bounds.upper.states = [Stage2.Bounds.Alt(2); Stage2.Bounds.v(2); Stage2.Bounds.gamma(2); Stage2.Bounds.mFuel(2); Stage2.Bounds.gammadot(2); Stage2.Bounds.zeta(2)];

% Control Bounds
bounds.lower.controls = Stage2.Bounds.control(1);
bounds.upper.controls = Stage2.Bounds.control(2); 

% Time Bounds
bounds.lower.time 	= [0; Stage2.Bounds.time(1)];	
bounds.upper.time	= [0; Stage2.Bounds.time(2)];



% if const == 32
%     v0 = 1580.8
% elseif const == 15
%     v0 = 1596
% else
% v0 = 1520; 
% end

%% Define Events
% This defines set values along the trajectory.
% These correspond to the values in SecondStageEvents.m

% Zetaf = 1.78;
% 
% gammaf = deg2rad(1.5);

% if const ==3 || const == 32
% bounds.lower.events = [v0/scale.v; mfuelU/scale.m; mfuelL/scale.m; Zetaf; gammaf];  % constrains initial values, final fuel and end altitude and trajectory angle within the bounds of thirdstage.dat
% bounds.upper.events = bounds.lower.events;      % equality event function bounds 
% else
% bounds.lower.events = [v0/scale.v; mfuelU/scale.m; mfuelL/scale.m; Zetaf; min(ThirdStageData(:,3)); min(ThirdStageData(:,4))];  % constrains initial values, final fuel and end altitude and trajectory angle within the bounds of thirdstage.dat
% bounds.upper.events = [v0/scale.v; mfuelU/scale.m; mfuelL/scale.m; Zetaf; max(ThirdStageData(:,3)); max(ThirdStageData(:,4))];
% % bounds.upper.events = bounds.lower.events;      % equality event function bounds
% end

bounds.lower.events = [Stage2.Initial.v; Stage2.Initial.mFuel; Stage2.End.mFuel; Stage2.End.Zeta; Stage2.End.gammaOpt(1)];
bounds.upper.events = [Stage2.Initial.v; Stage2.Initial.mFuel; Stage2.End.mFuel; Stage2.End.Zeta; Stage2.End.gammaOpt(2)];

%% Define Path Constraints
% This limits the dynamic pressure.
if const == 1 || const == 14 || const == 15
    bounds.lower.path = [0; 0];
    bounds.upper.path = [50000 ;9];
elseif const == 12
    bounds.lower.path = [0 ;0];
    bounds.upper.path = [55000 ;9];
elseif const == 13
    bounds.lower.path = [0 ;0];
    bounds.upper.path = [45000; 9];
elseif const ==3 || const == 32
        bounds.lower.path = [0 ;0];
    bounds.upper.path = [50010; 9];
end
%% 
%============================================
% Define the problem using DIDO expresssions:
%============================================
% Call the files whih DIDO uses
TwoStage2d.cost 		= 'SecondStageCost';
TwoStage2d.dynamics	    = 'SecondStageDynamics';
TwoStage2d.events		= 'SecondStageEvents';	
TwoStage2d.path         = 'SecondStagePath';
TwoStage2d.bounds       = bounds;


%% Node Definition ====================================================
% The number of nodes is important to the problem solution. 
% While any number should theoretically work, in practice the choice of
% node number can have a large effect on results.
% Usually between 80-100 works. The best node no. must be found using trial and error approach.

% Always try a variety of node values

if const == 3 || const == 31 || const == 32
    algorithm.nodes		= [101]; 
elseif const == 1
    algorithm.nodes		= [104];
elseif const == 12 
    algorithm.nodes		= [103]; 
elseif const == 13
    algorithm.nodes		= [103]; 
elseif const == 14
    algorithm.nodes		= [101];
elseif const == 15
    algorithm.nodes		= [101];
end

global nodes

nodes = algorithm.nodes;


%%  Guess =================================================================
%     
% % Altitude Guess. This is the most important guess, and should be close to
% % the expected end solution. It is good for this end guess to be lower than
% % expected.
% if const == 1 || const == 15
%     guess.states(1,:) = [interp1(Atmosphere(:,4),Atmosphere(:,1),2*50000/v0^2)-100 ,33500 ]; 
% elseif const == 12
%     guess.states(1,:) = [interp1(Atmosphere(:,4),Atmosphere(:,1),2*55000/v0^2)-100 ,34000];
% elseif const == 13
%     guess.states(1,:) = [interp1(Atmosphere(:,4),Atmosphere(:,1),2*45000/v0^2)-100 ,34000];
% elseif const == 14
%     guess.states(1,:) = [interp1(Atmosphere(:,4),Atmosphere(:,1),2*50000/v0^2)-100 ,33000]; 
% elseif const ==3
%     guess.states(1,:) =[interp1(Atmosphere(:,4),Atmosphere(:,1),2*50000/v0^2)-100,32000 ]/scale.V; 
% elseif const == 32
%    guess.states(1,:) =[interp1(Atmosphere(:,4),Atmosphere(:,1),2*50000/v0^2)-100,33000 ] ;
% end
% 
% % Velocity Guess. This should be relatively close to the end solution.
% if const == 32
%     guess.states(2,:) = [v0, 2970];
% else
% guess.states(2,:) = [v0, 2900];
% end
% 
% % Trajectory angle guess. 
% if const == 3
%  guess.states(3,:) = [0.0,0.0];   
% else
% % guess.states(3,:) = [0.05,0.05];
% % guess.states(3,:) = [0.00,0.09];
% guess.states(3,:) = [0.0,deg2rad(4.5)];
% end
% 
% % Mass guess. Simply the exact values at beginning and end (also constraints).
% guess.states(4,:) = [mfuelU, 0]/scale.m;
% 
% % Trajectory angle change rate guess. Keep at 0.
% guess.states(5,:) = [0,0];
% 
% % Heading angle guess. End defined. Start should be close to expected.
% if const == 14
%     guess.states(6,:) = [1.682,1.69];
% else
%     guess.states(6,:) = [1.682,1.699];
% end
% % Control guess. Keep at 0. Not important. 
% guess.controls(1,:)    = [0,0]; 
% 
% % Time guess. This should be close to expected
% guess.time        = [t0 ,360];

guess.states(1,:)   = Stage2.Guess.Alt;
guess.states(2,:)   = Stage2.Guess.v;
guess.states(3,:)   = Stage2.Guess.gamma;
guess.states(4,:) 	= Stage2.Guess.mFuel;
guess.states(5,:)   = Stage2.Guess.gammadot;
guess.states(6,:)   = Stage2.Guess.zeta;
guess.controls      = Stage2.Guess.control;
guess.time          = Stage2.Guess.time;

% Tell DIDO the guess
%========================
algorithm.guess = guess;
%=====================================================================================

%% Start Iterative Plot
figure(10)
plot(linspace(guess.time(1),guess.time(2),algorithm.nodes),linspace(guess.states(1,1),guess.states(1,2),algorithm.nodes),'k')
iterative_V(end+1,:) = linspace(guess.states(1,1),guess.states(1,2),algorithm.nodes);
iterative_t(end+1,:) = linspace(guess.time(1),guess.time(2),algorithm.nodes);

filename = 'testnew51.gif';
frame = getframe(10);
im = frame2im(frame);
[imind,cm] = rgb2ind(im,256);
imwrite(imind,cm,filename,'gif', 'Loopcount',0);


%% Call DIDO
% This is where all the work is done
% =====================================================================
tStart= cputime;    % start CPU clock 
[cost, primal, dual] = dido(TwoStage2d, algorithm);

%%

EndTime = datestr(now,30) % Display the ending time

% =========================================================================
% Assign the primal variables
V = primal.states(1,:);

v = primal.states(2,:);

t = primal.nodes;

gamma = primal.states(3,:);

mfuel = primal.states(4,:);

gammadot = primal.states(5,:);

zeta = primal.states(6,:);

omegadot = primal.controls(1,:);

% =========================================================================

%% Third Stage
% Optimise third stage trajectory from end point

global phi

cd('../ThirdStage')
[ThirdStagePayloadMass,ThirdStageControls,ThirdStageZeta,ThirdStagePhi,ThirdStageAlt,ThirdStagev,ThirdStaget,ThirdStageAlpha,ThirdStagem,ThirdStagegamma,ThirdStageq] = ThirdStageOptm(V(end),gamma(end),v(end), phi(end),zeta(end), 1);
ThirdStagePayloadMass
cd('../SecondStage')
% ThirdStagePayloadMass = 0;


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%          OUTPUT             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

global dfuel
dfuel

global M
global q
global a

global Engine
global Vehicle

eq = Engine.eq;
Thrust = Engine.Thrust;
Fueldt = Engine.Fueldt;

Fd = Vehicle.Fd;
Alpha = Vehicle.Alpha;
lift = Vehicle.lift;
flapdeflection = Vehicle.flapdeflection;

Thrust = Thrust./cos(deg2rad(Alpha)); % change thrust to account for total thrust, including portion that contributes to lift

dt = t(2:end)-t(1:end-1); % Time change between each node pt
FuelUsed = zeros(1,nodes-1);
FuelUsed(1) = dt(1)*Fueldt(1);
for i = 2:nodes-1
    FuelUsed(i) = dt(i).*Fueldt(i) + FuelUsed(i-1);
end


% figure out horizontal motion
H(1) = 0;
for i = 1:nodes-1
H(i+1) = v(i)*(t(i+1) - t(i))*cos(gamma(i)) + H(i);
end

Separation_LD = lift(end)/Fd(end)

figure(201)

subplot(5,5,[1,10])
hold on
plot(H, V)
plot(H(algorithm.nodes(1)), V(algorithm.nodes(1)), '+', 'MarkerSize', 10, 'MarkerEdgeColor','r')
title('Trajectory (m)')

dim = [.7 .52 .2 .2];
annotation('textbox',dim,'string',{['Payload Mass: ', num2str(ThirdStagePayloadMass), ' kg'],['Second Stage Fuel Used: ' num2str(1000 - mfuel(end)) ' kg']},'FitBoxToText','on');  


subplot(5,5,11)
hold on
plot(t, v)
plot(t(algorithm.nodes(1)), v(algorithm.nodes(1)), '+', 'MarkerSize', 10, 'MarkerEdgeColor','r')
title('Velocity (m/s)')


subplot(5,5,12)
plot(t, M)
title('Mach no')

subplot(5,5,13)
plot(t, q)
title('Dynamic Pressure (pa)')

subplot(5,5,14)
hold on
plot(t, rad2deg(gamma))
plot(t(algorithm.nodes(1)), rad2deg(gamma(algorithm.nodes(1))), '+', 'MarkerSize', 10, 'MarkerEdgeColor','r')
title('Trajectory Angle (Deg)')



subplot(5,5,15)
plot(t, Fd)
title('Drag Force')

subplot(5,5,16)
hold on
plot(t, mfuel + 8755.1 - 994)
title('Vehicle Mass (kg)')



subplot(5,5,17)
plot(t, Thrust)
title('Thrust (N)')

Isp = Thrust./Fueldt./9.81;
IspNet = (Thrust-Fd)./Fueldt./9.81;

subplot(5,5,18)
plot(t, Isp)
title('Isp')

subplot(5,5,19)
plot(t, IspNet)
title('Net Isp')

subplot(5,5,20)
plot(t, flapdeflection)
title('Flap Deflection (deg)')

subplot(5,5,21)
plot(t, Alpha)
title('Angle of Attack (deg)')

subplot(5,5,22);
plot(t, dual.dynamics);
title('costates')
xlabel('time');
ylabel('costates');
legend('\lambda_1', '\lambda_2', '\lambda_3');

subplot(5,5,23)
Hamiltonian = dual.Hamiltonian(1,:);
plot(t,Hamiltonian);
title('Hamiltonian')

subplot(5,5,24)
hold on
plot(t, rad2deg(gammadot))
title('Trajectory Angle Change Rate (Deg/s)')

subplot(5,5,25)
hold on
plot(t, rad2deg(omegadot))
title('Omegadot Control (Deg/s2)')


dim = [.8 .0 .2 .2];
annotation('textbox',dim,'string',{['Third Stage Thrust: ', num2str(50), ' kN'],['Third Stage Starting Mass: ' num2str(2850) ' kg'],['Third Stage Isp: ' num2str(350) ' s']},'FitBoxToText','on');  

figure(202)
sp1 = subplot(2,6,[1,6]);
ax1 = gca; % current axes
hold on
plot(H/1000, V/1000,'Color','k')

title('Trajectory')
xlabel('Earth Normal Distance Flown (km)')
ylabel('Vertical Position (km)')

for i = 1:floor(t(end)/30)
    [j,k] = min(abs(t-30*i));
    str = strcat(num2str(round(t(k))), 's');
    text(H(k)/1000,V(k)/1000,str,'VerticalAlignment','top', 'FontSize', 10);
    
    plot(H(k)/1000, V(k)/1000, '+', 'MarkerSize', 10, 'MarkerEdgeColor','k')
end

plot(H(end)/1000, V(end)/1000, 'o', 'MarkerSize', 10, 'MarkerEdgeColor','k')

text(H(end)/1000,V(end)/1000,'Third Stage Transition Point','VerticalAlignment','top', 'FontSize', 10);

dim = [.65 .45 .2 .2];
annotation('textbox',dim,'string',{['Payload Mass: ', num2str(ThirdStagePayloadMass,4), ' kg'],['Second Stage Fuel Used: ' num2str(mfuel(1) - mfuel(end)) ' kg']},'FitBoxToText','on');  

thirdstageexample_H = [0+H(end) (H(end)-H(end - 1))+H(end) 20*(H(end)-H(end - 1))+H(end) 40*(H(end)-H(end - 1))+H(end) 60*(H(end)-H(end - 1))+H(end) 80*(H(end)-H(end - 1))+H(end)]/1000; %makes a small sample portion of an arbitrary third stage trajectory for example
thirdstageexample_V = [0+V(end) (V(end)-V(end - 1))+V(end) 20*((V(end)-V(end -1)))+V(end) 40*((V(end)-V(end -1)))+V(end) 60*((V(end)-V(end -1)))+V(end) 80*((V(end)-V(end -1)))+V(end)]/1000;
plot(thirdstageexample_H, thirdstageexample_V, 'LineStyle', '--','Color','k');

hold on
sp2 = subplot(2,6,[7,9]);
xlabel('time (s)')

hold on
ax2 = gca; % current axes
xlim([min(t) max(t)]);

line(t, rad2deg(gamma),'Parent',ax2,'Color','k', 'LineStyle','-')

line(t, M,'Parent',ax2,'Color','k', 'LineStyle','--')

line(t, v./(10^3),'Parent',ax2,'Color','k', 'LineStyle','-.')

line(t, q./(10^4),'Parent',ax2,'Color','k', 'LineStyle',':', 'lineWidth', 2.0)

% line(t, heating_rate./(10^5),'Parent',ax1,'Color','k', 'LineStyle',':', 'lineWidth', 2.0)
% 
% line(t, Q./(10^7),'Parent',ax1,'Color','k', 'LineStyle','-', 'lineWidth', 2.0)

% legend(ax1,  'Trajectory Angle (degrees)', 'Mach no', 'Velocity (m/s x 10^3)', 'Dynamic Pressure (Pa x 10^4)',  'Q (Mj x 10)')
h = legend(ax2,  'Trajectory Angle (degrees)', 'Mach no', 'Velocity (m/s x 10^3)', 'Dynamic Pressure (Pa x 10^4)');
rect1 = [0.12, 0.35, .25, .25];
set(h, 'Position', rect1)


sp3 = subplot(2,6,[10,12]);
xlabel('time (s)')
ax3 = gca;
xlim([min(t) max(t)]);
line(t, [Alpha(1:end-1) Alpha(end-1)],'Parent',ax3,'Color','k', 'LineStyle','-')

line(t, [flapdeflection(1:end-1) flapdeflection(end-1)],'Parent',ax3,'Color','k', 'LineStyle','--')


% line(t, mfuel./(10^2),'Parent',ax2,'Color','k', 'LineStyle','-.')
line(t, eq.*10,'Parent',ax3,'Color','k', 'LineStyle','-.')

line(t, IspNet./(10^2),'Parent',ax3,'Color','k', 'LineStyle',':', 'lineWidth', 2.0)

% g = legend(ax2, 'AoA (degrees)','Flap Deflection (degrees)', 'Fuel Mass (kg x 10^2)', 'Net Isp (s x 10^2)');
g = legend(ax3, 'AoA (degrees)','Flap Deflection (degrees)', 'Equivalence Ratio x 10', 'Net Isp (s x 10^2)');

rect2 = [0.52, 0.35, .25, .25];
set(g, 'Position', rect2)

saveas(figure(202),[sprintf('../ArchivedResults/%s',Timestamp),filesep,'SecondStage.fig']);

% 
% dat_temp1 = get(ax1,'children');
% fig_temp1 = figure;
% ax_temp1 = axes;
% temp_fig1 = copyobj(dat_temp1,ax_temp1);
% title('Trajectory')
% xlabel('Earth Normal Distance Flown (km)')
% ylabel('Vertical Position (km)')
% dim = [.55 .15 .2 .2];
% annotation('textbox',dim,'string',{['Payload Mass: ', num2str(ThirdStagePayloadMass,4), ' kg'],['Second Stage Fuel Used: ' num2str(mfuel(1) - mfuel(end)) ' kg']},'FitBoxToText','on');  
%  set(fig_temp1, 'Position', [100, 100, 900, 400]);
%  saveas(fig_temp1,[pwd sprintf('../ArchivedResults/%s/FlightPath',Timestamp)]);
%  close fig_temp1;
%  
% dat_temp2 = get(ax2,'children');
% fig_temp2 = figure;
% ax_temp2 = axes;
% temp_fig2 = copyobj(dat_temp2,ax_temp2);
%  set(fig_temp2, 'Position', [100, 100, 900, 400]);
%  h = legend(ax_temp2,  'Trajectory Angle (degrees)', 'Mach no', 'Velocity (m/s x 10^3)', 'Dynamic Pressure (Pa x 10^4)');
% rect1 = [0.22, 0.85, .25, .25];
% % set(h, 'Position', rect1)
% set(h,'location','bestoutside')
% xlabel('time (s)')
 
 
% temp_fig3 = copyobj(sp3,ax3);
%  set(FigHandle, 'Position', [100, 100, 900, 400]);

figure(203)

subplot(2,5,[1,5]);

line(t, dual.dynamics(1,:),'Color','k', 'LineStyle','-');
line(t, dual.dynamics(2,:),'Color','k', 'LineStyle','--');
line(t, dual.dynamics(3,:),'Color','k', 'LineStyle','-.');
line(t, dual.dynamics(4,:),'Color','k', 'LineStyle',':');
line(t, dual.dynamics(5,:),'Color','k', 'LineStyle','-','LineWidth',2);
title('costates')
xlabel('time');
ylabel('Costates');
% axis([0,t(end),-1,1])
legend('\lambda_1', '\lambda_2', '\lambda_3', '\lambda_4','\lambda_5');

subplot(2,5,[6,10])
Hamiltonian = dual.Hamiltonian(1,:);
plot(t,Hamiltonian,'Color','k');
axis([0,t(end),-1,1])
title('Hamiltonian')


% save results
dlmwrite('primal.txt', [primal.states;primal.controls;primal.nodes;q;IspNet;Alpha;M;eq;flapdeflection;phi]);
dlmwrite('payload.txt', ThirdStagePayloadMass);
dlmwrite('dual.txt', [dual.dynamics;dual.Hamiltonian]);
dlmwrite('ThirdStage.txt',[ThirdStageZeta;ThirdStagePhi;ThirdStageAlt;ThirdStagev;ThirdStaget;[ThirdStageAlpha 0];ThirdStagem;ThirdStagegamma;[ThirdStageq 0]]);
dlmwrite('LD.txt', Separation_LD);


copyfile('primal.txt',sprintf('../ArchivedResults/%s/primal_%s.txt',Timestamp,Timestamp))
copyfile('dual.txt',sprintf('../ArchivedResults/%s/dual_%s.txt',Timestamp,Timestamp))
copyfile('payload.txt',sprintf('../ArchivedResults/%s/payload_%s.txt',Timestamp,Timestamp))
copyfile('ThirdStage.txt',sprintf('../ArchivedResults/%s/ThirdStage_%s.txt',Timestamp,Timestamp))
copyfile('LD.txt',sprintf('../ArchivedResults/%s/LD_%s.txt',Timestamp,Timestamp))
primal_old = primal;

ts = timeseries(Isp,t);
Mean_Isp = mean(ts)

% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% TESTING AND VALIDATION
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% If these are valid then solution is a KKT point

%COMPLEMENTARY CONDITIONS
% These should be zero if the state or control is within set bounds
% <=0 if at min bound, >=0 if at max bound

mu_1 = dual.states(1,:);
mu_2 = dual.states(2,:);
mu_3 = dual.states(3,:);
mu_4 = dual.states(4,:);
mu_5 = dual.states(5,:);

mu_u = dual.controls; % NOTE: This deviates from 0, as the controls are set as a buffer. Do not set a parameter directly tied to the vehicle model as the control.

%GRADIENT NORMALITY CONDITION

% Lagrangian of the Hamiltonian 
dLHdu = dual.dynamics(3,:) + mu_u; % 

figure(205)

plot(t,dLHdu,t,mu_1,t,mu_2,t,mu_3,t,mu_4,t,mu_5,t,mu_u);
legend('dLHdu','mu_1','mu_2','mu_3','mu_4','mu_5','mu_u');
title('Validation')
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% FORWARD INTEGRATION
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% This simply tests that the system dynamics hold, as the
% Pseudospectral method may not converge to a realistic
% solution



gamma_F = cumtrapz(t,gammadot)+ gamma(1);

gammadot_F = cumtrapz(t,omegadot) + gammadot(1);


v_F = cumtrapz(t,a);
v_F = v_F + v(1);

V_F = cumtrapz(t,v_F.*sin(gamma_F));
V_F = V_F + V(1);

mfuel_F = cumtrapz(t,-Fueldt);
mfuel_F = mfuel_F + mfuel(1);

figure(206)

subplot(5,1,1)
plot(t,gamma_F,t,gamma);
title('Forward Simulation Comparison');
% note this is just a trapezoidal rule check, may not be exactly accurate
subplot(5,1,2)
plot(t,v_F,t,v);
subplot(5,1,3)
plot(t,V_F,t,V);
subplot(5,1,4)
plot(t,mfuel_F,t,mfuel);
subplot(5,1,4)
plot(t,gammadot_F,t,gammadot);

% Compute difference with CADAC for constant dynamic pressure path

t_diff = t - [0 t(1:end-1)];
if const == 3
    CADAC_DATA = dlmread('TRAJ.ASC');
    CADAC_Alpha = interp1(CADAC_DATA(:,2),CADAC_DATA(:,4),M(1:68)); % 1:68 gives mach numbers that align, may need to change this
    CADAC_V = interp1(CADAC_DATA(:,2),CADAC_DATA(:,11),M(1:68));
    MeanError_V = sum(abs(CADAC_V - V(1:68))./V(1:68).*t_diff(1:68))/t(end)
    MeanError_Alpha = sum(abs(CADAC_Alpha - Alpha(1:68))./Alpha(1:68).*t_diff(1:68))/t(end)
end

% if PayloadGrid(phi(end),zeta(end),V(end)+10,gamma(end),v(end)) - PayloadGrid(phi(end),zeta(end),V(end),gamma(end),v(end)) < 0
%     disp('Check Third Stage Payload Matrix, May Have Found False Maxima')
% end
if PayloadGrid(V(end)+10,gamma(end),v(end)) - PayloadGrid(V(end),gamma(end),v(end)) < 0
    disp('Check Third Stage Payload Matrix, Found Maxima')
end

% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% FORWARD SIMULATION
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

% This is a full forward simulation, using the angle of attack and flap
% deflection at each node.

% Note, because the nodes are spaced widely, small interpolation
% differences result in the forward simulation being slightly different
% than the actual. This is mostly a check to see if they are close. 

forward0 = [V(1),phi(1),gamma(1),v(1),zeta(1),mstruct+mThirdStage+mfuelU];

% [f_t, f_y] = ode45(@(f_t,f_y) ForwardSim(f_y,AlphaInterp(t,Alpha,f_t),communicator,communicator_trim,SPARTAN_SCALE,Atmosphere,const,interp),t,forward0);
[f_t, f_y] = ode45(@(f_t,f_y) ForwardSim(f_y,AlphaInterp(t,Alpha,f_t),communicator,communicator_trim,SPARTAN_SCALE,Atmosphere,const,interp,AlphaInterp(t,lift,f_t),AlphaInterp(t,Fd,f_t),AlphaInterp(t,Thrust,f_t),AlphaInterp(t,flapdeflection,f_t)),t(1:end),forward0);

figure(212)
subplot(7,1,[1 2])
hold on
plot(f_t(1:end),f_y(:,1));
plot(t,V);

subplot(7,1,3)
hold on
plot(f_t(1:end),f_y(:,2));
plot(t,phi);

subplot(7,1,4)
hold on
plot(f_t(1:end),f_y(:,3));
plot(t,gamma);

subplot(7,1,5)
hold on
plot(f_t(1:end),f_y(:,4));
plot(t,v);

subplot(7,1,6)
hold on
plot(f_t(1:end),f_y(:,5));
plot(t,zeta);

subplot(7,1,7)
hold on
plot(f_t(1:end),f_y(:,6));
plot(t,mstruct+mThirdStage+mfuel);

%% plot engine interpolation visualiser
T0 = spline( Atmosphere(:,1),  Atmosphere(:,2), V); 
T1 = interp.tempgridded(M,Alpha).*T0;
M1 = interp.M1gridded(M, Alpha);

plotM = [min(M_englist):0.01:9.5];
plotT = [min(T_englist):1:550];
[gridM,gridT] =  ndgrid(plotM,plotT);
interpeq = interp.eqGridded(gridM,gridT);
interpIsp = interp.IspGridded(gridM,gridT);

figure(210)
hold on
contourf(gridM,gridT,interpeq);
scatter(engine_data(:,1),engine_data(:,2),30,engine_data(:,4),'filled');
plot(M1,T1,'r');

error_Isp = interp.IspGridded(engine_data(:,1),engine_data(:,2))-engine_data(:,3);

figure(211)
hold on
contourf(gridM,gridT,interpIsp);
scatter(engine_data(:,1),engine_data(:,2),30,engine_data(:,3),'filled')
plot(M1,T1,'r');

%%
[gridM2,gridAoA2] =  ndgrid(plotM,plotT);



% Run First Stage =========================================================
cd('../FirstStage')
[FirstStageStates] = FirstStageProblem(V(1),gamma(1),phi(1),zeta(1),const);
cd('../SecondStage')
dlmwrite('FirstStage.txt', FirstStageStates);
copyfile('FirstStage.txt',sprintf('../ArchivedResults/%s/firststage_%s.txt',Timestamp,Timestamp))


%% Latitude Plot
figure(250)
plot(FirstStageStates(:,9))
plot(phi)
plot(ThirdStagePhi)
title('Latitude')

%% SAVE FIGS
saveas(figure(301),[sprintf('../ArchivedResults/%s',Timestamp),filesep,'ThirdStage.fig']);
saveas(figure(101),[sprintf('../ArchivedResults/%s',Timestamp),filesep,'FirstStage.fig']);
%%

% =========================================================================
% Troubleshooting Procedure
% =========================================================================

% 1: Check that you have posed your problem correctly ie. it is physically
% feasible and the bounds allow for a solution
% 2: Check for NaN values (check derivatives in Dynamics file while running)
% 3: Check guess, is it reasonable? Is it too close to the expected
% solution? Both can cause errors! Sometimes there is no real rhyme or
% reason to picking the correct guess, but a close bound to
% the expected solution has worked the most in my experience
% 4: Play with the no. of nodes, try both even and odd values
% 5: Play with scaling
% 6: Try all of the above in various combinations until it works!






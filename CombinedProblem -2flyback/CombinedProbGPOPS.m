%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Scramjet Flight Optimiser
% By Sholto Forbes-Spyratos
% Utilises the DIDO proprietary optimisation software
% startup.m must be run before this file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all;
clc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
addpath('..\thirdStage-GPOPS')
addpath('..\SecondStage\EngineData')
addpath('..\SecondStage\SecondStageAscent')
addpath('..\SecondStageReturn')
%% Atmosphere Data %%======================================================
Atmosphere = dlmread('atmosphere.txt');
interp.Atmosphere = Atmosphere;
auxdata.interp.Atmosphere = interp.Atmosphere;

auxdata.interp.c_spline = spline( interp.Atmosphere(:,1),  interp.Atmosphere(:,5)); % Calculate speed of sound using atmospheric data

auxdata.interp.rho_spline = spline( interp.Atmosphere(:,1),  interp.Atmosphere(:,4)); % Calculate density using atmospheric data

auxdata.interp.p_spline = spline( interp.Atmosphere(:,1),  interp.Atmosphere(:,3)); % Calculate density using atmospheric data

auxdata.interp.T0_spline = spline( interp.Atmosphere(:,1),  interp.Atmosphere(:,2)); 

auxdata.interp.P0_spline = spline( interp.Atmosphere(:,1),  interp.Atmosphere(:,3)); 

%% Import Vehicle and trajectory Config Data %%============================
addpath('../')
run VehicleConfig.m
run TrajectoryConfig50kPa.m

auxdata.Stage3 = Stage3;
auxdata.Stage2 = Stage2;


%%
auxdata.Re   = 6371203.92;                     % Equatorial Radius of Earth (m)

auxdata.A = 62.77; %m^2
%%
% Copy the current setting to archive
% This saves the entire problem file every time the program is run. 

% Timestamp = datestr(now,30)
% mkdir('../ArchivedResults', sprintf(Timestamp))
% copyfile('SecondStageProb.m',sprintf('../ArchivedResults/%s/SecondStageProb.m',Timestamp))
% copyfile('SecondStageCost.m',sprintf('../ArchivedResults/%s/SecondStageCost.m',Timestamp))

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


const = 1
auxdata.const = const;
%% Aerodynamic Data - Communicator %%======================================
% Take inputs of aerodynamic communicator matrices, these should be .txt files 
% This is used for forward simulation. 
communicator = importdata('communicator.txt');
communicator_trim = importdata('communicator_trim.txt');

auxdata.interp.flapdeflection_spline = scatteredInterpolant(communicator_trim(:,1),communicator_trim(:,2),communicator_trim(:,4),communicator_trim(:,3));
auxdata.interp.flapdrag_spline = scatteredInterpolant(communicator_trim(:,1),communicator_trim(:,2),communicator_trim(:,4),communicator_trim(:,5));
auxdata.interp.flaplift_spline = scatteredInterpolant(communicator_trim(:,1),communicator_trim(:,2),communicator_trim(:,4),communicator_trim(:,6));

[MList,AOAList] = ndgrid(unique(communicator(:,1)),unique(communicator(:,2)));
Cl_Grid = reshape(communicator(:,3),[length(unique(communicator(:,2))),length(unique(communicator(:,1)))]).';
Cd_Grid = reshape(communicator(:,4),[length(unique(communicator(:,2))),length(unique(communicator(:,1)))]).';
pitchingmoment_Grid = reshape(communicator(:,11),[length(unique(communicator(:,2))),length(unique(communicator(:,1)))]).';

auxdata.interp.Cl_spline1 = griddedInterpolant(MList,AOAList,Cl_Grid,'spline','linear');
auxdata.interp.Cd_spline1 = griddedInterpolant(MList,AOAList,Cd_Grid,'spline','linear');
auxdata.interp.pitchingmoment_spline1 = griddedInterpolant(MList,AOAList,pitchingmoment_Grid,'spline','linear');

%% Aerodynamic Data 
%%
% aero = importdata('SPARTANaero.txt');
% 
% interp.Cl_scattered2 = scatteredInterpolant(aero(:,1),aero(:,2),aero(:,3));
% interp.Cd_scattered2 = scatteredInterpolant(aero(:,1),aero(:,2),aero(:,4));
% 
% 
% [MList2,AOAList2] = ndgrid(unique(aero(:,1)),unique(aero(:,2)));
% % Cl_Grid = reshape(aero(:,3),[length(unique(aero(:,2))),length(unique(aero(:,1)))]).';
% % Cd_Grid = reshape(aero(:,4),[length(unique(aero(:,2))),length(unique(aero(:,1)))]).';
% 
% Cl_Grid2 = [];
% Cd_Grid2 = [];
% 
% for i = 1:numel(MList2)
%     M_temp2 = MList2(i);
%     AoA_temp2 = AOAList2(i);
%     
%     Cl_temp2 = interp.Cl_scattered2(M_temp2,AoA_temp2);
%     Cd_temp2 = interp.Cd_scattered2(M_temp2,AoA_temp2);
%     
%     I = cell(1, ndims(MList2)); 
%     [I{:}] = ind2sub(size(MList2),i);
%     
%     Cl_Grid2(I{(1)},I{(2)}) = Cl_temp2;
%     Cd_Grid2(I{(1)},I{(2)}) = Cd_temp2;
% 
% end
% 
% auxdata.interp.Cl_spline2 = griddedInterpolant(MList2,AOAList2,Cl_Grid2,'spline','linear');
% auxdata.interp.Cd_spline2 = griddedInterpolant(MList2,AOAList2,Cd_Grid2,'spline','linear');
flapaero = importdata('SPARTAN_Flaps.txt');

interp.flap_momentCl_scattered = scatteredInterpolant(flapaero(:,1),flapaero(:,5),flapaero(:,3), 'linear', 'nearest');
interp.flap_momentCd_scattered = scatteredInterpolant(flapaero(:,1),flapaero(:,5),flapaero(:,4), 'linear', 'nearest');
interp.flap_momentdef_scattered = scatteredInterpolant(flapaero(:,1),flapaero(:,5),flapaero(:,2), 'linear', 'nearest');

aero = importdata('SPARTANaero.txt');

interp.Cl_scattered = scatteredInterpolant(aero(:,1),aero(:,2),aero(:,3));
interp.Cd_scattered = scatteredInterpolant(aero(:,1),aero(:,2),aero(:,4));
interp.Cm_scattered = scatteredInterpolant(aero(:,1),aero(:,2),aero(:,5));

[MList,AOAList] = ndgrid(unique(aero(:,1)),unique(aero(:,2)));
% Cl_Grid = reshape(aero(:,3),[length(unique(aero(:,2))),length(unique(aero(:,1)))]).';
% Cd_Grid = reshape(aero(:,4),[length(unique(aero(:,2))),length(unique(aero(:,1)))]).';

Cl_Grid = [];
Cd_Grid = [];
Cm_Grid = [];
flap_Grid = [];

for i = 1:numel(MList)
    M_temp = MList(i);
    AoA_temp = AOAList(i);
    
    Cl_temp = interp.Cl_scattered(M_temp,AoA_temp);
    Cd_temp = interp.Cd_scattered(M_temp,AoA_temp);
    Cm_temp = interp.Cm_scattered(M_temp,AoA_temp);
    
    Cd_temp_AoA0 = interp.Cd_scattered(M_temp,0);
    Cl_temp_AoA0 = interp.Cl_scattered(M_temp,0);
    Cm_temp_AoA0 = interp.Cm_scattered(M_temp,0);
    
    Cl_AoA0_withflaps_temp = interp.flap_momentCl_scattered(M_temp,-(Cm_temp-Cm_temp_AoA0));
    Cd_AoA0_withflaps_temp = interp.flap_momentCd_scattered(M_temp,-(Cm_temp-Cm_temp_AoA0)) ;
    
    flap_Cl_temp = Cl_AoA0_withflaps_temp - Cl_temp_AoA0;
    flap_Cd_temp = Cd_AoA0_withflaps_temp - Cd_temp_AoA0;
    
    I = cell(1, ndims(MList)); 
    [I{:}] = ind2sub(size(MList),i);
    
    Cl_Grid(I{(1)},I{(2)}) = Cl_temp+flap_Cl_temp;
    Cd_Grid(I{(1)},I{(2)}) = Cd_temp+flap_Cd_temp;
    Cm_Grid(I{(1)},I{(2)}) = Cm_temp;

    flap_Grid(I{(1)},I{(2)}) = interp.flap_momentdef_scattered(M_temp,-(Cm_temp-Cm_temp_AoA0)) ;
    
    Cl_Grid_test(I{(1)},I{(2)}) = Cl_temp;
    Cd_Grid_test(I{(1)},I{(2)}) = Cd_temp;
    Cm_Grid_test(I{(1)},I{(2)}) = Cm_temp;
    
%     Cl_Grid(I{(1)},I{(2)}) = Cl_temp;
%     Cd_Grid(I{(1)},I{(2)}) = Cd_temp;
%     Cm_Grid(I{(1)},I{(2)}) = Cm_temp;
end
auxdata.interp.Cl_spline2 = griddedInterpolant(MList,AOAList,Cl_Grid,'spline','linear');
auxdata.interp.Cd_spline2 = griddedInterpolant(MList,AOAList,Cd_Grid,'spline','linear');
auxdata.interp.Cm_spline = griddedInterpolant(MList,AOAList,Cm_Grid,'spline','nearest');
%% Conical Shock Data %%===================================================
% Import conical shock data and create interpolation splines 
shockdata = dlmread('ShockMat');
[MList,AOAList] = ndgrid(unique(shockdata(:,1)),unique(shockdata(:,2)));
M1_Grid = reshape(shockdata(:,3),[length(unique(shockdata(:,2))),length(unique(shockdata(:,1)))]).';
pres_Grid = reshape(shockdata(:,4),[length(unique(shockdata(:,2))),length(unique(shockdata(:,1)))]).';
temp_Grid = reshape(shockdata(:,5),[length(unique(shockdata(:,2))),length(unique(shockdata(:,1)))]).';
auxdata.interp.M1gridded = griddedInterpolant(MList,AOAList,M1_Grid,'spline','linear');
auxdata.interp.presgridded = griddedInterpolant(MList,AOAList,pres_Grid,'spline','linear');
auxdata.interp.tempgridded = griddedInterpolant(MList,AOAList,temp_Grid,'spline','linear');


%% Engine Data %%==========================================================
% Import engine data
auxdata.interp.engine_data = dlmread('ENGINEDATA.txt');  % reads four columns; Mach no after conical shock, temp after conical shock, Isp, max equivalence ratio
engine_data = auxdata.interp.engine_data;

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

auxdata.interp.equivalence = scatteredInterpolant(eq_data(:,1),eq_data(:,2),eq_data(:,4), 'linear');
grid.eq_eng = auxdata.interp.equivalence(grid.Mgrid_eng,grid.T_eng);
auxdata.interp.eqGridded = griddedInterpolant(grid.Mgrid_eng,grid.T_eng,grid.eq_eng,'linear','linear');

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

auxdata.interp.IspGridded = griddedInterpolant(grid.Mgrid_eng,grid.T_eng,grid.Isp_eng,'spline','spline');


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

auxdata.PayloadGrid = griddedInterpolant(VGrid,gammaGrid,vGrid,PayloadData,'spline','linear');

%% Import Bounds %%========================================================
lonMin = -pi;         lonMax = -lonMin;
latMin = -70*pi/180;  latMax = -latMin;
lat0 = -0.264;
lon0 = deg2rad(145);
aoaMin = 0;  aoaMax = 9*pi/180;
bankMin1 = -1*pi/180; bankMax1 =   50*pi/180;

% Primal Bounds
bounds.phase(1).state.lower = [Stage2.Bounds.Alt(1), lonMin, latMin, Stage2.Bounds.v(1), Stage2.Bounds.gamma(1), Stage2.Bounds.zeta(1), aoaMin, bankMin1, Stage2.Bounds.mFuel(1)];
bounds.phase(1).state.upper = [Stage2.Bounds.Alt(2), lonMax, latMax, Stage2.Bounds.v(2), Stage2.Bounds.gamma(2), Stage2.Bounds.zeta(2), aoaMax, bankMax1, Stage2.Bounds.mFuel(2)];

% Initial States
bounds.phase(1).initialstate.lower = [Stage2.Bounds.Alt(1),lon0, lat0, Stage2.Initial.v, Stage2.Bounds.gamma(1), Stage2.Bounds.zeta(1), aoaMin, bankMin1, Stage2.Initial.mFuel] ;
bounds.phase(1).initialstate.upper = [Stage2.Bounds.Alt(2),lon0, lat0, Stage2.Initial.v, Stage2.Bounds.gamma(2), Stage2.Bounds.zeta(2), aoaMax, bankMax1, Stage2.Initial.mFuel];

% End States
bounds.phase(1).finalstate.lower = [Stage2.Bounds.Alt(1), lonMin, latMin, Stage2.Bounds.v(1), Stage2.End.gammaOpt(1), Stage2.End.Zeta, aoaMin, bankMin1, Stage2.End.mFuel];
bounds.phase(1).finalstate.upper = [Stage2.Bounds.Alt(2), lonMax, latMax, Stage2.Bounds.v(2), Stage2.End.gammaOpt(2), Stage2.End.Zeta, aoaMax, bankMax1, Stage2.Initial.mFuel];

% Control Bounds
bounds.phase(1).control.lower = [deg2rad(-.1), deg2rad(-.1)];
bounds.phase(1).control.upper = [deg2rad(.1), deg2rad(.1)];
% Time Bounds

bounds.phase(1).initialtime.lower = 0;
bounds.phase(1).initialtime.upper = 0;
bounds.phase(1).finaltime.lower = Stage2.Bounds.time(1);
bounds.phase(1).finaltime.upper = Stage2.Bounds.time(2);

%% Define Path Constraints
% This limits the dynamic pressure.
if const == 1 || const == 14 || const == 15
    bounds.phase(1).path.lower = [0];
    bounds.phase(1).path.upper = [50000];
elseif const == 12
    bounds.phase(1).path.lower = [0 ,0];
    bounds.phase(1).path.upper = [55000 ,9];
elseif const == 13
    bounds.phase(1).path.lower = [0 ,0];
    bounds.phase(1).path.upper = [45000, 9];
elseif const ==3 || const == 32
        bounds.phase(1).path.lower = [0 ,0];
    bounds.phase(1).path.upper = [50010, 9];
end


%%  Guess =================================================================

guess.phase(1).state(:,1)   = [22000;25000];
guess.phase(1).state(:,2)   = [0;0];
guess.phase(1).state(:,3)   = [-0.269;-0.13];
guess.phase(1).state(:,4)   = Stage2.Guess.v.';
guess.phase(1).state(:,5)   = Stage2.Guess.gamma.';
guess.phase(1).state(:,6)   = Stage2.Guess.zeta.';
guess.phase(1).state(:,7)   = [8*pi/180; 8*pi/180];
guess.phase(1).state(:,8)   = [0;0];
guess.phase(1).state(:,9) 	= [Stage2.Initial.mFuel, 200];

guess.phase(1).control      = [[0;0],[0;0]];
guess.phase(1).time          = [0;650];

% Tire stages together
bounds.eventgroup(1).lower = [zeros(1,10)];
bounds.eventgroup(1).upper = [zeros(1,10)]; 

%% Flyback
tfMin = 0;            tfMax = 5000;
altMin = 10;  altMax = 70000;
speedMin = 10;        speedMax = 5000;
fpaMin = -80*pi/180;  fpaMax =  80*pi/180;
aziMin = 60*pi/180; aziMax =  360*pi/180;
mFuelMin = 0; mFuelMax = Stage2.Initial.mFuel-100;
bankMin2 = -1*pi/180; bankMax2 =   100*pi/180

lonf = deg2rad(145);
latf   = -0.269;

throttleMin = 0; throttleMax = 1;

bounds.phase(2).initialtime.lower = 0;
bounds.phase(2).initialtime.upper = 3000;
bounds.phase(2).finaltime.lower = 400;
bounds.phase(2).finaltime.upper = 4000;
bounds.phase(2).initialstate.lower = [altMin, lonMin, latMin, speedMin, fpaMin, aziMin, aoaMin, bankMin2, mFuelMin, throttleMin];
bounds.phase(2).initialstate.upper = [altMax, lonMax, latMax, speedMax, fpaMax, aziMax, aoaMax, bankMax2, mFuelMax, throttleMax];

bounds.phase(2).state.lower = [altMin, lonMin, latMin, speedMin, fpaMin, aziMin, aoaMin, bankMin2, mFuelMin, throttleMin];
bounds.phase(2).state.upper = [altMax, lonMax, latMax, speedMax, fpaMax, aziMax, aoaMax, bankMax2, mFuelMax, throttleMax];

bounds.phase(2).finalstate.lower = [altMin, lonf-0.001, latf-0.001, speedMin, deg2rad(-10), aziMin, aoaMin, bankMin2, Stage2.End.mFuel, throttleMin];
bounds.phase(2).finalstate.upper = [200, lonf+0.001, latf+0.001, speedMax, deg2rad(30), aziMax, aoaMax, bankMax2, Stage2.End.mFuel, throttleMax];

% bounds.phase(2).finalstate.lower = [altMin, lonf-.001, latf-.001, speedMin, deg2rad(-80), aziMin, aoaMin, bankMin2, Stage2.End.mFuel, throttleMin];
% bounds.phase(2).finalstate.upper = [200000+auxdata.Re, lonf+.001, latf+.001, speedMax, deg2rad(80), aziMax, aoaMax, bankMax2, Stage2.End.mFuel, throttleMax];

bounds.phase(2).control.lower = [deg2rad(-.5), deg2rad(-5), -1];
bounds.phase(2).control.upper = [deg2rad(.5), deg2rad(5), 1];

bounds.phase(2).path.lower = 0;
bounds.phase(2).path.upper = 50000;

tGuess              = [650; 1500];
altGuess            = [35000; 100];
lonGuess            = [lon0; lon0+1*pi/180];
latGuess            = [lat0; lat0-1*pi/180];
speedGuess          = [3000; 10];
fpaGuess            = [0; 0];
aziGuess            = [deg2rad(97); deg2rad(270)];
aoaGuess            = [6*pi/180; 6*pi/180];
bankGuess           = [80*pi/180; 80*pi/180];
% mFuelGuess          = [mFuelMax; mFuelMin];
mFuelGuess          = [200; mFuelMin];
guess.phase(2).state   = [altGuess, lonGuess, latGuess, speedGuess, fpaGuess, aziGuess, aoaGuess, bankGuess, mFuelGuess,[0;0]];
guess.phase(2).control = [[0;0],[0;0],[0;0]];
% guess.phase.control = [aoaGuess];
guess.phase(2).time    = tGuess;


%%
%-------------------------------------------------------------------------%
%----------Provide Mesh Refinement Method and Initial Mesh ---------------%
%-------------------------------------------------------------------------%
% mesh.method       = 'hp-LiuRao-Legendre';
mesh.maxiterations = 5;
mesh.colpointsmin = 3;
mesh.colpointsmax = 50;
mesh.tolerance    = 1e-5;


%-------------------------------------------------------------------%
%---------- Configure Setup Using the information provided ---------%
%-------------------------------------------------------------------%
setup.name                           = 'Reusable-Launch-Vehicle-Entry-Problem';
setup.functions.continuous           = @CombinedContinuous;
setup.functions.endpoint             = @CombinedEndpoint;
setup.auxdata                        = auxdata;
setup.bounds                         = bounds;
setup.guess                          = guess;
setup.mesh                           = mesh;
setup.displaylevel                   = 2;
setup.nlp.solver                     = 'ipopt';
setup.nlp.ipoptoptions.linear_solver = 'ma57';
setup.nlp.ipoptoptions.maxiterations = 1000;
setup.derivatives.supplier           = 'sparseCD';
setup.derivatives.derivativelevel    = 'second';
setup.scales.method                  = 'automatic-bounds';
setup.method                         = 'RPM-Differentiation';
% setup.scales.method                  = 'automatic-guessUpdate';

%-------------------------------------------------------------------%
%------------------- Solve Problem Using GPOPS2 --------------------%
%-------------------------------------------------------------------%


output = gpops2(setup);

%%

EndTime = datestr(now,30) % Display the ending time

% =========================================================================
% Assign the primal variables
alt = output.result.solution.phase(1).state(:,1).';
alt2 = output.result.solution.phase(2).state(:,1).';
lon = output.result.solution.phase(1).state(:,2).';
lon2 = output.result.solution.phase(2).state(:,2).';
lat = output.result.solution.phase(1).state(:,3).';
lat2 = output.result.solution.phase(2).state(:,3).';
v = output.result.solution.phase(1).state(:,4).'; 
v2 = output.result.solution.phase(2).state(:,4).'; 
gamma = output.result.solution.phase(1).state(:,5).'; 
gamma2 = output.result.solution.phase(2).state(:,5).'; 
zeta = output.result.solution.phase(1).state(:,6).';
zeta2 = output.result.solution.phase(2).state(:,6).';
Alpha = output.result.solution.phase(1).state(:,7).';
eta = output.result.solution.phase(1).state(:,8).';
mFuel = output.result.solution.phase(1).state(:,9).'; 
mFuel2 = output.result.solution.phase(2).state(:,9).'; 

throttle2 = output.result.solution.phase(2).state(:,10).';

omegadot  = output.result.solution.phase(1).control.'; 


time = output.result.solution.phase(1).time.';
time2 = output.result.solution.phase(2).time.';

figure(201)
subplot(9,1,1)
hold on
plot(time,alt)
plot(time2,alt2)
subplot(9,1,2)
hold on
plot(time,v)
plot(time2,v2)
subplot(9,1,3)
hold on
plot(time,lon)
plot(time2,lon2)
subplot(9,1,4)
hold on
plot(time,lat)
plot(time2,lat2)
subplot(9,1,5)
hold on
plot(time,v)
plot(time2,v2)
subplot(9,1,6)
hold on
plot(time,gamma)
plot(time2,gamma2)
subplot(9,1,7)
hold on
plot(time,ones(1,length(time)))
plot(time2,throttle2)



% =========================================================================

%% Third Stage
% Optimise third stage trajectory from end point

global phi

% cd('../ThirdStage')
% [ThirdStagePayloadMass,ThirdStageControls,ThirdStageZeta,ThirdStagePhi,ThirdStageAlt,ThirdStagev,ThirdStaget,ThirdStageAlpha,ThirdStagem,ThirdStagegamma,ThirdStageq] = ThirdStageOptm(V(end),gamma(end),v(end), phi(end),zeta(end), 1);
% ThirdStagePayloadMass
% cd('../SecondStage')
ThirdStagePayloadMass = 0;


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%          OUTPUT             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

nodes = length(alt)

% eq = Engine.eq;
% Thrust = Engine.Thrust;
% Fueldt = Engine.Fueldt;

% Fd = Vehicle.Fd;
% Alpha = Vehicle.Alpha;
% lift = Vehicle.lift;
% flapdeflection = Vehicle.flapdeflection;
% 
% Thrust = Thrust./cos(deg2rad(Alpha)); % change thrust to account for total thrust, including portion that contributes to lift
% 
% dt = time(2:end)-time(1:end-1); % Time change between each node pt
% FuelUsed = zeros(1,nodes-1);
% FuelUsed(1) = dt(1)*Fueldt(1);
% for i = 2:nodes-1
%     FuelUsed(i) = dt(i).*Fueldt(i) + FuelUsed(i-1);
% end


% figure out horizontal motion
H(1) = 0;
for i = 1:nodes-1
H(i+1) = v(i)*(time(i+1) - time(i))*cos(gamma(i)) + H(i);
end

% Separation_LD = lift(end)/Fd(end)

figure(201)

subplot(5,5,[1,10])
hold on
plot(H, alt)
% plot(H(algorithm.nodes(1)), V(algorithm.nodes(1)), '+', 'MarkerSize', 10, 'MarkerEdgeColor','r')
title('Trajectory (m)')

dim = [.7 .52 .2 .2];
annotation('textbox',dim,'string',{['Payload Mass: ', num2str(ThirdStagePayloadMass), ' kg'],['Second Stage Fuel Used: ' num2str(1000 - mFuel(end)) ' kg']},'FitBoxToText','on');  


subplot(5,5,11)
hold on
plot(time, v)

title('Velocity (m/s)')


% subplot(5,5,12)
% plot(time, M)
% title('Mach no')

% subplot(5,5,13)
% plot(time, q)
% title('Dynamic Pressure (pa)')

subplot(5,5,14)
hold on
plot(time, rad2deg(gamma))

title('Trajectory Angle (Deg)')



% subplot(5,5,15)
% plot(time, Fd)
% title('Drag Force')

subplot(5,5,16)
hold on
plot(time, mFuel + 8755.1 - 994)
title('Vehicle Mass (kg)')



% subplot(5,5,17)
% plot(time, Thrust)
% title('Thrust (N)')

% Isp = Thrust./Fueldt./9.81;
% IspNet = (Thrust-Fd)./Fueldt./9.81;

% subplot(5,5,18)
% plot(time, Isp)
% title('Isp')

% subplot(5,5,19)
% plot(time, IspNet)
% title('Net Isp')

% subplot(5,5,20)
% plot(time, flapdeflection)
% title('Flap Deflection (deg)')

subplot(5,5,21)
plot(time, Alpha)
title('Angle of Attack (deg)')

% subplot(5,5,22);
% plot(time, dual.dynamics);
% title('costates')
% xlabel('time');
% ylabel('costates');
% legend('\lambda_1', '\lambda_2', '\lambda_3');

% subplot(5,5,23)
% Hamiltonian = dual.Hamiltonian(1,:);
% plot(time,Hamiltonian);
% title('Hamiltonian')

% subplot(5,5,24)
% hold on
% plot(time, rad2deg(gammadot))
% title('Trajectory Angle Change Rate (Deg/s)')
% 
% subplot(5,5,25)
% hold on
% plot(time, rad2deg(omegadot))
% title('Omegadot Control (Deg/s2)')


dim = [.8 .0 .2 .2];
annotation('textbox',dim,'string',{['Third Stage Thrust: ', num2str(50), ' kN'],['Third Stage Starting Mass: ' num2str(2850) ' kg'],['Third Stage Isp: ' num2str(350) ' s']},'FitBoxToText','on');  

figure(202)
sp1 = subplot(2,6,[1,6]);
ax1 = gca; % current axes
hold on
plot(H/1000, alt/1000,'Color','k')

title('Trajectory')
xlabel('Earth Normal Distance Flown (km)')
ylabel('Vertical Position (km)')

for i = 1:floor(time(end)/30)
    [j,k] = min(abs(time-30*i));
    str = strcat(num2str(round(time(k))), 's');
    text(H(k)/1000,alt(k)/1000,str,'VerticalAlignment','top', 'FontSize', 10);
    
    plot(H(k)/1000, alt(k)/1000, '+', 'MarkerSize', 10, 'MarkerEdgeColor','k')
end

plot(H(end)/1000, alt(end)/1000, 'o', 'MarkerSize', 10, 'MarkerEdgeColor','k')

text(H(end)/1000,alt(end)/1000,'Third Stage Transition Point','VerticalAlignment','top', 'FontSize', 10);

dim = [.65 .45 .2 .2];
annotation('textbox',dim,'string',{['Payload Mass: ', num2str(ThirdStagePayloadMass,4), ' kg'],['Second Stage Fuel Used: ' num2str(mFuel(1) - mFuel(end)) ' kg']},'FitBoxToText','on');  

thirdstageexample_H = [0+H(end) (H(end)-H(end - 1))+H(end) 20*(H(end)-H(end - 1))+H(end) 40*(H(end)-H(end - 1))+H(end) 60*(H(end)-H(end - 1))+H(end) 80*(H(end)-H(end - 1))+H(end)]/1000; %makes a small sample portion of an arbitrary third stage trajectory for example
thirdstageexample_V = [0+alt(end) (alt(end)-alt(end - 1))+alt(end) 20*((alt(end)-alt(end -1)))+alt(end) 40*((alt(end)-alt(end -1)))+alt(end) 60*((alt(end)-alt(end -1)))+alt(end) 80*((alt(end)-alt(end -1)))+alt(end)]/1000;
plot(thirdstageexample_H, thirdstageexample_V, 'LineStyle', '--','Color','k');

hold on
sp2 = subplot(2,6,[7,9]);
xlabel('time (s)')

hold on
ax2 = gca; % current axes
xlim([min(time) max(time)]);

line(time, rad2deg(gamma),'Parent',ax2,'Color','k', 'LineStyle','-')

line(time, M,'Parent',ax2,'Color','k', 'LineStyle','--')

line(time, v./(10^3),'Parent',ax2,'Color','k', 'LineStyle','-.')

line(time, q./(10^4),'Parent',ax2,'Color','k', 'LineStyle',':', 'lineWidth', 2.0)

% line(time, heating_rate./(10^5),'Parent',ax1,'Color','k', 'LineStyle',':', 'lineWidth', 2.0)
% 
% line(time, Q./(10^7),'Parent',ax1,'Color','k', 'LineStyle','-', 'lineWidth', 2.0)

% legend(ax1,  'Trajectory Angle (degrees)', 'Mach no', 'Velocity (m/s x 10^3)', 'Dynamic Pressure (Pa x 10^4)',  'Q (Mj x 10)')
h = legend(ax2,  'Trajectory Angle (degrees)', 'Mach no', 'Velocity (m/s x 10^3)', 'Dynamic Pressure (Pa x 10^4)');
rect1 = [0.12, 0.35, .25, .25];
set(h, 'Position', rect1)


sp3 = subplot(2,6,[10,12]);
xlabel('time (s)')
ax3 = gca;
xlim([min(time) max(time)]);
line(time, [Alpha(1:end-1) Alpha(end-1)],'Parent',ax3,'Color','k', 'LineStyle','-')

line(time, [flapdeflection(1:end-1) flapdeflection(end-1)],'Parent',ax3,'Color','k', 'LineStyle','--')


% line(time, mfuel./(10^2),'Parent',ax2,'Color','k', 'LineStyle','-.')
line(time, eq.*10,'Parent',ax3,'Color','k', 'LineStyle','-.')

line(time, IspNet./(10^2),'Parent',ax3,'Color','k', 'LineStyle',':', 'lineWidth', 2.0)

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

figure(230)
hold on
plot3(lon,lat,alt)
plot3(lon2,lat2,alt2)



figure(203)

subplot(2,5,[1,5]);

line(time, dual.dynamics(1,:),'Color','k', 'LineStyle','-');
line(time, dual.dynamics(2,:),'Color','k', 'LineStyle','--');
line(time, dual.dynamics(3,:),'Color','k', 'LineStyle','-.');
line(time, dual.dynamics(4,:),'Color','k', 'LineStyle',':');
line(time, dual.dynamics(5,:),'Color','k', 'LineStyle','-','LineWidth',2);
title('costates')
xlabel('time');
ylabel('Costates');
% axis([0,time(end),-1,1])
legend('\lambda_1', '\lambda_2', '\lambda_3', '\lambda_4','\lambda_5');

subplot(2,5,[6,10])
Hamiltonian = dual.Hamiltonian(1,:);
plot(time,Hamiltonian,'Color','k');
axis([0,time(end),-1,1])
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

ts = timeseries(Isp,time);
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

plot(time,dLHdu,time,mu_1,time,mu_2,time,mu_3,time,mu_4,time,mu_5,time,mu_u);
legend('dLHdu','mu_1','mu_2','mu_3','mu_4','mu_5','mu_u');
title('Validation')
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% FORWARD INTEGRATION
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% This simply tests that the system dynamics hold, as the
% Pseudospectral method may not converge to a realistic
% solution



gamma_F = cumtrapz(time,gammadot)+ gamma(1);

gammadot_F = cumtrapz(time,omegadot) + gammadot(1);


v_F = cumtrapz(time,a);
v_F = v_F + v(1);

V_F = cumtrapz(time,v_F.*sin(gamma_F));
V_F = V_F + alt(1);

mfuel_F = cumtrapz(time,-Fueldt);
mfuel_F = mfuel_F + mFuel(1);

figure(206)

subplot(5,1,1)
plot(time,gamma_F,time,gamma);
title('Forward Simulation Comparison');
% note this is just a trapezoidal rule check, may not be exactly accurate
subplot(5,1,2)
plot(time,v_F,time,v);
subplot(5,1,3)
plot(time,V_F,time,alt);
subplot(5,1,4)
plot(time,mfuel_F,time,mFuel);
subplot(5,1,4)
plot(time,gammadot_F,time,gammadot);

% Compute difference with CADAC for constant dynamic pressure path

t_diff = time - [0 time(1:end-1)];
if const == 3
    CADAC_DATA = dlmread('TRAJ.ASC');
    CADAC_Alpha = interp1(CADAC_DATA(:,2),CADAC_DATA(:,4),M(1:68)); % 1:68 gives mach numbers that align, may need to change this
    CADAC_V = interp1(CADAC_DATA(:,2),CADAC_DATA(:,11),M(1:68));
    MeanError_V = sum(abs(CADAC_V - alt(1:68))./alt(1:68).*t_diff(1:68))/time(end)
    MeanError_Alpha = sum(abs(CADAC_Alpha - Alpha(1:68))./Alpha(1:68).*t_diff(1:68))/time(end)
end

% if PayloadGrid(phi(end),zeta(end),V(end)+10,gamma(end),v(end)) - PayloadGrid(phi(end),zeta(end),V(end),gamma(end),v(end)) < 0
%     disp('Check Third Stage Payload Matrix, May Have Found False Maxima')
% end
if PayloadGrid(alt(end)+10,gamma(end),v(end)) - PayloadGrid(alt(end),gamma(end),v(end)) < 0
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

forward0 = [alt(1),phi(1),gamma(1),v(1),zeta(1),Stage2.mStruct+Stage3.mTot+Stage2.mFuel];

% [f_t, f_y] = ode45(@(f_t,f_y) ForwardSim(f_y,AlphaInterp(time,Alpha,f_t),communicator,communicator_trim,SPARTAN_SCALE,Atmosphere,const,interp),time,forward0);
[f_t, f_y] = ode45(@(f_t,f_y) ForwardSim(f_y,AlphaInterp(time,Alpha,f_t),communicator,communicator_trim,interp.Atmosphere,const,auxdata.interp,AlphaInterp(time,lift,f_t),AlphaInterp(time,Fd,f_t),AlphaInterp(time,Thrust,f_t),AlphaInterp(time,flapdeflection,f_t)),time(1:end),forward0);

figure(212)
subplot(7,1,[1 2])
hold on
plot(f_t(1:end),f_y(:,1));
plot(time,alt);

subplot(7,1,3)
hold on
plot(f_t(1:end),f_y(:,2));
plot(time,phi);

subplot(7,1,4)
hold on
plot(f_t(1:end),f_y(:,3));
plot(time,gamma);

subplot(7,1,5)
hold on
plot(f_t(1:end),f_y(:,4));
plot(time,v);

subplot(7,1,6)
hold on
plot(f_t(1:end),f_y(:,5));
plot(time,zeta);

subplot(7,1,7)
hold on
plot(f_t(1:end),f_y(:,6));
plot(time,Stage2.mStruct+Stage3.mTot+mFuel);

%% plot engine interpolation visualiser
T0 = spline( interp.Atmosphere(:,1),  interp.Atmosphere(:,2), alt); 
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
[FirstStageStates] = FirstStageProblem(alt(1),gamma(1),phi(1),zeta(1),const);
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






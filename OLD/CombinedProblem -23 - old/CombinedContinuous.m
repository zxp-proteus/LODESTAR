function phaseout = CombinedContinuous(input)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 2D Dynamics

% This uses velocity calculated in the Cost file

% This file is calculated after the Cost file in the iterative process 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
V1 = input.phase(1).state(:,1).';
v1 = input.phase(1).state(:,2).'; 
gamma1 = input.phase(1).state(:,3).'; 
mfuel1 = input.phase(1).state(:,4).'; 
gammadot1 = input.phase(1).state(:,5).';
zeta1 = input.phase(1).state(:,6).';

omegadot1  = input.phase(1).control.'; 

time1 = input.phase(1).time.';

Stage2 = input.auxdata.Stage2;
Stage3 = input.auxdata.Stage3;
interp = input.auxdata.interp;
const = input.auxdata.const;
auxdata = input.auxdata;


[dfuel, Engine.Fueldt, a, q, M, Vehicle.Fd, Engine.Thrust, Vehicle.flapdeflection, Vehicle.Alpha, rho,Vehicle.lift,zeta1,phi,Engine.eq,zetadot1] = VehicleModel(time1, gamma1, V1, v1, mfuel1,interp,const,gammadot1, interp.Atmosphere,zeta1,Stage2.mStruct,Stage3.mTot,auxdata);

vdot1 = a;
mfueldot1 = -Engine.Fueldt; 
%==========================================================================

Vdot1 = v1.*sin(gamma1);

%==========================================================================

phaseout(1).dynamics = [Vdot1.',vdot1.', gammadot1.', mfueldot1.', omegadot1.', zetadot1.'];

phaseout(1).path = [q.',Vehicle.Alpha.'];

%%

alt2  = input.phase(2).state(:,1);
v2    = input.phase(2).state(:,2);
gamma2  = input.phase(2).state(:,3);
m2    = input.phase(2).state(:,4);
Alpha2    = input.phase(2).state(:,5);


time2 = input.phase(2).time;
Alphadot2  = input.phase(2).control(:,1);


[rdot2,xidot2,phidot2,gammadot2,vdot2,zetadot2, mdot2, Vec_angle2, AoA_max2, T2] = ThirdStageDyn(alt2,gamma2,v2,m2,Alpha2,time2,auxdata, Alphadot2);

phaseout(2).dynamics  = [rdot2.', vdot2.', gammadot2.', -mdot2*ones(length(rdot2),1), Alphadot2];

Alpha_constraint = Alpha2-AoA_max2;

phaseout(2).path = [Vec_angle2,Alpha_constraint];

end

%======================================================
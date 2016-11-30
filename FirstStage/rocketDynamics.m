function dz = rocketDynamicsFullSize(z,u,phase,scattered)
global mach
Atmosphere = dlmread('atmosphere.txt');
h = z(1,:);   %Height
v = z(2,:);   %Velocity
m = z(3,:);   %Mass
gamma = z(4,:);
alpha = z(5,:);

dalphadt = u(1,:);

if isnan(gamma)
    gamma = 1.5708;
end

%%%% Compute gravity from inverse-square law:
rEarth = 6.3674447e6;  %(m) radius of earth
mEarth = 5.9721986e24;  %(kg) mass of earth
G = 6.67e-11; %(Nm^2/kg^2) gravitational constant
g = G*mEarth./((h+rEarth).^2);

density = interp1(Atmosphere(:,1),Atmosphere(:,4),h);
P_atm = interp1(Atmosphere(:,1),Atmosphere(:,3),h);
speedOfSound = interp1(Atmosphere(:,1),Atmosphere(:,5),h);

SCALE = 1.2;
T = 422581*SCALE + (101325 - P_atm)*0.5667*SCALE; %(This whole thing is nearly a Falcon 1 first stage) 
Isp = 275 + (101325 - P_atm)*2.9410e-04;

dm = -T./Isp./g;


mach = v./speedOfSound;
Cd = scattered.Drag(mach,rad2deg(alpha));
Cl = scattered.Lift(mach,rad2deg(alpha));

%%%% Compute the drag:
Area = 62.77;  
D = 0.5*Cd.*Area.*density.*v.^2;
L = 0.5*Cl.*Area.*density.*v.^2;



%%%% Complete the calculation:


xi = 0*ones(1,length(h));
phi = 0*ones(1,length(h));
zeta = 0*ones(1,length(h));


switch phase
    case 'prepitch'
    gamma = 1.5708*ones(1,length(h)); % Control Trajectory Angle 
    case 'postpitch'
    %Do nothing
end


[dr,dxi,dphi,dgamma,dv,dzeta] = RotCoords(h+rEarth,xi,phi,gamma,v,zeta,L,D,T,m,alpha,phase);

if isnan(dgamma)
dgamma = 0;
end

dz = [dr;dv;dm;dgamma;dalphadt];

end
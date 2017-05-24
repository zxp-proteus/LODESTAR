function [eventCost, runningCost] = LanderCost(primal)

% global q
Atmosphere = dlmread('atmosphere.txt');


V = primal.states(1,:);	
v = primal.states(2,:);	
m = primal.states(3,:);	
gamma = primal.states(4,:);	
alpha = primal.states(5,:);	


density = interp1(Atmosphere(:,1),Atmosphere(:,4),V);
q = 0.5*density.*v.^2;

% eventCost   = -v(end);
% eventCost   = 0;
% eventCost   = -v(end)*1000 + (q(end)-50000)^2;

% eventCost   = (q(end)-50000)^2;

% eventCost   = (V(end)-23000)^2 + (10000*(gamma(end)-0.0))^2 - v(end);

global hf
% eventCost   = (V(end)-hf)^2  - v(end);

% eventCost = m(1);
% eventCost   = (V(end)-hf)^2 + m(1);


% eventCost   = 0.000001*m(1);
% eventCost   = 0.01*m(1);
eventCost   = .01*m(1);

%  eventCost   = m(1);
% eventCost   = 0;

% eventCost   = -0.001*v(end);
runningCost =0;
% runningCost =abs(alpha);
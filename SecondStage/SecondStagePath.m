function path = SecondStagePath(primal)
V = primal.states(1,:);
v = primal.states(2,:);
theta  = primal.states(3, :);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
global scattered
global q
global const
DynamicPressure = q;
v0 = v(1);

% vfunc = v0 -1524*(1-1e-10*(50000-q(1))^2); % constrain initial velocity
vfunc = v0 -scattered.FirstStagev(V(1),theta(1));

if const == 3
   path = vfunc*ones(1,length(v)); 
else
path = [DynamicPressure ;vfunc*ones(1,length(v))];
end
% path = DynamicPressure ;





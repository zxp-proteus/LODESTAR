clear all
mat = [];




% u = [2850:25:2925];
% u = 2900
u = [2900:25:2950];
% u = [2925 2950]

% options.Display = 'iter';
% options.Display = 'final';
% options.Algorithm = 'sqp';
% options.TolFun = 1e-3;
% options.TolX = 1e-3;

% for phi0 = [-0.1271-0.005 -0.1271 -0.1271+0.005]
    phi0 = -0.13 % this has very minimal effect
% for zeta0 = [1.70 1.7040 1.7080]
zeta0 = 1.69 % this is the phi to reach close to 1.704 rad heading angle (SSO)


%     guess = [2500/10000  deg2rad(20) deg2rad(20) deg2rad(20) deg2rad(20) 200/1000;
%         2500/10000  deg2rad(20) deg2rad(20) deg2rad(20) deg2rad(20) 200/1000;
%         2500/10000  deg2rad(20) deg2rad(20) deg2rad(20) deg2rad(20) 200/1000;
%         2500/10000  deg2rad(20) deg2rad(20) deg2rad(20) deg2rad(20) 200/1000];
%    guess = []; 
    
%     phi0 = -0.1271
%     zeta0 = 1.7011
%     
%     guess = [1500; deg2rad(13); deg2rad(13)]*ones(1,length(u));
%     guess = [1500; deg2rad(20); deg2rad(20)]*ones(1,length(u));
% phi0 = -0.13154;
% zeta0 = deg2rad(96.9);


% options.TypicalX = [2600 0.2 0.2 0.2 0.2 250];
% for k = [30000:1000:35000 35000:250:38000 38500:500:40000]
for k = [33000:1000:38000]
    for j = [0.00:0.025:0.05]
%         for j = [0]
        temp_guess_no = 1;
        
        phi0
        zeta0
        k
        j
        AltF = [];
        vF = [];
        Alt = [];
        t = [];
        mpayload = [];
        Alpha = [];
        m = [];
        AoA = [];
        options = cell(1,8);

        parfor i = 1:length(u)
     [AltF, vF, Alt, v, t, mpayload, Alpha, m,AoA,q,gamma,D,AoA_max] = ThirdStageSim([0*ones(1,5) 10],k,j,u(i), phi0, zeta0);
%         guess = [1700 AoA_max-0.01 AoA_max/2+AoA_max/2*(0.1-j)/0.1-0.01];
%         guess = [1600 AoA_max(i)-0.01];
% guess = [2700  deg2rad(7.5) deg2rad(10)];
% guess = [2750  (deg2rad(14)+(deg2rad(6)-deg2rad(14))*j/0.05) (deg2rad(10)+((AoA_max-0.01)-deg2rad(10))*j/0.05) (deg2rad(14)+((AoA_max-0.01)-deg2rad(14))*j/0.05) (deg2rad(12)+(deg2rad(8)-deg2rad(12))*j/0.05)]
% if k >= 34000 % variable guess
% x0 = [2500/10000  AoA_max AoA_max AoA_max AoA_max 200/1000]
% else
%     x0 = [2500/10000  0 AoA_max AoA_max AoA_max 200/1000]
% end

% if temp_guess_no == 1;
% x0 = [2500/10000  AoA_max AoA_max AoA_max AoA_max 200/1000];
% elseif temp_guess_no > 1
%    x0 =  guess(i,:);
% end


% x0 = [2590/10000  AoA_max*ones(1,16) 250/1000];


% nodesalt = [33000; 33000; 34000; 36000 ;36000];
% nodesgam = [0;0.05; 0; 0; 0.05];
% vals =  [deg2rad(2);deg2rad(.5); deg2rad(2); 0 ;0];
% interp = scatteredInterpolant(nodesalt,nodesgam,vals);
% x0 = [2590/10000  AoA_max*ones(1,16)-interp(k,j) 250/1000] % this problem is extremely sensitive to initital guess! mostly at low altitude low gamma

% mpayload(i) = 0;
% for i2 = 0:4
% x0 = [2590/10000  AoA_max*ones(1,16)-deg2rad(i2/2) 250/1000];
% x_temp = fmincon(@(x)Payload(x,k,j,u(i), phi0, zeta0),x0,[],[],[],[],[2200/10000 deg2rad(0)*ones(1,16) 200/1000],[3000/10000 AoA_max*ones(1,16) 270/1000],@(x)Constraint(x,k,j,u(i), phi0, zeta0),options);
% [AltF(i), vF(i), Alt, v, t, mpayload_temp, Alpha, m,AoA] = ThirdStageSim(x_temp,k,j,u(i),phi0,zeta0);
% if mpayload_temp > mpayload(i)
%     mpayload(i) = mpayload_temp;
%     x = x_temp;
% end
% end


mpayload(i) = 0;
% options{i}.Display = 'final';
% options{i}.Display = 'iter';
options{i}.Algorithm = 'sqp';
% options{i}.Algorithm = 'active-set';
% options(i).ScaleProblem = 'iter-and-constr'

options{i}.TolFun = 1e-3;
options{i}.TolX = 1e-3;
% for i3 = 0:3
% for i2 = 0:10

% for i3 = 0:4 %works decently 
% for i2 = 0:0.5:10
    
    for i3 = 0:.5:6
for i2 = 0:10
    
%     for i4 = 0:2
% x0 = [2590/10000  AoA_max*ones(1,16)-deg2rad(i/2) 250/1000];
% x0 = [2590/10000  AoA_max*ones(1,20) 250/1000];
i4 = 0;
x0 = [AoA_max*ones(1,10)-i4*AoA_max*0.01 250/10000+i2*5/10000]; 
% options{i}.DiffMinChange = 0.0005 + 0.0001*i2;
options{i}.DiffMinChange = 0.0005*i3;
% if i2 < 6
% x0 = [2590/10000  AoA_max*ones(1,20) 250/10000+i2*10/10000]; 
% % options{i}.DiffMinChange = 0.0005 + 0.0001*i2;
% options{i}.DiffMinChange = 0.0005;
% else
%     x0 = [2590/10000  AoA_max*ones(1,20) 250/1000+(i2-6)*10/1000]; 
% % options{i}.DiffMinChange = 0.0005 + 0.0001*i2;
% options{i}.DiffMinChange = 0.001;
% end
[x_temp,fval,exitflag] = fmincon(@(x)Payload(x,k,j,u(i), phi0, zeta0),x0,[],[],[],[],[deg2rad(0)*ones(1,10) 200/10000],[AoA_max*ones(1,10) 350/10000],@(x)Constraint(x,k,j,u(i), phi0, zeta0),options{i});
[AltF(i), vF(i), Alt, v, t, mpayload_temp, Alpha, m,AoA,q,gamma,D,AoA_max,zeta] = ThirdStageSim(x_temp,k,j,u(i), phi0, zeta0);
% mpayload_temp
% mpayload_temp = 1;
% x_temp = 1;

if mpayload_temp > mpayload(i) && (exitflag ==1 || exitflag ==2|| exitflag ==3)
    mpayload(i) = mpayload_temp;
%     x = x_temp;
end
end
end
% end

% [AltF(i), vF(i), Alt, v, t, mpayload(i), Alpha, m,AoA] = ThirdStageSim(x,k,j,u(i),phi0,zeta0);

% x = fmincon(@(x)Payload(x,k,j,u(i), phi0, zeta0),x0,[],[],[],[],[2200/10000 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 200/1000],[3000/10000 AoA_max AoA_max AoA_max AoA_max AoA_max AoA_max AoA_max AoA_max AoA_max AoA_max AoA_max AoA_max AoA_max AoA_max AoA_max AoA_max 270/1000],@(x)Constraint(x,k,j,u(i), phi0, zeta0),options);

%         mfuel_burn = x(1);

%         [AltF(i), vF(i), Alt, v, t, mpayload(i), Alpha, m,AoA] = ThirdStageSim(x,k,j,u(i),phi0,zeta0);
        
%         temp(i,:) = x;
        temp_payload(i) = mpayload(i);
        u(i)
        mpayload(i)
        end
temp_payload
%         guess = temp;
        
%         mat = [mat;[phi0*ones(length(u),1),zeta0*ones(length(u),1),k*ones(length(u),1),j*ones(length(u),1),u.',mpayload.',temp(1,:).',temp(2,:).',temp(3,:).']];
mat = [mat;[phi0*ones(length(u),1),zeta0*ones(length(u),1),k*ones(length(u),1),j*ones(length(u),1),u.',temp_payload.']];

temp_guess_no = temp_guess_no + 1;
    end
end
% end
% end
dlmwrite('thirdstagenew.dat', mat,'delimiter','\t')
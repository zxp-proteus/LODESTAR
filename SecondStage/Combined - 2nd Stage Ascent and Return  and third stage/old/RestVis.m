% Engine Data Visualisation
clear all
addpath('./rbf')

scattered.data = dlmread('RESTM12DATA.txt');  
data = scattered.data;

newdata = []
j=1
for i = 1: length(data(:,1))
    if data(i,1) < 5.4
        newdata(j,:) = data(i,:);
        j=j+1;
    end
end

IspScattered = scatteredInterpolant(data(:,1),data(:,2),data(:,3));
%  IspScattered = rbfcreate([data(:,1).';data(:,2).'],data(:,3).','RBFFunction','gaussian');

 p=polyfitn([data(:,1),data(:,2)],data(:,3),4)
 
 
 
 

% [MData,I] = sort(data(:,1));
% [MData,J] = unique(MData);
% TData = data(I,2);
% TData = TData(J);
% IspData = data(I,3);
% IspData = IspData(J);
% eqData = data(I,4);

% k= 1;
% for j = 0:5:5*5
% for i = 1:4
% 
%     newMtemp(k) = (MData(i+j) + MData(i+j+1))/2;
%     newTtemp(k) = (TData(i+j) + TData(i+j+1))/2;
%     newIsptemp(k) = (IspData(i+j) + IspData(i+j+1))/2;
%     i
%     j
% MData(i+j)
% MData(i+j+1)
% TData(i+j)
% TData(i+j+1)
%     k = k+1;
% end
% end


% data2(:,1) = [data(:,1);newMtemp.'];
% data2(:,2) = [data(:,2);newTtemp.'];
% data2(:,4) = [data(:,4);newIsptemp.'];

M_englist = unique(sort(data(:,1))); % create unique list of Mach numbers from engine data
M_eng_interp = floor(M_englist(1)):0.1:ceil(M_englist(end)); % enlarge spread, this is not necessary if you have a lot of engine data
M_eng_interp = unique(sort(data(:,1)));

T_englist = unique(sort(data(:,2))); % create unique list of angle of attack numbers from engine data
T_eng_interp = floor(T_englist(1)):1:ceil(T_englist(end)); 
T_eng_interp = unique(sort(data(:,2)));


[grid.Mgrid_eng,grid.T_eng] =  ndgrid(M_eng_interp,T_eng_interp);

%% Most important bit..
% grid.Isp_eng = IspScattered(grid.Mgrid_eng,grid.T_eng); % An 'interpolator' which only interpolates at the data points. This is just an easy way to make a grid.


%%


for i = 1:30
    for j= 1:30
grid.Isp_eng(i,j) = polyvaln(p,[grid.Mgrid_eng(i,j) grid.T_eng(i,j)]);
    end
end

% for i = 1:30
%     for j= 1:30
% grid.Isp_eng(i,j) = rbfinterp([grid.Mgrid_eng(i,j);grid.T_eng(i,j)],IspScattered);
%     end
% end

% 
% Vq = []
% for i = 1:length(M_englist)
% for j =1:length(T_englist)
%     DT = delaunayTriangulation(data(:,1),data(:,2))
%     [ti,bc] = pointLocation(DT,[grid.Mgrid_eng(i,j),grid.T_eng(i,j)])
%     if isempty(ti) || isnan(ti)
%     Vq(i,j) =     IspScattered(grid.Mgrid_eng(i,j),grid.T_eng(i,j));
%     else
%     triVals = [data(DT(ti,1),4) data(DT(ti,2),4) data(DT(ti,3),3)]
%     Vq(i,j) = dot(bc',triVals')'
%     
% %     bc = nearestNeighbor(DT,[grid.Mgrid_eng(i,j),grid.T_eng(i,j)])
%     end
% end
% end


scattered.IspGridded = griddedInterpolant(grid.Mgrid_eng,grid.T_eng,grid.Isp_eng,'spline','linear');
% scattered.IspGridded = griddedInterpolant(grid.Mgrid_eng,grid.T_eng,Vq,'linear','linear');

scattered.equivalence = scatteredInterpolant(newdata(:,1),newdata(:,2),newdata(:,4), 'linear');
grid.eq_eng = scattered.equivalence(grid.Mgrid_eng,grid.T_eng);
scattered.eqGridded = griddedInterpolant(grid.Mgrid_eng,grid.T_eng,grid.eq_eng,'linear','linear');


plotM = [min(M_englist):0.01:10];
plotT = [min(T_englist):1:600];
[gridM,gridT] =  ndgrid(plotM,plotT);
interpeq = scattered.eqGridded(gridM,gridT);
interpIsp = scattered.IspGridded(gridM,gridT);




figure(100)
contourf(gridM,gridT,interpeq);

hold on
scatter(data(:,1),data(:,2),30,data(:,4),'filled');

figure(101)
hold on
contourf(gridM,gridT,interpIsp);
scatter(data(:,1),data(:,2),30,data(:,3),'filled')


% contourf(gridM,gridT,griddata(data(:,1),data(:,2),data(:,3),gridM,gridT,'cubic'));
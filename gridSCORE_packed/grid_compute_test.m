
wd='/Users/robert.mok/Desktop/gridSCORE_packed';

cd(wd);
addpath([wd '/gridSCORE_dependencies']);

% load('ex_amap.mat')
% im=amap;
[g,gdata] = gridSCORE(im,'allen'); %allen or wills



%%


% nTrlsToUse = 10000;
% spacing = linspace(locRange(1),locRange(2),locRange(2)+1);
% densityPlot = zeros(length(spacing),length(spacing),nIter);
% for iterI=1:10
%     clus = round(muAll(:,:,nTrials-nTrlsToUse+1:nTrials,iterI));
%     for iTrl=1:nTrlsToUse
%         for i=1:nClus
%             densityPlot(clus(i,1,iTrl),clus(i,2,iTrl),iterI)=densityPlot(clus(i,1,iTrl),clus(i,2,iTrl),iterI)+1; % works, but better way / faster to vectorise?
%         end
%     end
%     densityPlot(:,:,iterI) = imgaussfilt(densityPlot(:,:,iterI),12); %smooth
% %     figure;
% %     imagesc(densityPlot(:,:,iterI));
%     % imagesc(densityPlot(:,:,iter),[100 800]);
% end
% 


figure;
iPlot=0;
for iter=1:3
    iPlot=iPlot+1;
    subplot(2,2,iPlot);
    im=aCorrMap(:,:,iter);
    [g,gdata] = gridSCORE(im,'wills'); %allen or wills
end
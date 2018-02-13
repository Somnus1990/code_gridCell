%% run covering map algorithm with a batch update

clear all;
% close all;

wd='/Users/robert.mok/Documents/Postdoc_ucl/Grid_cell_model';
% wd='/Users/robertmok/Documents/Postdoc_ucl/Grid_cell_model';
% wd='/home/robmok/Documents/Grid_cell_model'; %on love01

cd(wd);
codeDir = [wd '/code_gridCell'];
saveDir = [wd '/data_gridCell'];
addpath(codeDir); addpath(saveDir);
addpath(genpath([wd '/gridSCORE_packed']));

dat = 'rand'; % rand or cat; rand = uniform points in a box, cat = category learning in a 2D feature space

% if cat learning specify number of categories (cluster centres) and sigma of the gaussan
nCats   = 2; %2 categories
sigmaG = [3 0; 0 3]; R = chol(sigmaG);    % isotropic
% sigmaG = [1 .5; .5 2]; R = chol(sigmaG);  % non-isotropic

%run multiple cluster numbers
clus2run = 20; %20, 30
nTrials = 40000; %how many locations in the box / trials - 2.5k ; 5k if reset

%box
nSteps = 50; %to define spacing beween each loc in box
locRange = [0, nSteps-1]; %[-1, 1]; % from locRange(1) to locRange(2)
stepSize=diff(linspace(locRange(1),locRange(2),nSteps)); stepSize=stepSize(1); %smallest diff between locs

% parameters
% epsMuVals=[.05 .075 .1];% %learning rate / starting learning rate 
epsMuVals = [.075 .1]; 

%weight learning rate by SSE 
weightEpsSSE = 0; %1 or 0

%define box / environement - random points in a box
box = 'square'; %square, rect, trapz, trapzSq (trapz and a square box attached)

% change box shape during learning
%rectangle
warpBox = 0; %1 or 0
warpType = 'sq2rect';

%mometum-like adaptive learning rate - define alpha (higher = weight
%previous update (direction and magnitude) more; 0 = don't weight previous at all)
alphaVals = 0;
alpha=0;

sTypes = 0;%:1;% :3; %0, 1 ,2, 3
stochasticType=0;
c=0;
% % Create / load in saved test data
% % tile the whole space
% sq=linspace(locRange(1),locRange(2),nSteps);
% allPts=[];
% for i=1:length(sq)
%     for j=1:length(sq)
%         allPts = [allPts; [sq(i), sq(j)]];
%     end
% end
% trials=repmat(allPts,nTrials/length(allPts),1); %note, numel of allPts must be divisble by nTrials atm
% trials=trials(randperm(length(trials)),:);
% % save([saveDir '/randTrialsBox_40k'],'trials');
% trialsUnique=allPts;
% save([saveDir '/randTrialsBox_trialsUnique'],'trialsUnique');
%%
saveDat=0; %save simulations

nIter=1; %how many iterations (starting points)

switch dat
    case 'rand'
        if nTrials==40000
            load([saveDir '/randTrialsBox_40k']); %load in same data with same trial sequence so same for each sim
        elseif nTrials==80000
            load([saveDir '/randTrialsBox_80k']);
        end
        %for computing sse over trials
        load([saveDir '/randTrialsBox_trialsUnique']);
    case 'cat'
        % draw points from 2 categories (gaussian) from a 2D feature space
        nPoints = floor(nTrials/nCats); % points to sample
        for iCat = 1:nCats
            mu(iCat,:)=randsample(locRange(1)+10:locRange(2)-10,2,'true'); % �10 so category centres are not on the edge
            datPtsGauss(:,:,iCat) = round(repmat(mu(iCat,:),nPoints,1) + randn(nPoints,2)*R); % key - these are the coordinates of the points
        end
        trials = reshape(datPtsGauss,nTrials,2);
        trials = trials(randperm(length(trials)),:);
        trialsUnique=[];
end
    

tic
for iClus2run = 1:length(clus2run) %nClus conditions to run
    nClus = clus2run(iClus2run);
    for iEps = 1:length(epsMuVals) 
        epsMuOrig=epsMuVals(iEps);
        epsMuOrig1000=epsMuOrig*1000; %for saving
        
        [densityPlot,clusMu,muAvg,nTrlsUpd,gA,gW,muAll] = covering_map_batch_sim(nClus,locRange,box,warpType,epsMuOrig,nTrials,nIter,warpBox,alpha,trials,trialsUnique,stochasticType,c,dat,weightEpsSSE);
        fname = [saveDir, sprintf('/covering_map_batch_dat_%dclus_%dtrls_eps%d_%diters',nClus,nTrials,epsMuOrig1000,nIter)];
        timeTaken=toc;
        if saveDat
            if warpBox
                fname = [fname '_warpBox'];
            end
            cTime=datestr(now,'HHMMSS'); fname = sprintf([fname '_%s'],cTime);
            save(fname,'densityPlot','clusMu','gA','gW','muAvg','nIter','timeTaken');
        end
    end
end



toc



% figure; plot(cParams.closestChosen)
% propClosestC = nnz(cParams.closestChosen)/nTrials
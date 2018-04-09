%% run covering map algorithm with a batch update

clear all;
% close all;

wd='/Users/robert.mok/Documents/Postdoc_ucl/Grid_cell_model';
% wd='/Users/robertmok/Documents/Postdoc_ucl/Grid_cell_model';
wd='/home/robmok/Documents/Grid_cell_model'; %on love01

cd(wd);
codeDir = [wd '/code_gridCell'];
saveDir = [wd '/data_gridCell'];
addpath(codeDir); addpath(saveDir);
addpath(genpath([codeDir '/gridSCORE_packed'])); % ****note edited this - in codeDir now not wd

%define box / environment - random points in a box
dat = 'circ'; % rand or cat; rand = uniform points in a box, cat = category learning in a 2D feature space
% dat = 'square'; 
% dat = 'trapz1'; %square rect, trapz, trapzNorm (without Krupic scaling) trapzSqs, or cat (cat learning)
% dat = 'trapz2';% dat = 'trapz3';
% dat = 'trapzKrupic'; % dat = 'trapzKrupic2'; % dat = 'trapzKrupic3';
% dat = 'trapzScaled1';
% dat = 'trapzScaled2';
%  dat = 'trapzScaled3';
% dat = 'trapzNorm';%not scaled, fit into square

boxSize = 1; % 1=normal, 2=double size, 3=triple size

% if cat learning specify number of categories (cluster centres) and sigma of the gaussan
nCats   = 2; %2 categories
sigmaG = [3 0; 0 3]; R = chol(sigmaG);    % isotropic % sigmaG = [1 .5; .5 2]; R = chol(sigmaG);  % non-isotropic


%annealed learning rate
annEps = 0; %1 or 0

%perm testing
doPerm = 0;

jointTrls = 1;


% clus2run = [16:2:30];

% fewer trials, lower learning rate
% clus2run = [16, 20, 18, 30];
% clus2run = [22, 28, 26, 14];

%joint trials; 8, 12, 16, 20, 24, 28;    then 6, 10, 14, 18, 22, 26, 28
clus2run = [8,24];
% clus2run = [28,16];
% clus2run = [20,12];

% clus2run = 20;


%trapz
% clus2run = [18, 24, 26, 28, 16, 30, 20, 22]; %trapzScaled
% clus2run = [24, 26, 30, 28, 20, 22]; %trapzScaled3 x2 size - note 16, 18 actplots dont work
% clus2run = [28 22 14]; %krupic3

% nTrials = 5000000; %how many locations in the box / trials 
% nTrials = 2000000;
nTrials = 1000000; %new

%batch size
fixBatchSize = 1; %fixed, or batchSize depends on mean updates per cluster

% 13, 25, 83, 125, 167, 250, 333, 500, 1000, 2000
if fixBatchSize
%     nBatches = [1250, 2500, 5000, 7500, 10000, 15000, 20000];
%     nBatches = [30000, 100000, 200000, 500000, 1250, 2500, 5000, 7500, 10000, 15000, 20000];
% new select batchSizes
%     nBatches = [2500, 20000,5000 50000];
%     nBatches = [2500, 50000];
%   nBatches = [5000, 20000]; % just run these for annealed learning rate (for now)
%     nBatches = 50000; %even smaller batch size for annealed eps?
    
    %new - for 100k trials, half nBatches for same batchsize
%     nBatches = [20000, 5000, 50000]./2; %half nBatches
    %joint trials
    nBatches = [1000, 10000, 2500]; 
%     nBatches = 2500;
    batchSizeVals = nTrials./nBatches;
    nBvals = length(batchSizeVals);
    
else % define batch size based on average number of updates per cluster
    avgBatchUpdate = [10, 25, 35, 50]; % 
    avgBatchUpdate = [1, 2, 5]; % avgBatchUpdate = 25;
    nBvals = length(avgBatchUpdate);
%     batchSizePerClus = clus2run.*avgBatchUpdate %just to check
    % nBatches = nTrials./batchSizePerClus; %per clus cond %this is not used..
end

% parameters
% epsMuVals=[.01, .05, .075, .1, .2, .3];% %learning rate / starting learning rate 
% epsMuVals = 0.075; 
% epsMuVals = [0.05, 0.025]; 
epsMuVals = 0.05;
epsMuVals = 0.025;
% epsMuVals = 0.015; 


% learning rate - annealed (reduced over time)  -actually beter to compute
% inside?
% if annEps
%     epsMuVals = nBatches/100;
% end

% %tesing 60+clusters
% nTrials = 1000000; 
% nBatches = 1000;
% batchSizeVals = nTrials/nBatches; 
% epsMuVals = 0.025; 

% use the same training data (trials) across current sims or gen new data
useSameTrls=0;

%box
nSteps = 50; %to define spacing beween each loc in box
locRange = [0, nSteps-1]; %[-1, 1]; % from locRange(1) to locRange(2)
stepSize=diff(linspace(locRange(1),locRange(2),nSteps)); stepSize=stepSize(1); %smallest diff between locs

if boxSize==2 %double
    locRange(2)= locRange(2)*2;
elseif boxSize==3 %triple
    locRange(2)= locRange(2)*3;
end


% change box shape during learning rectangle
warpBox = 0; %1 or 0
warpType = 'sq2rect';

sTypes = 0;%:1;% :3; %0, 1 ,2, 3
stochasticType=0;
c=0;
%%
saveDat=1; %save simulations

nIter=200; %how many iterations (starting points)

switch dat
    case 'square'
        trials = [randsample(linspace(locRange(1),locRange(2),50),nTrials,'true'); randsample(linspace(locRange(1),locRange(2),50),nTrials,'true')]';
        %for computing sse over trials
%         load([saveDir '/randTrialsBox_trialsUnique']);
        trialsUnique=[];
    case 'cat'
        % draw points from 2 categories (gaussian) from a 2D feature space
        nTrials = floor(nTrials/nCats); % points to sample
        for iCat = 1:nCats 
            mu(iCat,:)=randsample(locRange(1)+10:locRange(2)-10,2,'true'); % �10 so category centres are not on the edge
            datPtsGauss(:,:,iCat) = round(repmat(mu(iCat,:),nTrials,1) + randn(nTrials,2)*R); % key - these are the coordinates of the points
        end
        trials = reshape(datPtsGauss,nTrials,2);
        trials = trials(randperm(length(trials)),:);
        trialsUnique=[];
    otherwise
        trials=[]; trialsUnique=[];
end

tic
for iClus2run = 1:length(clus2run) %nClus conditions to run
    nClus = clus2run(iClus2run);
    for iEps = 1:length(epsMuVals) 
        epsMuOrig=epsMuVals(iEps);
        epsMuOrig1000=epsMuOrig*1000; %for saving
        for iBvals = 1:nBvals
            if annEps
                epsMuOrig1000 = nBatches(iBvals)/100;%for saving
            end
            if fixBatchSize
                batchSize = batchSizeVals(iBvals); %fixed batch size
                fprintf('Running %s, nClus=%d, epsMu=%d, batchSize=%d\n',dat,nClus,epsMuOrig1000,batchSize)
%                 fname = [saveDir, sprintf('/covering_map_batch_dat_%dclus_%dktrls_eps%d_batchSiz%d_%diters',nClus,round(nTrials/1000),epsMuOrig1000,round(batchSize),nIter)];
                fname = [saveDir, sprintf('/covering_map_batch_dat_%dclus_%dktrls_eps%d_batchSiz%d_%diters_%s_wAct',nClus,round(nTrials/1000),epsMuOrig1000,round(batchSize),nIter,dat)];
            else % define batch size based on average number of updates per cluster 
%                 batchSize = clus2run(iClus2run).*avgBatchUpdate(iBvals); % batch size depends on average updates per cluster (depends on nClus cond)
%                 fprintf('Running %s, nClus=%d, epsMu=%d, avgBatchUpd=%d; batchSize=%d\n',dat,nClus,epsMuOrig1000,avgBatchUpdate(iBvals),batchSize)
%                 fname = [saveDir, sprintf('/covering_map_batch_dat_%dclus_%dktrls_eps%d_avgBatch%d_batchSiz%d_%diters',nClus,round(nTrials/1000),epsMuOrig1000,round(avgBatchUpdate(iBvals)),round(batchSize),nIter)];
            end
%             [densityPlot,densityPlotAct,densityPlotActNorm,clusMu,gA,gW,gA_act,gW_act,gA_actNorm,gW_actNorm,rSeed] = covering_map_batch_sim(nClus,locRange,warpType,epsMuOrig,nTrials,batchSize,nIter,warpBox,alpha,trials,useSameTrls,trialsUnique,stochasticType,c,dat,weightEpsSSE);
            [densityPlot,densityPlotActNorm,gA,gA_actNorm,muInit,rSeed,clusDistB, permPrc] = covering_map_batch_sim(nClus,locRange,warpType,epsMuOrig,nTrials,batchSize,nIter,warpBox,trials,useSameTrls,stochasticType,c,dat,annEps,doPerm);

            timeTaken=toc;
            if saveDat
                if useSameTrls
                    fname = [fname '_useSameTrls'];
                end
                if warpBox
                    fname = [fname '_warpBox'];
                end
                if boxSize>1
                    fname = [fname sprintf('_boxSizex%d',boxSize)];
                end
                if annEps
                    fname = [fname '_annEps'];
                end
                cTime=datestr(now,'HHMMSS'); fname = sprintf([fname '_%s'],cTime);
%                 save(fname,'densityPlot','densityPlotAct','clusMu','gA','gW','gA_act','gW_act','nIter','rSeed','timeTaken'); %added trialsAll for xval - removed, too big.maybe compute at end of each sim? or at each set
%                 save(fname,'densityPlot','densityPlotActNorm','gA','gA_actNorm','rSeed','muInit','clusDistB','timeTaken'); 

                if doPerm
                    fname = [fname '_doPerm'];
                end
                
                if jointTrls
                    fname = [fname '_jointTrls'];
                end
                    
                
                save(fname,'densityPlot','densityPlotActNorm','gA','gA_actNorm','rSeed','muInit','clusDistB','permPrc','timeTaken'); 

            end
        end
        
    end
end
toc

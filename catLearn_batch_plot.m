clear all;

wd='/Users/robertmok/Documents/Postdoc_ucl/Grid_cell_model';
wd='/Users/robert.mok/Documents/Postdoc_ucl/Grid_cell_model';
cd(wd);

codeDir = [wd '/code_gridCell'];
savDir = [wd '/data_gridCell'];
figDir = [wd '/data_gridCell/figs'];
addpath(codeDir); addpath(savDir); addpath(figDir);
addpath(genpath([codeDir '/gridSCORE_packed']));

dat='catLearn';
% annEps=0;
boxSize=1;
nIter=20;
locRange = [0, 49];

% clus2run = 2:26; 
% clus2run = [2,3,4,5,8]; 
% clus2run = [10, 15,20,25,30]; 

clus2run = [2,3,4]; 
clus2run = [5,8,10]; 
clus2run = [15, 25, 30]; 


jointTrls=0;
epsMuVals=.025;
nTrials=50000;
batchSizeVals= [5, 10, 25]; %5, 10, 25?
% batchSizeVals= 10; 

nCats=2; %2,3,4
stoch=1;
cVals = [2, 4, 10, 40];
% cVals = 4;

catsInfo.nCats=2; %2 categories
% sigmaG = [5 0; 0 5];   % isotropic % sigmaG = [1 .5; .5 2]; R = chol(sigmaG);  % non-isotropic
sigmaG = [3 0; 0 3];
catsInfo.R=chol(sigmaG);



%load loop
muAllClus = cell(1,length(clus2run));
rSeedAll  = cell(length(clus2run),length(batchSizeVals),length(cVals));

 for iClus = 1:length(clus2run)
    nClus = clus2run(iClus);
    for iEps = 1:length(epsMuVals)
        epsMuOrig=epsMuVals(iEps);
        epsMuOrig1000=epsMuOrig*1000;
        for iBvals = 1:length(batchSizeVals)
            for iC = 1:length(cVals)
                fprintf('Loading %s, nClus=%d, epsMu=%d, c=%d, batchSize=%d\n',dat,nClus,epsMuOrig1000,cVals(iC),batchSizeVals(iBvals))

                fname = [savDir, sprintf('/covering_map_batch_dat_%dclus_%dktrls_eps%d_batchSiz%d_%diters_%s_wAct_%dcats_stoch%d_c%d_*',nClus,round(nTrials/1000),epsMuOrig1000,batchSizeVals(iBvals),nIter,dat,nCats,stoch,cVals(iC))];
                f=dir(fname);
                load(f.name);
                
                %just load in those to plot
                nBatches = size(muAll,3)-1;
%                 trls2Plt = [1, nBatches*.25, nBatches*.5, nBatches*.75, nBatches+1];
                trls2plt = [1, nBatches*.5, nBatches+1];
                muAllClus{iClus}(:,:,:,:,iBvals,iC)=muAll(:,:,trls2plt,:);
                rSeedAll{iClus,iBvals,iC} = rSeed;

%                 muAllClus{iClus}(:,:,:,:,iBvals,iC)=muAll;
%                 muAllClus{iClus}(:,:,:,:,iEps,iBvals,iC)=muAll;                
                
                
            end
        end
    end
end
    
%%
savePlots = 1;

fontSiz=15;
datPtSiz=15;

% iterI=1;

trls2plt = {1:25, 1:100, 1:2000};

for iterI=1:5
    
    for iBvals= 1:length(batchSizeVals)
    for iC = 1:length(cVals)
    
    ctr=0;
    figure; hold on;
    for iClus = 1:length(clus2run)
        colors  = distinguishable_colors(clus2run(iClus));
        %     figure; hold on;
        for iPlot = 1:length(trls2plt)
            ctr=ctr+1;
            subplot(length(clus2run),length(trls2plt),ctr); hold on;
            %         subplot(1,length(trls2Plt),iPlot);
            trials = createTrls(dat,nTrials,locRange,1,jointTrls,boxSize,catsInfo,rSeedAll{iClus,iBvals,iC}(iterI)); hold on;
            
            
%             scatter(trials(:,1),trials(:,2),5,[.5 .5 .5],'.');
            scatter(trials(trls2plt{iPlot},1),trials(trls2plt{iPlot},2),datPtSiz,[.5 .5 .5],'.');

            
            
            scatter(muAllClus{iClus}(:,1,iPlot,iterI,iBvals,iC),muAllClus{iClus}(:,2,iPlot,iterI,iBvals,iC),200,colors,'.');hold on;
            
            xlim([locRange(1) locRange(2)+1]);
            ylim([locRange(1) locRange(2)+1]);
            %         xticks([0, 50]); xticklabels({'0', '50'}); yticks(50); yticklabels({'50'});
            xticks([]); xticklabels({''}); yticks([]); yticklabels({''});
            
            if iClus==1 && iPlot==ceil(length(trls2plt)/2)
%                 title(sprintf('Category Learning, %d categories; batchSize=%d',nCats, batchSizeVals(iBvals)))
                title(sprintf('Category Learning, %d categories',nCats))
            end
            if iPlot==1
                ylabel(sprintf('%d clus',clus2run(iClus)));
            end
            if iClus==3 && iPlot==2
                xlabel('Timesteps (start, middle, end)')
            end
            set(gca,'FontSize',fontSiz,'fontname','Arial')
        end
    end
    
    fname = [figDir, sprintf('/catLearn_eps%d_batchSiz%d_%dcats_stoch%d_c%d_nClus%d-%d-%d_iter%d',epsMuOrig1000,batchSizeVals(iBvals),nCats,stoch,cVals(iC),clus2run(1),clus2run(2),clus2run(3),iterI)];
    if savePlots
        set(gcf,'Renderer','painters');
        print(gcf,'-depsc2',fname)
        saveas(gcf,fname,'png');
        close all
    end
    end
    end
    
end
                
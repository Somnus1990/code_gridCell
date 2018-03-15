function [densityPlot,clusMu,gA,gW,rSeed,muAll] = covering_map_batch_sim(nClus,locRange,warpType,epsMuOrig,nTrials,batchSize,nIter,warpBox,alpha,trials,useSameTrls,trialsUnique,stochasticType,c,dat,weightEpsSSE)

spacing=linspace(locRange(1),locRange(2),locRange(2)+1); 
stepSize=diff(spacing(1:2)); nSteps = length(spacing);

nTrialsTest = nTrials;

gaussSmooth=1; %smoothing for density map

nBatch=floor(nTrials/batchSize);
batchSize = floor(batchSize); % when have decimal points, above needed

% selecting cluster postions from a certain phase to test gridness
% note: with batch, may be less purposeful to average over trials. it would
% also mean averaging over batches (which would be even more stable). only
% thing if just looking at some point in time, small batches = less stable.
trlSel = ceil([nBatch*.25, nBatch*.5, nBatch*.67, nBatch*.75, nBatch*.9, nBatch+1]);


%also get a bunch of trials to plot activations from current trial (gauss
%func of clus loc) - make it 6 like sets above
%note that this is averaging over trials, not just batches though - might
%be to show activations as clusters are stationary as well as move?

fromTrlI = [nTrials*.24+1, nTrials*.49+1, nTrials*.66+1, nTrials*.74+1, nTrials*.89+1, nTrials*.99+1]; % 1% of trials, should have a handful of batch updates %+1 so not 1 trial extra
toTrlN   = [nTrials*.25,   nTrials*.5,    nTrials*.67,   nTrials*.75,   nTrials*.9,    nTrials+1];%same prop to above batches; but show activations that lead up to this
   

if nargout > 5
    muAll            = nan(nClus,2,nBatch+1,nIter);
end
nSets                = length(trlSel);
clusMu               = nan(nClus,2,nSets,nIter);
% tsseAll              = nan(nBatch+1,nIter); %not sure if this is +1 or not; not tested
% rSeed = struct(1,nIter); %how to initialise this struct?
gA = nan(nSets,nIter,4);
gW = nan(nSets,nIter,4);
%if trapz - compute gridness of left/right half of boxes too
if strcmp(dat(1:5),'trapz')
    gA = nan(nSets,nIter,4,3);
    gW = nan(nSets,nIter,4,3);
end

%set densityPlot array size
trapzSpacing{1} = spacing(10:41);
trapzSpacing{2} = spacing(7:44); 
trapzSpacing{3} = spacing(4:47);
if strcmp(dat(1:5),'trapz') && length(dat)>10
    if strcmp(dat(1:11),'trapzScaled')
        spacingTrapz = trapzSpacing{str2double(dat(12))}; %trapzScaled1,2,3
        a=length(spacingTrapz); %trapz length1
        b=locRange(2)+1; %50 - trapz length2
        h=round(((locRange(2)+1)^2)/((a+b)/2)); %trapz height (area = 50^2; like square)
    elseif strcmp(dat,'trapzKrupic2')
        b=length(spacing)*1.5; %make smaller; since datapoints dont reach out there
        h=length(spacing)*2;
    elseif strcmp(dat,'trapzKrupic3')
        b=length(spacing)*2; %make smaller; since datapoints dont reach out there
        h=length(spacing)*3;
    end
else
    b=length(spacing);
    h=length(spacing);
end
densityPlotClus = zeros(b,h,nClus,nSets,nIter);
densityPlot     = zeros(b,h,nSets,nIter);

for iterI = 1:nIter
    
    fprintf('iter %d \n',iterI);
    epsMu = epsMuOrig; %revert learning rate back to original if reset

    if ~useSameTrls %if want training data to be different set of points
        %make seed so can regenerate the trials later without saving - load up
        %the seed using: rng(s); then run trials = ...
        rSeed(iterI)=rng;
        switch dat
            case 'square' %square
                trials      = [randsample(linspace(locRange(1),locRange(2),50),nTrials,'true'); randsample(linspace(locRange(1),locRange(2),50),nTrials,'true')]';
                dataPtsTest = [randsample(linspace(locRange(1),locRange(2),50),nTrials,'true'); randsample(linspace(locRange(1),locRange(2),50),nTrials,'true')]';
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
                
                for iCat = 1:nCats
                    mu(iCat,:)=randsample(locRange(1)+10:locRange(2)-10,2,'true'); % �10 so category centres are not on the edge
                    datPtsGauss(:,:,iCat) = round(repmat(mu(iCat,:),nTrials,1) + randn(nTrials,2)*R); % key - these are the coordinates of the points
                end
                dataPtsTest = reshape(datPtsGauss,nTrials,2);
                dataPtsTest = dataPtsTest(randperm(length(dataPtsTest)),:);
                
            case 'rect'
                trials      = [randsample(locRange(1):diff(spacing(1:2)):locRange(2)/1.5,nTrialsTest,'true'); randsample(spacing,nTrialsTest,'true')]';
                dataPtsTest = [randsample(locRange(1):diff(spacing(1:2)):locRange(2)/1.5,nTrialsTest,'true'); randsample(spacing,nTrialsTest,'true')]';
            case 'trapzKrupic'
                %if scale to Krupic:
                %%%%%
                spacingTrapz = spacing(14:37); %23.7 would be right, here 24; krupic (relative): [5.26, 23.68, 50]
                %%%%% 
                trapY=locRange(2).*trapmf(spacingTrapz,[spacingTrapz(1), spacingTrapz(round(length(spacingTrapz)*.25)), spacingTrapz(round(length(spacingTrapz)*.75)),spacingTrapz(end)]);
                trapX=spacingTrapz;
                trapPts=[];
                for i=1:length(trapY)
                    trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
                end
                %             trapPts(2,:)=trapPts(2,:).*2-1; %put it back into -1 to 1
                % use this to select from the PAIR in trapPts
                trialInd     = randi(length(trapPts),nTrials,1);
                trials       = trapPts(:,trialInd)';
                %dataPtsTest
                trialIndTest = randi(length(trapPts),nTrials,1);
                dataPtsTest  = trapPts(:,trialIndTest)';
            case 'trapzKrupic2'
                 %if scale to Krupic x 2:
                spacingTrapz = spacing(14:37); %23.7 would be right, here 24; krupic (relative): [5.26, 23.68, 50]
                trapY=locRange(2)*2.*trapmf(spacingTrapz,[spacingTrapz(1), spacingTrapz(round(length(spacingTrapz)*.25)), spacingTrapz(round(length(spacingTrapz)*.75)),spacingTrapz(end)]);
                trapX=spacingTrapz(1):2:spacingTrapz(end)*2;
                trapPts=[];
                for i=1:length(trapY)
                    trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
                end
                % use this to select from the PAIR in trapPts
                trialInd     = randi(length(trapPts),nTrials,1);
                trials       = trapPts(:,trialInd)';
                %dataPtsTest
                trialIndTest = randi(length(trapPts),nTrials,1);
                dataPtsTest  = trapPts(:,trialIndTest)';  
            case 'trapzKrupic3'
                 %if scale to Krupic x 3:
                spacingTrapz = spacing(14:37); %23.7 would be right, here 24; krupic (relative): [5.26, 23.68, 50]
                trapY=locRange(2)*3.*trapmf(spacingTrapz,[spacingTrapz(1), spacingTrapz(round(length(spacingTrapz)*.25)), spacingTrapz(round(length(spacingTrapz)*.75)),spacingTrapz(end)]);
                trapX=spacingTrapz(1):2:spacingTrapz(end)*2;
                trapPts=[];
                for i=1:length(trapY)
                    trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
                end
                trialInd     = randi(length(trapPts),nTrials,1);
                trials       = trapPts(:,trialInd)';
                %dataPtsTest
                trialIndTest      = randi(length(trapPts),nTrials,1);
                dataPtsTest       = trapPts(:,trialIndTest)';
            case 'trapzNorm' % not scale - fit into square 
                spacingTrapz = spacing; 
                trapY=locRange(2).*trapmf(spacingTrapz,[spacingTrapz(1), spacingTrapz(round(length(spacingTrapz)*.25)), spacingTrapz(round(length(spacingTrapz)*.75)),spacingTrapz(end)]);
                trapX=spacingTrapz;
                trapPts=[];
                for i=1:length(trapY)
                    trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
                end
                trialInd     = randi(length(trapPts),nTrials,1);
                trials       = trapPts(:,trialInd)';
                %dataPtsTest
                trialIndTest = randi(length(trapPts),nTrials,1);
                dataPtsTest  = trapPts(:,trialIndTest)';
                
            case 'trapz1' % new - scale differently - more like box but more squished
                spacingTrapz = spacing(10:41); 
                trapY=locRange(2).*trapmf(spacingTrapz,[spacingTrapz(1), spacingTrapz(round(length(spacingTrapz)*.25)), spacingTrapz(round(length(spacingTrapz)*.75)),spacingTrapz(end)]);
                trapX=spacingTrapz;
                trapPts=[];
                for i=1:length(trapY)
                    trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
                end
                % use this to select from the PAIR in trapPts
                trialInd     = randi(length(trapPts),nTrials,1);
                trials       = trapPts(:,trialInd)';
                %dataPtsTest
                trialIndTest = randi(length(trapPts),nTrials,1);
                dataPtsTest  = trapPts(:,trialIndTest)';                
            case 'trapz2' % new - scale differently - more like box but more squished
                spacingTrapz = spacing(7:44); 
                trapY=locRange(2).*trapmf(spacingTrapz,[spacingTrapz(1), spacingTrapz(round(length(spacingTrapz)*.25)), spacingTrapz(round(length(spacingTrapz)*.75)),spacingTrapz(end)]);
                trapX=spacingTrapz;
                trapPts=[];
                for i=1:length(trapY)
                    trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
                end
                % use this to select from the PAIR in trapPts
                trialInd     = randi(length(trapPts),nTrials,1);
                trials       = trapPts(:,trialInd)';
                %dataPtsTest
                trialIndTest = randi(length(trapPts),nTrials,1);
                dataPtsTest  = trapPts(:,trialIndTest)';  
            case 'trapz3' % new - scale differently - more like box but more squished
                spacingTrapz = spacing(4:47); 
                trapY=locRange(2).*trapmf(spacingTrapz,[spacingTrapz(1), spacingTrapz(round(length(spacingTrapz)*.25)), spacingTrapz(round(length(spacingTrapz)*.75)),spacingTrapz(end)]);
                trapX=spacingTrapz;
                trapPts=[];
                for i=1:length(trapY)
                    trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
                end
                % use this to select from the PAIR in trapPts
                trialInd     = randi(length(trapPts),nTrials,1);
                trials       = trapPts(:,trialInd)';
                %dataPtsTest
                trialIndTest = randi(length(trapPts),nTrials,1);
                dataPtsTest  = trapPts(:,trialIndTest)';  
                
            case 'trapzScaled1' % new - scale differently - now loc > 50 though
%                 spacingTrapz = spacing(10:41); 
                trapY=h.*trapmf(spacingTrapz,[spacingTrapz(1), spacingTrapz(round(length(spacingTrapz)*.25)), spacingTrapz(round(length(spacingTrapz)*.75)),spacingTrapz(end)]);
                trapX=spacingTrapz;
                trapPts=[];
                for i=1:length(trapY)
                    trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
                end
                % use this to select from the PAIR in trapPts
                trialInd     = randi(length(trapPts),nTrials,1);
                trials       = trapPts(:,trialInd)';
                %dataPtsTest
                trialIndTest = randi(length(trapPts),nTrials,1);
                dataPtsTest  = trapPts(:,trialIndTest)';  
                          
            case 'trapzScaled2' % new - scale differently - now loc > 50 though
%                 spacingTrapz = spacing(7:44); 
                trapY=h.*trapmf(spacingTrapz,[spacingTrapz(1), spacingTrapz(round(length(spacingTrapz)*.25)), spacingTrapz(round(length(spacingTrapz)*.75)),spacingTrapz(end)]);
                trapX=spacingTrapz;
                trapPts=[];
                for i=1:length(trapY)
                    trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
                end
                % use this to select from the PAIR in trapPts
                trialInd     = randi(length(trapPts),nTrials,1);
                trials       = trapPts(:,trialInd)';
                %dataPtsTest
                trialIndTest = randi(length(trapPts),nTrials,1);
                dataPtsTest  = trapPts(:,trialIndTest)';  
               
            case 'trapzScaled3' % new - scale differently - now loc > 50 though
%                 spacingTrapz = spacing(4:47); 
                trapY=h.*trapmf(spacingTrapz,[spacingTrapz(1), spacingTrapz(round(length(spacingTrapz)*.25)), spacingTrapz(round(length(spacingTrapz)*.75)),spacingTrapz(end)]);
                trapX=spacingTrapz;
                trapPts=[];
                for i=1:length(trapY)
                    trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
                end
                % use this to select from the PAIR in trapPts
                trialInd     = randi(length(trapPts),nTrials,1);
                trials       = trapPts(:,trialInd)';
                %dataPtsTest
                trialIndTest = randi(length(trapPts),nTrials,1);
                dataPtsTest  = trapPts(:,trialIndTest)';  
                
            case 'trapzSq' %probably need a more narrow trapezium!
                trapY=locRange(2)/2.*trapmf(spacing,[spacing(1), spacing(round(length(spacing)*.25)), spacing(round(length(spacing)*.75)),spacing(end)]);
                trapY=trapY+floor(length(trapY)./2);
                trapX=spacing;
                trapPts=[];
                for i=1:length(trapY)
                    trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
                end
                %make square box attached to it
                sqX=spacing;
                sqY=spacing(1:floor(length(spacing)/2));
                for i=1:length(sqX)
                    for j=1:length(sqY)
                        trapPts = [trapPts, [sqX(i); sqY(j)]];
                    end
                end
                % use this to select from the PAIR in trapPts
                trialInd     = randi(length(trapPts),nTrials,1);
                trials       = trapPts(:,trialInd)';
                %dataPtsTest
                trialIndTest = randi(length(trapPts),nTrials,1);
                dataPtsTest  = trapPts(:,trialIndTest)';  
            case 'circ'
                % Create logical image of a circle
                imageSizeX = nSteps;
                [columnsInImage, rowsInImage] = meshgrid(1:imageSizeX, 1:imageSizeX);
                centerX = nSteps/2; centerY = nSteps/2;
                radius = nSteps/2-1;
                circIm = (rowsInImage - centerY).^2 ...
                    + (columnsInImage - centerX).^2 <= radius.^2;
                circPts=[]; % find circle points in XY coords
                for iX=1:length(circIm)
                    yVals = find(circIm(iX,:));
                    circPts = [circPts; ones(length(yVals),1)*iX, yVals'];
                end
                trialInd=randi(length(circPts),nTrials,1);
                trials=circPts(trialInd,:);
                %dataPtsTest
                trialIndTest = randi(length(circPts),nTrials,1);
                dataPtsTest  = circPts(trialIndTest,:);
        end
        %trialsAll(:,:,iterI) = trials;
    end
    
    % if expand box
    switch warpType
        case 'sq2rect'
            trialsExpand = [randsample(locRange(1):diff(spacing(1:2)):locRange(2)*2,nTrials*.75,'true'); randsample(spacing,nTrials*.75,'true')]';
        case 'rect2sq'
            trialsExpand = [randsample(spacing,nTrials*.75,'true'); randsample(spacing,nTrials*.75,'true')]'; %this doesn't work - actually, maybe this isn't a thing?
    end
    
    %initialise each cluster location  
    mu = nan(nClus,2,nBatch+1);
    mu(:,:,1) = kmplusInit(dataPtsTest,nClus); %kmeans++ initialisation
    %%
    
%     updatedC = nan(nTrials,1);
%     epsMuAll = nan(nTrials,2);
    deltaMu  = zeros(nClus,2,nBatch);
%     clusUpdates = zeros(nClus,2); %acutally starting at 0 is OK, since there was no momentum from last trial
    tsse            = nan(nBatch,1);
    sseW            = ones(nBatch,1);
    
    for iBatch=1:nBatch
        batchInd=batchSize*(iBatch-1)+1:batchSize*(iBatch-1)+batchSize; %trials to average over

        trls2Upd = trials(batchInd,:); %trials to use this batch

%             %if change size of box half way
%             if iTrl == nTrials*.75 && warpBox
%                 trials(nTrials*.75+1:end,:) = trialsExpand;
%             end

            %compute distances
%             dist2Clus = sqrt(sum([mu(:,1,iTrl)'-trials(iTrl,1); mu(:,2,iTrl)'-trials(iTrl,2)].^2)); % vectorising euclid dist - sqrt(sum((a-b).^2)), since can't use xval method
            
            %compute distances - vectorise both clusters and trials (in batch)
            dist2Clus = sqrt(sum(reshape([mu(:,1,iBatch)'-trls2Upd(:,1), mu(:,2,iBatch)'-trls2Upd(:,2)].^2,batchSize,nClus,2),3));% reshapes it into batchSize x nClus x 2 (x and y locs)
%             dist2Clus = sqrt(sum(dist2Clus,3));
            
            %stochastic update - select 1 of the closest clusters w random element - stochastic parameter c - large is deterministic, 0 - random            
%             if stochasticType %stochastic update
%                 if stochasticType==1
% %                     beta=c*(iTrl-1);         % so this gets bigger, and more deterministic with more trials
%                     beta=c*(iTrl+nTrials/50);  % maybe no need to be so stochatic at start
%                 elseif stochasticType==2
%                     beta=c*(iTrl+nTrials/50);  % maybe no need to be so stochatic at start
%                     if beta >= c*500 %it might be worth checking if this depends on nClusters - distances will change
%                         beta = c*500;
%                     end
%                 elseif stochasticType==3
%                     beta = c*500; % as a function of c %prev:.185; 
%                 end
%                 dist2Clus2 = exp(-beta.*dist2Clus)./ sum(exp(-beta.*dist2Clus));
%                 distClusPr = cumsum(dist2Clus2);
%                 closestC=find(rand(1)<distClusPr,1);
%                 if isempty(closestC)  %if beta is too big, just do deterministic update (already will be near deterministic anyway)
%                     closestC=find(min(dist2Clus)==dist2Clus);
%                 end
%                 cParams.betaAll(iTrl)       = beta;
%             else %deterministic update
%                 closestC=find(min(dist2Clus)==dist2Clus);
%             end
%             if numel(closestC)>1 %if more than 1, randomly choose one
%                 closestC = randsample(closestC,1);
%             end
            
            %deterministic update
%             closestC=find(min(dist2Clus)==dist2Clus);

            %deterministic update - batch; save closestC for each trial
            %%%% -need to find min dist cluster for each trial; better way?
            %%%% / vectorize?
            closestC = nan(1,batchSize);
            for iTrlBatch = 1:batchSize
                closestTmp = find(min(dist2Clus(iTrlBatch,:))==dist2Clus(iTrlBatch,:));
                if numel(closestTmp)>1
                    closestC(iTrlBatch) = randsample(closestTmp,1);
                else
                    closestC(iTrlBatch) = closestTmp;
                end
            end
            
%             %if stochastic, closestC might not be if more than 1 actual
%             %closest, have to check if stoch update chose one of them
%             actualClosestC = find(min(dist2Clus)==dist2Clus); 
%             closestMatch = zeros(1,length(actualClosestC));
%             for iC = 1:length(actualClosestC)
%                 closestMatch(iC) = actualClosestC(iC) == closestC;
%             end
%             cParams.closestChosen(iTrl) = any(closestMatch); %was (one of) the closest cluster selected?
%             cParams.closestDist(iTrl)   = dist2Clus(closestC);

            %log which cluster has been updated
%             updatedC(iTrl) = closestC;
            
            %learning rate
            epsMu = epsMuOrig;
%             epsMu = epsMuOrig*sseW(iTrl); %weight learning rate by prop SSE reduce from start
%             epsMuAll(iTrl,:) = [epsMu,closestC]; 
            
            %batch update - save all updates for each cluster for X
            %trials, update it, then again
            % - goes through each cluster, compute distances, average,
            %then update
            for iClus = 1:nClus
                updInd = closestC==iClus;
                if any(nnz(updInd)) %if not, no need to update
                deltaMu(iClus,1,iBatch) = nanmean(epsMu*(trls2Upd(updInd,1)-mu(iClus,1,iBatch)));
                deltaMu(iClus,2,iBatch) = nanmean(epsMu*(trls2Upd(updInd,2)-mu(iClus,2,iBatch)));
                end
            end
            
%             %update (with momemtum-like parameter)
%             deltaMu(closestC,1,iTrl) = ((1-alpha)*(epsMu*(trials(iTrl,1)-mu(closestC,1,iTrl))))+(alpha*clusUpdates(closestC,1));
%             deltaMu(closestC,2,iTrl) = ((1-alpha)*(epsMu*(trials(iTrl,2)-mu(closestC,2,iTrl))))+(alpha*clusUpdates(closestC,2));
%             
%             %for momentum - consider not using this, or switch to a
%             %'batch-like' momentum later?
%             clusUpdates(closestC,1)=deltaMu(closestC,1,iTrl);
%             clusUpdates(closestC,2)=deltaMu(closestC,2,iTrl);

            % update mean estimates
            mu(:,1,iBatch+1) = mu(:,1,iBatch) + deltaMu(:,1,iBatch);
            mu(:,2,iBatch+1) = mu(:,2,iBatch) + deltaMu(:,2,iBatch);
            
            
            % compute sse on each trial with respect to 'all trials' 
            % trials - since values are all points in the box, no need to use a
            % trialsTest, juse use all unique locations (unique pairs of xy) from trials
            
            
            %weight learning rate by SSE - 
            %%%%%%
            % - atm SSE goes down really quick with batch - shouldn't weigh
            % by initial SSE!(even more so than before)
            %%%%%%
            if weightEpsSSE
                sse=nan(1,nClus);
                distTrl=(mu(:,1,iBatch)'-trialsUnique(:,1)).^2+(mu(:,2,iBatch)'-trialsUnique(:,2)).^2; % vectorised
                [indValsTrl, indTmp]=min(distTrl,[],2); % find which clusters are points closest to
                
                %any way to vectorize this?
                for iClus = 1:size(clusMu,1)
                    sse(iClus)=sum(sum([mu(iClus,1,iBatch)-trialsUnique(indTmp==iClus,1), mu(iClus,2,iBatch)-trialsUnique(indTmp==iClus,2)].^2,2)); %distance from each cluster from training set to datapoints closest to that cluster
                    % sse(iClus)=sum(sum([clusMu(iClus,1,iSet,iterI)-dataPtsTest(indTmp==iClus,1), clusMu(iClus,2,iSet,iterI)-dataPtsTest(indTmp==iClus,2)].^2,2)); %distance from each cluster from training set to datapoints closest to that cluster
                end
                tsse(iBatch)=sum(sse);
                sseW(iBatch+1) = tsse(iBatch)./tsse(1);% weight next learning rate by prop of sse from the start
                
%                 devAvgSSE             = sse-mean(sse);
%                 stdAcrossClus(iBatch) = std(devAvgSSE); % may be better since normalises by nClus?
%                 varAcrossClus(iBatch) = var(devAvgSSE);
            end
            
%             %compute SSE and save - don't do if run above. consider only
%             %running this outside of the sim? - yes; in xVal_clus.m. Also
%             not sure if this works here

%             sse=nan(1,nClus);
%             distTrl=(mu(:,1,iBatch)'-trialsUnique(:,1)).^2+(mu(:,2,iBatch)'-trialsUnique(:,2)).^2; % vectorised
%             [indValsTrl, indTmp]=min(distTrl,[],2); % find which clusters are points closest to
%             
%             %any way to vectorize this?
%             for iClus = 1:size(clusMu,1)
%                 sse(iClus)=sum(sum([mu(iClus,1,iBatch)-trialsUnique(indTmp==iClus,1), mu(iClus,2,iBatch)-trialsUnique(indTmp==iClus,2)].^2,2)); %distance from each cluster from training set to datapoints closest to that cluster
%                 % sse(iClus)=sum(sum([clusMu(iClus,1,iSet,iterI)-dataPtsTest(indTmp==iClus,1), clusMu(iClus,2,iSet,iterI)-dataPtsTest(indTmp==iClus,2)].^2,2)); %distance from each cluster from training set to datapoints closest to that cluster
%             end
%             tsse(iBatch)=sum(sse);
%             sseW(iBatch+1) = tsse(iBatch)./tsse(1);% weight next learning rate by prop of sse from the start
%             devAvgSSE             = sse-mean(sse);
%             stdAcrossClus(iBatch) = std(devAvgSSE); % may be better since normalises by nClus?
%             varAcrossClus(iBatch) = var(devAvgSSE);


    end
    if nargout > 5
        muAll(:,:,:,iterI)      = mu;
    end
%     tsseAll(:,iterI)        = tsse;
%     sseSpreadSd(:,iterI)    = stdAcrossClus;
%     sseSpreadVar(:,iterI)   = varAcrossClus;

    % densityPlotClus - density plot with each cluster in dim 3 - more like
    % a place cell map - use to find clusMu (clus centres) - leave it out
    % here so can use diff smoothing values outside . also then use to make
    % it a gridcell map: densityPlot=sum(densityPlotClus,3); - to compute autocorrelogram
    % muAvg - also save cluster positions averaged over to plot average cluster
    %positions
    for iSet = 1:nSets
        %compute density map
        clus = round(mu(:,:,trlSel(iSet)));
        ind=clus<=0; clus(ind)=1; %indices <= 0 make to 1
        for iClus=1:nClus
            ntNanInd = squeeze(~isnan(clus(iClus,1,:)));
            clusTmp = []; %clear else dimensions change over clus/sets
            clusTmp(1,:) = squeeze(clus(iClus,1,ntNanInd)); %split into two to keep array dim constant - when only 1 location, the array flips.
            clusTmp(2,:) = squeeze(clus(iClus,2,ntNanInd));
            %             clusTmp = squeeze(clus(iClus,:,ntNanInd));
            nTrlsUpd(iClus,iSet,iterI)=nnz(ntNanInd);
            for iTrlUpd=1:size(clusTmp,2)
                densityPlotClus(clusTmp(1,iTrlUpd),clusTmp(2,iTrlUpd),iClus,iSet,iterI) = densityPlotClus(clusTmp(1,iTrlUpd),clusTmp(2,iTrlUpd),iClus,iSet, iterI)+1;
            end
        end
        
        %now also compute clus means
        densityPlotClusSmth = zeros(size(densityPlot,1),size(densityPlot,2),nClus);
        for iClus=1:nClus
            %find peaks
            densityPlotClusSmth(:,:,iClus)=imgaussfilt(densityPlotClus(:,:,iClus,iSet,iterI),gaussSmooth);
            [peakX, peakY] = find(densityPlotClusSmth(:,:,iClus)==max(max((densityPlotClusSmth(:,:,iClus)))));
            if length(peakX)>1 || length(peakY)>1 %if more than one peak rand sel one; normally next to each other
                randInd=randi(length(peakX));
                peakX=peakX(randInd);
                peakY=peakY(randInd);
            end
            clusMu(iClus,:,iSet,iterI) = [peakX, peakY];
            
            %make combined (grid cell) plot, smooth
            densityPlot(:,:,iSet,iterI) = nansum(densityPlotClus(:,:,:,iSet,iterI),3); %save this
            densityPlotSm = imgaussfilt(densityPlot(:,:,iSet,iterI),gaussSmooth);
        end
        
        if ~strcmp(dat,'cat') %if finding cats, won't be gridlike
            %compute autocorrmap, no need to save
            aCorrMap = ndautoCORR(densityPlotSm);
            %compute gridness
            [g,gdataA] = gridSCORE(aCorrMap,'allen',0);
            [g,gdataW] = gridSCORE(aCorrMap,'wills',0);
            gA(iSet,iterI,:,1) = [gdataA.g_score, gdataA.orientation, gdataA.wavelength, gdataA.radius];
            gW(iSet,iterI,:,1) = [gdataW.g_score, gdataW.orientation, gdataW.wavelength, gdataW.radius];
            
            %split in half then compute gridness for each half
            if  strcmp(dat(1:5),'trapz')
                
                %left half of box
                aCorrMap = ndautoCORR(densityPlotSm(:,1:length(spacing)/2));
                [g,gdataA] = gridSCORE(aCorrMap,'allen',0);
                [g,gdataW] = gridSCORE(aCorrMap,'wills',0);
                gA(iSet,iterI,:,2) = [gdataA.g_score, gdataA.orientation, gdataA.wavelength, gdataA.radius];
                gW(iSet,iterI,:,2) = [gdataW.g_score, gdataW.orientation, gdataW.wavelength, gdataW.radius];
                %right half of box
                aCorrMap = ndautoCORR(densityPlotSm(:,length(spacing)/2+1:end));
                [g,gdataA] = gridSCORE(aCorrMap,'allen',0);
                [g,gdataW] = gridSCORE(aCorrMap,'wills',0);
                gA(iSet,iterI,:,3) = [gdataA.g_score, gdataA.orientation, gdataA.wavelength, gdataA.radius];
                gW(iSet,iterI,:,3) = [gdataW.g_score, gdataW.orientation, gdataW.wavelength, gdataW.radius];                
            end
            
        end
        
    end
    
end
end



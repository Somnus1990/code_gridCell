function [densityPlot,clusMu,muAvg,nTrlsUpd,gA,gW,muAll] = covering_map_batch_sim(nClus,locRange,box,warpType,epsMuOrig,nTrials,nIter,warpBox,alpha,trials,trialsUnique,stochasticType,c,dat,weightEpsSSE)

spacing=linspace(locRange(1),locRange(2),locRange(2)+1); 
stepSize=diff(spacing(1:2));

nTrialsTest = nTrials;

gaussSmooth=1; %smoothing for density map


if nTrials==40000
%     fromTrlI = [1.0e+4, 2.0e+4, 3.5e+4, 1.0e+4, 1.5e+4, 3.0e+4, 1.0e+4,  1.5e+4, 2.5e+4, 1.0e+4, 2.0e+4];
%     toTrlN   = [1.5e+4, 2.5e+4, 4.0e+4, 2.0e+4, 2.5e+4, 4.0e+4, 2.50e+4, 3.0e+4, 4.0e+4, 3.0e+4, 4.0e+4];

    fromTrlI = [3.5e+4, 3.0e+4, 2.5e+4, 2.0e+4];
    toTrlN   = [4.0e+4, 4.0e+4, 4.0e+4, 4.0e+4];
elseif nTrials==80000
    % with double nTrials 
%     fromTrlI = [2.5e+4, 3.5e+4, 7.5e+4, 3.0e+4, 4.0e+4, 7.0e+4, 3.5e+4,  4.5e+4, 5.5e+4, 4.0e+4, 6.0e+4]; %this makes avg over same trials as above
%     toTrlN   = [1.5e+4, 2.5e+4, 4.0e+4, 2.0e+4, 2.5e+4, 4.0e+4, 2.50e+4, 3.0e+4, 4.0e+4, 3.0e+4, 4.0e+4].*2;    
    fromTrlI = [1.0e+4, 2.0e+4, 3.5e+4, 1.0e+4, 1.5e+4, 3.0e+4, 1.0e+4,  1.5e+4, 2.5e+4, 1.0e+4, 2.0e+4].*2; %this doubles the trials averaged over
    toTrlN   = [1.5e+4, 2.5e+4, 4.0e+4, 2.0e+4, 2.5e+4, 4.0e+4, 2.50e+4, 3.0e+4, 4.0e+4, 3.0e+4, 4.0e+4].*2;
end
nSets                = length(fromTrlI);
densityPlotClus      = zeros(length(spacing),length(spacing),nClus,nSets,nIter);
densityPlot          = zeros(length(spacing),length(spacing),nSets,nIter);
clusMu               = nan(nClus,2,nSets,nIter);
muAvg                = nan(nClus,2,nSets,nIter);
muAll                = nan(nClus,2,nTrials,nIter);
nTrlsUpd             = nan(nClus,nSets,nIter);
gA = nan(nSets,nIter,4);
gW = nan(nSets,nIter,4);
for iterI = 1:nIter
    
    fprintf('iter %d \n',iterI);
    epsMu = epsMuOrig; %revert learning rate back to original if reset
    
    switch box
        case 'square'
%             trials      = [randsample(spacing,nTrials,'true'); randsample(spacing,nTrials,'true')]';
            dataPtsTest = [randsample(linspace(locRange(1),locRange(2),locRange(2)+1),nTrialsTest,'true'); randsample(linspace(locRange(1),locRange(2),locRange(2)+1),nTrialsTest,'true')]'; % random points in a box
        case 'rect'
%             trials      = [randsample(-1:diff(spacing(1:2)):2,nTrials,'true'); randsample(spacing,nTrials,'true')]';
            dataPtsTest = [randsample(locRange(1):diff(spacing(1:2)):locRange(2)*2,nTrialsTest,'true'); randsample(spacing,nTrialsTest,'true')]';
        case 'trapz'
            trapY=locRange(2).*trapmf(spacing,[spacing(1), spacing(round(length(spacing)*.25)), spacing(round(length(spacing)*.75)),spacing(end)]);
            trapX=spacing;
            trapPts=[];
            for i=1:length(trapY)
               trapPts = [trapPts, [repmat(trapX(i),1,length(0:stepSize:trapY(i))); 0:stepSize:trapY(i)]];
            end
%             trapPts(2,:)=trapPts(2,:).*2-1; %put it back into -1 to 1            
            % use this to select from the PAIR in trapPts
            trialInd     = randi(length(trapPts),nTrials,1);
            trials       = trapPts(:,trialInd)';
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
                tic
                for j=1:length(sqY)
                    trapPts = [trapPts, [sqX(i); sqY(j)]];
                end
                toc
            end
            % use this to select from the PAIR in trapPts
            trialInd=randi(length(trapPts),nTrials,1);
            trials=trapPts(:,trialInd)';
            trialIndTest = randi(length(trapPts),nTrials,1);
            dataPtsTest  = trapPts(:,trialIndTest)';
    end
    
    % if expand box
    switch warpType
        case 'sq2rect'
            trialsExpand = [randsample(locRange(1):diff(spacing(1:2)):locRange(2)*2,nTrials*.75,'true'); randsample(spacing,nTrials*.75,'true')]';
        case 'rect2sq'
            trialsExpand = [randsample(spacing,nTrials*.75,'true'); randsample(spacing,nTrials*.75,'true')]'; %this doesn't work - actually, maybe this isn't a thing?
    end

    
    %initialise each cluster location  
    mu = nan(nClus,2,nTrials); %also note variable muUpd below - %variable that only logs updated clusters mean value
    for clusterI = 1:nClus

        % k means++
        if clusterI==1% random datapoint as 1st cluster
            mu(clusterI,:,1) = dataPtsTest(randi(length(dataPtsTest)),:); 
        end
        if clusterI~=nClus % no need update k+1
            clear distInit
            for iClus = 1:clusterI% loop over clusters that exist now
                distInit(:,iClus)=sum([mu(iClus,1,1)-dataPtsTest(:,1),  mu(iClus,2,1)-dataPtsTest(:,2)].^2,2); %squared euclid for k means
            end
            [indValsInit, indInit]=min(distInit,[],2); % find which clusters are points closest to
            
            distClus=[];
            for iClus = 1:clusterI
                indOrig(:,clusterI) = indInit==iClus;
                distClusTmp = sum([(mu(iClus,1,1)-dataPtsTest(indOrig(:,clusterI),1)), (mu(iClus,2,1)-dataPtsTest(indOrig(:,clusterI),2))].^2,2);
                distClus = [distClus; [distClusTmp, repmat(iClus,length(distClusTmp),1)]];
            end
            
            %need to keep track of the indices of the original dist variable - get the
            %datapoints that were the farthest from all clusters, get that cluster and see which datapoint that was relative to that cluster (since i just save the distance)
            distClusNorm = distClus(:,1)./sum(distClus(:,1));
            distClusPr   = cumsum(distClusNorm(:,1)); %get cumsum, then generate rand val from 0 to 1 and choose smallest val - the larger the dis, the more likely the rand value will lie between it and its previous value in a cumsum plot
            ind=find(rand(1)<distClusPr,1);% %find smallest value that is larger than the random value (0 to 1 uniform distr)
            
            % tmp(i)=distClus(ind,1); %testing if getting the right values; if plot, see that it should be lower pr for closer values, higher for larger. note if very few high distances, this hist will look normally distributed
            
            clusInd = distClus(ind,2); %find which is the closest cluster
            indDat = find(distInit(:,clusInd)==distClus(ind,1)); %find where the datapoint is in the original vector
            
            if size(indDat,1)>1
                indDat=indDat(randi(size(indDat,1),1));
            end
            mu(clusterI+1,:,1) = dataPtsTest(indDat,:);
        end
    end
    muUpd = mu;  %variable that only logs updated clusters mean value % - get initialised locs
    %%

    updatedC = nan(nTrials,1);
    epsMuAll = nan(nTrials,2);
    deltaMu  = zeros(nClus,2,nTrials);
    clusUpdates = zeros(nClus,2); %acutally starting at 0 is OK, since there was no momentum from last trial
    tsse            = nan(nTrials,1);
    sseW            = ones(nTrials,1);
    for iTrl=1:nTrials
            
            %if change size of box half way
            if iTrl == nTrials*.75 && warpBox
                trials(nTrials*.75+1:end,:) = trialsExpand;
            end
            
            %compute distances
            dist2Clus = sqrt(sum([mu(:,1,iTrl)'-trials(iTrl,1); mu(:,2,iTrl)'-trials(iTrl,2)].^2)); % vectorising euclid dist - sqrt(sum((a-b).^2)), since can't use xval method

            %stochastic update - sel 1 of the closest clusters w random element - stochastic parameter c - large is deterministic, 0 - random            

            if stochasticType %stochastic update
                if stochasticType==1
%                     beta=c*(iTrl-1);         % so this gets bigger, and more deterministic with more trials
                    beta=c*(iTrl+nTrials/50);  % maybe no need to be so stochatic at start
                elseif stochasticType==2
                    beta=c*(iTrl+nTrials/50);  % maybe no need to be so stochatic at start
                    if beta >= c*500 %it might be worth checking if this depends on nClusters - distances will change
                        beta = c*500;
                    end
                elseif stochasticType==3
                    beta = c*500; % as a function of c %prev:.185; 
                end
                dist2Clus2 = exp(-beta.*dist2Clus)./ sum(exp(-beta.*dist2Clus));
                distClusPr = cumsum(dist2Clus2);
                closestC=find(rand(1)<distClusPr,1);
                if isempty(closestC)  %if beta is too big, just do deterministic update (already will be near deterministic anyway)
                    closestC=find(min(dist2Clus)==dist2Clus);
                end
                cParams.betaAll(iTrl)       = beta;
            else %deterministic update
                closestC=find(min(dist2Clus)==dist2Clus);
            end
            if numel(closestC)>1 %if more than 1, randomly choose one
                closestC = randsample(closestC,1);
            end
            
            %if stochastic, closestC might not be if more than 1 actual
            %closest, have to check if stoch update chose one of them
            actualClosestC = find(min(dist2Clus)==dist2Clus); 
            closestMatch = zeros(1,length(actualClosestC));
            for iC = 1:length(actualClosestC)
                closestMatch(iC) = actualClosestC(iC) == closestC;
            end
            cParams.closestChosen(iTrl) = any(closestMatch); %was (one of) the closest cluster selected?
            cParams.closestDist(iTrl)   = dist2Clus(closestC);

            %log which cluster has been updated
            updatedC(iTrl) = closestC;

%             epsMu = epsMuOrig;
            epsMu = epsMuOrig*sseW(iTrl); %weight learning rate by prop SSE reduce from start
            epsMuAll(iTrl,:) = [epsMu,closestC]; 

            %update (with momemtum-like parameter)
            deltaMu(closestC,1,iTrl) = ((1-alpha)*(epsMu*(trials(iTrl,1)-mu(closestC,1,iTrl))))+(alpha*clusUpdates(closestC,1));
            deltaMu(closestC,2,iTrl) = ((1-alpha)*(epsMu*(trials(iTrl,2)-mu(closestC,2,iTrl))))+(alpha*clusUpdates(closestC,2));
            
            clusUpdates(closestC,1)=deltaMu(closestC,1,iTrl);
            clusUpdates(closestC,2)=deltaMu(closestC,2,iTrl);

            deltaMuVec = zeros(nClus,2);
            deltaMuVec(closestC,:) = deltaMu(closestC,:,iTrl); % only update winner
            
            
            
            
            %batch update - use deltaMu update
            % save all updates for each cluster for X trials, update it,
            % then again
            
            
%             batches = [1, 500:500:nTrials];
%             for i = 1:length(batches)-1
%                 ind = deltaMu(1,1,batches(i):batches(i+1))~=0;
%                 x(i)=mean(deltaMu(1,1,ind));
%             end


            

% either
% 1) save update, keep deltaMuVec a vector of zeros until batch update (so
% that cluster positions (mu) will remain the same),update, average all 
% updates using deltaMu, put into deltaMuVec, then update mu positions

% 2) no need to update mu with an empty deltaMuVec - just point to the mu
% value before the update (save this). Then at update, average all deltaMu
% updates...etc.
            
            
            
            
            
            
            % update mean estimates
            if iTrl~=nTrials %no need to update for last trial +1)
                mu(:,1,iTrl+1) = mu(:,1,iTrl) + deltaMuVec(:,1);
                mu(:,2,iTrl+1) = mu(:,2,iTrl) + deltaMuVec(:,2);
                %log updated value only
                % don't want to save the cluster positions when they don't move
                % but need to keep track of the last cluster position
                % - have two variables, one with all, one without
                % - the one without; this is with nans just remove
                % all the nans then put into densityPlotClus).
                muUpd(closestC,1,iTrl+1)=mu(closestC,1,iTrl+1);
                muUpd(closestC,2,iTrl+1)=mu(closestC,2,iTrl+1);
            end
            
            
            
            
            
            
            
            % compute sse on each trial with respect to 'all trials' 
            % trials - since values are all points in the box, no need to use a
            % trialsTest, juse use all unique locations (unique pairs of xy) from trials
            
            if weightEpsSSE
                sse=nan(1,nClus);
                distTrl=(mu(:,1,iTrl)'-trialsUnique(:,1)).^2+(mu(:,2,iTrl)'-trialsUnique(:,2)).^2; % vectorised
                [indValsTrl, indTmp]=min(distTrl,[],2); % find which clusters are points closest to
                
                %any way to vectorize this?
                for iClus = 1:size(clusMu,1)
                    sse(iClus)=sum(sum([mu(iClus,1,iTrl)-trialsUnique(indTmp==iClus,1), mu(iClus,2,iTrl)-trialsUnique(indTmp==iClus,2)].^2,2)); %distance from each cluster from training set to datapoints closest to that cluster
                    %                         sse(iClus)=sum(sum([clusMu(iClus,1,iSet,iterI)-dataPtsTest(indTmp==iClus,1), clusMu(iClus,2,iSet,iterI)-dataPtsTest(indTmp==iClus,2)].^2,2)); %distance from each cluster from training set to datapoints closest to that cluster
                end
                tsse(iTrl)=sum(sse);
                sseW(iTrl+1) = tsse(iTrl)./tsse(1);% weight next learning rate by prop of sse from the start
            end


    end
    muAll(:,:,:,iterI) = mu;
    

    % densityPlotClus - density plot with each cluster in dim 3 - more like
    % a place cell map - use to find clusMu (clus centres) - leave it out
    % here so can use diff smoothing values outside . also then use to make
    % it a gridcell map: densityPlot=sum(densityPlotClus,3); - to compute autocorrelogram
    % muAvg - also save cluster positions averaged over to plot average cluster
    %positions
    for iSet = 1:nSets
        %compute density map
        clus = round(muUpd(:,:,fromTrlI(iSet):toTrlN(iSet)));
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
        densityPlotClusSmth = zeros(length(spacing),length(spacing),nClus);
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
        
        if strcmp(dat,'rand') %if finding cats, won't be gridlike
            %compute autocorrmap, no need to save
            aCorrMap = ndautoCORR(densityPlotSm);
            %compute gridness
            [g,gdataA] = gridSCORE(aCorrMap,'allen',0);
            [g,gdataW] = gridSCORE(aCorrMap,'wills',0);
            gA(iSet,iterI,:) = [gdataA.g_score, gdataA.orientation, gdataA.wavelength, gdataA.radius];
            gW(iSet,iterI,:) = [gdataW.g_score, gdataW.orientation, gdataW.wavelength, gdataW.radius];
        end
        
        %save average cluster positions (to compare with above)
        muAvg(:,:,iSet,iterI) = nanmean(mu(:,:,fromTrlI(iSet):toTrlN(iSet)),3);
    end
end
end


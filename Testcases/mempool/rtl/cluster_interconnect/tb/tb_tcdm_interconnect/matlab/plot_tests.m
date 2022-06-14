% Copyright 2019 ETH Zurich and University of Bologna.
% Copyright and related rights are licensed under the Solderpad Hardware
% License, Version 0.51 (the "License"); you may not use this file except in
% compliance with the License.  You may obtain a copy of the License at
% http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
% or agreed to in writing, software, hardware and materials distributed under
% this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
% CONDITIONS OF ANY KIND, either express or implied. See the License for the
% specific language governing permissions and limitations under the License.
% 
% Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
% Date: 07.03.2019
% Description: Plot evaluation statistics as bar-plots.
%
% Usage: [] = plot_tests(stats, configLabels, netLabels)
%
% Inputs: - stats: statistics struct, created with read_stats.
%         - configLabels: cell array with network port configs, e.g. {'64x128', '64x256'}
%         - netLabels: cell array with network labels, e.g. {'lic', 'bfly4_n1'}
%
% See also: read_stats, fairness_test, read_synth, plot_tests,
% scatterplot_tests, plot_scaling

function [] = plot_tests(stats, configLabels, netLabels)
%plot_tests Plot evaluation statistics as bar-plots.

    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% global plot configs
    %%%%%%%%%%%%%%%%%%%%%%%%%%%

    altGrey = [0.8, 0.9];
    skip = 0.5;

    cols=colormap('lines');
    close;
    figure;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% preprocess args
    %%%%%%%%%%%%%%%%%%%%%%%%%%%    
    
    fprintf('\n');
    
    if nargin < 2
        configLabels = stats.configLabels;
        netLabels    = stats.netTypes;
    else
        
        if ~isempty(configLabels)
            % check whether these exist
            tmp = {};
            order = [];
            for k = 1:length(configLabels)
                if any(strcmp(configLabels{k},stats.configLabels))
                    tmp = [tmp configLabels(k)];
                    y=sscanf(configLabels{k},'%dx%d');
                    order = [order y(1)*1e6+y(2)];
                else
                    warning('config %s not found in batch results, skipping config...', configLabels{k});
                end    
            end
            [~,idx]=sortrows(order');
            configLabels = tmp(idx);
        else 
            configLabels = stats.configLabels;
        end
        
        if ~isempty(netLabels)
            tmp = {};
            for k = 1:length(netLabels)
                if any(strcmp(netLabels{k},stats.netTypes))
                    tmp = [tmp netLabels(k)];
                else
                    warning('netType %s not found in batch results, skipping config...', netLabels{k});
                end    
            end
            netLabels = tmp;
        else
            netLabels    = stats.netTypes;
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% gather results
    %%%%%%%%%%%%%%%%%%%%%%%%%%% 

    totalRes = [];
    totalX   = [];
    labels   = {};
    tests    = {};
    pReq     = [];
    pReqPos  = [];
    
    for k=1:stats.numTestNamesFull
        p=nan(length(configLabels)*length(netLabels),max(stats.numMaster));
        w=nan(length(configLabels)*length(netLabels),max(stats.numMaster));
        res=[];
        for c=1:length(configLabels)
            for n=1:length(netLabels)
                tst = strcmp(stats.testNamesFull{k}, stats.testNameFull)& ...
                      strcmp(configLabels{c}, stats.configs)            & ...
                      strcmp(netLabels{n}, stats.network)          ;
                    
                if sum(tst)>2
                    error('selection not unique');
                end
                if sum(tst)<1
                    warning(['no result found for ' netLabels{n} ' ' configLabels{c} ' ' stats.testNamesFull{k}]);
                    res(c,n,1) = nan;
                    res(c,n,2) = nan;
                else
                    idx = find(tst,1);
                    res(c,n,1) = mean(stats.ports{idx}(:,3));
                    res(c,n,2) = mean(stats.ports{idx}(:,4));
                end    
            end
            tests  = [tests stats.testName{idx}];
            labels = [labels configLabels{c}]; 
        end
        totalRes = cat(1, totalRes, res);
        x = (1:length(configLabels))+(k-1)*(length(configLabels)+skip);
        totalX = [totalX x];
        pReq     = [pReq  stats.pReq(idx)];
        pReqPos  = [pReqPos mean(x)];
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% grant probability
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    yMax = 1.1;
    subplot(2,1,1);
    hold on;
    
    % print test base name
    for t=1:stats.numTestNames
        tst=strcmp(stats.testNames{t},tests);
        idx=find(tst);
        
        fill([totalX(idx(1)),totalX(idx(end)),totalX(idx(end)),totalX(idx(1))] + [-(1+skip)/2,(1+skip)/2,(1+skip)/2,-(1+skip)/2], ...
             [0,0,yMax,yMax],[1 1 1] .* altGrey(mod(t-1,2)+1),'EdgeColor',[1 1 1] .* altGrey(mod(t-1,2)+1)); 
        
        text(mean(totalX(tst)),yMax-0.025,stats.testNames{t},'FontSize',9,'HorizontalAlignment','Center','FontWeight','bold');
    end
    grid on;
    box on;
    
    % plot black lines
    a=axis();
    a(1) = totalX(1)-1;
    a(2) = totalX(end)+1;
    a(3) = 0;
    a(4) = yMax;
    axis(a);
    for k=0:0.2:1
        plot(a(1:2),[1 1].*k,':k');
    end
    plot(a(1:2),[1 1],'k');
    
    % print request probs
    for k=1:length(pReq)
        text(mean(pReqPos(k)),yMax-0.075,sprintf('p=%.2f',pReq(k)),'FontSize',8,'HorizontalAlignment','Center');
    end    
    
    % bar plot
    b=bar(totalX, totalRes(:,:,1));
    for l=1:length(b)
        b(l).DisplayName = netLabels{l};
        for j=1:size(b(l).CData,1)
            b(l).FaceColor = 'flat';
            b(l).LineStyle = 'none';
            b(l).CData(j,:) = cols(mod(l-1,length(netLabels))+1,:);
        end
    end
    
    % boxplot
%     b=boxplot(totalP');
    
    set(gca,'FontSize',8);
    ylabel('p');
    title('average grant probability');
    xticks(totalX);
    xticklabels(labels);
    xtickangle(45);
    legend(b,'location','southeast','interpreter','none');
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% avg wait cycles
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    yMax = 100;
    subplot(2,1,2);
    hold on;
    
    % print test base name
    for t=1:stats.numTestNames
        tst=strcmp(stats.testNames{t},tests);
        idx=find(tst);
        
        fill([totalX(idx(1)),totalX(idx(end)),totalX(idx(end)),totalX(idx(1))] + [-(1+skip)/2,(1+skip)/2,(1+skip)/2,-(1+skip)/2], ...
             [eps,eps,yMax,yMax],[1 1 1] .* altGrey(mod(t-1,2)+1),'EdgeColor',[1 1 1] .* altGrey(mod(t-1,2)+1)); 
        
        text(mean(totalX(tst)),yMax*0.8,stats.testNames{t},'FontSize',9,'HorizontalAlignment','Center','FontWeight','bold');
    end
    grid on;
    box on;
    
    % plot black lines
    a=axis();
    a(1) = totalX(1)-1;
    a(2) = totalX(end)+1;
    a(3) = 0.01;
    a(4) = yMax;
    axis(a);
    for j=log10(a(3)):log10(a(4))
        for k=10^j:10^j:10^(j+1)
            % leave some space for the text
            if k > max(max(max(totalRes(:,:,2))))+10^j
                continue;
            end    
            plot(a(1:2),[1 1].*k,':k');
        end
    end    
    
    plot(a(1:2),[1 1],'k');
    
    % print request probs
    for k=1:length(pReq)
        text(mean(pReqPos(k)),yMax*0.6,sprintf('p=%.2f',pReq(k)),'FontSize',8,'HorizontalAlignment','Center');
    end    
    
    % bar plot
    b=bar(totalX, totalRes(:,:,2));
    for l=1:length(b)
        b(l).DisplayName = netLabels{l};
        for j=1:size(b(l).CData,1)
            b(l).FaceColor = 'flat';
            b(l).LineStyle = 'none';
            b(l).CData(j,:) = cols(mod(l-1,length(netLabels))+1,:);
        end
    end
    
    set(gca,'FontSize',8);
    ylabel('cycles')
    title('average wait cycles');
    set(gca,'yscale','log')
    xticks(totalX);
    xticklabels(labels);
    xtickangle(45);
    legend(b,'location','southeast','interpreter','none');
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% avg wait cycles
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    set(gcf,'position',[0,0,1600,1000]);
    
    
end
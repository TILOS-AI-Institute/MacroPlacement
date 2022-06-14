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
% Description: Plot evaluation statistics and synthesis results as Pareto
% plot.
%
% Usage: [] = scatterplot_tests(stats, masterConfig, netLabels, testName)
%
% Inputs: - stats: statistics struct, created with read_stats.
%         - masterConfig: string with network master port config, e.g. '64x'
%         - netLabels: cell array with network labels, e.g. {'lic', 'bfly4_n1'}
%         - testName: name of the traffic pattern to determine grant
%         probability, e.g. 'random uniform (p_{req}=1.00)'
%
% See also: read_stats, fairness_test, read_synth, plot_tests,
% plot_tests, plot_scaling

function [] = scatterplot_tests(stats, masterConfig, netLabels, testName)
% scatterplot_tests Plot evaluation statistics and synthesis results as Pareto
% plot.    

    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% global plot configs
    %%%%%%%%%%%%%%%%%%%%%%%%%%%

    close;
    figure;
    
    % instances that do not meet timing will be highlighted with a border
    % with this color
    negSlackCol  = 'r';
    
    % highlight a particular instance (i.e. highlight a well known anchor in
    % the plot). e.g., LIC with banking factor of 2.
    highlightCol = [0 0.6 0];
    netHighlight = 'lic';
    bf = 2;
    configHighlight = [masterConfig num2str(sscanf(masterConfig,'%dx',1)*bf)];
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% preprocess args
    %%%%%%%%%%%%%%%%%%%%%%%%%%%    
    
    fprintf('\n');
    
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
    
    configLabels={};
    bankFacts=[];
    for k=1:length(stats.configLabels)
        if strcmp(masterConfig, stats.configLabels{k}(1:min(length(stats.configLabels{k}),length(masterConfig))))
            configLabels = [configLabels stats.configLabels(k)];
            bankFacts = [bankFacts str2num(stats.configLabels{k}(length(masterConfig)+1:end)) /sscanf(masterConfig,'%dx',1)];
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% gather results
    %%%%%%%%%%%%%%%%%%%%%%%%%%% 
    
    labels   = {};
    tests    = {};
    
    markers = ['o','d','s','<','>','v','h','^','+','x','p'];

    res=[];
    for c=1:length(configLabels)
        for n=1:length(netLabels)
            tst = strcmp(testName, stats.testNameFull)    & ...
                  strcmp(configLabels{c}, stats.configs)  & ...
                  strcmp(netLabels{n}, stats.network)          ;
            
            isHighlight = strcmp(configHighlight, configLabels{c})  & ...
                          strcmp(netHighlight, netLabels{n})          ;
              
            if sum(tst)>2
                error('selection not unique');
            end
            if sum(tst)<1
                warning(['no result found for ' netLabels{n} ' ' configLabels{c} ' ' testName]);
                res(c,n,1:3) = nan;
                continue;
            end
            
            tst2=strcmp(configLabels{c}, stats.configLabels);
            tst3=strcmp(netLabels{n}, stats.netTypes);
            
            idx = find(tst,1);  
            idx2 = find(tst2,1);  
            idx3 = find(tst3,1);  
            res(c,n,1) = mean(stats.ports{idx}(:,3));
            res(c,n,2) = mean(stats.ports{idx}(:,4));
            res(c,n,3) = stats.synthArea(idx3,idx2,1);
            res(c,n,4) = isHighlight;
            res(c,n,5) = stats.synthSlack(idx3,idx2)>=0;% check if timing is reached
            if isnan(res(c,n,3))
                warning(['area of ' netLabels{n} ' ' configLabels{c} ' is ' num2str(res(c,n,3))]);
            end
            if ~res(c,n,5)
                warning(['slack of ' netLabels{n} ' ' configLabels{c} ' is ' num2str(stats.synthSlack(idx3,idx2))]);
            end
        end
        tests  = [tests stats.testName{idx}];
        labels = [labels configLabels{c}]; 
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% grant prob vs synth area
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % plot the pareto line first
    x=1-res(:,:,1);
    y=res(:,:,3);
    x=x(:);
    y=y(:);
    
    mask = ~(isnan(x) | isnan(y));
    x = x(mask);
    y = y(mask);
    
    [x,idx]=sortrows(x);
    y=y(idx);
    px = x(1);
    py = y(1);
    for k=2:length(x)
        if y(k)<py(end)
            px = [px;x(k);x(k)];
            py = [py;py(end);y(k)];
        end
    end    

    axx(1)=0;
    axx(2)=max(x)*1.1;
    axx(3)=0;
    axx(4)=max(y)*1.1;
    px = [px(1);px;axx(2)];
    py = [axx(4);py;py(end)];
    plot(px,py,'color',[0.5 0.5 0.5]);
    axis(axx);

    % plot the banking factor labels
    hold on
    sz = 35;
    fzs = 9;
    xoff=0.01;
    yoff=0;
    for k=1:size(res,2)
        for j=1:size(res,1)
            col = 'k';
            if res(j,k,4)
                col = highlightCol;
            end  
            text(1-res(j,k,1)+xoff, res(j,k,3)+yoff, num2str(bankFacts(j)), 'FontSize', fzs, 'color', col);
        end
    end
    
    % plot the markers
    for k=1:size(res,2)
        h(k)=scatter(1-res(:,k,1), res(:,k,3), sz, 'filled', 'marker', markers(k),'MarkerEdgeColor','k','LineWidth',0.5);
    end
    
    % plot the highlighted instance(s)
    for k=1:size(res,2)
        for j=1:length(res(:,k,1))
            % plot highlighted reference
            if res(j,k,4)
                scatter(1-res(j,k,1), res(j,k,3), sz, 'marker', markers(k),'MarkerEdgeColor',highlightCol,'LineWidth',2.0);
            end
            % mark instances that do not meet timing
            if ~res(j,k,5)
                scatter(1-res(j,k,1), res(j,k,3), sz, 'marker', markers(k),'MarkerEdgeColor',negSlackCol,'LineWidth',1.0);
            end    
        end
    end
    
    % further annotation
    grid on
    box on
    ylabel('area [\mum^2]');
    xlabel('1 - p_{gnt}');

    legend(h,netLabels,'location','northeast','interpreter','none');
    title({[masterConfig ' Master Ports']; testName});

end
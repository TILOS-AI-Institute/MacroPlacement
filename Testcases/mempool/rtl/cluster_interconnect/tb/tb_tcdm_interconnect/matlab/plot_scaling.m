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
% Description: Plot scaling behavior of different networks, i.e. area in
% dependency of the Master x Slave configuration.
%
% Usage: [] = plot_scaling(stats, configLabels, netLabels)
%
% Inputs: - stats: statistics struct, created with read_stats.
%         - configLabels: cell array with network port configs, e.g. {'64x128', '64x256'}
%         - netLabels: cell array with network labels, e.g. {'lic', 'bfly4_n1'}
%
% See also: read_stats, fairness_test, read_synth, plot_tests,
% plot_tests, scatterplot_tests


function [] = plot_scaling(stats, configLabels, netLabels)
% plot_scaling Plot scaling behavior of different networks, i.e. area in
% dependency of the Master x Slave configuration.

    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% global plot configs
    %%%%%%%%%%%%%%%%%%%%%%%%%%%

    close;
    figure;
    
    cols    = colormap('lines');
    markers = ['o','d','s','<','>','v','h','^','+','-','x','.'];
   
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

    if isempty(configLabels)
        configLabels=stats.configLabels;
    end

    masterConfigs = [];
    bankFacts = [];
    for k=1:length(configLabels)
        tmp = sscanf(configLabels{k},'%dx%d');
        masterConfigs(k)=tmp(1);
        bankFacts(k)=tmp(2)/tmp(1);
%         for j=1:length(configLabels{k})
%             if configLabels{k}(j) == 'x'
%                 masterConfigs{k} = configLabels{k}(1:j-1);
%             end
%         end
    end
    
    masterConfigs = unique(masterConfigs);
    bankFacts  = unique(bankFacts);
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% gather results
    %%%%%%%%%%%%%%%%%%%%%%%%%%% 

    res=nan(length(netLabels),length(bankFacts),length(masterConfigs));
    for n=1:length(netLabels)
        for c=1:length(configLabels)
            tst2=strcmp(configLabels{c}, stats.configLabels);
            tst3=strcmp(netLabels{n}, stats.netTypes);
            
            idx2 = find(tst2,1);  
            idx3 = find(tst3,1);  
            
            tmp = sscanf(configLabels{c},'%dx%d');
            
            tst = masterConfigs == tmp(1);
            idx = find(tst,1);  
            tst4 = bankFacts == tmp(2)/tmp(1);
            idx4 = find(tst4,1);  
            
            res(n,idx4,idx) = stats.synthArea(idx3,idx2,1);
        end
    end
    
    labels   = {};
    
    for n=1:length(netLabels)
        for c=1:length(bankFacts)
            labels = [labels {[netLabels{n} '_bf' num2str(bankFacts(c))]}]; 
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% plot #ports versus area
    %%%%%%%%%%%%%%%%%%%%%%%%%%%   

    hold on;
    for k=1:size(res,1)
        for j=1:size(res,2)
            plot(masterConfigs,squeeze(res(k,j,:)),'--','marker',markers(j),'color',cols(k,:),'markerEdgeColor','k','markerFaceColor',cols(k,:));
        end
    end
    box on;
    grid on;
    
    legend(labels,'interpreter','none');
    xticks(masterConfigs)
    set(gca,'yscale','log');
    set(gca,'xscale','log');
   
    title('scaling behavior');
    xlabel('master ports');
    ylabel('complexity [\mum^2]');

end
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
% Description: This function reads synthesis results and annotates the stats struct
% configurations with no synthesis result will be set to NaN.
%
% Usage: [stats] = read_synth(directory, stats)
%
% Inputs: - directory: directory to simulation output folder.
%         - stats: statistics struct, created with read_stats.
%
% Outputs: - stats: annotated statistics struct.
%
% See also: fairness_test, read_stats, plot_tests,
% plot_tests, plot_scaling, scatterplot_tests

function [stats] = read_synth(directory, stats)
% read_synth this function reads synthesis results and annotates the stats struct
% configurations with no synthesis result will be set to NaN.
    
    fprintf('\nreading synthesis results...\n');
    
    stats.synthArea  = nan(length(stats.netTypes), length(stats.configLabels), 3);
    stats.synthSlack = nan(length(stats.netTypes), length(stats.configLabels));
    numFiles = 0;
    numSkipped = 0;
    for k = 1:length(stats.netTypes)
        for j = 1:length(stats.configLabels)
            fileName = [directory filesep stats.netTypes{k} '_' stats.configLabels{j} '_area.rpt'];
            
            if exist(fileName, 'file')
                [~,out] = system(['grep "Total cell area:" ' fileName ' | awk -e ''{print $4;}'' ']);
                stats.synthArea(k,j,1) = sscanf(out,'%f',1);
                [~,out] = system(['grep "Combinational area:" ' fileName ' | awk -e ''{print $3;}'' ']);
                stats.synthArea(k,j,2) = sscanf(out,'%f',1);
                [~,out] = system(['grep "Noncombinational area:" ' fileName ' | awk -e ''{print $3;}'' ']);
                stats.synthArea(k,j,3) = sscanf(out,'%f',1);
                numFiles = numFiles + 1;
            else
                warning('No Synthesis results found for %s', [stats.netTypes{k} '_' stats.configLabels{j}]);
                numSkipped = numSkipped + 1;
            end 
            
            fileName = [directory filesep stats.netTypes{k} '_' stats.configLabels{j} '_timing.rpt'];
            
            if exist(fileName, 'file')
                [~,out] = system(['grep "slack" ' fileName ' | awk -e ''{print $3;}'' ']);
                stats.synthSlack(k,j) = sscanf(out,'%f',1);
            else
                warning('No Timing results found for %s', [stats.netTypes{k} '_' stats.configLabels{j}]);
            end     
        end
    end    
    
    fprintf('read %d synthesis results (%d skipped)\n\n', numFiles, numSkipped);
end
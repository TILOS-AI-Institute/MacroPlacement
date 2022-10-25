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
% Description: Result parsing and plotting master script for network evaluation.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Setup and Result Parsing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

addpath(genpath('./matlab'));
mkdir plots

% get simulation results
[stats] = read_stats('sim-results');
% check for outliers (== implementation or arbitration bugs!)
fairness_test(stats, 0.13);
% annotate this with synthesis results
stats = read_synth('sim-results', stats);

% backup results
save('plots/stats.mat','stats');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Statistical Evaluation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% clos networks
plot_tests(stats, {'32x32','32x64','32x128'}, {'clos_2mn', 'clos_m1n', 'clos_m2n','lic'});
export_fig 'plots/stats_clos_32x' -png -pdf
%% selection x8
networkSel = {'bfly2_n1', 'bfly2_n2','bfly2_n4','bfly4_n1', 'bfly4_n2','bfly4_n4', 'lic'};
plot_tests(stats,  {'8x8','8x16','8x32'}, networkSel);
export_fig 'plots/stats_selection_8x' -png -pdf
%% selection x16
networkSel = {'bfly2_n1', 'bfly2_n2','bfly2_n4','bfly4_n1', 'bfly4_n2','bfly4_n4', 'lic'};
plot_tests(stats,  {'16x16','16x32','16x64'}, networkSel);
export_fig 'plots/stats_selection_16x' -png -pdf
%% selection x32
networkSel = {'bfly2_n1', 'bfly2_n2','bfly2_n4','bfly4_n1', 'bfly4_n2','bfly4_n4', 'lic'};
plot_tests(stats,  {'32x32','32x64','32x128'}, networkSel);
export_fig 'plots/stats_selection_32x' -png -pdf
%% selection x64
networkSel = {'bfly2_n1', 'bfly2_n2','bfly2_n4','bfly4_n1', 'bfly4_n2','bfly4_n4', 'lic'};
plot_tests(stats,  {'64x64','64x128','64x256'}, networkSel);
export_fig 'plots/stats_selection_64x' -png -pdf
%% selection x128
networkSel = {'bfly2_n1', 'bfly2_n2','bfly2_n4','bfly4_n1', 'bfly4_n2','bfly4_n4', 'bfly4_n8', 'lic'};
plot_tests(stats,  {'128x128','128x256','128x512'}, networkSel);
export_fig 'plots/stats_selection_128x' -png -pdf
%% selection x256
networkSel = {'bfly2_n4','bfly4_n1', 'bfly4_n2','bfly4_n4', 'bfly4_n8', 'lic'};
plot_tests(stats,  {'256x256','256x512','256x1024'}, networkSel);
export_fig 'plots/stats_selection_256x' -png -pdf
%% plot only banking factor 2
plot_tests(stats, {'64x64','64x128','64x256'}, {'bfly4_n1', 'clos_2mn', 'clos_m1n', 'clos_m2n','lic'});
export_fig 'plots/stats_bf2_64x' -png -pdf

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Pareto Plots
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 8 masters
networkSel = {'clos_2mn', 'clos_m1n', 'clos_m2n', 'bfly2_n1', 'bfly2_n2','bfly2_n4', 'bfly4_n1', 'bfly4_n2','bfly4_n4', 'lic'};
scatterplot_tests(stats, '8x', networkSel,'random uniform (p_{req}=1.00)');
export_fig 'plots/pareto_random_uniform_8x' -png -pdf
%%
scatterplot_tests(stats, '8x', networkSel,'random linear bursts (p_{req}=1.00, len_{max}=100.00)');
export_fig 'plots/pareto_random_linear_8x' -png -pdf
%% 16 masters
networkSel = {'clos_2mn', 'clos_m1n', 'clos_m2n', 'bfly2_n1', 'bfly2_n2','bfly2_n4', 'bfly4_n1', 'bfly4_n2','bfly4_n4', 'lic'};
scatterplot_tests(stats, '16x', networkSel,'random uniform (p_{req}=1.00)');
export_fig 'plots/pareto_random_uniform_16x' -png -pdf
%%
scatterplot_tests(stats, '16x', networkSel,'random linear bursts (p_{req}=1.00, len_{max}=100.00)');
export_fig 'plots/pareto_random_linear_16x' -png -pdf
%% 32 masters
networkSel = {'clos_2mn', 'clos_m1n', 'clos_m2n', 'bfly2_n1', 'bfly2_n2','bfly2_n4', 'bfly4_n1', 'bfly4_n2','bfly4_n4', 'lic'};
scatterplot_tests(stats, '32x', networkSel,'random uniform (p_{req}=1.00)');
export_fig 'plots/pareto_random_uniform_32x' -png -pdf
%%
scatterplot_tests(stats, '32x', networkSel,'random linear bursts (p_{req}=1.00, len_{max}=100.00)');
export_fig 'plots/pareto_random_linear_32x' -png -pdf
%% 64 masters
networkSel = {'clos_2mn', 'clos_m1n', 'clos_m2n', 'bfly2_n1', 'bfly2_n2','bfly2_n4', 'bfly4_n1', 'bfly4_n2','bfly4_n4', 'lic'};
scatterplot_tests(stats, '64x', networkSel,'random uniform (p_{req}=1.00)');
export_fig 'plots/pareto_random_uniform_64x' -png -pdf
%%
scatterplot_tests(stats, '64x', networkSel,'random linear bursts (p_{req}=1.00, len_{max}=100.00)');
export_fig 'plots/pareto_random_linear_64x' -png -pdf
%% 128 masters
networkSel = {'clos_2mn', 'clos_m1n', 'clos_m2n', 'bfly2_n1', 'bfly2_n2','bfly2_n4', 'bfly4_n1', 'bfly4_n2','bfly4_n4','bfly4_n8', 'lic'};
scatterplot_tests(stats, '128x', networkSel,'random uniform (p_{req}=1.00)');
export_fig 'plots/pareto_random_uniform_128x' -png -pdf
%%
scatterplot_tests(stats, '128x', networkSel,'random linear bursts (p_{req}=1.00, len_{max}=100.00)');
export_fig 'plots/pareto_random_linear_128x' -png -pdf
%% 256 masters
networkSel = {'bfly4_n1', 'bfly4_n2','bfly4_n4','bfly4_n8', 'lic'};
scatterplot_tests(stats, '256x', networkSel,'random uniform (p_{req}=1.00)');
export_fig 'plots/pareto_random_uniform_256x' -png -pdf
%%
scatterplot_tests(stats, '256x', networkSel,'random linear bursts (p_{req}=1.00, len_{max}=100.00)');
export_fig 'plots/pareto_random_linear_256x' -png -pdf

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Pareto Plots
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% scaling behavior with BF=1 
networkSel = {'bfly4_n1', 'bfly4_n2','bfly4_n4','bfly4_n8', 'lic'};
plot_scaling(stats, {'8x8','16x16','32x32','64x64','128x128','256x256'}, networkSel);
export_fig 'plots/scaling_bf1' -png -pdf
%% scaling behavior with BF=2
plot_scaling(stats, {'8x16','16x32','32x64','64x128','128x256','256x512'}, networkSel);
export_fig 'plots/scaling_bf2' -png -pdf
%% scaling behavior with BF=4
plot_scaling(stats, {'8x32','16x64','32x128','64x256','128x512','256x1024'}, networkSel);
export_fig 'plots/scaling_bf4' -png -pdf
%% for batch use
exit(0);
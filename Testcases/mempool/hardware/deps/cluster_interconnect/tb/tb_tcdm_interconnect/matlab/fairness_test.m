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
% Description: Checks whether grant probability std deviation is within
% tolerance. This can be used as a quick sanity check since arbitration or
% implementation errors often result in a non-uniform grant probability
% when comparing across master ports.
%
% Usage: [idx] = fairness_test(stats, tol)
%
% Inputs: - stats: statistics struct, created with read_stats.
%         - tol: tolerance for std deviation
%
% Outputs: - idx: indices of failing tests.
%
% See also: read_stats, read_synth, plot_tests,
% plot_tests, plot_scaling, scatterplot_tests

function [idx] = fairness_test(stats, tol)
%fairness_test checks whether grant probability std deviation is within tolerance
    
    fprintf('\nFairness check with tol=%.2f\n\n', tol);
    failingTests = '';
    idx = [];
    for k = 1:length(stats.ports)
        tst_mean = mean(stats.ports{k}(:,2));
        tst_std  = std(stats.ports{k}(:,2));
        str  = 'OK';
        str2 = '';
        if tst_std ./ tst_mean > tol 
            str = 'FAILED';
            str2 = [stats.network{k} ' ' stats.configs{k} ' ' stats.testNameFull{k}];
            failingTests = [failingTests str2 '\n'];
        end
        fprintf('> mean=%04.2f std=%04.2f -> %s %s\n', tst_mean, tst_std, str, str2);
        idx = [idx k];    
    end
    
    if ~isempty(failingTests)
        fprintf(['\n\nSome tests have failed:\n', failingTests]);
    else
        fprintf('\n\nAll tests passed with tol=%.2f!\n', tol);
    end
end

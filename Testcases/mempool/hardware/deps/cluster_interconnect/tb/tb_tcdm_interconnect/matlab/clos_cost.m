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
% Description: Calculates (abstract) clos cost in dependence of #banks, banking factor
% and redundancy factor. The function also outputs the optimum network
% configuration for a specific parameterisation (in terms of N, M, R).
%
% Usage: [cost, n, m, r] = clos_cost(k, b, c)
%
% Inputs: - k: number of banks
%         - b: banking factor
%         - c: redundancy factor
%
% Outputs: - cost: abstract area cost 
%          - n, m, r: optimum clos configuration
%
% See also: gen_clos_params
%

function [cost, n, m, r] = clos_cost(k, b, c)
% clos_cost Calculates (abstract) clos cost in dependence of #banks, banking factor
% and redundancy factor. The function also outputs the optimum network
% configuration for a specific parameterisation (in terms of N, M, R).

    n    = 2.^ceil(log2(sqrt(k ./ (1+1./b))));
    m    = 2.^ceil(log2(c.*n));
    r    = 2.^ceil(log2(k./n));
    cost = r.*n./b.*m + m.*r.^2 + r.*m.*n;
    
    if length(k) == 1
        fprintf('\nClos cost: \nk=%d, b=%d, c=%d\nm=%d, n=%d, r=%d\n-> cost = %.2f\n\n', k, b, c, m, n, r, cost);
    end    
end
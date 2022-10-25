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
% Description: Reads statistics from RTL simulation dumps.
%
% Usage: [stats] = read_stats(directory)
%
% Inputs: - directory: directory to simulation output folder.
%
% Outputs: - stats: statistics struct.
%
% See also: fairness_test, read_synth, plot_tests,
% plot_tests, plot_scaling, scatterplot_tests

function [stats] = read_stats(directory)
%readStats reads statistics files written by the testbench

    statFiles = split(ls([directory filesep '*_statistics.log']));

    fprintf('\nreading statistics files...\n\n');

    idx      = 1;
    numFiles = 0;
    containsFatal = {};
    containsError = {};

    for k=1:length(statFiles)
        if ~isfile(statFiles{k})
            continue;
        end
        fprintf('> %s\n',statFiles{k});

        transFile = replace(statFiles{k},'statistics','transcript');

        [~,ret] = system(['grep -c -i fatal ' transFile]);
        ret = sscanf(ret, '%d',1);
        if ret
            containsFatal = [containsFatal {transFile}];
            warning('> %s contains fatal - skipping\n',transFile);
            continue;
        end

        [~,ret] = system(['grep -c "Errors: 0" ' transFile]);

        ret = sscanf(ret, '%d',1);
        if ret == 0
            containsError = [containsError {transFile}];
            warning('> %s contains errors - skipping\n',transFile);
            continue;
        end


        fp=fopen(statFiles{k},'r');
        while ~feof(fp)
            % read config
            stats.network{idx}      = fscanf(fp, 'test config:\nnet: %s\n');
            stats.numMaster(idx)    = fscanf(fp, 'numMaster: %5d\n',1);
            stats.numBanks(idx)     = fscanf(fp, 'numBanks: %5d\n',1);
            stats.dataWidth(idx)    = fscanf(fp, 'dataWidth: %5d\n',1);
            stats.memAddrBits(idx)  = fscanf(fp, 'memAddrBits:%5d\n',1);
            stats.testCycles(idx)   = fscanf(fp, 'testCycles: %5d\n',1);
            fscanf(fp, 'testName:\n');
            stats.testName{idx}     = '';
            c=fscanf(fp, '%c',1);
            while c~=newline
                stats.testName{idx} = [stats.testName{idx} c];
                c=fscanf(fp, '%c',1);
            end
            stats.pReq(idx)         = fscanf(fp, 'pReq: %e\n',1);
            stats.maxLen(idx)       = fscanf(fp, 'maxLen: %d\n',1);
            % append to make name unique
            if stats.maxLen(idx) > 0
                stats.testNameFull{idx} = [stats.testName{idx} ' (p_{req}=' num2str(stats.pReq(idx),'%.2f') ', len_{max}=' num2str(stats.maxLen(idx),'%.2f') ')'];
            else
                stats.testNameFull{idx} = [stats.testName{idx} ' (p_{req}=' num2str(stats.pReq(idx),'%.2f') ')'];
            end
            % read test statistics
            stats.ports{idx}        = reshape(fscanf(fp, 'Port %d: Req=%5d Gnt=%5d p=%e Wait=%e\n',5*stats.numMaster(idx))',5,[])';
            stats.ports{idx}        = stats.ports{idx}(:,2:end);
            stats.banks{idx}        = reshape(fscanf(fp, 'Bank %d: Req=%05d Load=%e\n',3*stats.numBanks(idx))',3,[])';
            stats.banks{idx}        = stats.banks{idx}(:,2:end);
            fscanf(fp, '\n');

            % check whether test is unique
            tst =  strcmp(stats.network,stats.network{idx})    & ...
                   strcmp(stats.testNameFull,stats.testNameFull{idx}) & ...
                   stats.numMaster(idx)   == stats.numMaster   & ...
                   stats.numBanks(idx)    == stats.numBanks    & ...
                   stats.dataWidth(idx)   == stats.dataWidth   & ...
                   stats.memAddrBits(idx) == stats.memAddrBits & ...
                   stats.testCycles(idx)  == stats.testCycles  & ...
                   stats.maxLen(idx)      == stats.maxLen      & ...
                   stats.pReq(idx)        == stats.pReq;

            if sum(tst) > 1
                error('result already exists with this configuration (conflicting file: %s)', statFiles{k});
            end
            idx=idx+1;
        end
        fclose(fp);
        numFiles=numFiles+1;
    end

%     % only to fix some naming, can be commented later once tb has been
%     % fixed
%     for k = 1:length(stats.network)
%         switch stats.network{k}
%             case 'bfly2(n=1)'
%                 stats.network{k} = 'bfly2_n1';
%             case 'bfly2(n=2)'
%                 stats.network{k} = 'bfly2_n2';
%             case 'bfly2(n=4)'
%                 stats.network{k} = 'bfly2_n4';
%         end
%     end


    % get some meta info
    % network types and number of runs
    stats.netTypes = sortrows(unique(stats.network)')';
    stats.numNetTypes = length(stats.netTypes);

    stats.testNames         = sortrows(unique(stats.testName)')';
    stats.numTestNames      = length(stats.testNames);
    stats.testNamesFull     = sortrows(unique(stats.testNameFull)')';
    stats.numTestNamesFull  = length(stats.testNamesFull);

    stats.numFiles = numFiles;
    stats.numRuns  = idx-1;
    stats.configs  = {};
    order=[];
    % network configurations in terms of nMaster x nBanks
    for k=1:stats.numRuns
        stats.configs  = [stats.configs {[num2str(stats.numMaster(k)) 'x' num2str(stats.numBanks(k))]}];
        order(k)       = stats.numMaster(k)*1e6 + stats.numBanks(k);
    end
    % sort the configs
    [stats.configLabels, idx, ~] = unique(stats.configs);
    [~,idx]                      = sortrows(order(idx)');
    stats.configLabels           = stats.configLabels(idx);
    stats.numConfigs             = length(stats.configLabels);

    % sort according to networks
    [~,idx]                 = sortrows(stats.network');
    stats.network           = stats.network(idx);
    stats.numMaster         = stats.numMaster(idx);
    stats.numBanks          = stats.numBanks(idx);
    stats.dataWidth         = stats.dataWidth(idx);
    stats.memAddrBits       = stats.memAddrBits(idx);
    stats.testCycles        = stats.testCycles(idx);
    stats.testName          = stats.testName(idx);
    stats.testNameFull      = stats.testNameFull(idx);
    stats.pReq              = stats.pReq(idx);
    stats.maxLen            = stats.maxLen(idx);
    stats.ports             = stats.ports(idx);
    stats.banks             = stats.banks(idx);
    stats.configs           = stats.configs(idx);
    order                   = order(idx);

    % sort nMaster x nBank configs within network type
    for k = 1:length(stats.netTypes)
        tst     = strcmp(stats.netTypes{k}, stats.network);
        [~,idx] = sortrows(order(tst)');
        tmp                    = stats.network(tst);
        stats.network(tst)     = tmp(idx);
        tmp                    = stats.numMaster(tst);
        stats.numMaster(tst)   = tmp(idx);
        tmp                    = stats.numBanks(tst);
        stats.numBanks(tst)    = tmp(idx);
        tmp                    = stats.dataWidth(tst);
        stats.dataWidth(tst)   = tmp(idx);
        tmp                    = stats.memAddrBits(tst);
        stats.memAddrBits(tst) = tmp(idx);
        tmp                    = stats.testCycles(tst);
        stats.testCycles(tst)  = tmp(idx);
        tmp                    = stats.testName(tst);
        stats.testName(tst)    = tmp(idx);
        tmp                    = stats.testNameFull(tst);
        stats.testNameFull(tst)= tmp(idx);
        tmp                    = stats.pReq(tst);
        stats.pReq(tst)        = tmp(idx);
        tmp                    = stats.maxLen(tst);
        stats.maxLen(tst)      = tmp(idx);
        tmp                    = stats.ports(tst);
        stats.ports(tst)       = tmp(idx);
        tmp                    = stats.banks(tst);
        stats.banks(tst)       = tmp(idx);
        tmp                    = stats.configs(tst);
        stats.configs(tst)     = tmp(idx);
    end

    % sort tests names
    for k = 1:length(stats.netTypes)
        for l = 1:length(stats.numTestNamesFull)
            tst     = strcmp(stats.netTypes{k}, stats.network) & ...
                      strcmp(stats.testNamesFull{l}, stats.testNameFull);

            [~,idx] = sortrows(stats.testNameFull(tst)');
            tmp                    = stats.network(tst);
            stats.network(tst)     = tmp(idx);
            tmp                    = stats.numMaster(tst);
            stats.numMaster(tst)   = tmp(idx);
            tmp                    = stats.numBanks(tst);
            stats.numBanks(tst)    = tmp(idx);
            tmp                    = stats.dataWidth(tst);
            stats.dataWidth(tst)   = tmp(idx);
            tmp                    = stats.memAddrBits(tst);
            stats.memAddrBits(tst) = tmp(idx);
            tmp                    = stats.testCycles(tst);
            stats.testCycles(tst)  = tmp(idx);
            tmp                    = stats.testName(tst);
            stats.testName(tst)    = tmp(idx);
            tmp                    = stats.testNameFull(tst);
            stats.testNameFull(tst)= tmp(idx);
            tmp                    = stats.pReq(tst);
            stats.pReq(tst)        = tmp(idx);
            tmp                    = stats.maxLen(tst);
            stats.maxLen(tst)      = tmp(idx);
            tmp                    = stats.ports(tst);
            stats.ports(tst)       = tmp(idx);
            tmp                    = stats.banks(tst);
            stats.banks(tst)       = tmp(idx);
            tmp                    = stats.configs(tst);
            stats.configs(tst)     = tmp(idx);
        end
    end

    % print skipped files
    fprintf('\nskipped due to errors:\n');
    for k = 1:length(containsError)
        fprintf('> %s\n', containsError{k});
    end
    fprintf(']nskipped due to fatal:\n');
    for k = 1:length(containsFatal)
        fprintf('> %s\n', containsFatal{k});
    end

    fprintf('\nread %d files with %d simulation runs, %d/%d skipped (fatal, error)\n\n', stats.numFiles, stats.numRuns, length(containsFatal), length(containsError));
end

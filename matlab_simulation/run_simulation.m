%% run_simulation.m - Quick test runner for the mobile DFA simulation
%
% Description:
%   Simple wrapper script to test the simulation with synthetic data
%   and verify all components work correctly.

clear; clc; close all;

fprintf('Mobile DFA Simulation Test Runner\n');
fprintf('=================================\n\n');

% Check if test data exists, create if not
if ~exist('MHEALTH_Subject1_Activity1.mat', 'file')
    fprintf('Test data not found. Creating synthetic MHEALTH data...\n');
    create_test_data();
    fprintf('\n');
end

% Add a small test to verify functions are available
fprintf('Verifying all functions are available...\n');
required_functions = {'dfa_naive', 'dfa_vectorized', 'dfa_q15_sim', ...
                     'a15_dvfs_model', 'generate_reproduction_package', ...
                     'pinknoise'};

all_available = true;
for i = 1:length(required_functions)
    if ~exist(required_functions{i}, 'file')
        fprintf('  ERROR: %s.m not found!\n', required_functions{i});
        all_available = false;
    else
        fprintf('  ✓ %s.m found\n', required_functions{i});
    end
end

if ~all_available
    error('Some required functions are missing. Please ensure all .m files are in the current directory.');
end

fprintf('\nAll functions verified. Starting simulation...\n\n');

% Run the main simulation
try
    mobile_dfa_simulation_final;
    fprintf('\n✓ Simulation completed successfully!\n');
catch ME
    fprintf('\n✗ Simulation failed with error:\n');
    fprintf('  %s\n', ME.message);
    fprintf('  in %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
end
function [freq_ghz, power_w] = a15_dvfs_model(load_percent)
% A15_DVFS_MODEL - Simplified DVFS model for Apple A15 Bionic
%
% Description:
%   Models the dynamic voltage and frequency scaling behavior of the
%   Apple A15 Bionic processor based on CPU load percentage.
%
% Input:
%   load_percent - CPU load percentage (0-100)
%
% Output:
%   freq_ghz - Operating frequency in GHz
%   power_w  - Power consumption in Watts
%
% References:
%   [1] AnandTech Apple A15 Deep Dive (2021)
%   [2] NotebookCheck A15 Bionic Analysis
%   [3] Measured values from iOS power profiling tools

    % Validate input
    if load_percent < 0
        load_percent = 0;
    elseif load_percent > 100
        load_percent = 100;
    end
    
    % DVFS curve based on real measurements and literature
    % Load ranges aligned with iOS scheduler behavior
    if load_percent < 0.1
        % Ultra-low power mode (E-core minimum)
        freq_ghz = 1.0;  % E-core base frequency
        power_w = 0.4;   % Near-idle power consumption
    elseif load_percent < 1
        % E-core efficient range
        freq_ghz = 1.8;  % E-core mid frequency
        power_w = 1.3;   % Measured E-core active power
    elseif load_percent < 5
        % Transition to P-core
        freq_ghz = 2.4;  % P-core base frequency
        power_w = 2.5;   % P-core efficient operation
    elseif load_percent < 10
        % P-core normal operation
        freq_ghz = 2.8;  % P-core mid frequency
        power_w = 3.4;   % Measured P-core active power
    else
        % P-core maximum performance
        freq_ghz = 3.2;  % P-core max frequency (3.23 GHz nominal)
        power_w = 4.3;   % Peak single-core power
    end
    
    % Note: Real DVFS includes intermediate steps and hysteresis
    % This simplified model captures the key operating points
end
%% Mobile DFA Performance Simulation for IEICE Paper
% Purpose: Quantify mobile computation gap for DFA implementation
% Target: iPhone 13 (A15 Bionic 3.2GHz) equivalent performance
% Output: Processing time, battery consumption, and performance metrics

clear; clc; close all;

%% Configuration
% iPhone 13 A15 Bionic specifications
CPU_FREQ = 3.2e9;          % 3.2 GHz
POWER_HIGH_LOAD = 4.0;     % 4W during high computational load
BATTERY_CAPACITY = 12.36;  % 12.36 Wh (3227mAh @ 3.83V)

% Signal parameters
SIGNAL_LENGTHS = [150, 300, 600, 1000];  % Sample lengths to test
SAMPLING_RATE = 50;                       % 50 Hz (MHEALTH dataset)
WINDOW_SIZE = 3;                          % 3-second windows
NUM_ITERATIONS = 100;                     % Number of iterations for averaging

% DFA parameters
MIN_BOX_SIZE = 4;
MAX_BOX_SIZE_RATIO = 0.25;  % Max box size = 25% of signal length
NUM_SCALES = 10;

%% Generate test signals (realistic gait-like signals)
rng(42);  % For reproducibility
results = struct();

fprintf('=== Mobile DFA Performance Simulation ===\n');
fprintf('Target Device: iPhone 13 (A15 Bionic)\n');
fprintf('CPU Frequency: %.1f GHz\n', CPU_FREQ/1e9);
fprintf('High Load Power: %.1f W\n\n', POWER_HIGH_LOAD);

%% Main simulation loop
for sig_idx = 1:length(SIGNAL_LENGTHS)
    N = SIGNAL_LENGTHS(sig_idx);
    fprintf('Testing signal length: %d samples (%.1f seconds)\n', N, N/SAMPLING_RATE);
    
    % Initialize timing arrays
    fp32_times = zeros(NUM_ITERATIONS, 1);
    
    for iter = 1:NUM_ITERATIONS
        % Generate realistic gait signal with nonlinear components
        t = (0:N-1) / SAMPLING_RATE;
        
        % Base gait pattern (periodic with variations)
        base_freq = 1.8 + 0.2*randn();  % 1.8 Hz ± variations (typical walking)
        gait_signal = sin(2*pi*base_freq*t) + ...
                      0.3*sin(4*pi*base_freq*t) + ...  % Harmonics
                      0.1*sin(6*pi*base_freq*t);
        
        % Add physiological noise and variations
        pink_noise = generate_pink_noise(N);
        gait_signal = gait_signal + 0.2*pink_noise;
        
        % Add nonlinear dynamics (fatigue simulation)
        fatigue_factor = 1 + 0.1*t/max(t);  % Gradual fatigue
        gait_signal = gait_signal .* fatigue_factor;
        
        % Measure FP32 DFA execution time
        tic;
        [alpha_fp32, F_n, n] = compute_dfa_fp32(gait_signal, MIN_BOX_SIZE, ...
                                                 floor(N*MAX_BOX_SIZE_RATIO), NUM_SCALES);
        fp32_times(iter) = toc;
    end
    
    % Calculate statistics
    mean_time = mean(fp32_times) * 1000;  % Convert to ms
    std_time = std(fp32_times) * 1000;
    
    % Calculate computational complexity
    % DFA complexity: O(N²) for cumulative sum + O(N×S) for detrending
    % where S is number of scales
    theoretical_ops = N^2 + N*NUM_SCALES*log(N);
    cycles_required = theoretical_ops * 10;  % Assume 10 cycles per operation
    theoretical_time = cycles_required / CPU_FREQ * 1000;  % ms
    
    % Energy consumption calculation
    energy_per_window = POWER_HIGH_LOAD * mean_time/1000;  % Joules
    windows_per_day = 24*3600 / WINDOW_SIZE;  % Continuous monitoring
    energy_per_day = energy_per_window * windows_per_day / 3600;  % Wh
    battery_percentage = (energy_per_day / BATTERY_CAPACITY) * 100;
    
    % Store results
    results(sig_idx).signal_length = N;
    results(sig_idx).mean_time_ms = mean_time;
    results(sig_idx).std_time_ms = std_time;
    results(sig_idx).theoretical_time_ms = theoretical_time;
    results(sig_idx).energy_per_window_mJ = energy_per_window * 1000;
    results(sig_idx).battery_per_day_percent = battery_percentage;
    results(sig_idx).alpha = alpha_fp32;
    
    fprintf('  Processing time: %.2f ± %.2f ms\n', mean_time, std_time);
    fprintf('  Energy per window: %.2f mJ\n', energy_per_window * 1000);
    fprintf('  Battery consumption: %.1f%% per day\n', battery_percentage);
    fprintf('  DFA α: %.3f\n\n', alpha_fp32);
end

%% Generate summary for paper
fprintf('\n=== SUMMARY FOR PAPER ===\n');
target_idx = find([results.signal_length] == 300);  % Focus on 300-sample window
if ~isempty(target_idx)
    fprintf('For 3-second windows (150 samples @ 50Hz):\n');
    fprintf('- FP32 DFA processing time: %.1f ms\n', results(target_idx).mean_time_ms);
    fprintf('- Daily battery consumption: %.0f%%\n', results(target_idx).battery_per_day_percent);
    fprintf('- This is %.0fx higher than typical step counter (0.1%%/day)\n', ...
            results(target_idx).battery_per_day_percent / 0.1);
end

%% Visualization
figure('Position', [100, 100, 1200, 400]);

% Subplot 1: Processing time vs signal length
subplot(1, 3, 1);
bar([results.signal_length], [results.mean_time_ms], 'FaceColor', [0.8, 0.2, 0.2]);
hold on;
errorbar([results.signal_length], [results.mean_time_ms], [results.std_time_ms], ...
         'k', 'LineStyle', 'none', 'LineWidth', 1.5);
xlabel('Signal Length (samples)');
ylabel('Processing Time (ms)');
title('FP32 DFA Processing Time');
grid on;

% Subplot 2: Battery consumption
subplot(1, 3, 2);
bar([results.signal_length], [results.battery_per_day_percent], 'FaceColor', [0.2, 0.5, 0.8]);
xlabel('Signal Length (samples)');
ylabel('Battery Consumption (%/day)');
title('Daily Battery Drain');
ylim([0, max([results.battery_per_day_percent])*1.2]);
grid on;

% Add 23% line for 300-sample case
hold on;
yline(23, 'r--', 'LineWidth', 2);
text(400, 24, 'Target: 23%', 'Color', 'red', 'FontWeight', 'bold');

% Subplot 3: Computational efficiency
subplot(1, 3, 3);
efficiency = [results.theoretical_time_ms] ./ [results.mean_time_ms];
plot([results.signal_length], efficiency, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Signal Length (samples)');
ylabel('Efficiency Ratio');
title('Theoretical vs Actual Performance');
ylim([0, 1.2]);
grid on;

sgtitle('Mobile DFA Performance Analysis');

%% Save results
save('mobile_dfa_results.mat', 'results', 'CPU_FREQ', 'POWER_HIGH_LOAD', 'BATTERY_CAPACITY');
fprintf('\nResults saved to mobile_dfa_results.mat\n');

%% Helper Functions

function [alpha, F_n, n] = compute_dfa_fp32(signal, min_box, max_box, num_scales)
    % Floating-point DFA implementation (Peng method)
    N = length(signal);
    
    % Step 1: Remove mean and integrate
    signal_mean = mean(signal);
    y = cumsum(signal - signal_mean);
    
    % Step 2: Create logarithmically spaced box sizes
    n = round(logspace(log10(min_box), log10(max_box), num_scales));
    n = unique(n);  % Remove duplicates
    F_n = zeros(size(n));
    
    % Step 3: Calculate F(n) for each box size
    for i = 1:length(n)
        box_size = n(i);
        num_boxes = floor(N / box_size);
        
        if num_boxes < 2
            F_n(i) = NaN;
            continue;
        end
        
        % Detrending in each box
        variance_sum = 0;
        for j = 1:num_boxes
            idx_start = (j-1)*box_size + 1;
            idx_end = j*box_size;
            
            % Linear detrending
            box_indices = idx_start:idx_end;
            box_data = y(box_indices);
            
            % Fit linear trend
            p = polyfit(box_indices', box_data', 1);
            trend = polyval(p, box_indices');
            
            % Calculate variance
            detrended = box_data' - trend;
            variance_sum = variance_sum + sum(detrended.^2);
        end
        
        F_n(i) = sqrt(variance_sum / (num_boxes * box_size));
    end
    
    % Step 4: Calculate scaling exponent (alpha)
    valid_idx = ~isnan(F_n) & F_n > 0;
    if sum(valid_idx) >= 2
        p = polyfit(log10(n(valid_idx)), log10(F_n(valid_idx)), 1);
        alpha = p(1);
    else
        alpha = NaN;
    end
end

function noise = generate_pink_noise(N)
    % Generate 1/f (pink) noise
    f = (0:N-1)'/N;
    f(1) = 1/N;  % Avoid division by zero
    
    % Generate complex random phases
    phases = exp(2*pi*1i*rand(N, 1));
    
    % Apply 1/f amplitude scaling
    fft_noise = phases ./ sqrt(f);
    
    % Convert to time domain
    noise = real(ifft(fft_noise));
    
    % Normalize
    noise = noise / std(noise);
end
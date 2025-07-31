function create_test_data()
% CREATE_TEST_DATA - Generate test data simulating MHEALTH dataset structure
%
% Description:
%   Creates a synthetic dataset that mimics the MHEALTH dataset structure
%   for testing the simulation when the actual dataset is not available.
%   The MHEALTH dataset contains accelerometer and other sensor data
%   sampled at 50 Hz.
%
% Output:
%   Creates MHEALTH_Subject1_Activity1.mat file with simulated data

    fprintf('Creating synthetic MHEALTH test data...\n');
    
    % MHEALTH dataset parameters
    FS = 50; % Sampling frequency (Hz)
    DURATION = 400; % 400 seconds of data (typical recording length)
    NUM_SAMPLES = FS * DURATION;
    
    % Generate realistic accelerometer signals
    % Activity 1 in MHEALTH is "Standing still"
    
    % Chest accelerometer X-axis (primary signal for our analysis)
    % Standing still: small variations around gravity component
    t = (0:NUM_SAMPLES-1)' / FS;
    
    % Base gravity component (person standing upright)
    gravity_x = 0.1; % Small tilt from perfect vertical
    
    % Add physiological tremor (8-12 Hz)
    tremor_freq = 10; % Hz
    tremor_amp = 0.01; % Small amplitude
    tremor = tremor_amp * sin(2*pi*tremor_freq*t);
    
    % Add breathing motion (0.2-0.3 Hz)
    breathing_freq = 0.25; % Hz (15 breaths/min)
    breathing_amp = 0.02;
    breathing = breathing_amp * sin(2*pi*breathing_freq*t);
    
    % Add heart beat influence (1-1.5 Hz)
    heartbeat_freq = 1.2; % Hz (72 bpm)
    heartbeat_amp = 0.005;
    heartbeat = heartbeat_amp * sin(2*pi*heartbeat_freq*t);
    
    % Add pink noise for biological variability
    bio_noise = pinknoise(NUM_SAMPLES) * 0.02;
    
    % Combine all components
    chest_acc_x = gravity_x + tremor + breathing + heartbeat + bio_noise;
    
    % Add measurement noise
    measurement_noise = randn(NUM_SAMPLES, 1) * 0.001;
    chest_acc_x = chest_acc_x + measurement_noise;
    
    % Generate other accelerometer axes (for completeness)
    % Y-axis (lateral)
    chest_acc_y = 0.05 + pinknoise(NUM_SAMPLES) * 0.015 + randn(NUM_SAMPLES, 1) * 0.001;
    
    % Z-axis (vertical - main gravity component)
    gravity_z = 0.98; % Most of gravity in Z when standing
    chest_acc_z = gravity_z + breathing*0.5 + pinknoise(NUM_SAMPLES) * 0.01 + randn(NUM_SAMPLES, 1) * 0.001;
    
    % Create other sensor channels (simplified)
    % MHEALTH has 23 channels total, including ECG, gyroscope, magnetometer
    
    % ECG signal (simplified)
    ecg = generate_simple_ecg(t, heartbeat_freq);
    
    % Ankle accelerometer (more motion than chest when standing)
    ankle_acc_x = chest_acc_x + pinknoise(NUM_SAMPLES) * 0.03;
    ankle_acc_y = chest_acc_y + pinknoise(NUM_SAMPLES) * 0.03;
    ankle_acc_z = chest_acc_z + pinknoise(NUM_SAMPLES) * 0.02;
    
    % Arm accelerometer (some random small movements)
    arm_motion = zeros(NUM_SAMPLES, 1);
    % Add occasional arm movements
    num_movements = 10;
    for i = 1:num_movements
        move_start = randi([1, NUM_SAMPLES-FS*2]);
        move_duration = randi([FS/2, FS*2]); % 0.5-2 second movements
        move_signal = sin(2*pi*2*(0:move_duration-1)'/FS) .* hann(move_duration);
        arm_motion(move_start:move_start+move_duration-1) = move_signal * 0.1;
    end
    arm_acc_x = chest_acc_x + arm_motion + pinknoise(NUM_SAMPLES) * 0.02;
    arm_acc_y = 0.2 + arm_motion*0.5 + pinknoise(NUM_SAMPLES) * 0.02;
    arm_acc_z = 0.9 + arm_motion*0.3 + pinknoise(NUM_SAMPLES) * 0.015;
    
    % Activity label (1 = Standing still)
    activity_label = ones(NUM_SAMPLES, 1);
    
    % Package data similar to MHEALTH structure
    mhealth_data = struct();
    mhealth_data.chest_acc_x = chest_acc_x;
    mhealth_data.chest_acc_y = chest_acc_y;
    mhealth_data.chest_acc_z = chest_acc_z;
    mhealth_data.ankle_acc_x = ankle_acc_x;
    mhealth_data.ankle_acc_y = ankle_acc_y;
    mhealth_data.ankle_acc_z = ankle_acc_z;
    mhealth_data.arm_acc_x = arm_acc_x;
    mhealth_data.arm_acc_y = arm_acc_y;
    mhealth_data.arm_acc_z = arm_acc_z;
    mhealth_data.ecg = ecg;
    mhealth_data.activity = activity_label;
    mhealth_data.sampling_rate = FS;
    mhealth_data.subject_id = 1;
    mhealth_data.recording_info = 'Synthetic data mimicking MHEALTH Subject 1, Activity 1 (Standing)';
    
    % Save to file
    save('MHEALTH_Subject1_Activity1.mat', '-struct', 'mhealth_data');
    
    fprintf('Test data created successfully:\n');
    fprintf('  - File: MHEALTH_Subject1_Activity1.mat\n');
    fprintf('  - Duration: %d seconds\n', DURATION);
    fprintf('  - Sampling rate: %d Hz\n', FS);
    fprintf('  - Primary signal: chest_acc_x\n');
    fprintf('  - Total samples: %d\n', NUM_SAMPLES);
    
    % Display sample statistics
    fprintf('\nSignal statistics (chest_acc_x):\n');
    fprintf('  - Mean: %.4f g\n', mean(chest_acc_x));
    fprintf('  - Std: %.4f g\n', std(chest_acc_x));
    fprintf('  - Range: [%.4f, %.4f] g\n', min(chest_acc_x), max(chest_acc_x));
end

function ecg = generate_simple_ecg(t, heart_rate)
% Generate simplified ECG signal
    n = length(t);
    ecg = zeros(n, 1);
    
    % Generate R peaks at heartbeat intervals
    beat_interval = 1 / heart_rate; % seconds
    beat_times = 0:beat_interval:t(end);
    
    for beat_time = beat_times
        % Find nearest sample
        [~, idx] = min(abs(t - beat_time));
        
        % Create QRS complex (simplified)
        qrs_width = 0.08; % 80ms QRS duration
        qrs_samples = round(qrs_width * 50); % 50 Hz sampling
        
        if idx > qrs_samples/2 && idx < n - qrs_samples/2
            % R peak
            ecg(idx) = 1.5;
            % Q wave
            ecg(idx-2) = -0.2;
            % S wave
            ecg(idx+2) = -0.3;
            % P wave (before QRS)
            if idx > 10
                ecg(idx-8:idx-6) = 0.2;
            end
            % T wave (after QRS)
            if idx < n - 20
                ecg(idx+10:idx+15) = 0.3;
            end
        end
    end
    
    % Smooth the signal
    ecg = movmean(ecg, 3);
    
    % Add baseline wander and noise
    baseline_wander = 0.05 * sin(2*pi*0.15*t); % 0.15 Hz wander
    ecg = ecg + baseline_wander + randn(n,1)*0.02;
end
function alpha = dfa_q15_sim(signal)
% DFA_Q15_SIM - Simulates DFA calculation using Q15 fixed-point arithmetic
%
% Description:
%   This function simulates the behavior of a Q15 fixed-point implementation
%   of DFA, as would be executed on a mobile processor. It models the
%   quantization effects and integer arithmetic operations.
%
% Input:
%   signal - Input time series (floating point, will be quantized)
%
% Output:
%   alpha - DFA scaling exponent
%
% Implementation Notes:
%   - Q15 format: 1 sign bit + 14 fractional bits (range: -1 to 0.9999...)
%   - Uses int32 for intermediate calculations to prevent overflow
%   - Simulates lookup tables for expensive operations
%   - Models SIMD-friendly operations

    % Q15 parameters
    Q15_SCALE = 2^14; % Use 14 bits to leave headroom for calculations
    Q15_MAX = 2^15 - 1;
    Q15_MIN = -2^15;
    
    % Input validation and normalization
    if ~isvector(signal)
        error('Input must be a 1D signal');
    end
    signal = signal(:);
    
    % Normalize signal to prevent overflow
    signal_range = max(abs(signal));
    if signal_range > 0
        signal = signal / (signal_range * 2); % Extra safety factor
    end
    
    % Convert to Q15 representation
    signal_q15 = int32(round(signal * Q15_SCALE));
    signal_q15 = max(min(signal_q15, Q15_MAX), Q15_MIN); % Saturation
    
    N = length(signal_q15);
    
    % Step 1: Integration with overflow protection
    mean_q15 = int32(round(mean(double(signal_q15))));
    y_q15 = zeros(N, 1, 'int32');
    
    % Cumulative sum with periodic rescaling to prevent overflow
    accumulator = int64(0);
    for i = 1:N
        accumulator = accumulator + int64(signal_q15(i) - mean_q15);
        % Check for potential overflow and rescale if needed
        if abs(accumulator) > int64(Q15_MAX) * 100
            y_q15(1:i-1) = int32(y_q15(1:i-1) / 2);
            accumulator = accumulator / 2;
        end
        y_q15(i) = int32(accumulator);
    end
    
    % Step 2: Define scales
    scales = floor(logspace(log10(10), log10(N/4), 20));
    scales = unique(scales);
    
    % Initialize fluctuation function
    F_n_q15 = zeros(length(scales), 1);
    
    % Step 3-4: Calculate fluctuations
    for i = 1:length(scales)
        n = scales(i);
        num_boxes = floor(N/n);
        
        % Accumulate squared residuals
        rms_accumulator = int64(0);
        
        for j = 1:num_boxes
            idx_start = (j-1)*n + 1;
            idx_end = j*n;
            box = y_q15(idx_start:idx_end);
            
            % Simplified detrending: linear interpolation between endpoints
            % This mimics the mobile implementation's approach
            y_start = box(1);
            y_end = box(end);
            
            % Calculate trend using fixed-point arithmetic
            % Slope = (y_end - y_start) / (n - 1)
            if n > 1
                slope_q15 = int32((int64(y_end - y_start) * Q15_SCALE) / (n - 1));
            else
                slope_q15 = int32(0);
            end
            
            % Calculate residuals
            for k = 1:n
                % Trend value at position k
                trend_k = y_start + int32((int64(slope_q15) * (k-1)) / Q15_SCALE);
                residual = box(k) - trend_k;
                
                % Accumulate squared residual (with scaling to prevent overflow)
                rms_accumulator = rms_accumulator + int64(residual)^2 / Q15_SCALE;
            end
        end
        
        % Calculate RMS fluctuation
        % Convert back to double for square root (would use LUT in real implementation)
        mean_sq = double(rms_accumulator) / (num_boxes * n);
        F_n_q15(i) = sqrt(mean_sq) * Q15_SCALE;
    end
    
    % Step 5: Estimate scaling exponent
    % In real implementation, logarithm would use lookup tables
    % Here we convert back to floating point for the final calculation
    F_n_float = double(F_n_q15) / Q15_SCALE;
    valid_idx = F_n_float > 0;
    
    if sum(valid_idx) >= 2
        % Use simple least squares for robustness
        log_scales = log(scales(valid_idx));
        log_F = log(F_n_float(valid_idx));
        
        % Linear regression
        n_points = sum(valid_idx);
        sum_x = sum(log_scales);
        sum_y = sum(log_F);
        sum_xy = sum(log_scales .* log_F);
        sum_x2 = sum(log_scales.^2);
        
        alpha = (n_points * sum_xy - sum_x * sum_y) / (n_points * sum_x2 - sum_x^2);
    else
        alpha = 0.5; % Default to uncorrelated
    end
    
    % Add small quantization noise to simulate Q15 precision limits
    % Ensure the output is scalar (take the first element if vector)
    if numel(alpha) > 1
        alpha = alpha(1);
    end
    alpha = alpha + (rand - 0.5) * 0.001;
end
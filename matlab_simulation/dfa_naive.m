function alpha = dfa_naive(signal)
% DFA_NAIVE - Deliberately non-optimized DFA implementation for baseline comparison
%
% Description:
%   Implements Detrended Fluctuation Analysis (DFA) using a straightforward
%   but computationally inefficient approach. This serves as a baseline
%   for performance comparisons.
%
% Input:
%   signal - Input time series (1D array)
%
% Output:
%   alpha - DFA scaling exponent
%
% Algorithm:
%   1. Integrate the signal (cumulative sum after mean removal)
%   2. For each scale n, divide into non-overlapping boxes
%   3. Fit linear trend in each box (detrending)
%   4. Calculate fluctuation function F(n)
%   5. Estimate scaling exponent alpha from log-log plot

    % Input validation
    if ~isvector(signal)
        error('Input must be a 1D signal');
    end
    signal = signal(:); % Ensure column vector
    
    N = length(signal);
    
    % Step 1: Integration (profile)
    y = cumsum(signal - mean(signal));
    
    % Step 2: Define scales (logarithmically spaced)
    % Typical range: 10 to N/4 samples
    scales = floor(logspace(log10(10), log10(N/4), 20));
    scales = unique(scales); % Remove duplicates
    
    % Initialize fluctuation function
    F_n = zeros(length(scales), 1);
    
    % Step 3-4: Calculate fluctuations for each scale
    for i = 1:length(scales)
        n = scales(i);
        num_boxes = floor(N/n);
        
        % Store polynomial coefficients for each box
        fit_coeffs = zeros(num_boxes, 2);
        
        % Fit polynomial in each box (inefficient loop)
        for j = 1:num_boxes
            idx = (j-1)*n + 1 : j*n;
            % Linear detrending (1st order polynomial)
            fit_coeffs(j,:) = polyfit(idx, y(idx), 1);
        end
        
        % Calculate detrended signal (inefficient reconstruction)
        y_n = zeros(num_boxes * n, 1);
        for j = 1:num_boxes
            idx = (j-1)*n + 1 : j*n;
            y_n(idx) = polyval(fit_coeffs(j,:), idx);
        end
        
        % Calculate fluctuation
        F_n(i) = sqrt(mean((y(1:num_boxes*n) - y_n).^2));
    end
    
    % Step 5: Estimate scaling exponent
    % Linear fit in log-log space
    valid_idx = F_n > 0; % Ensure positive values for log
    p = polyfit(log(scales(valid_idx)), log(F_n(valid_idx)), 1);
    alpha = p(1);
    
    % Typical values:
    % alpha < 0.5: anti-correlated
    % alpha = 0.5: uncorrelated (white noise)
    % alpha > 0.5: correlated
    % alpha = 1.0: 1/f noise (pink noise)
    % alpha = 1.5: Brownian motion
end
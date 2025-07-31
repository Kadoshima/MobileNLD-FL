function alpha = dfa_vectorized(signal)
% DFA_VECTORIZED - Optimized DFA implementation using MATLAB vectorization
%
% Description:
%   Implements Detrended Fluctuation Analysis (DFA) using MATLAB's
%   vectorized operations (bsxfun, reshape) for improved performance.
%   This represents typical MATLAB optimization techniques.
%
% Input:
%   signal - Input time series (1D array)
%
% Output:
%   alpha - DFA scaling exponent
%
% Optimizations:
%   - Vectorized detrending using matrix operations
%   - Efficient reshaping for box-wise processing
%   - bsxfun for broadcasting operations

    % Input validation
    if ~isvector(signal)
        error('Input must be a 1D signal');
    end
    signal = signal(:); % Ensure column vector
    
    N = length(signal);
    
    % Step 1: Integration (profile)
    y = cumsum(signal - mean(signal));
    
    % Step 2: Define scales
    scales = floor(logspace(log10(10), log10(N/4), 20));
    scales = unique(scales);
    
    % Initialize fluctuation function
    F_n = zeros(length(scales), 1);
    
    % Step 3-4: Vectorized fluctuation calculation
    for i = 1:length(scales)
        n = scales(i);
        num_boxes = floor(N/n);
        
        % Reshape signal into boxes (n × num_boxes matrix)
        % Each column is one box
        Y_reshaped = reshape(y(1:n*num_boxes), n, num_boxes);
        
        % Create index vector for detrending
        X = (1:n)';
        
        % Vectorized linear detrending using matrix operations
        % Calculate regression coefficients for all boxes simultaneously
        meanX = mean(X);
        meanY = mean(Y_reshaped, 1); % Mean of each box
        
        % Covariance and variance calculations
        X_centered = X - meanX;
        Y_centered = bsxfun(@minus, Y_reshaped, meanY);
        
        % Slope calculation for all boxes
        b = sum(bsxfun(@times, X_centered, Y_centered)) / sum(X_centered.^2);
        
        % Intercept calculation
        a = meanY - b * meanX;
        
        % Calculate trend for all boxes
        y_trend = bsxfun(@plus, bsxfun(@times, X, b), a);
        
        % Calculate fluctuation
        residuals = Y_reshaped - y_trend;
        F_n(i) = sqrt(mean(residuals(:).^2));
    end
    
    % Step 5: Estimate scaling exponent
    valid_idx = F_n > 0;
    p = polyfit(log(scales(valid_idx)), log(F_n(valid_idx)), 1);
    alpha = p(1);
end
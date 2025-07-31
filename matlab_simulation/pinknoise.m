function y = pinknoise(n)
% PINKNOISE - Generate 1/f pink noise
%
% Description:
%   Generates pink noise (1/f noise) using the Voss-McCartney algorithm.
%   Pink noise has equal power per octave and is commonly found in
%   biological signals and natural phenomena.
%
% Input:
%   n - Number of samples to generate
%
% Output:
%   y - Pink noise signal (normalized to [-1, 1] range)
%
% Algorithm:
%   Uses multiple white noise generators at different update rates
%   to approximate 1/f spectrum over a wide frequency range.

    % Input validation
    if nargin < 1 || n < 1
        error('Number of samples must be positive');
    end
    
    % Number of octaves to cover (more octaves = better approximation)
    num_octaves = 10;
    
    % Initialize output
    y = zeros(n, 1);
    
    % Generate pink noise using summed octaves
    for octave = 1:num_octaves
        % Update rate for this octave (powers of 2)
        update_rate = 2^(octave-1);
        
        % Generate white noise at this update rate
        num_updates = ceil(n / update_rate);
        white = randn(num_updates, 1);
        
        % Expand to full signal length using sample-and-hold
        expanded = zeros(n, 1);
        for i = 1:num_updates
            start_idx = (i-1) * update_rate + 1;
            end_idx = min(i * update_rate, n);
            expanded(start_idx:end_idx) = white(i);
        end
        
        % Add this octave's contribution
        y = y + expanded;
    end
    
    % Add a final white noise component for high frequencies
    y = y + randn(n, 1);
    
    % Normalize to [-1, 1] range
    max_val = max(abs(y));
    if max_val > 0
        y = y / max_val;
    end
    
    % Apply slight high-pass filter to remove DC drift
    % (Pink noise can accumulate DC offset due to 1/f characteristic)
    if n > 10
        y = y - movmean(y, min(100, floor(n/10)));
        % Re-normalize after filtering
        max_val = max(abs(y));
        if max_val > 0
            y = y / max_val * 0.9; % Scale to 0.9 to leave some headroom
        end
    end
end
function a15_dvfs_validate_model()
% a15_dvfs_validate_model  検証ルーチン
%   A15 Bionic DVFSモデルの出力を文献値と比較して誤差を表示します。

    fprintf('\n=== A15 DVFSモデル検証 ===\n');
    fprintf('負荷%%\t周波数[GHz]\t電力[W]\t文献値[W]\t誤差%%\n');
    fprintf('--------------------------------------------------------\n');

    % テストポイント
    test_loads        = [0, 25, 50, 75, 100];
    expected_freqs    = [1.0, 1.8, 2.4, 2.8, 3.2];   % 実測周波数 (GHz)
    literature_powers = [0.4, 1.3, 2.5, 3.4, 4.3];   % 文献値 (W)

    for i = 1:numel(test_loads)
        [f, p, ~]  = a15_dvfs_model(test_loads(i));
        freq_ghz   = f / 1e9;
        power_err  = abs(p - literature_powers(i)) / literature_powers(i) * 100;
        freq_err   = abs(freq_ghz - expected_freqs(i))  / expected_freqs(i)  * 100;

        fprintf('%d%%\t%.1f\t\t%.2f\t%.2f\t\t%.1f%%', ...
                test_loads(i), freq_ghz, p, literature_powers(i), power_err);

        if freq_err < 1 && power_err < 10
            fprintf(' ✓\n');
        else
            fprintf(' △\n');
        end
    end

    fprintf('\n電力モデル詳細（AnandTech 2021 + Apple公式）:\n');
    fprintf('- 0%%  (1.0GHz): 0.4W (E-core アイドル)\n');
    fprintf('- 25%% (1.8GHz): 1.3W (E-core/P-core混合)\n');
    fprintf('- 50%% (2.4GHz): 2.5W (P-core中負荷)\n');
    fprintf('- 75%% (2.8GHz): 3.4W (P-core高負荷)\n');
    fprintf('- 100%%(3.2GHz): 4.3W (P-core最大ブースト)\n');
    fprintf('- モデル式: P = 0.422×f²-0.022 (f in GHz)\n');
end 
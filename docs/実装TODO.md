# MobileNLD-FL 実装TODO（1週間計画）

## 📅 ガントチャート（7日間）

| Day | 0–3h | 3–6h | 6–8h |
|-----|------|------|------|
| 1   | プロジェクト雛形作成 | MHEALTH DL & 解凍 | Python 前処理 |
| 2   | LyE/DFA q15 実装（Swift） | UnitTest (Mac) | HRV(RMSSD/LF/HF) Python 実装 |
| 3   | iPhone13 実行 & Instruments 電力測定 | 処理時間計測 & ログ整理 | 結果 Excel 化 |
| 4   | Flower-Sim & FedAvg-AE ベース | PFL-AE(共有Enc/ローカルDec) | AUC/通信量 集計 |
| 5   | 図表 5 枚作成 (Matplotlib) | 関連研究表作成 | アブレーション確認 |
| 6   | LaTeX テンプレ DL & セクション見出し |  §1–§4 執筆 |  §5–§6 & 参考文献 |
| 7   | 日本語校閲 & 数式/図 体裁調整 | GitHub 公開 (コード+CSV) | 電子投稿 (IEICE) |

## 📁 フォルダ構成

```
MobileNLD-FL/
├── data/
│   ├── raw/          # MHEALTH_txt
│   └── processed/    # numpy, rri.csv
├── ios/
│   └── MobileNLD/    # Xcode プロジェクト
├── ml/
│   ├── feature_extract.py
│   └── train_federated.py
├── figs/
├── paper/
│   └── ieice_letter.tex
└── scripts/
    ├── 00_download.sh
    ├── 01_preprocess.py
    └── 02_energy_test.md
```

## Day 1: 基盤構築

### ✅ 1-1. リポジトリ作成
```bash
mkdir MobileNLD-FL && cd MobileNLD-FL
git init
```

### ✅ 1-2. データ取得
```bash
wget -P data/raw https://archive.ics.uci.edu/static/public/319/mhealth+dataset.zip
unzip data/raw/mhealth+dataset.zip -d data/raw/mhealth/
```

### ✅ 1-3. Python前処理
- TXT → pandas読込、列名付与
- ECG → NeuroKit2でR-R抽出 → rri.csv
- 3秒窓で統計特徴計算（mean/rms等）
- `data/processed/subject_XX.csv`として保存

## Day 2: iOS解析ライブラリ実装

### ✅ 2-1. Xcodeプロジェクト作成
- iOS App "MobileNLD"作成
- Swift 5.0, Deployment Target: iOS 17.0

### ✅ 2-2. 固定小数点実装
```swift
typealias Q15 = Int16

// vDSPのvDSP_vlogの代わりにLUT(256)
func lyapunov(_ x:[Q15]) -> Float
func dfaAlpha(_ x:[Q15]) -> Float
```

### ✅ 2-3. UnitTest
- MATLABとのRMSE確認（許容 <0.03）

## Day 3: 処理性能・電力計測

### ✅ 3-1. Instruments計測
1. iPhone13実機接続 → "Energy Log"開始
2. App起動 → `StartBenchmark()`で5分間連続処理
3. Average Energy Impact, CPU時間をCSV出力
4. `figs/energy_bar.pdf`作成

### ✅ 3-2. 処理時間
- Xcode "Points of Interest"で1ウィンドウ4ms以下を確認
- `figs/time_hist.pdf`作成

## Day 4: Flower連合学習

### ✅ 4-1. 基本実装
```bash
pip install flwr tensorflow==2.15
python ml/train_federated.py --algo fedavg
python ml/train_federated.py --algo pflae
```

### ✅ 4-2. モデル構成
- セッションCSV別に`ClientX`を生成
- 入力次元10（NLD2 + HRV2 + 基本統計6）
- Encoder=[32,16], Decoder=[16,32]
- Round20, Epoch1, lr=1e-3

### ✅ 4-3. 評価
- AUC計算 → `results.csv`出力
- 通信量＝送信weight数×float32サイズで計算

## ✅ Day 5: 図表作成

### ✅ 5-1. 必要な図表（5枚）
1. ✅ `roc_pfl_vs_fedavg.pdf` - ROC曲線比較
2. ✅ `comm_size.pdf` - 通信量比較
3. ✅ `rmse_lye_dfa.pdf` - 計算精度
4. ✅ `energy_bar.pdf` - 消費電力
5. ✅ `pipeline_overview.svg` - システム概要図

### ✅ 5-2. 関連研究表
- ✅ 既存手法との比較表作成

## ✅ Day 6: 論文執筆

### ✅ 6-1. IEICE和文論文誌レター執筆
✅ IEICE形式完全準拠論文完成 (2ページ)

### ✅ 6-2. 論文構成完成
- ✅ あらまし (119字/120字制限)
- ✅ まえがき・提案手法・実験・考察・むすび
- ✅ 英文Abstract (49語/50語制限)
- ✅ 文献8件・付録・実装詳細
- §3 Mobile-NLD実装（900字）
- §4 個人化連合AE（700字）
- §5 結果（900字）
- §6 まとめ（300字）
- 合計≒4,000字＋図5枚＝6頁以内

## Day 7: 仕上げ・提出

### 7-1. 最終チェック
- `jlreq`で禁則チェック
- Co-author無し確認（単著）

### 7-2. GitHub公開
```bash
git remote add origin ...
git push -u origin main
```

### 7-3. IEICE電子投稿
- 論文PDF
- 著者情報
- オンライン資料URL（GitHub）
- 研究倫理：公開DS＋自己計測（同意済）

## 参考コマンド集

### HRV抽出（Python）
```python
import neurokit2 as nk, pandas as pd
sig = pd.read_csv('ecg_col.txt', header=None).values.squeeze()
rpeaks = nk.ecg_peaks(sig, sampling_rate=250)[1]['ECG_R_Peaks']
rri = np.diff(rpeaks) / 250 * 1000
nk.hrv_time(rri, sampling_rate=1000)
```

### LyE MATLAB検算
```matlab
[lye] = RosensteinLyapunov(x,5,4,1000);
```

## 注意事項
- データ公開：生波形とラベルを論文公開と同時にGitHubで無償公開
- 倫理：公開データセット＋自己計測（同意済）を明記
- 被験者数：1名でも手法提案＋オープンリソース提供で採択可能
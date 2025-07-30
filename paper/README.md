# IEICE論文LaTeX版

## ファイル構成
- `ieice_paper.tex`: メインのLaTeXファイル
- `compile_latex.sh`: コンパイル用スクリプト
- `figs/`: 図ファイルを配置するディレクトリ（PDFまたはEPS形式）

## コンパイル方法

### 1. IEICE LaTeXクラスファイルの準備
電子情報通信学会のWebサイトから以下をダウンロード：
- `ieice.cls`: IEICEクラスファイル
- `sieicej.bst`: 参考文献スタイルファイル（必要な場合）

これらを論文ファイルと同じディレクトリに配置してください。

### 2. 図ファイルの準備
`../figs/`ディレクトリに以下の図を配置：
- `fig1_performance_comparison.pdf`
- `fig2_simd_breakdown.pdf`
- `fig3_error_analysis.pdf`
- `fig4_speedup_analysis.pdf`
- `fig5_memory_efficiency.pdf`
- `fig6_algorithm_flow.pdf`

### 3. コンパイル実行
```bash
./compile_latex.sh
```

または手動で：
```bash
platex ieice_paper.tex
platex ieice_paper.tex  # 2回目（相互参照のため）
platex ieice_paper.tex  # 3回目（最終）
dvipdfmx ieice_paper.dvi
```

## LaTeX環境の準備（macOS）
```bash
# MacTeXのインストール（Homebrew使用）
brew install --cask mactex

# または直接ダウンロード
# https://www.tug.org/mactex/
```

## 注意事項
1. 日本語環境（pLaTeX）が必要です
2. 図は`../figs/`から参照されるため、相対パスに注意
3. IEICEの投稿規定に従って余白等を調整してください
4. 最終投稿時は図をEPS形式に変換することを推奨

## 論文の特徴
- 技術的新規性：Q15+SIMDによるNLD最適化
- 定量的改善：21.8倍高速化、95% SIMD利用率
- 理論的裏付け：誤差解析による精度保証
- 実機検証：iPhone 13での3.9ms処理時間

## 図表
- 表1：処理時間比較（3秒窓、150サンプル）
- 表2：演算別SIMD利用率比較
- 表3：計算精度評価
- 図1：性能比較（処理時間とSIMD利用率）
- 図2：演算別SIMD利用率の詳細
- 図3：誤差解析（理論値vs実測値）
- 図4：窓サイズvs高速化率
- 図5：メモリ効率の比較
- 図6：アルゴリズムフロー図
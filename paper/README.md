# 論文LaTeXファイル

このディレクトリには、IEICE論文誌投稿用のLaTeXファイルが含まれています。

## ファイル構成

- `main.tex`: 論文本体のLaTeXファイル
- `references.bib`: 参考文献データベース
- `Makefile`: コンパイル用Makefile
- `figures/`: 図表用ディレクトリ（作成が必要）

## コンパイル方法

### 日本語環境でのコンパイル（推奨）

```bash
# PDFを生成
make

# クリーンアップ
make clean

# 完全クリーンアップ（PDFも削除）
make distclean

# PDFを表示
make view
```

### 手動コンパイル

```bash
platex main.tex
pbibtex main
platex main.tex
platex main.tex
dvipdfmx main.dvi
```

## 必要なパッケージ

### TeXシステム
- TeX Live または MacTeX（日本語対応版）
- platex, pbibtex, dvipdfmx

### LaTeXパッケージ
- IEEEtran クラスファイル
- pxjahyper（日本語PDF対応）
- bxcjkjatype（日本語組版）

## 図表の準備

論文中で参照されている以下の図表を`figures/`ディレクトリに配置してください：

- `system_flowchart.pdf`: システムフローチャート（図1）
- `system_architecture.pdf`: システムアーキテクチャ（図2）
- `processing_time_graph.pdf`: 処理時間グラフ（図3）
- `author1.jpg`: 第一著者の写真（オプション）
- `author2.jpg`: 第二著者の写真（オプション）

## 注意事項

1. **文字コード**: UTF-8を使用しています
2. **図表形式**: PDFまたはEPS形式を推奨
3. **参考文献**: BibTeXで管理されています
4. **クラスファイル**: IEEEtranのcompsocオプションを使用

## トラブルシューティング

### コンパイルエラーの場合
1. TeX環境が正しくインストールされているか確認
2. 必要なパッケージがすべてインストールされているか確認
3. `make clean`してから再度コンパイル

### 日本語が表示されない場合
1. platexではなくpdflatexを使用していないか確認
2. 日本語フォントが正しく設定されているか確認
3. dvipdfmxの設定を確認

## カスタマイズ

### ページ番号・巻号の変更
`main.tex`の以下の部分を編集：
```latex
\markboth{電子情報通信学会論文誌~D, Vol.~J107-D, No.~X, pp.~XXX--XXX, 2024年X月}
```

### 著者情報の更新
`\author`セクションで所属や連絡先を更新してください。
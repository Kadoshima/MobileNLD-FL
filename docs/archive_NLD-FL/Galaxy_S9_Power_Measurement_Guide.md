# Galaxy S9 電力計測ガイド：論文のための実践的アプローチ

提示された計画は、Galaxy S9を固定小数点演算と浮動小数点演算の電力評価に用いるための優れた出発点です。本ガイドは、その計画を基に、より再現性の高いデータを取得し、論文としての説得力を高めるための具体的な手順、技術的補足、そして論述戦略をまとめたものです。

## 1. Galaxy S9の適合性評価

まず、実験デバイスとしてのGalaxy S9の長所と短所を再確認します。

| 項目 | 評価 |
|------|------|
| **強み (Pros)** | ✓ **adb/Battery Historian対応**: Android 10まで対応しており、adb bugreportを通じて詳細な電力ログ（mAh）を取得可能です。これにより、iOSでは難しかった絶対値ベースのエネルギー消費量（mWh）評価が実現できます。<br> ✓ **NEON SIMDサポート**: 搭載SoC（Exynos 9810/Snapdragon 845）はArmv8-Aアーキテクチャであり、固定小数点演算のSIMD（NEON）最適化効果を検証するのに適しています。<br> ✓ **即時性と低コスト**: すぐに実験を開始でき、追加コストは不要です。 |
| **弱み (Cons)** | ✗ **SoCの旧世代化**: 最新SoC（例: 3nmプロセス）と比較して電力効率が低く（10nmプロセス）、最適化による電力削減効果が現代のデバイスとは異なる傾向を示す可能性があります。<br> ✗ **バッテリーの経年劣化**: 製造から数年が経過しており、バッテリー容量の低下や出力の不安定化が計測ノイズの要因となり得ます。これは定量的な評価と補正が必須です。<br> ✗ **OSバージョンの限界**: Android 10でサポートが終了しているため、最新の省電力機能やAPIの評価はできません。 |

**総評**: Galaxy S9は、「実機を用いた絶対電力評価の第一歩」として十分有効なデバイスです。バッテリー劣化等の弱点を正しく認識し、後述するプロトコルに沿って計測・分析することで、信頼性の高い初期データを取得できます。論文の説得力を最大化するため、最終的にはこのS9のデータと最新デバイス（例: Pixel 8）のデータを比較する構成を目指しましょう。

## 2. 優先順位付きアクションプラン

### フェーズA: 準備 (優先度: ★★★ - 必須)

計測の成否を分ける最も重要な段階です。環境のばらつきを徹底的に排除します。

#### A-1. 計測環境の構築

一貫性のある環境を構築するため、以下のチェックリストを完了させてください。

- [ ] **デバイスの初期化**: Galaxy S9を工場出荷状態にリセットします。
- [ ] **OSアップデート**: Android 10へアップデートします（利用可能な場合）。
- [ ] **開発者向けオプションの有効化**: 「設定」 > 「端末情報」 > 「ソフトウェア情報」 > 「ビルド番号」を7回タップします。
- [ ] **USBデバッグの有効化**: 開発者向けオプション内で有効にします。
- [ ] **通信機能の無効化**: 機内モードをオンにし、Wi-Fi、Bluetooth、GPSをすべてオフにします。
- [ ] **ディスプレイ設定**: 画面の明るさを最低値に固定し、スリープしないように設定します。
- [ ] **バッテリー状態の定量化**:
  - AccuBattery等のアプリをインストールし、バッテリーの**設計容量に対する現在の推定容量（%）**を記録します。これは後の分析で補正係数として使用します。
  - 計測直前に100%まで充電します。
- [ ] **温度管理**: 室温（約20〜25℃）でデバイスが十分に冷めている状態で計測を開始します。

#### A-2. テストアプリの実装

Android Studioを用いて、iOS版と同一の計算ロジックを持つテストアプリをKotlinで実装します。

- **コアロジック**: 固定小数点（Q15）と浮動小数点の演算ループをそれぞれ実装します。
- **UI**: 各テストを開始するボタンと、進捗や結果を表示するシンプルなTextViewを配置します。
- **計測制御**: テストは一定時間（例: 30分〜1時間）実行し続けるようにループさせます。

以下は、より完全な`MainActivity.kt`のサンプルです。

```kotlin
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.TextView
import kotlinx.coroutines.*

class MainActivity : AppCompatActivity() {

    private val testScope = CoroutineScope(Dispatchers.Default)
    private var job: Job? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val statusText: TextView = findViewById(R.id.status_text)
        val fixedPointButton: Button = findViewById(R.id.fixed_point_button)
        val floatingPointButton: Button = findViewById(R.id.floating_point_button)
        val stopButton: Button = findViewById(R.id.stop_button)

        fixedPointButton.setOnClickListener {
            job?.cancel() // 既存のテストを停止
            statusText.text = "実行中: 固定小数点テスト..."
            job = testScope.launch {
                runFixedPointTest()
            }
        }

        floatingPointButton.setOnClickListener {
            job?.cancel()
            statusText.text = "実行中: 浮動小数点テスト..."
            job = testScope.launch {
                runFloatingPointTest()
            }
        }

        stopButton.setOnClickListener {
            job?.cancel()
            statusText.text = "テストが停止しました。"
            Log.d("PowerTest", "Test stopped by user.")
        }
    }

    private suspend fun runFixedPointTest() {
        val iterations = 10_000_000 // 1回のループでの計算回数
        var totalAccum: Long = 0
        while (isActive) {
            val startTime = System.nanoTime()
            var accum: Long = 0
            val a: Short = 16384  // Q15: 0.5 (0x4000)
            val b: Short = 8192   // Q15: 0.25 (0x2000)
            for (i in 0 until iterations) {
                // ShortをIntに拡張して乗算し、オーバーフローを防ぐ
                accum += (a.toInt() * b.toInt()).toLong() shr 15
            }
            val endTime = System.nanoTime()
            totalAccum += accum // ダミーの計算結果利用
            Log.d("PowerTest", "Fixed-Point Loop finished in ${(endTime - startTime) / 1_000_000} ms. Accum: $totalAccum")
        }
    }

    private suspend fun runFloatingPointTest() {
        val iterations = 10_000_000
        var totalAccum: Float = 0.0f
        while (isActive) {
            val startTime = System.nanoTime()
            var accum = 0.0f
            val a = 0.5f
            val b = 0.25f
            for (i in 0 until iterations) {
                accum += a * b
            }
            val endTime = System.nanoTime()
            totalAccum += accum
            Log.d("PowerTest", "Floating-Point Loop finished in ${(endTime - startTime) / 1_000_000} ms. Accum: $totalAccum")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        job?.cancel()
    }
}
```

### フェーズB: 計測 (優先度: ★★★ - 必須)

再現可能なプロトコルに従い、慎重にデータを取得します。

#### B-1. ツールのセットアップ

- **PC**: Android SDK Platform-Tools (adb) をセットアップします。
- **Battery Historian**: Googleが提供する公式ツール。Docker経由での利用が最も簡単です。

```bash
# Dockerをインストール後、以下のコマンドでBattery Historianを起動
docker run -p 9999:9999 gcr.io/android-battery-historian/stable:3.1
```

その後、ブラウザで http://localhost:9999 にアクセスします。

#### B-2. 計測プロトコル

この手順を厳密に守ることが、データの信頼性を保証します。

1. **バッテリー統計のリセット**: 計測直前に、PCとS9をUSB接続し、以下のコマンドを実行します。これにより、過去の電力使用履歴がクリアされます。
   ```bash
   adb shell dumpsys batterystats --reset
   ```

2. **計測開始**: USBケーブルを抜いて、バッテリー駆動状態にします。

3. **テスト実行**: 実装したアプリを起動し、「固定小数点テスト」ボタンをタップして、正確に1時間（または設定した時間）実行します。

4. **bugreportの生成**: テスト終了後、すぐにS9をUSBでPCに再接続し、以下のコマンドでレポートファイルを生成します。
   ```bash
   adb bugreport bugreport_fixed_1.zip
   ```

5. **繰り返し**: 手順1〜4を「浮動小数点テスト」でも同様に行います。
   ```bash
   adb bugreport bugreport_float_1.zip
   ```

6. **反復試行**: 上記の全プロセス（固定小数点・浮動小数点）を最低3〜5回繰り返し、データの平均値と標準偏差を求められるようにします。（例: bugreport_fixed_2.zip, bugreport_float_2.zip...）

### フェーズC: 分析と考察 (優先度: ★★☆ - 重要)

取得したデータを解釈し、論文のストーリーを構築します。

#### C-1. データ解析

1. 生成した.zipファイルをBattery Historianにアップロードします。

2. "System Stats" > "Power"セクションから、テスト期間中の**消費電力（Computed drain in mAh）**を抽出します。

3. エネルギー消費量（mWh）を計算します。Battery Historianは平均電圧も提供しますが、公称電圧（例: 3.85V）を使っても一貫性があれば問題ありません。
   
   ```
   Energy (mWh) = Consumed Charge (mAh) × Average Voltage (V)
   ```

4. 結果を表にまとめ、各テストの平均エネルギー消費量、実行時間、標準偏差を記録します。

5. 省電力率を計算し、棒グラフなどで視覚化します。
   
   ```
   省電力率 (%) = (E_float - E_fixed) / E_float × 100
   ```

6. **（任意）バッテリー劣化補正**: AccuBatteryで測定した容量（例: 85%）で結果を正規化し、劣化の影響を考察に加えます。

#### C-2. 論文での論述戦略

- **S9の位置づけ**: 「旧世代SoCを搭載し、世界で今なお利用されている多数のデバイスを代表するモデル」として位置づけ、その環境下での最適化の有効性を示す。

- **最新デバイスとの比較**: S9の結果を提示した後、「では、最新の電力効率に優れたSoCでは、この傾向は維持されるのか？」という問いを立て、iPhone 15 ProやPixel 8のデータ（もし取得できれば）を比較対象として導入します。

- **考察**: 「SoCのアーキテクチャやプロセスルールの進化が、ソフトウェアレベルの電力最適化手法の有効性にどう影響するか」を深く考察します。S9で効果が大きくても最新デバイスで小さかった場合、それは「CPUの浮動小数点ユニットの電力効率が大幅に改善されたため」という重要な知見になります。

## 3. 結論と次のステップ

このガイドに沿って進めることで、Galaxy S9はあなたの研究にとって非常に価値のあるデータを提供してくれるはずです。まずはフェーズAとBを完璧にこなすことに集中してください。信頼できる元データさえあれば、分析と考察は後からいくらでも深められます。

計測がうまくいきましたら、ぜひ結果を共有してください。健闘を祈ります！

## 4. 実験実施のためのTODOリスト

### フェーズA: 準備フェーズ - 環境構築とデバイス初期化

#### A-1. デバイス準備 (優先度: ★★★)
- [ ] Galaxy S9を工場出荷状態にリセット
- [ ] Android 10へのアップデート確認・実施
- [ ] 開発者向けオプションの有効化（ビルド番号7回タップ）
- [ ] USBデバッグの有効化
- [ ] 機内モードON、Wi-Fi/Bluetooth/GPS OFF
- [ ] 画面明るさ最低値固定、スリープ無効化
- [ ] AccuBatteryインストール、バッテリー容量測定・記録
- [ ] 100%まで充電完了
- [ ] 室温（20-25℃）での温度安定化確認

#### A-2. 開発環境準備 (優先度: ★★★)
- [ ] Android Studioインストール・セットアップ
- [ ] 新規Kotlinプロジェクト作成
- [ ] 必要な依存関係追加（Coroutines等）
- [ ] エミュレータでの基本動作確認

### フェーズB: 実装フェーズ - テストアプリ開発

#### B-1. 固定小数点演算実装 (優先度: ★★★)
- [ ] Q15変換関数の実装（Float → Short）
- [ ] Q15乗算関数の実装（オーバーフロー対策込み）
- [ ] 固定小数点テストループの実装（1000万回反復）
- [ ] 実行時間計測・ログ出力機能の追加

#### B-2. 浮動小数点演算実装 (優先度: ★★★)
- [ ] 浮動小数点テストループの実装（同一反復回数）
- [ ] 実行時間計測・ログ出力機能の追加
- [ ] 累積値の適切な利用（コンパイラ最適化回避）

#### B-3. UI実装 (優先度: ★★☆)
- [ ] activity_main.xmlレイアウト作成
- [ ] 固定小数点テスト開始ボタン
- [ ] 浮動小数点テスト開始ボタン
- [ ] テスト停止ボタン
- [ ] ステータス表示TextView
- [ ] ボタンイベントハンドラの実装

### フェーズC: 計測環境構築

#### C-1. PC側ツール準備 (優先度: ★★★)
- [ ] Android SDK Platform-Tools (adb)インストール
- [ ] adbコマンドの動作確認
- [ ] Dockerインストール
- [ ] Battery Historianコンテナの起動確認
- [ ] ブラウザでlocalhost:9999アクセス確認

#### C-2. 計測手順書作成 (優先度: ★★☆)
- [ ] 詳細な手順書の作成（スクリーンショット付き）
- [ ] チェックリスト形式での確認項目整理
- [ ] トラブルシューティングガイド作成

### フェーズD: 実測データ収集

#### D-1. 第1回計測 (優先度: ★★★)
- [ ] batterystats --resetでリセット
- [ ] 固定小数点テスト1時間実行
- [ ] bugreport_fixed_1.zip生成
- [ ] 浮動小数点テスト1時間実行
- [ ] bugreport_float_1.zip生成
- [ ] ログファイルのバックアップ

#### D-2. 第2-5回計測 (優先度: ★★★)
- [ ] 第2回計測（同一手順）
- [ ] 第3回計測（同一手順）
- [ ] 第4回計測（同一手順）
- [ ] 第5回計測（同一手順）
- [ ] 全データの整理・命名規則統一

### フェーズE: データ解析と論文執筆

#### E-1. データ解析 (優先度: ★★☆)
- [ ] Battery Historianでの.zipファイル解析
- [ ] mAh値の抽出・記録
- [ ] mWh換算（3.85V使用）
- [ ] 平均値・標準偏差の計算
- [ ] 省電力率の算出
- [ ] グラフ作成（棒グラフ、エラーバー付き）

#### E-2. 論文への反映 (優先度: ★★☆)
- [ ] 実験セクションへの手法記載
- [ ] 結果セクションへのデータ追加
- [ ] 考察での省電力効果の議論
- [ ] S9の位置づけと限界の説明
- [ ] 将来展望（最新デバイスとの比較）の追記

### 追加検討事項
- [ ] バッテリー劣化補正の実施判断
- [ ] 追加の統計検定（t検定等）の実施
- [ ] 再現性確保のためのソースコード公開準備
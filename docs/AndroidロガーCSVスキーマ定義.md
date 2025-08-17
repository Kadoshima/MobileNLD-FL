以下をそのままファイルとして保存すれば使えます。コア列は要件定義・解析ノートブックに完全対応。拡張列は将来互換を壊さずに追加できます。

1) phone_log_schema_dictionary_v1.csv（人が読む用の辞書）
保存名: phone_log_schema_dictionary_v1.csv
内容:
"column_name","requirement","type","unit","allowed_values","min","max","description","example"
"recv_unix_ms","required","integer","ms since epoch (UTC)","","946684800000","","受信時刻（Unixミリ秒, UTC）。解析の主キーの一部","1723890123456"
"recv_elapsed_ns","optional","integer","ns (monotonic)","","","","Android elapsedRealtimeNanosのスナップショット（単調増加）。遅延推定の補助","1234567890123"
"device_id","recommended","string","","","1","32","センサ側デバイスID（英数-_）。同一run内で不変","devA01"
"rssi_dbm","required","integer","dBm","","-127","20","受信RSSI（dBm）。品質診断と欠落率の解析に使用","-63"
"mfg_raw_hex","required","string","hex","","0","62","Manufacturer Specific Dataの生hex（最大31B→最大62桁）。後段パースの元","5900013412002064102C0101002C01"
"seq","recommended","integer","","","0","255","広告ごとの8bitシーケンス番号。欠落率推定に使用","16"
"tick_lsb_10ms","recommended","integer","10 ms LSB","","0","65535","デバイス内部tick（10ms単位, 16bit LSB）。時刻合わせに使用","300"
"state","recommended","integer","","0|1|2","","","HARの粗状態。0=Quiet, 1=Active, 2=Uncertain","0"
"u_q_0_255","recommended","integer","","","0","255","不確実度（0-255, 255=最不確実）。校正済み推奨","32"
"battery_pct","optional","integer","%","","0","100","デバイスの推定バッテリー残量","100"
"flags","optional","integer","","","0","255","bit0=SYNC, bit1=STATE_CHANGE 等、イベントフラグ","1"
"state_seq","optional","integer","","","0","255","状態遷移カウンタ（8bit）。遅延測定のイベント識別に使用","0"
"state_chg_tick_lsb_10ms","optional","integer","10 ms LSB","","0","65535","状態遷移イベントのtick（10ms単位, 16bit LSB）","300"
"scan_callback_dropped","optional","integer","0/1","","0","1","Androidスキャンのドロップ指標（1=ドロップ検出）","0"
"phone_model","optional","string","","","","","受信端末モデル","Pixel 6"
"app_version","optional","string","semver","","","","ロガーアプリのバージョン","1.2.0"
"run_id","optional","string","","","","","実験run識別子（ファイル連携用）","20250817_A01_001"
"condition","optional","string","","Fixed-100ms|Fixed-200ms|Fixed-500ms|Adaptive|Adaptive-HighHyst","","","実験条件の表示名","Adaptive"
"subject_id","optional","string","","","","","被験者ID（匿名化）","S01"

2) phone_log_table_schema_v1.json（機械検証用 Table Schema）
保存名: phone_log_table_schema_v1.json
内容:
{
  "profile": "tabular-data-resource",
  "name": "android_ble_logger",
  "path": "phone_*.csv",
  "scheme": "file",
  "format": "csv",
  "encoding": "utf-8",
  "dialect": {
    "delimiter": ",",
    "lineTerminator": "\n",
    "quoteChar": "\"",
    "header": true
  },
  "schema": {
    "missingValues": ["", "NA", "NaN", "null"],
    "primaryKey": ["recv_unix_ms", "device_id", "seq"],
    "fields": [
      {
        "name": "recv_unix_ms",
        "type": "integer",
        "constraints": { "required": true, "minimum": 946684800000 },
        "description": "受信時刻（Unixミリ秒, UTC）"
      },
      {
        "name": "recv_elapsed_ns",
        "type": "integer",
        "constraints": { "required": false },
        "description": "Android elapsedRealtimeNanos（単調増加）"
      },
      {
        "name": "device_id",
        "type": "string",
        "constraints": { "required": false, "pattern": "^[A-Za-z0-9_-]{1,32}$" },
        "description": "センサ側デバイスID"
      },
      {
        "name": "rssi_dbm",
        "type": "integer",
        "constraints": { "required": true, "minimum": -127, "maximum": 20 },
        "description": "受信RSSI [dBm]"
      },
      {
        "name": "mfg_raw_hex",
        "type": "string",
        "constraints": { "required": true, "pattern": "^[0-9A-Fa-f]{0,62}$" },
        "description": "Manufacturer Specific Dataのhex"
      },
      {
        "name": "seq",
        "type": "integer",
        "constraints": { "required": false, "minimum": 0, "maximum": 255 },
        "description": "8bit広告シーケンス番号"
      },
      {
        "name": "tick_lsb_10ms",
        "type": "integer",
        "constraints": { "required": false, "minimum": 0, "maximum": 65535 },
        "description": "デバイスtick（10ms単位, 16bit LSB）"
      },
      {
        "name": "state",
        "type": "integer",
        "constraints": { "required": false, "minimum": 0, "maximum": 2 },
        "description": "0=Quiet, 1=Active, 2=Uncertain"
      },
      {
        "name": "u_q_0_255",
        "type": "integer",
        "constraints": { "required": false, "minimum": 0, "maximum": 255 },
        "description": "不確実度（0-255, 高いほど不確実）"
      },
      {
        "name": "battery_pct",
        "type": "integer",
        "constraints": { "required": false, "minimum": 0, "maximum": 100 },
        "description": "バッテリー残量 [%]"
      },
      {
        "name": "flags",
        "type": "integer",
        "constraints": { "required": false, "minimum": 0, "maximum": 255 },
        "description": "bit0=SYNC, bit1=STATE_CHANGE"
      },
      {
        "name": "state_seq",
        "type": "integer",
        "constraints": { "required": false, "minimum": 0, "maximum": 255 },
        "description": "状態遷移カウンタ"
      },
      {
        "name": "state_chg_tick_lsb_10ms",
        "type": "integer",
        "constraints": { "required": false, "minimum": 0, "maximum": 65535 },
        "description": "状態遷移イベントtick（10ms単位）"
      },
      {
        "name": "scan_callback_dropped",
        "type": "integer",
        "constraints": { "required": false, "minimum": 0, "maximum": 1 },
        "description": "Androidスキャンドロップ指標（0/1）"
      },
      {
        "name": "phone_model",
        "type": "string",
        "constraints": { "required": false, "maxLength": 64 },
        "description": "受信端末モデル"
      },
      {
        "name": "app_version",
        "type": "string",
        "constraints": { "required": false, "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+(-[A-Za-z0-9]+)?$" },
        "description": "ロガーアプリのバージョン（semver）"
      },
      {
        "name": "run_id",
        "type": "string",
        "constraints": { "required": false, "maxLength": 64 },
        "description": "実験run識別子"
      },
      {
        "name": "condition",
        "type": "string",
        "constraints": {
          "required": false,
          "enum": ["Fixed-100ms","Fixed-200ms","Fixed-500ms","Adaptive","Adaptive-HighHyst"]
        },
        "description": "実験条件の表示名"
      },
      {
        "name": "subject_id",
        "type": "string",
        "constraints": { "required": false, "maxLength": 32 },
        "description": "被験者ID（匿名化）"
      }
    ]
  }
}

3) phone_log_sample_v1.csv（ヘッダとサンプル2行）
保存名: phone_log_sample_v1.csv
内容:
recv_unix_ms,recv_elapsed_ns,device_id,rssi_dbm,mfg_raw_hex,seq,tick_lsb_10ms,state,u_q_0_255,battery_pct,flags,state_seq,state_chg_tick_lsb_10ms,scan_callback_dropped,phone_model,app_version,run_id,condition,subject_id
1723890123456,1234567890123,devA01,-63,5900013412002064102C0101002C01,16,300,0,32,100,1,0,300,0,Pixel 6,1.2.0,20250817_A01_001,Adaptive,S01
1723890123560,1234567891123,devA01,-61,590001341200C864112E0102012E01,17,302,1,200,100,2,1,302,0,Pixel 6,1.2.0,20250817_A01_001,Adaptive,S01

実装メモ
- 文字コードはUTF-8、区切りはカンマ、LF改行、ヘッダ行あり。
- 欠損は空文字にし、NA/NaN/nullは使用しない（検証時のmissingValuesに含めてあるため空も許容）。
- 数値の単位はスキーマ通り。特に recv_unix_ms はUTCのミリ秒で記録。
- mfg_raw_hex は広告のManufacturer Specific Dataの生bytesをそのまま16進文字列化（大文字/小文字は不問）。
- 拡張列（phone_model 等）は解析で無視されるが、将来の追跡に有用なため記録推奨。
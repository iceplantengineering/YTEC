# YTEC ASRS Refactoring Project

このプロジェクトは、既存の `origine` フォルダ内のASRS（自動倉庫）制御システムをリファクタリングし、保全性と拡張性を向上させることを目的としています。
`refact` フォルダには、改修後のコードおよびドキュメント格納フォルダ `doc` が含まれています。

## リファクタリングの主な変更点
1.  **ロジックのPLC移管**:
    *   従来PC (Lua) 側で行っていた詳細なタスク判定ロジックの一部を、PLC (ST言語 + ラダー) に移管しました。
    *   これにより、PCレスでの単独運転やトラブルシューティングが容易になりました。
2.  **ST言語の導入**:
    *   タスク種別（入庫/出庫/移動）の動的判定ロジックにST言語を採用しました (`refact/Masked_ST_Logic.st`)。
    *   Lua側では対応するコード (`TaskType` 送信) をマスク（無効化）しています。
3.  **ドキュメント整備**:
    *   `doc/` フォルダ配下に、システム構成図、信号表、デバッグ手順書を新規作成しました。

## フォルダ構成
- `origine/`: リファクタリング前のオリジナルソースコード（参照用）
- `process/`: 開発プロセスや指示書など
- `refact/`: **リファクタリング後の実稼働コード**
    - `TTask.lua`: タスク管理Luaスクリプト (一部機能マスク済み)
    - `TConEquipmentTest.lua`: 通信ドライバLuaスクリプト
    - `StackerCrane_Refactored_Q_GXW.asc`: スタッカークレーン用ラダープログラム
    - `Conveyor_Refactored_Q_GXW.asc`: コンベア用ラダープログラム
    - `GroundPanel_Refactored_Q_GXW.asc`: 地上盤用ラダープログラム
    - `Masked_ST_Logic.st`: **[新規]** PLC用タスク判定STロジック
- `doc/`: **プロジェクトドキュメント**
    - `io_signal_list.md`: IO信号および内部レジスタ一覧
    - `system_architecture.md`: システム構成図・ワークフロー (Mermaid)
    - `debugging_manual.md`: デバッグ・検証手順書
    - `debug_checklist.md`: 動作確認用チェックリスト

## 確認事項
この構成により、`origine` の機能が `refact` に完全に移植され、かつ設計コンセプト（PLC主体の制御）に従った実装となっていることを確認してください。
詳細は `doc/debugging_manual.md` を参照して動作検証を行ってください。

---

## 改変履歴

### 2025-02-17: ドキュメント更新 - CC-Link/Modbus通信仕様の明確化

**目的:**
プログラム実装（`refact`）とドキュメント（`doc`）の記述間にあったCC-LinkおよびModbus/TCPに関する齟齬を解消しました。

**変更内容:**

1. **`doc/system_architecture.md` の更新**
   - Modbus/TCP通信詳細の記載追加
     - 実装ファイル：`TConEquipmentTest.lua`, `TClientHelper`
     - 機能コード、接続処理の詳細
   - CC-Link通信詳細の記載追加
     - マスター/スレーブ構成
     - バッファメモリマップ（B00-BFF, B1000-B1023等）
     - 通信監視デバイス（M370-M372）
   - 通信プロトコル詳細セクション（セクション5）の新規追加

2. **`doc/io_signal_list.md` の更新**
   - CC-Link信号マップセクション（セクション5）の新規追加
     - B01設備 CC-Link入出力の詳細
     - RFIDデータバッファ（W0-W13等）
     - 通信監視デバイス（SB49, W900.0-2）
   - Modbus/TCP通信マップセクション（セクション6）の新規追加
     - 接続設定、レジスタマップ
     - `TConEquipmentTest.lua` メソッド対応表

3. **`doc/debug_checklist.md` の更新**
   - Modbus/TCP通信確認セクション（セクション2）の新規追加
   - CC-Link通信確認セクション（セクション3）の新規追加
   - トラブルシューティングの拡張（Modbus/CC-Link関連）

4. **`doc/debugging_manual.md` の更新**
   - Modbus/TCP通信確認セクション（セクション3）の新規追加
   - CC-Link通信確認セクション（セクション4）の新規追加
   - 通信フロー図の追加

5. **`doc/plc_flowcharts.md` の更新**
   - 地上盤PLC CC-Link処理フローの追加（セクション2）
   - コンベアPLC CC-Link処理フローの追加（セクション4）
   - CC-Linkシーケンス図の追加

**技術的詳細:**

| 項目 | 説明 |
|------|------|
| **Modbus/TCP** | PC(Lua) ↔ PLC間の通信<br/>実装: `TConEquipmentTest.lua`<br/>ポート: 502 |
| **CC-Link** | 地上盤PLC ↔ コンベア/スタッカーPLC間の通信<br/>マスター: 地上盤PLC<br/>スレーブ: コンベアPLC, スタッカーPLC |

**関連ファイル:**
- 更新MDファイル: `system_architecture.md`, `io_signal_list.md`, `debug_checklist.md`, `debugging_manual.md`, `plc_flowcharts.md`
- 参照プログラム: `TConEquipmentTest.lua`, `Conveyor_Refactored_Q_GXW.asc`, `GroundPanel_Refactored_Q_GXW.asc`

### 2026-02-17: ドキュメント修正 - GitHubでのMermaidチャート表示対応

**目的:**
GitHub上のMermaidレンダラーで正しく表示されない問題を修正しました。

**変更内容:**

1. **`doc/system_architecture.md` の修正**
   - FontAwesome HTMLタグ（`<i class='fa ...'>`）の削除
   - クラス図の `note for` 構文をクラス内プロパティに変更
   - シーケンス図の `box` 構文を削除（単純なparticipant宣言に変更）
   - 線種構文の統一（太線`==`、点線`-.`を実線`---`に変更）

2. **`doc/plc_flowcharts.md` の修正**
   - シーケンス図から無効なプレーンテキスト行を削除

3. **`doc/debugging_manual.md` の修正**
   - フローチャートの閉じていない引用符を修正

**GitHubでサポートされないMermaid構文:**
| 構文 | 対応 |
|------|------|
| `<i class='fa fa-xxx'></i>` | 削除（プレーンテキストに変更） |
| `note for クラス名 "テキスト"` | クラス内のプロパティに変更 |
| `box "タイトル" ... end` | 単純なparticipant宣言に変更 |
| `== Label ==\>` | `---\|"Label"\|` に変更 |
| `-.` | `---` に変更 |

**関連ファイル:**
- 更新MDファイル: `system_architecture.md`, `plc_flowcharts.md`, `debugging_manual.md`

### 2026-02-18: PLC分割検証レポートの作成

**目的:**
ORIGINE（4PLC構成）からREFACT（3PLC構成）への変更に伴う機能上の問題を分析し、GroundPanel PLCのB01/B02分割の可否を検証しました。

**変更内容:**

1. **`PLC_separation.md` の新規作成**
   - PLC構成比較（ORIGINE vs REFACT）
   - HMI接続構成の検討（1PLC+複数HMIの可能性）
   - GroundPanel_Refactored_Q_GXW.ascの構造分析
   - B01/B02分割の可否評価
   - HMI画面設計の推測
   - Modbusによるオフライン検証手法
   - CC-Link実装への移行手順

2. **分析結果のサマリー**
   - **分割の可否**: 技術的に容易。プログラム構造が明確に分離されている
   - **デバイス割り当て**: B01（M1000-M1079, D331-D338）、B02（M1200-M1279, D352-D359）
   - **HMI対応**: 1PLC+2HMI構成が可能。複数HMIから1PLCに同時接続できる
   - **検証手法**: Modbusシミュレータによるオフライン検証後、CC-Linkに置き換え可能

**技術的詳細:**

| 項目 | 説明 |
|------|------|
| **B01デバイス範囲** | M1000-M1079（内部リレー）、D331-D338（RFID1/2） |
| **B02デバイス範囲** | M1200-M1279（内部リレー）、D352-D359（RFID3/4） |
| **CC-Link B01用** | B00-B4F（77-185行） |
| **CC-Link B02用** | B100-B11F（201-206行） |
| **HMI接続** | MCプロトコル（TCP/IP、ポート5007） |

**検証フロー:**
```
Phase 1: Modbus（オフライン検証）
  └─ ModbusシミュレータでB01/B02設備を模倣
     └─ 機能検証完了

Phase 2: CC-Link（実装）
  └─ 実機（CC-Link対応）に接続
     └─ 通信タイミング調整
```

**関連ファイル:**
- 新規作成: `PLC_separation.md`
- 参照プログラム: `GroundPanel_Refactored_Q_GXW.asc`, `Conveyor_Refactored_Q_GXW.asc`

### 2026-02-18: GX Works ASCインポート手順書の作成

**目的:**
REFACTフォルダ内のASCファイルをGX Worksにインポートし、パラメータ設定を行う手順を文書化しました。

**変更内容:**

1. **`doc/import_asc.md` の新規作成**
   - プロジェクト新規作成手順（GX Works2/3）
   - IOアサイン設定方法（X/Yデバイス）
   - CC-Linkパラメータ設定（マスタ/スレーブ）
   - デバイスコメントのインポート方法
   - ASCファイルのインポート手順
   - コンパイルとエラーチェック方法
   - PLCへの書き込み手順
   - トラブルシューティング

2. **作業量見積もり**
   - **標準（コメントあり、設定入念）**: 10-14時間（1.5～2日）
   - **実務的（テンプレート使用）**: 6-8時間（1日）
   - **最短（基本設定のみ）**: 4-5時間（半日〜1日）
   - **現場作業（テンプレート使用）**: 2-3時間

3. **事前準備の重要性**
   - オフラインでテンプレートプロジェクト作成により現場作業を80%短縮可能
   - IOアサイン、CC-Linkパラメータ、デバイスコメントを事前設定
   - Modbusシミュレータでの事前検証が可能

**技術的詳細:**

| 項目 | 説明 |
|------|------|
| **ASCファイル形式** | Mitsubishi標準テキスト形式（ラダーロジックのみ） |
| **含まれるもの** | ラダーロジック、コメント |
| **含まれないもの** | IOアサイン、CC-Linkパラメータ、システム設定 |
| **設定が必要なデバイス** | X（入力260点）、Y（出力30点）、M（リレー2500点）、D（レジスタ5100点）、B（CC-Link300点） |

**作業フロー:**
```
Phase 1: オフライン準備（自社/オフィス）
  └─ テンプレートプロジェクト作成
  └─ IOアサイン、CC-Linkパラメータ設定
  └─ デバイスコメント登録
  └─ Modbusシミュレータで事前検証

Phase 2: 現場作業（現地）
  └─ 実機ハードウェア確認
  └─ ASCインポート & PLC書き込み
  └─ CC-Link接続テスト
  └─ 実機動作確認
```

**関連ファイル:**
- 新規作成: `doc/import_asc.md`
- 対象ASCファイル: `GroundPanel_Refactored_Q_GXW.asc`, `Conveyor_Refactored_Q_GXW.asc`, `StackerCrane_Refactored_Q_GXW.asc`

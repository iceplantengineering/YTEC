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

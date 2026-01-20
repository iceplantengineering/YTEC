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

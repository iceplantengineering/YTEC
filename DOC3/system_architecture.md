# システムアーキテクチャ・ソフトウェア構成（REFACT3 + GATEWAY版）

## 1. ハードウェア & ネットワーク構成

REFACT3では、地上盤PLCをB01/B02の2台に分割した **4PLC構成** を踏襲しつつ、**M8001（シミュレーション/実装モード切り替えフラグ）**を活用したオフラインデバッグ機能を実装しました。
さらに、PC単体でのテストを容易にするため、ModbusルーティングとCC-Link仮想コピーを統合した**GATEWAYプロセス**を追加しています。

```mermaid
graph TB
    subgraph Host ["上位層"]
        WMS["WMS Server<br/>倉庫管理システム"]
    end

    subgraph PC_Layer ["制御PC層 (Windows)"]
        style PC_Layer fill:#f9f,stroke:#333
        CtrlPC["制御PC"]

        subgraph PC_Internal ["PC内部ソフトウェア"]
            style PC_Internal fill:#fff,stroke:#666
            Redis["Redis DB"]
            LuaApp["Lua制御アプリ<br/>TTask.lua, TConEquipmentTest.lua"]
            
            GW["GATEWAY (Python)<br/>Modbus Server & CC-Link Copy"]
        end
    end

    subgraph PLC_Layer ["PLC制御層（GX Simulator2 / 実機）"]
        style PLC_Layer fill:#eef,stroke:#333

        B01_PLC["B01地上盤 PLC<br/>B01_GroundPanel_Q_Switch_GXW.asc<br/>ステーション1001制御"]
        B02_PLC["B02地上盤 PLC<br/>B02_GroundPanel_Q_Switch_GXW.asc<br/>ステーション1002制御"]
        SRM_PLC["スタッカー PLC<br/>StackerCrane_Refactored_Q_Switch_GXW.asc"]
        CV_PLC["コンベア PLC<br/>Conveyor_Refactored_Q_Switch_GXW.asc"]
    end

    subgraph Device_Layer ["フィールド機器層（M8001=ON時は切離し）"]
        AGV["無人搬送車 AGV"]
        SRM_HW[クレーン モータ/センサ]
        CV_HW[コンベア モータ/センサ]
        B01_HW["B01設備<br/>（ハッチパネル・RFID1/2）"]
        B02_HW["B02設備<br/>（ハッチパネル・RFID3/4）"]
    end

    %% Network Connections
    WMS ---|"Task I/F"| Redis
    Redis ---|"Localhost"| LuaApp

    %% Modbus to Gateway
    LuaApp ---|"Modbus/TCP<br/>(127.0.0.1:1502x)"| GW
    
    %% Gateway to PLC (MX Component / Ethernet)
    GW ---|"MX Component (ActUtlType)"| B01_PLC
    GW ---|"MX Component"| B02_PLC
    GW ---|"MX Component"| SRM_PLC
    GW ---|"MX Component"| CV_PLC

    %% Virtual CC-Link via Gateway
    GW -.->|"仮想CC-Link/ブロックコピー<br/>(cc_link_copy.py)"| GW

    %% Physical Field Connections (Bypassed in Sim)
    B01_PLC -.-|"実機CC-Link"| CV_PLC
    B01_PLC -.-|"実機U2\G"| SRM_PLC
    B01_PLC -.-|"Wireless"| AGV
    SRM_PLC -.- SRM_HW
    CV_PLC -.- CV_HW
```
*(注: `-.-` はM8001=ON時に論理的に切り離されるか、またはGATEWAY経由で仮想化される接続を示します)*

### 1.1 REFACT2 vs REFACT3 構成比較

| 項目 | REFACT2（実機前提） | REFACT3 + GATEWAY（シミュレーション対応） |
|------|----------------|-------------------------------------|
| I/O処理 | 物理入力に直結 | `M8001` により物理入力のバイパス・論理完結が可能 |
| PLC間通信 | CC-Linkケーブル必須 | **GATEWAY** がPC内でデバイス値を30ms周期でコピー（仮想CC-Link） |
| 接続先 | 各PLCの独自IP | Lua側からはGATEWAYのローカルポート(`15021~`)へModbus接続 |
| ハンドシェイク | Lua依存部分あり | `Store_1`, `Outbound_1` 相当のハンドシェイク機能をPLCに完全実装 |

### 1.2 通信レイヤ詳細（オフライン時）

オフライン検証時、PC上の各ソフトウェアは以下の役割を担います。

1. **Luaアプリケーション**: `127.0.0.1` 宛にModbus/TCPコマンドを送信（タスク情報の書き込み等）。
2. **GATEWAY (Modbus Server)**: 受信したModbusアドレス（例: 400339）を自動解析して対応するPLCの論理局番へ、**MX Component** を使ってデバイス値（`D339` 等）として直接書き込み・読み出しを行います。
3. **GATEWAY (CC-Link Copy)**: B01のDレジスタ（タスクデータ）、Bデバイス（コンベヤ在席フラグ）、U2\Gデータ等を定期的に読み取り、接続先のPLCデバイスへ上書きします。

これにより通信異常監視（M370~M372等）はPLC内でバイパスされつつ、値の授受自体はGATEWAYが行うため完璧な連動テストが成立します。

---

## 2. ソフトウェアモジュール関連図 (REFACT3)

```mermaid
classDiagram
    direction TB

    class LuaScript {
        +TTask.lua: タスク管理
        +TConEquipmentTest.lua: PLC通信
    }
    
    class GATEWAY {
        +modbus_server.py
        +plc_access_mx.py
        +cc_link_copy.py
    }

    class B01_PLCMemory {
        +M8001: オフラインモード切替
        +D3287-D3292: B01タスク
        +M1000-M1079: B01 CC-Link受信
    }

    class ST_Logic {
        <<PLC Internal>>
        +DetermineTaskType(D339, D340) -> D330
    }

    LuaScript ..> GATEWAY : Modbus/TCP (localhost)
    GATEWAY --> B01_PLCMemory : MX Component (D339)
    GATEWAY --> GATEWAY : Bデバイス・Dレジスタ定期コピー
    B01_PLCMemory --> ST_Logic : D339/D340入力
    ST_Logic --> B01_PLCMemory : D330書き込み
```

---

## 3. 詳細ワークフロー (オフライン連動シーケンス)

```mermaid
sequenceDiagram
    autonumber

    participant WMS
    participant Task as TTask.lua
    participant GW as GATEWAY (Python)
    participant B01 as B01 PLC (Sim)
    participant HW as CC-Link / 物理配線
    participant CV as CV PLC (Sim)

    Note over B01, CV: 【GATEWAY起動直後】
    GW->>B01: M8001 = ON (バイパス開始)
    GW->>CV: M8001 = ON (タイマー処理開始)

    Note over B01, CV: 【タスク発行】
    WMS->>Task: タスク発行 (実機レス)
    Task->>GW: 搬送指示 (Modbus 400339)
    GW->>B01: D339書込 (MX Component)
    
    B01->>B01: STロジック実行・待機
    
    CV->>CV: コンベヤ内部タイマー進行→到着
    CV->>CV: B39(在席) = 1

    Note over B01, CV: 【GATEWAY仮想CC-Link】
    GW->>CV: B39読出
    GW->>B01: B39書込 -> M1057 ON
    
    B01->>B01: ハンドシェイク成立、D212=1
```

## 4. プログラムファイル構成 (REFACT3)

| ファイル名 | 分類 | 主な機能 |
|-----------|-----|---------|
| `B01_GroundPanel_Q_Switch_GXW.asc` | PLC-1 | M8001によるI/Oバイパス、搬入・搬出ハンドシェイク実装済 |
| `B02_GroundPanel_Q_Switch_GXW.asc` | PLC-2 | M8001によるI/Oバイパス、搬入・搬出ハンドシェイク実装済 |
| `Conveyor_Refactored_Q_Switch_GXW.asc` | PLC-3 | M8001によるコンベヤモータ動作シミュレーション、センサ無視 |
| `StackerCrane_Refactored_Q_Switch_GXW.asc` | PLC-4 | 軸移動時間の内部タイマー代替（M8001=ON時）、位置決め完了擬似生成 |
| `Masked_ST_Logic.st` | PLC-1/2 | Lua側でマスクされたタスク生成ロジックのPLC側実装 |
| `GATEWAY/main.py` | PCツール | MX Component接続制御、M8001初期化 |
| `GATEWAY/modbus_server.py`| PCツール | Lua通信用ローカルModbusサーバー (Port 15021~) |
| `GATEWAY/cc_link_copy.py` | PCツール | 4つのPLCシミュレータ間でデバイス値（D, B, U2\G等）を定期コピー |

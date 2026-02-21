# システムアーキテクチャ・ソフトウェア構成（REFACT3版）

## 1. ハードウェア & ネットワーク構成

REFACT3では、地上盤PLCをB01/B02の2台に分割した **4PLC構成** を踏襲しつつ、**M8001（シミュレーション/実装モード切り替えフラグ）**を活用したオフラインデバッグ機能を全PLCに組み込んでいます。

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
        end
    end

    subgraph PLC_Layer ["PLC制御層（4PLC構成 + M8001対応）"]
        style PLC_Layer fill:#eef,stroke:#333

        B01_PLC["B01地上盤 PLC<br/>B01_GroundPanel_Q_Switch_GXW.asc<br/>ステーション1001制御"]
        B02_PLC["B02地上盤 PLC<br/>B02_GroundPanel_Q_Switch_GXW.asc<br/>ステーション1002制御"]
        SRM_PLC["スタッカー PLC<br/>StackerCrane_Refactored_Q_Switch_GXW.asc"]
        CV_PLC["コンベア PLC<br/>Conveyor_Refactored_Q_Switch_GXW.asc"]
    end

    subgraph Device_Layer ["フィールド機器層"]
        AGV["無人搬送車 AGV"]
        SRM_HW[クレーン モータ/センサ]
        CV_HW[コンベア モータ/センサ]
        B01_HW["B01設備<br/>（ハッチパネル・RFID1/2）"]
        B02_HW["B02設備<br/>（ハッチパネル・RFID3/4）"]
    end

    %% Network Connections
    WMS ---|"Task I/F"| Redis
    Redis ---|"Localhost"| LuaApp

    LuaApp ---|"Modbus/TCP"| B01_PLC
    LuaApp ---|"Modbus/TCP"| B02_PLC
    LuaApp ---|"Modbus/TCP"| SRM_PLC
    LuaApp ---|"Modbus/TCP"| CV_PLC

    B01_PLC ---|"CC-Link (B00-B4F)"| CV_PLC
    B02_PLC ---|"CC-Link (B100-B101)"| CV_PLC
    B01_PLC ---|"CC-Link (U2\G)"| SRM_PLC
    B02_PLC ---|"CC-Link (U2\G)"| SRM_PLC

    %% Field Connections
    B01_PLC -.-|"Wireless"| AGV
    B02_PLC -.-|"Wireless"| AGV
    SRM_PLC -.- SRM_HW
    CV_PLC -.- CV_HW
    CV_PLC -.- B01_HW
    CV_PLC -.- B02_HW
```
*(注: `---` は実機接続、`-.-` はM8001=ON時に論理的に切り離される（バイパス/ダミー化される）物理接続を示します)*

### 1.1 REFACT2 vs REFACT3 構成比較

| 項目 | REFACT2（4PLC） | REFACT3（4PLC + シミュレーション対応） |
|------|----------------|-------------------------------------|
| I/O処理 | 物理入力に直結 | `M8001` により物理入力のバイパス・論理完結が可能 |
| CC-Link異常 | 異常検知で即停止 | `M8001=ON` で通信異常をマスキング（正常扱い） |
| ファイル名 | `..._Q_GXW.asc` | `..._Q_Switch_GXW.asc` |
| ハンドシェイク | B01/B02の一部ロジック欠落 | `Store_1`, `Outbound_1` 相当のハンドシェイク機能をPLCに完全実装 |

### 1.2 Modbus/TCP通信詳細

PCのLuaアプリケーションとPLC間の通信はModbus/TCPプロトコルで行われます。（REFACT2から変更なし）

| B01 | B02 | スタッカー | コンベア |
|---|---|---|---|
| 192.168.1.1:502 | 192.168.1.4:502 | 192.168.1.2:502 | 192.168.1.3:502 |

### 1.3 CC-Link通信詳細

B01とB02が独立したCC-Linkマスターとして動作し、M8001=ONのオフライン時は通信異常監視（M370~M372）がバイパスされます。

---

## 2. ソフトウェアモジュール関連図 (REFACT3)

```mermaid
classDiagram
    direction TB

    class LuaScript {
        +TTask.lua: タスク管理
        +TConEquipmentTest.lua: PLC通信
    }

    class B01_PLCMemory {
        +M8001: オフラインモード切替
        +D331-D338: B01 RFIDデータ
        +D3287-D3292: B01タスク/AGV行先
        +M1000-M1079: B01 CC-Link入力
    }

    class ST_Logic {
        <<PLC Internal>>
        +DetermineTaskType(D339, D340) -> D330
    }

    class CCLink_Layer {
        <<Physical / Simulation>>
        +M8001=ON: 受信データを強制ON (バイパス)
        +M8001=OFF: 物理通信データを反映
    }

    LuaScript ..> B01_PLCMemory : Modbus/TCP
    B01_PLCMemory --> ST_Logic : D339/D340入力
    ST_Logic --> B01_PLCMemory : D330書き込み
    CCLink_Layer --> B01_PLCMemory : CC-Link Rx (フィルタリング)
```

---

## 3. 詳細ワークフロー (シミュレーション対応シーケンス)

```mermaid
sequenceDiagram
    autonumber

    participant WMS
    participant Task as TTask.lua
    participant Conn as TConEquipmentTest.lua
    participant PLC as PLCメモリ (B01/B02)
    participant HW as CC-Link / 物理配線

    Note over PLC, HW: 【実装モード: M8001=OFF】
    HW->>PLC: 実際のセンサ入力 (X, B)
    WMS->>Task: タスク発行
    Task->>Conn: 解析
    Conn->>PLC: 搬送指示 (D339/D340)
    PLC->>PLC: タスク処理・STロジック判定
    PLC->>HW: コマンド出力 (Y, B)

    Note over PLC, HW: 【オフラインモード: M8001=ON】
    HW--xPLC: (物理入力無視 / 通信異常無視)
    PLC->>PLC: センサ・セーフティ・通信異常 強制正常化
    WMS->>Task: タスク発行 (実機レスでテスト)
    Task->>Conn: 解析
    Conn->>PLC: 搬送指示
    PLC->>PLC: ロジック動作完結 (実機を動かさず内部遷移)
    PLC--xHW: (実際には動かないがシーケンス進行)
```

## 4. プログラムファイル構成 (REFACT3)

| ファイル名 | PLC | 主な機能（REFACT3の特長） |
|-----------|-----|-------------------------|
| `B01_GroundPanel_Q_Switch_GXW.asc` | PLC-1 | M8001によるI/Oバイパス、搬入・搬出ハンドシェイク実装済 |
| `B02_GroundPanel_Q_Switch_GXW.asc` | PLC-2 | M8001によるI/Oバイパス、搬入・搬出ハンドシェイク実装済 |
| `Conveyor_Refactored_Q_Switch_GXW.asc` | PLC-3 | M8001によるコンベヤモータ動作シミュレーション、センサ無視 |
| `StackerCrane_Refactored_Q_Switch_GXW.asc` | PLC-4 | 軸移動時間の内部タイマー代替（M8001=ON時）、位置決め完了擬似生成 |
| `Masked_ST_Logic.st` | PLC-1/2 | Lua側でマスクされたタスク生成ロジックのPLC側実装 |

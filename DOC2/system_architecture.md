# システムアーキテクチャ・ソフトウェア構成（REFACT2版）

## 1. ハードウェア & ネットワーク構成

REFACT2では、地上盤PLCをB01/B02の2台に分割した **4PLC構成** を採用しています。

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

    subgraph PLC_Layer ["PLC制御層（4PLC構成）"]
        style PLC_Layer fill:#eef,stroke:#333

        B01_PLC["B01地上盤 PLC<br/>B01_GroundPanel_Q_GXW.asc<br/>ステーション1001制御"]
        B02_PLC["B02地上盤 PLC<br/>B02_GroundPanel_Q_GXW.asc<br/>ステーション1002制御"]
        SRM_PLC["スタッカー PLC<br/>StackerCrane_Refactored_Q_GXW.asc"]
        CV_PLC["コンベア PLC<br/>Conveyor_Refactored_Q_GXW.asc"]
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
    B01_PLC ---|"Wireless"| AGV
    B02_PLC ---|"Wireless"| AGV
    SRM_PLC --- SRM_HW
    CV_PLC --- CV_HW
    CV_PLC --- B01_HW
    CV_PLC --- B02_HW
```

### 1.1 REFACT vs REFACT2 構成比較

| 項目 | REFACT（3PLC） | REFACT2（4PLC） |
|------|--------------|----------------|
| 地上盤 | GroundPanel（B01+B02統合） | B01_GroundPanel + B02_GroundPanel（分割） |
| コンベア | Conveyor_Refactored | Conveyor_Refactored（変更なし） |
| スタッカー | StackerCrane_Refactored | StackerCrane_Refactored（変更なし） |
| 信頼性 | 地上盤故障で全停止 | B01/B02独立運転可能 |
| 処理能力 | 1PLCで両ステーション処理 | 並列処理でスループット向上 |

### 1.2 Modbus/TCP通信詳細

PCのLuaアプリケーションとPLC間の通信はModbus/TCPプロトコルで行われます。

| 項目 | 設定値 |
|------|--------|
| プロトコル | Modbus/TCP |
| 実装ファイル | `TConEquipmentTest.lua`, `TClientHelper` |
| ポート番号 | 502 (デフォルト) |
| 通信機能 | レジスタ読み書き、接続監視 |

**接続先一覧（REFACT2）:**

| PLC | IPアドレス（例） | ポート | 用途 |
|-----|----------------|--------|------|
| B01地上盤 PLC | 192.168.1.1 | 502 | B01タスク指示、ステータス監視 |
| B02地上盤 PLC | 192.168.1.4 | 502 | B02タスク指示、ステータス監視 |
| スタッカー PLC | 192.168.1.2 | 502 | 走行/昇降/フォーク制御 |
| コンベア PLC | 192.168.1.3 | 502 | 搬入/搬出制御 |

### 1.3 CC-Link通信詳細

B01地上盤PLCとB02地上盤PLCがそれぞれ独立したCC-Linkマスターとして動作します。

| 項目 | B01地上盤 | B02地上盤 |
|------|----------|----------|
| 役割 | CC-Linkマスター | CC-Linkマスター |
| 受信バッファ | B00〜B4F（M1000〜M1079） | B100〜B101（M1200〜M1201） |
| 送信バッファ | B1000〜B1023 | B1100〜B1123 |
| RFIDデータ | W0/W10 → D331/D338（RFID1/2） | W80/W90 → D352/D359（RFID3/4） |
| STK通信 | U2\G4096（受信）/ U2\G12288（送信） | U2\G4096（受信）/ U2\G12288（送信） |

---

## 2. ソフトウェアモジュール関連図

```mermaid
classDiagram
    direction TB

    class LuaScript {
        +TTask.lua: タスク管理
        +TConEquipmentTest.lua: PLC通信
        +TRedis.lua: Redis操作
        +TClientHelper: Modbusクライアント
        +B01/B02 個別接続
    }

    class B01_PLCMemory {
        +D331-D338: B01 RFIDデータ
        +D3287-D3292: B01タスク/AGV行先
        +M1000-M1079: B01 CC-Link入力
        +D4001: B01 ForkSTタスクID
        +D4004: CV1 出庫STタスクID
    }

    class B02_PLCMemory {
        +D352-D359: B02 RFIDデータ
        +D3293-D3298: B02タスク/AGV行先
        +M1200-M1201: B02 CC-Link入力
        +D4049: B02 ForkSTタスクID
        +D4052: CV2 出庫STタスクID
    }

    class ST_Logic {
        <<New Function>>
        +DetermineTaskType(Src, Dest)
        Logic Rules: IF Src>0 AND Dest=0 THEN Type=100
    }

    class CCLink_B01 {
        <<Communication Layer>>
        +B00-B4F: B01設備状態ビット
        +W0, W10: RFID1/2データ
        +B1000-B1023: B01制御送信
        +M370: B01_ON正常
    }

    class CCLink_B02 {
        <<Communication Layer>>
        +B100-B101: B02設備状態ビット
        +W80, W90: RFID3/4データ
        +B1100-B1123: B02制御送信
        +M371: B02_ON正常
    }

    LuaScript ..> B01_PLCMemory : Modbus/TCP (B01専用)
    LuaScript ..> B02_PLCMemory : Modbus/TCP (B02専用)
    B01_PLCMemory --> ST_Logic : D339/D340入力
    ST_Logic --> B01_PLCMemory : D330書き込み
    B01_PLCMemory --> CCLink_B01 : CC-Link Tx
    CCLink_B01 --> B01_PLCMemory : CC-Link Rx
    B02_PLCMemory --> CCLink_B02 : CC-Link Tx
    CCLink_B02 --> B02_PLCMemory : CC-Link Rx
```

---

## 3. 詳細ワークフロー (シーケンス)

```mermaid
sequenceDiagram
    autonumber

    participant WMS
    participant Redis
    participant Task as TTask.lua
    participant Conn as TConEquipmentTest.lua
    participant B01Mem as B01 PLCメモリ
    participant B02Mem as B02 PLCメモリ
    participant ST as ST判定部
    participant B01Lad as B01 ラダー制御
    participant B02Lad as B02 ラダー制御
    participant CCLink as CC-Link通信部

    Note over WMS, B02Lad: タスク発行フェーズ
    WMS->>Redis: タスク登録 (LPUSH taskInfo)
    Task->>Redis: タスク検知 (RPOP)
    Task->>Task: データ解析 (analysisTask)
    Task->>Conn: B01/B02 PLC通信要求（ステーション判定）

    alt B01ステーション(1001)向け
        Conn->>B01Mem: 搬送指示書き込み (D339/D340)
        B01Mem->>ST: データ入力
        ST->>B01Mem: タスク種別確定 (D330)
        B01Mem->>B01Lad: 制御フラグON
        B01Lad->>CCLink: CC-Link送信 (B1000〜)
    else B02ステーション(1002)向け
        Conn->>B02Mem: 搬送指示書き込み (D339/D340)
        B02Mem->>ST: データ入力
        ST->>B02Mem: タスク種別確定 (D330)
        B02Mem->>B02Lad: 制御フラグON
        B02Lad->>CCLink: CC-Link送信 (B1100〜)
    end

    CCLink->>B01Lad: CC-Link受信 (B00〜B4F)
    CCLink->>B02Lad: CC-Link受信 (B100〜B101)

    Note over Conn, WMS: 完了報告フェーズ
    Conn->>B01Mem: 定期ポーリング (完了検知)
    Conn->>B02Mem: 定期ポーリング (完了検知)
    Conn->>Task: 完了通知
    Task->>Redis: 完了報告書き込み
    Redis->>WMS: 完了データ連携
```

---

## 4. プログラムファイル構成

### 4.1 PLCプログラムファイル（REFACT2）

| ファイル名 | PLC | 役割 | 主な機能 |
|-----------|-----|------|---------|
| `B01_GroundPanel_Q_GXW.asc` | PLC-1 | B01地上盤 | CC-Link B00〜B4F受信、RFID1/2、B01タスク管理、B1000〜送信 |
| `B02_GroundPanel_Q_GXW.asc` | PLC-2 | B02地上盤 | CC-Link B100〜B101受信、RFID3/4、B02タスク管理、B1100〜送信 |
| `Conveyor_Refactored_Q_GXW.asc` | PLC-3 | コンベア | CC-Link通信、RFID処理、AGV連携 |
| `StackerCrane_Refactored_Q_GXW.asc` | PLC-4 | スタッカークレーン | 軸制御、自動運転、安全監視 |
| `Masked_ST_Logic.st` | PLC-1/2共通 | STロジック（タスク判定） | D339/D340からD330を判定 |

### 4.2 Luaプログラムファイル

| ファイル名 | 役割 | 主な機能 |
|-----------|------|---------| 
| `TTask.lua` | タスク管理メタクラス | WMSからのタスク受信、解析、Redis連携、B01/B02振り分け |
| `TConEquipmentTest.lua` | PLC通信クラス | Modbus/TCP通信、B01/B02個別接続管理 |
| `TRedis.lua` | Redis操作クラス | hmget/hmset、lpush/rpop、接続プール管理 |

---

## 5. CC-Link通信仕様（REFACT2）

### 5.1 B01地上盤 CC-Link信号マッピング

| 方向 | バッファ | 内容 |
|------|---------|------|
| Rx（コンベア→B01） | B00〜B4F | B01設備状態ビット（電源、運転準備、RFID、CV1/CV2状態） |
| Rx（コンベア→B01） | W0/W10 | RFID1/2データ（各7ワード） |
| Tx（B01→コンベア） | B1000〜B1023 | B01制御データ（運転許可、モード、タスク） |
| STK通信 | U2\G4096/12288 | スタッカーとのデータ送受信 |

### 5.2 B02地上盤 CC-Link信号マッピング

| 方向 | バッファ | 内容 |
|------|---------|------|
| Rx（コンベア→B02） | B100〜B101 | B02設備状態ビット（電源、運転準備） |
| Rx（コンベア→B02） | W80/W90 | RFID3/4データ（各7ワード） |
| Tx（B02→コンベア） | B1100〜B1123 | B02制御データ（運転許可、モード、タスク） |
| STK通信 | U2\G4096/12288 | スタッカーとのデータ送受信 |

### 5.3 通信監視デバイス

| デバイス | 内容 | B01ファイル | B02ファイル |
|---------|------|------------|------------|
| M370 | B01_ON正常（SB49 AND W900.0） | ✅ 使用 | — |
| M371 | B02_ON正常（SB49 AND W900.1） | — | ✅ 使用 |
| M372 | AGV_ON正常（SB49 AND W900.2） | ✅ 使用 | ✅ 使用 |

# PLCプログラム 制御フロー図

各PLCプログラム（地上盤、スタッカークレーン、コンベア）の制御ロジックを可視化したフロー図です。

## 1. 地上盤PLC (Ground Panel)
ファイル: `GroundPanel_Refactored_Q_GXW.asc`

### 1-1. メイン処理フロー
プログラムの全体構成と実行順序です。

```mermaid
flowchart TD
    Start([スキャン開始]) --> Block00[00: 入力処理]
    Block00 --> Block01[01: CC-Link受信]
    Block01 --> Block02[02: STK通信受信]
    Block02 --> Block09[09: 異常監視・安全]
    Block09 --> Block10[10: モード管理]
    
    subgraph ModeCtrl ["モード別処理"]
        direction TB
        Block10 --> CheckMode{モード判定}
        CheckMode -- 連動PC有 --> Block11[11: 連動PC有処理]
        CheckMode -- 単独/PC無 --> Block12[12: 単独/PC無処理]
        CheckMode -- 手動 --> Block13[13: 手動操作処理]
    end
    
    Block11 --> Block14[14: タスク管理]
    Block12 --> Block14
    Block13 --> End([End])
    Block14 --> End
```

### 1-2. タスク管理フロー (連動モード)
WMS/PCからの指示を受け、STKへタスクを発行するフローです。

```mermaid
sequenceDiagram
    participant PC as PC (LUA)
    participant GP as 地上盤PLC
    participant STK as スタッカーPLC

    Note over GP: BLOCK_10: モード管理
    PC->>GP: D400=TaskType, D401=TaskID (Modbus)
    GP->>GP: D400を判定 (M3831-M3834)

    Note over GP: BLOCK_11: 待機チェック
    STK->>GP: D100=STK状態 (1=待機)
    GP->>GP: M3800=ON (STK待機)

    Note over GP: BLOCK_14: 指令生成
    alt STK待機中 AND 指令あり
        GP->>STK: D200=TaskType, D201=TaskID
        GP->>STK: D203-D208=棚座標
        GP->>STK: D209/D210=ST番号
    end

    Note over STK: タスク実行...
    
    STK->>GP: D104=実行中TaskID
    GP->>GP: 発行ID(D201) == 実行ID(D104)?
    
    alt 一致確認
        GP->>PC: タスクステータス更新 (完了待ち)
    end
```

## 2. 地上盤PLC (Ground Panel) - CC-Link通信詳細
ファイル: `GroundPanel_Refactored_Q_GXW.asc`

### 2-1. CC-Link受信処理フロー（プログラム01）

コンベアPLCからのステータス受信処理の詳細フローです。

```mermaid
flowchart LR
    Start([スキャン開始]) --> RxCk[CC-Link受信タイミング]
    RxCk --> B00Check[B00: 電源入]
    RxCk --> B01Check[B01: 運転準備入]
    RxCk --> B02Check[B02: 重故障]
    RxCk --> B03Check[B03: 軽故障]
    RxCk --> B04Check[B04: 非常停止正常]

    B00Check --> M1000[M1000: CCLink_In_B01電源入]
    B01Check --> M1001[M1001: CCLink_In_B01運転準備入]
    B02Check --> M1002[M1002: CCLink_In_B01重故障]
    B03Check --> M1003[M1003: CCLink_In_B01軽故障]
    B04Check --> M1004[M1004: CCLink_In_B01非常停止正常]

    RxCk --> RFID1Check[B20: RFID1読取完了]
    RFID1Check --> RFID1Data[W0-W13 → D331-D337<br/>RFIDデータ転送]

    RxCk --> RFID2Check[B22: RFID2読取完了]
    RFID2Check --> RFID2Data[W10-W23 → D338-D344<br/>RFIDデータ転送]
```

### 2-2. CC-Link送信処理フロー（プログラム41）

コンベアPLCへの制御データ送信処理の詳細フローです。

```mermaid
flowchart LR
    Start([スキャン開始]) --> TxCk[CC-Link送信タイミング]

    subgraph Control_Data ["制御データ生成"]
        M100[M100: 電源入] --> B1000[B1000: 電源入]
        M10[M10: 運転準備入] --> B1001[B1001: 運転準備入]
        M40[M40: 非常停止正常] --> B1004[B1004: 非常停止正常]
        M31[M31: 自動運転中] --> B100A[B100A: 自動運転中]
        M15[M15: サイクル停止中] --> B100B[B100B: サイクル停止中]
        M30[M30: 手動操作中] --> B100C[B100C: 手動操作中]
    end

    TxCk --> Control_Data
    Control_Data --> End([送信完了])
```

### 2-3. CC-Link通信監視フロー（プログラム09）

CC-Link通信状態の監視処理フローです。

```mermaid
flowchart TD
    Start([常時監視]) --> CheckSB[SB49: ユニットステータス]
    CheckSB --> LinkStatus{リモートI/Oステータス}

    LinkStatus -->|W900.0=ON| Check1[スレーブ1正常]
    LinkStatus -->|W900.1=ON| Check2[スレーブ2正常]
    LinkStatus -->|W900.2=ON| Check3[スレーブ3正常]

    Check1 --> M370[M370: B01_ON正常]
    Check2 --> M371[M371: B02_ON正常]
    Check3 --> M372[M372: AGV_ON正常]

    M370 --> MonitorOK[通信正常]
    M371 --> MonitorOK
    M372 --> MonitorOK
```

## 3. スタッカークレーンPLC (Stacker Crane)
ファイル: `StackerCrane_Refactored_Q_GXW.asc`

### 3-1. 自動運転ステートマシン (BLOCK_07)
スタッカークレーンの自動運転ロジックの中心となるステートマシンです。

```mermaid
stateDiagram-v2
    [*] --> Standby: 初期化完了
    
    state Standby {
        [*] --> M50_Wait: 待機中 (M50)
        M50_Wait --> TaskCheck: D331(TaskID)受信
    }

    state TaskCheck {
        [*] --> DetermineType
        DetermineType --> Inbound: 搬入 (Type=100)
        DetermineType --> Outbound: 搬出 (Type=200)
        DetermineType --> Transfer: 移庫 (Type=300)
        DetermineType --> Homing: 原点 (Type=400)
    }

    state Inbound {
        [*] --> MovePickup_In: 受取位置(ST)へ移動
        MovePickup_In --> ForkOut_In: フォーク伸出 (M55)
        ForkOut_In --> LiftUp_In: フォーク持上げ (M56)
        LiftUp_In --> ForkIn_In: フォーク収縮 (M57)
        ForkIn_In --> MoveDrop_In: 受渡位置(棚)へ移動 (M59)
        MoveDrop_In --> ForkOut_Drop_In: フォーク伸出 (M60)
        ForkOut_Drop_In --> LiftDown_In: フォーク下降 (M61)
        LiftDown_In --> ForkIn_Drop_In: フォーク収縮 (M62)
    }

    state Outbound {
        [*] --> MovePickup_Out: 受取位置(棚)へ移動
        MovePickup_Out --> ForkOut_Out: フォーク伸出
        ForkOut_Out --> LiftUp_Out: フォーク持上げ
        LiftUp_Out --> ForkIn_Out: フォーク収縮
        ForkIn_Out --> MoveDrop_Out: 受渡位置(ST)へ移動
        MoveDrop_Out --> ForkOut_Drop_Out: フォーク伸出
        ForkOut_Drop_Out --> LiftDown_Out: フォーク下降
        LiftDown_Out --> ForkIn_Drop_Out: フォーク収縮
    }

    Inbound --> Complete: 完了 (M65)
    Outbound --> Complete
    Transfer --> Complete
    Homing --> Complete

    state Complete {
        [*] --> Report: 完了報告
        Report --> Standby: 完了確認後、待機へ
    }
```

### 2-2. 軸制御・安全インターロック (BLOCK_03, 04)
物理的な軸動作と安全チェックのフローです。

```mermaid
flowchart TD
    subgraph SafetyCheck ["安全インターロック (BLOCK_03)"]
        CheckInv[INV電源ON?]
        CheckFork[フォーク中位?]
        CheckLimit[ソフトリミット内?]
        CheckSensor[障害物センサOFF?]
        
        CheckInv & CheckFork & CheckLimit & CheckSensor --> SafeOK{安全OK?}
    end

    subgraph MotionCtrl ["位置決め制御 (BLOCK_04/05/06)"]
        SafeOK -- Yes --> CalcTarget[目標位置計算]
        CalcTarget --> ServoOn[サーボ起動]
        ServoOn --> Moving[移動中]
        
        Moving --> Compare{偏差チェック}
        Compare -- "偏差 < 規定値" --> Arrived["位置到達 (M416/M437/M458)"]
        
        SafeOK -- No --> Stop[非常停止/インターロック]
    end
```

## 4. コンベアPLC (Conveyor)
ファイル: `Conveyor_Refactored_Q_GXW.asc`

### 4-1. CC-Link通信処理フロー

コンベアPLCと地上盤PLC間のCC-Link通信処理の詳細フローです。

```mermaid
sequenceDiagram
    autonumber
    participant GP as 地上盤PLC<br/>(Master)
    participant CV as コンベアPLC<br/>(Slave)
    participant MEM as 内部メモリ
    participant RFID as RFIDリーダー

    Note over GP: スキャン開始

    GP->>CV: B1000-B1023送信<br/>(制御データ)
    CV->>MEM: Bレジスタ→Mリレー変換
    MEM->>MEM: M1000-M1059更新

    CV->>GP: B00-BFF送信<br/>(ステータスデータ)
    Note over CV: M1000→B00<br/>M1001→B01<br/>...

    Note over CV: ネットワーク19開始
    CV->>RFID: RFID読取要求
    RFID-->>CV: RFIDデータ(12文字)
    CV->>MEM: W0-W13にRFIDデータ格納
    Note over CV: ネットワーク19終了

    Note over GP: スキャン終了
```

### 4-2. CC-Link信号マッピング

**地上盤→コンベア（制御データ）:**

| バッファ | 内部リレー | 説明 |
|---------|-----------|------|
| B1000 | M1000 | 電源入 |
| B1001 | M1001 | 運転準備入 |
| B1004 | M1004 | 非常停止正常 |
| B100A | M1010 | 自動運転中 |
| B1010 | M1016 | 自動モード選択 |
| B101A | M1026 | 連動運転開始 |

**コンベア→地上盤（ステータスデータ）:**

| 内部リレー | バッファ | 説明 |
|-----------|---------|------|
| M1000 | B00 | 電源入 |
| M1001 | B01 | 運転準備入 |
| M1002 | B02 | 重故障 |
| M1004 | B04 | 非常停止正常 |
| M1048 | B30 | CV1_STK受取可 |
| M1049 | B31 | CV1_AGV発進可 |
| M1064 | B40 | CV2_STK受渡可 |
| M1065 | B41 | CV2_AGV発進可 |

### 4-3. 搬入ライン連携フロー (Input Line)
AGV到着から地上盤へのデータ連携までのフローです。

```mermaid
flowchart LR
    Start([開始]) --> Check{"搬入開始条件<br/>M21"}
    Check -- OK --> Wait[AGV到着待ち]
    Wait -- 到着 --> RFID["RFID読取<br/>(Net.19)"]

    RFID --> CCLinkTx["CC-Link送信<br/>B00-BFF"]
    CCLinkTx --> Handshake["AGV発進許可<br/>(Y132)"]
    Handshake --> Send["地上盤へ<br/>データ送信"]

    classDef process fill:#e1f5fe,stroke:#01579b,stroke-width:2px;
    classDef cclink fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    class Check,Wait,RFID,Handshake,Send process;
    class CCLinkTx cclink;
```

### 4-4. 搬出ライン連携フロー (Output Line)
出庫フォーク待ちから搬出完了までのフローです。

```mermaid
flowchart LR
    Start([開始]) --> Check{"搬出開始条件<br/>M22"}
    Check -- OK --> Wait[出庫フォーク待ち]
    Wait -- 到着 --> RFID["RFID読取<br/>(Net.20)"]

    RFID --> CCLinkTx["CC-Link送信<br/>B00-BFF"]
    CCLinkTx --> Handshake["AGV発進許可<br/>(Y13A)"]
    Handshake --> Send["地上盤へ<br/>データ送信"]

    classDef process fill:#fff3e0,stroke:#e65100,stroke-width:2px;
    classDef cclink fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    class Check,Wait,RFID,Handshake,Send process;
    class CCLinkTx cclink;
```

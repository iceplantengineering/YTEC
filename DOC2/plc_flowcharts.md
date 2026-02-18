# PLCプログラム 制御フロー図（REFACT2版）

各PLCプログラム（B01地上盤、B02地上盤、スタッカークレーン、コンベア）の制御ロジックを可視化したフロー図です。

> **REFACT2の特徴:** 地上盤PLCがB01とB02に分割されており、各PLCが独立したCC-Linkマスターとして動作します。

---

## 1. B01地上盤PLC (`B01_GroundPanel_Q_GXW.asc`)

### 1-1. メイン処理フロー

```mermaid
flowchart TD
    Start([スキャン開始]) --> Block00[00: 入力処理<br/>X60〜X85]
    Block00 --> Block01[01: CC-Link受信<br/>B00〜B4F → M1000〜M1079<br/>W0/W10 → D331/D338 RFID1/2]
    Block01 --> Block02[02: STK通信受信<br/>D100〜D115]
    Block02 --> Block09[09: 異常監視・安全<br/>M370/M372 CC-Link監視]
    Block09 --> Block10[10: モード管理]

    subgraph ModeCtrl ["モード別処理"]
        direction TB
        Block10 --> CheckMode{モード判定}
        CheckMode -- 連動PC有 --> Block11[11: 連動PC有処理<br/>D400/D401 WMS指示]
        CheckMode -- 単独/PC無 --> Block12[12: 単独/PC無処理<br/>D500 手動タスク]
        CheckMode -- 手動 --> Block13[13: 手動操作処理<br/>STKへ手動制御]
    end

    Block11 --> Block14[14: B01タスク管理<br/>D3287/D3291 B01タスク<br/>D4001 ForkSTタスクID<br/>D4004 CV1出庫STタスクID]
    Block12 --> Block14
    Block13 --> Block30[30: HMI処理]
    Block14 --> Block30
    Block30 --> Block40[40: 出力処理<br/>Y90〜Y9A 積層灯/ランプ]
    Block40 --> Block41[41: CC-Link送信<br/>B1000〜B1023]
    Block41 --> Block42[42: STK通信送信<br/>D211〜D225]
    Block42 --> Block43[43: WMS通信<br/>D300〜D369]
    Block43 --> End([END])
```

### 1-2. B01 CC-Link受信処理フロー（プログラム01）

```mermaid
flowchart LR
    Start([スキャン開始]) --> RxCk[CC-Link受信タイミング]
    RxCk --> B00Check[B00: 電源入]
    RxCk --> B01Check[B01: 運転準備入]
    RxCk --> B04Check[B04: 非常停止正常]
    RxCk --> B0ACheck[B0A: 自動運転中]

    B00Check --> M1000[M1000: CCLink_In_B01電源入]
    B01Check --> M1001[M1001: CCLink_In_B01運転準備入]
    B04Check --> M1004[M1004: CCLink_In_B01非常停止正常]
    B0ACheck --> M1010[M1010: CCLink_In_B01自動運転中]

    RxCk --> B30Check[B30: CV1_STK受取可]
    RxCk --> B40Check[B40: CV2_STK受渡可]
    B30Check --> M1048[M1048: CCLink_In_B01CV1_STK受取可]
    B40Check --> M1064[M1064: CCLink_In_B01CV2_STK受渡可]

    RxCk --> RFID1Check[B20: RFID1読取完了]
    RFID1Check --> RFID1Data["W0〜W6 → D331〜D337<br/>RFID1データ転送(7ワード)"]

    RxCk --> RFID2Check[B22: RFID2読取完了]
    RFID2Check --> RFID2Data["W10〜W16 → D338〜D344<br/>RFID2データ転送(7ワード)"]
```

### 1-3. B01 CC-Link送信処理フロー（プログラム41）

```mermaid
flowchart LR
    Start([スキャン開始]) --> TxCk[CC-Link送信タイミング]

    subgraph Control_Data ["B01制御データ生成"]
        M100[M100: 電源入] --> B1000[B1000: 電源入]
        M10[M10: 運転準備入] --> B1001[B1001: 運転準備入]
        M40[M40: 非常停止正常] --> B1004[B1004: 非常停止正常]
        M31[M31: 自動運転中] --> B100A[B100A: 自動運転中]
        M15[M15: サイクル停止中] --> B100B[B100B: サイクル停止中]
        M30[M30: 手動操作中] --> B100C[B100C: 手動操作中]
        M12[M12: 自動モード] --> B1010[B1010: 自動モード選択]
        M14[M14: 連動モード] --> B1012[B1012: 連動モード選択]
        STK_K2["STK搬入受取可 K2"] --> B1020[B1020: 搬入中]
        STK_K4["STK搬出受渡可 K4"] --> B1022[B1022: 移載中]
    end

    TxCk --> Control_Data
    Control_Data --> End([B01送信完了])
```

### 1-4. B01タスク管理フロー（プログラム14）

```mermaid
sequenceDiagram
    participant PC as PC (LUA)
    participant B01 as B01地上盤PLC
    participant STK as スタッカーPLC
    participant CV1 as コンベアPLC (CV1)

    Note over B01: BLOCK_10: モード管理
    PC->>B01: D400=TaskType, D401=TaskID (Modbus)
    B01->>B01: D400を判定 (M3831-M3834)

    Note over B01: BLOCK_11: STK待機チェック
    STK->>B01: D100=STK状態 (1=待機)
    B01->>B01: M3800=ON (STK待機)

    Note over B01: BLOCK_14: B01指令生成
    alt STK待機中 AND B01指令あり
        B01->>STK: D200=TaskType, D201=TaskID
        B01->>STK: D203-D208=棚座標
        B01->>STK: D209=搬入ST番号(CV1)
    end

    Note over STK: タスク実行...

    STK->>B01: D104=実行中TaskID
    B01->>B01: 発行ID(D201) == 実行ID(D104)?

    Note over B01: BLOCK_14: B01 AGV発進許可
    B01->>CV1: CC-Link B1020〜B1023 (搬入/搬出制御)
    CV1->>B01: CC-Link B30/B40 (STK受取可/受渡可)

    B01->>B01: D3287/D3291 B01タスク管理
    B01->>B01: D4001 ForkSTタスクID発行
    B01->>B01: D4004 CV1出庫STタスクID発行
    B01->>B01: M3816 B01搬出AGVレディ
```

---

## 2. B02地上盤PLC (`B02_GroundPanel_Q_GXW.asc`)

### 2-1. メイン処理フロー

```mermaid
flowchart TD
    Start([スキャン開始]) --> Block00[00: 入力処理<br/>X60〜X8D]
    Block00 --> Block01[01: CC-Link受信<br/>B100〜B101 → M1200〜M1201<br/>W80/W90 → D352/D359 RFID3/4]
    Block01 --> Block02[02: STK通信受信<br/>D100〜D115]
    Block02 --> Block09[09: 異常監視・安全<br/>M371/M372 CC-Link監視]
    Block09 --> Block10[10: モード管理]

    subgraph ModeCtrl ["モード別処理"]
        direction TB
        Block10 --> CheckMode{モード判定}
        CheckMode -- 連動PC有 --> Block11[11: 連動PC有処理<br/>D400/D401 WMS指示]
        CheckMode -- 単独/PC無 --> Block12[12: 単独/PC無処理<br/>D500 手動タスク]
        CheckMode -- 手動 --> Block13[13: 手動操作処理<br/>STKへ手動制御]
    end

    Block11 --> Block14[14: B02タスク管理<br/>D3293/D3297 B02タスク<br/>D4049 ForkSTタスクID<br/>D4052 CV2出庫STタスクID]
    Block12 --> Block14
    Block13 --> Block30[30: HMI処理]
    Block14 --> Block30
    Block30 --> Block40[40: 出力処理<br/>Y90〜Y9A 積層灯/ランプ]
    Block40 --> Block41[41: CC-Link送信<br/>B1100〜B1123]
    Block41 --> Block42[42: STK通信送信<br/>D211〜D225]
    Block42 --> Block43[43: WMS通信<br/>D300〜D369]
    Block43 --> End([END])
```

### 2-2. B02 CC-Link受信処理フロー（プログラム01）

```mermaid
flowchart LR
    Start([スキャン開始]) --> RxCk[CC-Link受信タイミング]
    RxCk --> B100Check[B100: 電源入]
    RxCk --> B101Check[B101: 運転準備入]

    B100Check --> M1200[M1200: CCLink_In_B02電源入]
    B101Check --> M1201[M1201: CCLink_In_B02運転準備入]

    RxCk --> RFID3Check[B02 RFID3読取完了]
    RFID3Check --> RFID3Data["W80〜W86 → D352〜D358<br/>RFID3データ転送(7ワード)"]

    RxCk --> RFID4Check[B02 RFID4読取完了]
    RFID4Check --> RFID4Data["W90〜W96 → D359〜D365<br/>RFID4データ転送(7ワード)"]

    Note1["※ B02はB100〜B101のみ受信<br/>（B01の B00〜B4Fより少ない）"]
```

### 2-3. B02 CC-Link送信処理フロー（プログラム41）

```mermaid
flowchart LR
    Start([スキャン開始]) --> TxCk[CC-Link送信タイミング]

    subgraph Control_Data ["B02制御データ生成"]
        M100[M100: 電源入] --> B1100[B1100: 電源入]
        M10[M10: 運転準備入] --> B1101[B1101: 運転準備入]
        M40[M40: 非常停止正常] --> B1104[B1104: 非常停止正常]
        M31[M31: 自動運転中] --> B110A[B110A: 自動運転中]
        M15[M15: サイクル停止中] --> B110B[B110B: サイクル停止中]
        M30[M30: 手動操作中] --> B110C[B110C: 手動操作中]
        M12[M12: 自動モード] --> B1110[B1110: 自動モード選択]
        M14[M14: 連動モード] --> B1112[B1112: 連動モード選択]
        STK_K6["STK搬入受取可 K6"] --> B1120[B1120: 搬入中]
        STK_K8["STK搬出受渡可 K8"] --> B1122[B1122: 移載中]
    end

    TxCk --> Control_Data
    Control_Data --> End([B02送信完了])
```

### 2-4. B02タスク管理フロー（プログラム14）

```mermaid
sequenceDiagram
    participant PC as PC (LUA)
    participant B02 as B02地上盤PLC
    participant STK as スタッカーPLC
    participant CV2 as コンベアPLC (CV2)

    Note over B02: BLOCK_10: モード管理
    PC->>B02: D400=TaskType, D401=TaskID (Modbus)
    B02->>B02: D400を判定 (M3831-M3834)

    Note over B02: BLOCK_11: STK待機チェック
    STK->>B02: D100=STK状態 (1=待機)
    B02->>B02: M3800=ON (STK待機)

    Note over B02: BLOCK_14: B02指令生成
    alt STK待機中 AND B02指令あり
        B02->>STK: D200=TaskType, D201=TaskID
        B02->>STK: D203-D208=棚座標
        B02->>STK: D210=搬出ST番号(CV2)
    end

    Note over STK: タスク実行...

    STK->>B02: D104=実行中TaskID
    B02->>B02: 発行ID(D201) == 実行ID(D104)?

    Note over B02: BLOCK_14: B02 AGV発進許可
    B02->>CV2: CC-Link B1120〜B1123 (搬入/搬出制御)
    CV2->>B02: CC-Link B100/B101 (設備状態)

    B02->>B02: D3293/D3297 B02タスク管理
    B02->>B02: D4049 ForkSTタスクID発行
    B02->>B02: D4052 CV2出庫STタスクID発行
    B02->>B02: M3817 CV2出庫AGVレディ
```

---

## 3. B01/B02共通 CC-Link通信監視フロー（プログラム09）

```mermaid
flowchart TD
    Start([常時監視]) --> CheckSB[SB49: ユニットステータス]
    CheckSB --> LinkStatus{リモートI/Oステータス}

    LinkStatus -->|"W900.0=ON (B01)"| Check1[スレーブ1正常]
    LinkStatus -->|"W900.1=ON (B02)"| Check2[スレーブ2正常]
    LinkStatus -->|"W900.2=ON (AGV)"| Check3[スレーブ3正常]

    Check1 --> M370["M370: B01_ON正常<br/>（B01地上盤PLCのみ）"]
    Check2 --> M371["M371: B02_ON正常<br/>（B02地上盤PLCのみ）"]
    Check3 --> M372["M372: AGV_ON正常<br/>（B01/B02両方）"]

    M370 --> MonitorOK[通信正常]
    M371 --> MonitorOK
    M372 --> MonitorOK

    Check1 -->|OFF| Alarm1["CC-Link異常アラーム<br/>D456=Alarm_Code"]
    Check2 -->|OFF| Alarm2["CC-Link異常アラーム<br/>D456=Alarm_Code"]
```

---

## 4. スタッカークレーンPLC (`StackerCrane_Refactored_Q_GXW.asc`)

> ※ REFACT2ではStackerCraneは変更なし。B01/B02両方の地上盤PLCからタスクを受信します。

### 4-1. 自動運転ステートマシン (BLOCK_07)

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
        MovePickup_In --> ForkOut_In: フォーク伸出
        ForkOut_In --> LiftUp_In: フォーク持上げ
        LiftUp_In --> ForkIn_In: フォーク収縮
        ForkIn_In --> MoveDrop_In: 受渡位置(棚)へ移動
        MoveDrop_In --> ForkOut_Drop_In: フォーク伸出
        ForkOut_Drop_In --> LiftDown_In: フォーク下降
        LiftDown_In --> ForkIn_Drop_In: フォーク収縮
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

---

## 5. コンベアPLC (`Conveyor_Refactored_Q_GXW.asc`)

> ※ REFACT2ではConveyorは変更なし。B01地上盤とB02地上盤の両方からCC-Link制御を受けます。

### 5-1. CC-Link通信処理フロー（REFACT2対応）

```mermaid
sequenceDiagram
    autonumber
    participant B01 as B01地上盤PLC<br/>(Master)
    participant B02 as B02地上盤PLC<br/>(Master)
    participant CV as コンベアPLC<br/>(Slave)
    participant MEM as 内部メモリ
    participant RFID as RFIDリーダー

    Note over B01: スキャン開始

    B01->>CV: B1000-B1023送信<br/>(B01制御データ)
    CV->>MEM: Bレジスタ→Mリレー変換
    MEM->>MEM: M1000-M1079更新

    CV->>B01: B00-B4F送信<br/>(B01ステータスデータ)

    Note over B02: スキャン開始

    B02->>CV: B1100-B1123送信<br/>(B02制御データ)
    CV->>MEM: Bレジスタ→Mリレー変換
    MEM->>MEM: M1200-M1201更新

    CV->>B02: B100-B101送信<br/>(B02ステータスデータ)

    Note over CV: RFID処理
    CV->>RFID: RFID読取要求
    RFID-->>CV: RFIDデータ(12文字)
    CV->>MEM: W0-W6にRFID1データ格納 → B01へ
    CV->>MEM: W10-W16にRFID2データ格納 → B01へ
    CV->>MEM: W80-W86にRFID3データ格納 → B02へ
    CV->>MEM: W90-W96にRFID4データ格納 → B02へ
```

### 5-2. CC-Link信号マッピング（REFACT2）

**B01地上盤→コンベア（B01制御データ）:**

| バッファ | 内部リレー | 説明 |
|---------|-----------|------|
| B1000 | M1000 | B01電源入 |
| B1001 | M1001 | B01運転準備入 |
| B1004 | M1004 | B01非常停止正常 |
| B100A | M1010 | B01自動運転中 |
| B1010 | M1016 | B01自動モード選択 |
| B101A | M1026 | B01連動運転開始 |
| B1020 | M1032 | B01搬入中（STK搬入受取可 K2） |
| B1022 | M1034 | B01移載中（STK搬入受渡可 K4） |

**B02地上盤→コンベア（B02制御データ）:**

| バッファ | 内部リレー | 説明 |
|---------|-----------|------|
| B1100 | M1200 | B02電源入 |
| B1101 | M1201 | B02運転準備入 |
| B1104 | M1204 | B02非常停止正常 |
| B110A | M1210 | B02自動運転中 |
| B1110 | M1216 | B02自動モード選択 |
| B111A | M1226 | B02連動運転開始 |
| B1120 | M1232 | B02搬入中（STK搬入受取可 K6） |
| B1122 | M1234 | B02移載中（STK搬入受渡可 K8） |

**コンベア→B01地上盤（B01ステータスデータ）:**

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

**コンベア→B02地上盤（B02ステータスデータ）:**

| 内部リレー | バッファ | 説明 |
|-----------|---------|------|
| M1200 | B100 | B02電源入 |
| M1201 | B101 | B02運転準備入 |

---

## 6. REFACT2 全体通信フロー

```mermaid
graph TB
    subgraph PC ["制御PC"]
        WMS["WMS/Redis"]
        Lua["TTask.lua<br/>TConEquipmentTest.lua"]
    end

    subgraph B01_PLC ["B01地上盤PLC"]
        B01_Lad["ラダー制御<br/>B00〜B4F受信<br/>B1000〜B1023送信"]
        B01_ST["STロジック<br/>D330判定"]
        B01_Task["タスク管理<br/>D3287/D4001/D4004"]
    end

    subgraph B02_PLC ["B02地上盤PLC"]
        B02_Lad["ラダー制御<br/>B100〜B101受信<br/>B1100〜B1123送信"]
        B02_ST["STロジック<br/>D330判定"]
        B02_Task["タスク管理<br/>D3293/D4049/D4052"]
    end

    subgraph CV_PLC ["コンベアPLC"]
        CV_B01["B01側処理<br/>RFID1/2(W0/W10)"]
        CV_B02["B02側処理<br/>RFID3/4(W80/W90)"]
    end

    subgraph STK_PLC ["スタッカーPLC"]
        STK["軸制御<br/>自動運転"]
    end

    WMS -->|"Modbus/TCP"| B01_Lad
    WMS -->|"Modbus/TCP"| B02_Lad
    Lua -->|"Modbus/TCP"| B01_Lad
    Lua -->|"Modbus/TCP"| B02_Lad

    B01_Lad <-->|"CC-Link<br/>B00〜B4F/B1000〜B1023"| CV_B01
    B02_Lad <-->|"CC-Link<br/>B100〜B101/B1100〜B1123"| CV_B02

    B01_Lad <-->|"CC-Link<br/>U2\G"| STK
    B02_Lad <-->|"CC-Link<br/>U2\G"| STK

    B01_ST --> B01_Task
    B02_ST --> B02_Task
```

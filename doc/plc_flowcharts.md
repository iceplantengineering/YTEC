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

## 2. スタッカークレーンPLC (Stacker Crane)
ファイル: `StackerCrane_Refactored_Q_GXW.asc`

### 2-1. 自動運転ステートマシン (BLOCK_07)
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

## 3. コンベアPLC (Conveyor)
ファイル: `Conveyor_Refactored_Q_GXW.asc`

### 3-1. 搬入・搬出連携フロー
AGVおよび地上盤との連携ロジックです。

```mermaid
flowchart TD
    subgraph InputLine ["搬入ライン制御"]
        StartIn([開始]) --> CheckCondIn{搬入開始条件}
        CheckCondIn -- "準備OK(M21)" --> WaitAGV_In["AGV到着待ち"]
        WaitAGV_In --> RFID_In["RFID読取 (Net.19)"]
        RFID_In --> Handshake_In["AGV発進許可 (Y132)"]
        Handshake_In --> SendGP_In[地上盤へデータ送信]
    end

    subgraph OutputLine ["搬出ライン制御"]
        StartOut([開始]) --> CheckCondOut{搬出開始条件}
        CheckCondOut -- "準備OK(M22)" --> WaitFork_Out["出庫フォーク待ち"]
        WaitFork_Out --> RFID_Out["RFID読取 (Net.20)"]
        RFID_Out --> Handshake_Out["AGV発進許可 (Y13A)"]
        Handshake_Out --> SendGP_Out[地上盤へデータ送信]
    end
```

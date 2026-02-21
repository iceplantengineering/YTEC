# PLCプログラム 制御フロー図（REFACT3版）

各PLCプログラム（B01地上盤、B02地上盤、スタッカークレーン、コンベア）の制御ロジックを可視化したフロー図です。

> **REFACT3の特徴:** 
> - REFACT2の4PLC構成をベースとし、全PLCにM8001（シミュレーション/実装モード切替）機能が追加されています。
> - B01/B02地上盤PLCに、コンベアとの搬入・搬出ハンドシェイク機能（Store_1/Outbound_1相当）が完全実装されました。

---

## 1. B01地上盤PLC (`B01_GroundPanel_Q_Switch_GXW.asc`)

### 1-1. メイン処理フロー

```mermaid
flowchart TD
    Start([スキャン開始]) --> Block00[00: 入力処理<br/>X60〜X85]
    Block00 --> CheckM8001_1{M8001=ON?}
    CheckM8001_1 -- Yes (Offline) --> BypassInput[物理入力無視・強制ON化]
    CheckM8001_1 -- No (Real) --> RealInput[実入力反映]
    BypassInput --> Block01
    RealInput --> Block01
    
    Block01[01: CC-Link受信<br/>B00〜B4F → M1000〜M1079<br/>W0/W10 → D331/D338 RFID1/2]
    Block01 --> Block02[02: STK通信受信<br/>D100〜D115]
    Block02 --> Block09[09: 異常監視・安全]
    
    Block09 --> CheckM8001_2{M8001=ON?}
    CheckM8001_2 -- Yes --> BypassAlarm[CC-Link通信異常等強制クリア]
    CheckM8001_2 -- No --> RealAlarm[M370/M372 異常スロー]
    BypassAlarm --> Block10
    RealAlarm --> Block10
    
    Block10[10: モード管理]

    subgraph ModeCtrl ["モード別処理"]
        direction TB
        Block10 --> CheckMode{モード判定}
        CheckMode -- 連動PC有 --> Block11[11: 連動PC有処理<br/>D400/D401 WMS指示]
        CheckMode -- 単独/PC無 --> Block12[12: 単独/PC無処理<br/>D500 手動タスク]
        CheckMode -- 手動 --> Block13[13: 手動操作処理<br/>STKへ手動制御]
    end

    Block11 --> Block14[14: B01タスク管理<br/>D3287/D3291 B01タスク<br/>CV1ハンドシェイク制御]
    Block12 --> Block14
    Block13 --> Block30[30: HMI処理]
    Block14 --> Block30
    Block30 --> Block40[40: 出力処理<br/>Y90〜Y9A 積層灯/ランプ]
    Block40 --> Block41[41: CC-Link送信<br/>B1000〜B1023]
    Block41 --> Block42[42: STK通信送信<br/>D211〜D225<br/>D213: 搬入受取可, D214: 搬出受渡可]
    Block42 --> Block43[43: WMS通信<br/>D300〜D369]
    Block43 --> End([END])
```

### 1-2. M8001（シミュレーション）における信号バイパス詳細

```mermaid
flowchart LR
    subgraph B01_Input_Simulation
    direction TB
    M8001_ON(M8001 ON) -->|OR| X60[DI_電源入]
    M8001_ON -->|OR| X7A_X7B[運転準備入 二重化]
    M8001_ON -->|OR| X80_X81[安全機器_非常停止]
    M8001_ON -->|OR| B00[CCLink_電源入]
    M8001_ON -->|OR| B04[CCLink_非常停止]
    M8001_ON -->|OR| B0A[CCLink_自動運転中]
    M8001_ON -->|OR| B12[CCLink_連動モード]
    
    M8001_ON -->|ANI| X6C[盤クーラ異常無視]
    M8001_ON -->|ANI| X6D[Ethernet異常無視]
    M8001_ON -->|ANI| B02[CCLink_重故障無視]
    end
```

### 1-3. 新規実装: 搬入・搬出ハンドシェイク (Block 42)

```mermaid
sequenceDiagram
    participant B01 as B01地上盤
    participant CV1 as コンベアCV1
    participant STK as スタッカー
    
    Note over B01,STK: 搬入シーケンス (store_1相当)
    CV1->>B01: 入庫口リフタ上限 (B3f -> M1063)
    CV1->>B01: 入庫口在席検出 (B39 -> M1057)
    B01->>B01: 両方成立
    B01->>STK: D213 = 1 (搬入受取可)
    STK->>B01: 搬入完了通知
    B01->>STK: D213 = 0
    
    Note over B01,STK: 搬出シーケンス (outbound_1相当)
    CV1->>B01: 出庫口リフタ上限 (B4f -> M1079)
    CV1->>B01: 出庫口在席なし (NOT B49 -> NOT M1073)
    B01->>B01: 両方成立
    B01->>STK: D214 = 1 (搬出受渡可)
    STK->>B01: 搬出完了通知
    B01->>STK: D214 = 0
```

---

## 2. B02地上盤PLC (`B02_GroundPanel_Q_Switch_GXW.asc`)

B02側の処理フローは基本的にB01と同様ですが、監視対象のCC-Linkデバイス範囲が限られています (B100~B101)。
また、搬入・搬出ハンドシェイクロジックは B02 独自のアドレスを使用します。

```mermaid
sequenceDiagram
    participant B02 as B02地上盤
    participant CV3 as コンベアCV3/CV4
    participant STK as スタッカー
    
    Note over B02,STK: 搬入・搬出ハンドシェイク (B02)
    CV3->>B02: 入庫口(B1200) および在席(B1204)
    B02->>STK: D213 = 1 (搬入受取可)

    CV3->>B02: 出庫口(B1201) および在席なし(NOT B1205)
    B02->>STK: D214 = 1 (搬出受渡可)
```

---

## 3. コンベアPLC (`Conveyor_Refactored_Q_Switch_GXW.asc`)

```mermaid
flowchart TD
    Start([スキャン開始]) --> BlockA[実入力 / シミュレーション分岐]
    BlockA --> BlockB{M8001=ON?}
    
    BlockB -- 実装モード --> BlockReal[物理センサ入力受付]
    BlockB -- シミュレーション --> BlockSim[内部タイマーによる<br/>搬送シミュレーション]
    
    BlockReal --> BlockCtrl
    BlockSim --> BlockCtrl[CC-Link制御データに基づくモータ制御]
    
    BlockCtrl --> RFID[RFIDデータ読み取り (実機 or ダミー)]
    RFID --> Send[B01(B00~B4F) / B02(B100~B101) へ送信]
    Send --> End([END])
```

---

## 4. スタッカークレーンPLC (`StackerCrane_Refactored_Q_Switch_GXW.asc`)

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
    }

    state Inbound {
        [*] --> Init_In
        Init_In --> Move_In: 実移動 or<br/> M8001=ON時 タイマー待機
        Move_In --> WaitHandshake: 搬入先の ハンドシェイク<br/>(D213=1など) 待機
        WaitHandshake --> Finish_In: 完了処理
    }
```
*(シミュレーション時は、X軸・Y軸・Z軸（フォーク）の物理インバータ起動をスキップし、タイムアウトや位置決め完了フラグを内部的に強制ONして遷移させます)*

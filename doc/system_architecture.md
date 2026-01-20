# システムアーキテクチャ・ソフトウェア構成

## 1. ハードウェア & ネットワーク構成
物理的な機器の接続構成です。PCを中心に、Modbus/TCPとCC-Linkの2つのネットワークで構成されています。

```mermaid
graph TB
    subgraph Host ["上位層"]
        WMS["<i class='fa fa-server'></i> WMS Server<br/>(倉庫管理システム)"]
    end

    subgraph PC_Layer ["制御PC層 (Windows)"]
        style PC_Layer fill:#f9f,stroke:#333
        CtrlPC["<i class='fa fa-desktop'></i> 制御PC"]
        
        subgraph PC_Internal ["PC内部ソフトウェア"]
            style PC_Internal fill:#fff,stroke:#666
            Redis["<i class='fa fa-database'></i> Redis DB"]
            LuaApp["<i class='fa fa-code'></i> Lua制御アプリ"]
        end
    end

    subgraph PLC_Layer ["PLC制御層"]
        style PLC_Layer fill:#eef,stroke:#333
        
        GP_PLC["<i class='fa fa-microchip'></i> 地上盤 PLC<br/>(Q Series)"]
        SRM_PLC["<i class='fa fa-microchip'></i> スタッカー PLC<br/>(SRM)"]
        CV_PLC["<i class='fa fa-microchip'></i> コンベア PLC<br/>(CV)"]
    end

    subgraph Device_Layer ["フィールド機器層"]
        AGV["<i class='fa fa-truck'></i> 無人搬送車 (AGV)"]
        SRM_HW[クレーン モータ/センサ]
        CV_HW[コンベア モータ/センサ]
    end

    %% Network Connections
    WMS <==>|Task I/F| Redis
    Redis <==>|Localhost| LuaApp
    
    LuaApp == Modbus/TCP ==> GP_PLC
    LuaApp == Modbus/TCP ==> SRM_PLC
    LuaApp == Modbus/TCP ==> CV_PLC

    GP_PLC == CC-Link ==> SRM_PLC
    GP_PLC == CC-Link ==> CV_PLC

    %% Field Connections
    GP_PLC -. Wireless .-> AGV
    SRM_PLC --- SRM_HW
    CV_PLC --- CV_HW
```

## 2. ソフトウェアモジュール関連図
リファクタリング後のソフトウェアコンポーネント間のデータの流れを示します。今回の改修でPLC内部にロジックが一部移管されました。

```mermaid
classDiagram
    direction TB
    
    class LuaScript {
        +analysisTask()
        +createCommand() [Masked]
        +Read/Write PLC Memory
    }
    
    class PLCMemory {
        +D339: SrcStation
        +D340: DestStation
        +D330: TaskType (Output)
    }

    class ST_Logic {
        <<New Function>>
        +DetermineTaskType(Src, Dest)
    }
    note for ST_Logic "Logic Rules:\nIF Src>0 AND Dest=0 THEN Type=100\nIF Src=0 AND Dest>0 THEN Type=200"

    class LadderLogic {
        +BLOCK_02: Input Check
        +BLOCK_03: Motion Control
        +Safety Interlock
    }

    LuaScript ..> PLCMemory : 1. Write Stations (No TaskType)
    PLCMemory --> ST_Logic : 2. Input Data
    ST_Logic --> PLCMemory : 3. Write TaskType (D330)
    PLCMemory --> LadderLogic : 4. Control Signals
    LadderLogic --|> LuaScript : 5. Completion Status
```

## 3. 詳細ワークフロー (シーケンス)
タスク発生から完了までの時系列フロー詳細です。

```mermaid
sequenceDiagram
    autonumber
    
    box "上位システム" #f9f9f9
        participant WMS
        participant Redis
    end
    
    box "制御PC" #ececff
        participant Lua as Lua App
    end
    
    box "PLC (制御ロジック)" #ffecec
        participant Mem as PLCメモリ
        participant ST as ST判定部
        participant Lad as ラダー制御部
    end

    Note over WMS, Lad: 搬送指示フェーズ
    WMS->>Redis: タスク登録 (LPUSH)
    Lua->>Redis: タスク検知 (RPOP)
    Lua->>Lua: データ解析
    Lua->>Mem: 搬送指示書き込み Modbus<br/>(搬入元/搬出先のみ)
    
    Note over Mem, Lad: 判定・実行フェーズ (PLC内部)
    Mem->>ST: データ入力 (D339, D340)
    activate ST
    ST->>ST: タスク種別自動判定
    ST->>Mem: タスク種別確定 (D330書き込み)
    deactivate ST
    
    Mem->>Lad: 制御フラグON
    activate Lad
    Lad->>Lad: 搬送・走行制御実行
    Lad->>Mem: 動作完了フラグON
    deactivate Lad

    Note over Lua, WMS: 完了報告フェーズ
    Lua->>Mem: 定期ポーリング (完了検知)
    Lua->>Redis: 完了報告書き込み
    Redis->>WMS: 完了データ連携
```

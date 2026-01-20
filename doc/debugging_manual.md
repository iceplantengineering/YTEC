# デバッグ手順書

本手順書は、リファクタリングされたシステム（特にPLC側のSTロジック導入部分）の動作確認を行うためのものです。

## 1. 準備
1. **PC環境**: Windows端末にて必要なLUAスクリプト、Redisサーバーが動作していることを確認する。
2. **PLC環境**: GX Works2/3にて、`refact`フォルダ内のプログラム (`.asc`, `.st`) がPLCに書き込まれているか（シミュレータ含む）確認する。
3. **ネットワーク**: PCとPLCがEthernetで接続され、Pingが通ることを確認する。

## 2. タスク判定ロジック (ST言語) の確認
今回新たに追加された `Masked_ST_Logic.st` が正しく機能し、PCからの指示（TaskTypeなし）を補完できるか確認します。
以下に検証フローを示します。

```mermaid
graph TD
    Start[検証開始] --> GXW[GX Works モニタモード起動]
    GXW --> BatchMon[デバイステスト/ウォッチウィンドウを開く]
    
    BatchMon --> InputSet[入力値を強制セット]
    
    subgraph Test Cases
        direction TB
        CaseA["ケースA: 入庫<br/>D339=1001, D340=0"]
        CaseB["ケースB: 出庫<br/>D339=0, D340=1002"]
        CaseC["ケースC: 移動<br/>D339=1001, D340=1002"]
    end
    
    InputSet --> CaseA
    InputSet --> CaseB
    InputSet --> CaseC
    
    CaseA --> CheckA{D330を確認}
    CaseB --> CheckB{D330を確認}
    CaseC --> CheckC{D330を確認}
    
    CheckA -- "100 (入庫)" --> PassA["OK"]
    CheckA -- その他 --> FailA["NG: ロジック確認"]
    
    CheckB -- "200 (出庫)" --> PassB["OK"]
    CheckB -- その他 --> FailB["NG: ロジック確認"]
    
    CheckC -- "300 (移動)" --> PassC["OK"]
    CheckC -- その他 --> FailC["NG: ロジック確認"]
```

### 判定条件テーブル
| ケース | 入力: D339 (Src) | 入力: D340 (Dest) | 期待値: D330 (TaskType) |
|---|---|---|---|
| A. 入庫 | 0より大 (例: 1001) | 0 | **100** |
| B. 出庫 | 0 | 0より大 (例: 1002) | **200** |
| C. 移動 | 0より大 (例: 1001) | 0より大 (例: 1002) | **300** |

*※ `Masked_ST_Logic.st` がラダーのスキャンタイム内で実行されている必要があります。*

## 3. Lua - PLC 通信確認
LUAスクリプトとPLC間の通信確立を確認します。

```mermaid
sequenceDiagram
    participant PC as PC (Cmd)
    participant Lua as Lua Script
    participant PLC as PLC (Ground/SRM)
    
    PC->>Lua: lua TConEquipmentTest.lua 実行
    activate Lua
    Lua->>Lua: 初期化・Redis接続
    Lua->>PLC: Modbus/TCP 接続要求
    
    alt 接続成功
        PLC-->>Lua: Accept
        Lua->>PC: コンソール表示 "Connect OK"
    else 接続失敗
        PLC--xLua: タイムアウト/拒否
        Lua->>PC: エラー表示・再試行
    end
    
    loop 定期通信 (Worker)
        Lua->>PLC: Read/Write 要求
        PLC-->>Lua: レジスタ値応答
    end
    deactivate Lua
```

## 4. 統合動作確認
Redisへのタスク投入からPLCの実動作までの統合テストフローです。

```mermaid
graph TD
    User((ユーザー)) -->|1. タスク発行| Redis[Redis DB]
    
    subgraph PC_Process ["PC側処理"]
        Redis -->|RPOP| Lua[LUAスクリプト]
        Lua -->|"解析 & マスク"| Lua
        Lua -->|"2. 書込 (Src/Destのみ)"| PLC_Mem["PLCメモリ (通信エリア)"]
    end
    
    subgraph PLC_Process ["PLC側処理"]
        PLC_Mem -->|BLOCK_02受信| D339_D340[D339 / D340]
        D339_D340 -->|STロジック| Judge{判定実行}
        Judge -->|結果| D330["D330: TaskType確定"]
        D330 -->|起動条件成立| Ladder["ラダー: 搬送シーケンス開始"]
        Ladder -->|"3. 物理動作"| Motor[モータ/機器動作]
    end
    
    Motor -->|完了信号| Ladder
    Ladder -->|4. 完了通知| Lua
    Lua -->|ステータス更新| Redis
    Redis -->|完了確認| User
```

### 確認手順
1. redis-cli 等でリスト `taskInfo` にJSON文字列を `LPUSH` する。
2. PLCの `D3009`, `D3010` に値が反映されるのを目視確認。
3. 自動的に `D330` が変化し、装置が動き出す（またはシミュレータ上で該当リレーが動く）ことを確認。

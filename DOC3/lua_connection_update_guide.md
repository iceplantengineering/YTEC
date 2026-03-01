# Luaアプリ（Modbus接続先）の変更手順

GATEWAYを用いたオフライン検証（M8001=ON）を行うためには、LuaアプリケーションがPLC実機ではなく、PC内で起動しているGATEWAYプロセスへModbus/TCP接続を行うように変更する必要があります。

変更対象ファイル：`d:\Users\ymj\Desktop\YTEC-1\REFACT3\TConEquipmentTest.lua` 

## 1. 接続先IPとポートの変更箇所

`TConEquipmentTest.lua` では、B01・B02・スタッカー・コンベアといった各PLCのIPアドレスとポート（通常 `502`）が定義されています。これを以下のように変更します。

### 【変更前：実機環境（例）】
```lua
-- B01 地上盤
client_B01 = TClientHelper:new("B01", "192.168.1.1", 502)
-- B02 地上盤
client_B02 = TClientHelper:new("B02", "192.168.1.4", 502)
-- SRM スタッカー
client_SRM = TClientHelper:new("SRM", "192.168.1.2", 502)
-- CV コンベア
client_CV  = TClientHelper:new("CV",  "192.168.1.3", 502)
```

### 【変更後：GATEWAY・オフライン環境】
```lua
-- GATEWAYで定義したポート番号へ向ける（127.0.0.1）
client_B01 = TClientHelper:new("B01", "127.0.0.1", 15021)
client_B02 = TClientHelper:new("B02", "127.0.0.1", 15024)
client_SRM = TClientHelper:new("SRM", "127.0.0.1", 15022)
client_CV  = TClientHelper:new("CV",  "127.0.0.1", 15023)
```

> **Note:** 
> これにより、LuaからのModbus通信要求はすべてGATEWAY（Python）の `modbus_server.py` に到達し、GATEWAYがMX Componentを介してGX Simulator2 上のPLCメモリへ書き込みを行います。

## 2. 変更・運用上の運用ポイント

1. **実機とシミュレーションの切り替え**: 頻繁に切り替える場合、環境変数やLuaの設定ファイル（INI等）で切り替えられるようにしておくと便利です。
   ```lua
   local IS_SIMULATION = true
   local host_b01 = IS_SIMULATION and "127.0.0.1" or "192.168.1.1"
   local port_b01 = IS_SIMULATION and 15021 or 502
   ```

2. **D339 / D340への書き込み**: `TTask.lua` から呼び出される `TConEquipmentTest.lua` のデバイス書き込み関数は、オフライン環境でも変更する必要はありません。GATEWAYがアドレス（例：400339）を自動で `D339` 等にマッピングします。

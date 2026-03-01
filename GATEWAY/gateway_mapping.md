付録B：最小マッピング表（初期リリース版）
B-1. 方針

まずは Dレジスタ中心

ハンドシェイク成立に必要な点のみ

M/Bビットは必要になったら拡張

4PLC間の論理コピーは「D中心」で再現

B-2. Modbus ⇔ PLC デバイスマッピング
■ B01 PLC（Port:15021）
Modbus Addr	PLCデバイス	R/W	内容	備考
400339	D339	W	搬入ステーション指令	Lua書込み 

io_signal_list


400340	D340	W	搬出ステーション指令	Lua書込み 

io_signal_list


400330	D330	R	STKタスク種別	PLC内自動生成 

io_signal_list


400212	D212	R	B01入庫搬入受取可	ハンドシェイク 

io_signal_list


400214	D214	R	B01入庫搬出受渡可	ハンドシェイク 

io_signal_list

■ B02 PLC（Port:15024）
Modbus Addr	PLCデバイス	R/W	内容
401339	D339	W	搬入ステーション指令
401340	D340	W	搬出ステーション指令
401330	D330	R	STKタスク種別
401213	D213	R	B02出庫搬入受取可 

io_signal_list


401215	D215	R	B02出庫搬出受渡可 

io_signal_list

■ SRM PLC（Port:15022）
Modbus Addr	PLCデバイス	R/W	内容
402330	D330	R	実行中タスク種別
402500	D500	R	状態コード（待機/移動/完了など）

※D500は状態確認用（既存プログラムに合わせて変更）

■ CV PLC（Port:15023）

最小版では外部Modbus公開不要
（必要なら後で追加）

B-3. CC-Link仮想コピー定義（最小版）

周期：30ms（初期値）

① B01 → SRM
送信元	受信先	内容
B01:D330	SRM:D330	タスク種別伝達
B01:D212	SRM:D212	搬入受取可
B01:D214	SRM:D214	搬出受渡可
② B02 → SRM
送信元	受信先	内容
B02:D330	SRM:D331	B02側タスク
B02:D213	SRM:D213	搬入受取可
B02:D215	SRM:D215	搬出受渡可
③ SRM → B01/B02（完了通知）
送信元	受信先	内容
SRM:D520	B01:D520	完了通知
SRM:D521	B02:D521	完了通知

※D520/D521は既存プログラム定義に合わせ調整

B-4. SIM_MODE制御
PLC	デバイス	動作
全PLC	M100	ON固定（オフライン時）

※既存がM8001の場合は内部ブリッジで吸収 

io_signal_list

B-5. 初期受入れテスト手順
1️⃣ 起動確認

4PLC起動

Gateway起動

SIM_MODE=ON確認

2️⃣ 正常系テスト

Lua → B01へ D339=1001 書込み 

io_signal_list

B01で D330 が生成される 

io_signal_list

D212 または D214 が成立 

io_signal_list

SRMが遷移し完了通知D520が立つ 

plc_flowcharts

完了通知がB01へコピーされる

→ ここまで流れれば「総合機能検証OK」

B-6. 点数まとめ

Modbus公開点数：約15点

CC-Linkコピー点数：約10点

合計：約25点

最小で十分回ります。
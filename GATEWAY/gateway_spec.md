ゲートウェイ仕様書（最小構成）v0.1
1. 目的と範囲
1.1 目的

実機構成（4PLC + Lua/Redis + Modbus/TCP + PLC間CC-Link）を、1台のWindows PC内でオフライン総合検証できるようにする。

1.2 対象範囲（やること）

Luaアプリからの Modbus/TCP Read/Write を受ける

内部で MX Component を用いてGX Simulator上のPLCメモリへ反映する

実機のCC-Link相当を **周期コピー（論理コピー）**で再現する 

目的の構造化要約

1.3 対象外（最小構成ではやらない）

ネットワーク遅延・パケットロス等の精密再現

GUI/HMI

異常自動診断（ただしログは出す）

WMS側（Redis）は既存を利用

2. システム前提
2.1 実機の前提（参考）

PLC：B01 / B02 / SRM / CV の4PLC構成 

system_architecture

上位：Lua + Redis、PLCとはModbus/TCP 

system_architecture

PLC間：CC-Link（実機） 

system_architecture

2.2 オフライン前提

各PLCは シミュレーションモードフラグ（例：M100）=ONで動作させ、物理I/O・通信異常監視をバイパスする

※既存資料ではM8001想定があるが、運用標準ビットへ置換可能（本仕様ではSIM_MODEと呼ぶ）

3. 全体構成
3.1 論理構成

GatewayはPC内プロセスとして動作する。

Gatewayは以下の3機能で構成される： 

目的の構造化要約

Modbus層（Lua互換インタフェース）

PLCアクセス層（MX Component）

PLC間通信仮想層（CC-Link論理コピー）

3.2 ネットワーク（オフライン時）

Luaが接続するModbus/TCP先は、実IPではなく localhost + ポート分離とする。例： 

目的の構造化要約

B01：127.0.0.1:15021

SRM：127.0.0.1:15022

CV ：127.0.0.1:15023

B02：127.0.0.1:15024

4. 機能要件
4.1 Modbusサーバ機能
4.1.1 基本

GatewayはPLCごとにModbus/TCPサーバを提供する（上記ポート分離）。

Luaは従来通り Read/Writeを行うだけで良い（接続先変更のみ）。

4.1.2 対応コマンド（最小）

FC03: Read Holding Registers

FC06: Write Single Register

FC16: Write Multiple Registers
（必要ならFC01/FC05/FC15を追加）

4.1.3 アドレスマッピング

Modbusレジスタ ⇔ PLCデバイス（D/M/B等）の対応は「マッピング表」で定義する。

最小構成では Dレジスタ中心で開始し、必要に応じてM/Bを拡張する。

（例：必須候補）

D339：搬入ステーション指令（Lua→PLC） 

io_signal_list

D340：搬出ステーション指令（Lua→PLC） 

io_signal_list

D330：タスク種別（PLC内で自動判定される出力） 

io_signal_list

注：D339/D340のみ書けば、PLC側のSTロジックでD330が生成される設計（REFACT3）

4.2 PLCアクセス機能（MX Component）
4.2.1 対象

GX Simulator2上の各PLC（B01/B02/SRM/CV）に対し、読み書きを行う。

4.2.2 アクセス粒度

最小は D単位の一括読み書き（ブロックアクセス）を推奨。

将来拡張でM/B/W/U2\G等を追加可能。

4.2.3 失敗時の扱い

読み書き失敗（例：GX Sim未起動、局番不一致）の場合：

リトライ（最大N回）

それでも失敗ならエラー状態に遷移しログ出力

Modbus応答は例外応答（Exception Response）を返す

4.3 PLC間通信仮想（CC-Link論理コピー）
4.3.1 基本思想

実機のCC-Linkネットワークを再現せず、送受信領域をGatewayが周期コピーして論理を再現する。

4.3.2 周期

デフォルト：20ms〜50ms

設定値として変更可能（configファイル or 起動引数） 

目的の構造化要約

4.3.3 コピー対象（例）

実機では以下の関係がある： 

system_architecture

B01 ⇄ CV（CC-Link B00〜B4F 等）

B02 ⇄ CV（CC-Link B100〜B101 等）

B01 ⇄ SRM（U2\G等を使用）

B02 ⇄ SRM（U2\G等を使用）

最小構成では、まず ハンドシェイク成立に必要な信号に絞る（例：D212〜D215等）。

4.3.4 コピーの原則

「送信元→受信先」を固定定義し、同一周期内で順序を保証する（例：CV→B01→SRMの順）。

同一デバイスへの多重書込があり得る場合は、優先順位を明記する（最小構成では多重書込を避ける設計に寄せる）。

4.4 モード（SIM_MODE）要件
4.4.1 SIM_MODEの意味

SIM_MODE=ON時：物理I/O無視・異常マスク・擬似完了などでロジックを進める。

SIM_MODE=OFF時：実機動作（Gateway停止・実機IPへ戻す）。

4.4.2 Gateway側の責務

Gateway起動時に、対象PLCのSIM_MODEをONにできること（任意：運用ポリシーにより手動でも可）

少なくとも「SIM_MODEがONである」ことを起動チェックしてログに出す

5. 非機能要件
5.1 性能

Modbus要求応答：平均 < 50ms（目標）

CC-Linkコピー周期：20〜50ms（設定可能）

5.2 可用性

GX Simulatorが落ちた場合、Gatewayは異常検知してログ出力し、自動復帰を試みる（最小構成では“落ちたら止まる”でも可。その場合は手順書で回復方法を明記）

5.3 ログ

最低限、以下を必ず記録：

Modbus受信（PLC名、アドレス、値、時刻）

MX Component読み書き結果（成功/失敗）

CC-Linkコピー実行（周期遅延、エラー）

重要レジスタ変化（例：D339/D340/D330、D212〜D215）

6. 設定（Config）
6.1 必須設定項目

PLCごとのポート番号（15021〜15024）

PLC局番/接続先（MX Component設定）

CC-Linkコピー周期（ms）

マッピング表（Modbus ⇔ PLCデバイス）

6.2 最小構成の推奨

configファイルはJSON 1枚にまとめる（初心者運用向け）

7. 受入れ試験（最小）
7.1 起動確認

GX Simulator2で4PLC起動済み

Gateway起動 → 各ポートで待受開始

SIM_MODEがONであることをログで確認 

io_signal_list

7.2 正常系シナリオ（例）

Lua（またはテストツール）からB01へ D339/D340を書込 

io_signal_list

PLC内のSTロジックで D330 が期待値になる

ハンドシェイク（D212〜D215 等）が立ち上がる（または成立条件が満たされる）

SRM側が状態遷移し完了通知まで進む（REFACT3フローに沿う） 

plc_flowcharts

7.3 異常系（最小）

GX Simが1台落ちた場合：Gatewayが検知しログを出す

Modbus不正アドレス：例外応答を返す

8. 実機切替（運用要件）

実機時：Gateway停止、Lua接続先を実IPへ戻す。PLCプログラム変更不要。

付録A：用語

Gateway：Modbusサーバ + MXアクセス + CC-Link論理コピーを行うPC内ソフト

SIM_MODE：シミュレーションモード切替フラグ（例：M100）
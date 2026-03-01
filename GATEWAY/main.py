import json
import time
from logger import logger
from plc_access_stub import PLCAccessStub
from plc_access_mx import PLCAccessMx
from modbus_server import launch_modbus_servers
from cc_link_copy import CCLinkCopy

def load_config(config_path="config.json"):
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Failed to load config file: {e}")
        return {}

def main():
    logger.info("Initializing Gateway (MX Component Version)...")
    
    # 1. コンフィグを読み込む
    config = load_config()
    if not config:
        logger.error("Empty or invalid config, shutting down.")
        return
        
    # 2. PLCアクセス層の初期化 (MX Component版を使用)
    plc_access = PLCAccessMx(config.get("plcs", {}))
    # plc_access = PLCAccessStub()
    
    # SIM_MODEの有効化
    sim_enabled = config.get("sim_mode", {}).get("enabled", True)
    if sim_enabled:
        sim_device = config.get("sim_mode", {}).get("device", "M100")
        plc_access.set_sim_mode(sim_device, 1)
        
    # 3. 各PLCごとのModbusサーバをスレッドで起動する
    launch_modbus_servers(config, plc_access)
    
    # 4. CC-Linkの論理コピーをバックグラウンドスレッドで開始する
    cclink = CCLinkCopy(config, plc_access)
    cclink.start()
    
    logger.info("Gateway is running. Press Ctrl+C to stop.")
    
    # メインスレッドは無限ループで維持
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Stopping Gateway...")
        cclink.stop()
        logger.info("Gateway stopped gracefully.")

if __name__ == "__main__":
    main()

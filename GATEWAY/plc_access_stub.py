from logger import logger

class PLCAccessStub:
    """
    PLCへのアクセスを辞書（インメモリ）でモックするスタブクラス。
    最小構成での動作確認用。
    """
    def __init__(self):
        self.memory = {
            "B01": {},
            "B02": {},
            "SRM": {},
            "CV": {}
        }
        logger.info("PLCAccessStub initialized.")

    def read_device(self, plc_name, device):
        val = self.memory.get(plc_name, {}).get(device, 0)
        return val

    def write_device(self, plc_name, device, value):
        if plc_name not in self.memory:
            self.memory[plc_name] = {}
        
        # 変更された場合のみログ出力（ログの溢れ防止）
        old_val = self.memory[plc_name].get(device, None)
        self.memory[plc_name][device] = value
        
        if old_val != value:
            logger.info(f"[Modbus/STUB Write] {plc_name}:{device} <- {value}")

    def set_sim_mode(self, mod_device="M100", value=1):
        for plc in self.memory.keys():
            self.write_device(plc, mod_device, value)
        logger.info(f"SIM_MODE ({mod_device}) set to {value} for all PLCs (Stub).")

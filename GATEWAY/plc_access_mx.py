import win32com.client
from logger import logger

class PLCAccessMx:
    """
    MX Componentを利用してGX Simulator2上のPLCへ実アクセスを行うクラス
    """
    def __init__(self, plcs_config):
        self.connections = {}
        logger.info("PLCAccessMx initialized. Trying to connect to PLCs...")
        
        # NOTE: plcs_configには "station_number" 等の設定が必要になる場合があります
        # ここでは最低限の構成として、局番を1, 2, 3...と仮定するか、外から渡す想定にします。
        # Minimal例として、configに基づき接続を試みる機構
        for plc_name, info in plcs_config.items():
            station = info.get("station_number", 0)
            if station > 0:
                self._connect(plc_name, station)

    def _connect(self, plc_name, station_number):
        try:
            # MX Component の一般的なWrapper (ActUtlType)
            act = win32com.client.Dispatch("ActUtlType.ActUtlType")
            act.ActLogicalStationNumber = station_number
            ret = act.Open()
            if ret == 0:
                self.connections[plc_name] = act
                logger.info(f"Connected to {plc_name} (Station: {station_number}) using MX Component.")
            else:
                logger.error(f"Failed to connect to {plc_name}. MX Error Code: {hex(ret)}")
        except Exception as e:
            logger.error(f"MX Component Error for {plc_name}: {e}")

    def read_device(self, plc_name, device):
        if plc_name not in self.connections:
            # mxに接続していない時は0を返す
            return 0
        
        act = self.connections[plc_name]
        try:
            # GetDevice: return code, value
            # deviceが "D100" または "B39" などの形式でも、MX Componentはそのまま受け付けます
            ret, val = act.GetDevice(str(device))
            if ret == 0:
                return val
            else:
                logger.error(f"Read error {plc_name}:{device} Code: {hex(ret)}")
                return 0
        except Exception as e:
            logger.error(f"Read exception {plc_name}:{device} : {e}")
            return 0

    def write_device(self, plc_name, device, value):
        if plc_name not in self.connections:
            return
        
        act = self.connections[plc_name]
        try:
            # SetDevice: args (DeviceName, Value)
            ret = act.SetDevice(str(device), int(value))
            if ret != 0:
                logger.error(f"Write error {plc_name}:{device} Code: {hex(ret)}")
            else:
                logger.info(f"Write MX Component {plc_name}:{device} <- {value}")
        except Exception as e:
            logger.error(f"Write exception {plc_name}:{device} : {e}")

    def set_sim_mode(self, mod_device="M100", value=1):
        for plc in self.connections.keys():
            self.write_device(plc, mod_device, value)
        logger.info(f"SIM_MODE ({mod_device}) set to {value} for connected PLCs via MX Component.")

import threading
import asyncio
from pymodbus.server import StartAsyncTcpServer
from pymodbus.datastore import ModbusSequentialDataBlock, ModbusSlaveContext, ModbusServerContext
from logger import logger

class CustomDataBlock(ModbusSequentialDataBlock):
    """
    PLCアクセス機能(Stub または MX Component)を内包して、
    Modbusリクエストがあった際に自動でPLC側を読み書きするカスタムデータブロック
    """
    def __init__(self, plc_name, access, mapping):
        # 10000レジスタ分確保 (0で初期化)
        super().__init__(0, [0]*10000)
        self.plc_name = plc_name
        self.access = access
        
        # マッピング辞書の構築 (Modbusアドレス -> PLCデバイス)
        # 400339 -> D339 のように文字列で設定されている前提
        self.offset_to_device = {}
        for m_addr_str, device in mapping.items():
            m_addr = int(m_addr_str)
            # 400000から始まるベースアドレスを想定
            if m_addr > 400000:
                # 0-based offset 
                # e.g. 400330 -> offset 329 または 330
                # pymodbusがaddress引数をどう渡すかに依存しますが、通常は0-basedです
                # ここでは正確さを期すため、下3桁・4桁をそのままoffsetとします
                # 例) 400330 -> offset = 330
                offset = m_addr - 400000
                self.offset_to_device[offset] = device

    def setValues(self, address, values):
        """ Modbus Write """
        super().setValues(address, values)
        for i, val in enumerate(values):
            offset = address + i
            if offset in self.offset_to_device:
                device = self.offset_to_device[offset]
                self.access.write_device(self.plc_name, device, val)
                logger.debug(f"[Modbus Write] {self.plc_name} {device} <- {val}")

    def getValues(self, address, count=1):
        """ Modbus Read """
        values = []
        for i in range(count):
            offset = address + i
            if offset in self.offset_to_device:
                device = self.offset_to_device[offset]
                val = self.access.read_device(self.plc_name, device)
                values.append(val)
            else:
                # デバイスマッピングがない場合は内部の0を返す
                val = super().getValues(offset, 1)[0]
                values.append(val)
        return values

async def run_modbus_server_async(plc_name, port, access, mapping):
    logger.info(f"Starting Modbus server for {plc_name} at 127.0.0.1:{port}")
    block = CustomDataBlock(plc_name, access, mapping)
    
    # Holding Registers (hr)にアサイン
    store = ModbusSlaveContext(hr=block)
    context = ModbusServerContext(slaves=store, single=True)
    
    await StartAsyncTcpServer(
        context=context,
        address=("127.0.0.1", port)
    )

def start_server_in_thread(plc_name, port, access, mapping):
    """
    非同期のPyModbusサーバを別スレッドで立ち上げるラッパー関数
    """
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        loop.run_until_complete(run_modbus_server_async(plc_name, port, access, mapping))
    except Exception as e:
        logger.error(f"Modbus server {plc_name} failed: {e}")

def launch_modbus_servers(config, access):
    """
    configに記載された全PLCのModbusサーバを起動する
    """
    threads = []
    plcs = config.get("plcs", {})
    for plc_name, plc_info in plcs.items():
        port = plc_info.get("port")
        mapping = plc_info.get("modbus_mapping", {})
        if port:
            t = threading.Thread(
                target=start_server_in_thread, 
                args=(plc_name, port, access, mapping), 
                daemon=True
            )
            t.start()
            threads.append(t)
    return threads

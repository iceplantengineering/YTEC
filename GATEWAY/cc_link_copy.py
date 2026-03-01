import time
import threading
from logger import logger

class CCLinkCopy:
    def __init__(self, config, plc_access):
        self.config = config.get("cclink_copy", {})
        self.rules = self.config.get("rules", [])
        self.interval = self.config.get("interval_ms", 30) / 1000.0
        self.plc_access = plc_access
        self.running = False
        self.thread = None

    def _copy_loop(self):
        logger.info(f"Starting CC-Link virtual copy loop (interval: {self.interval}s)")
        while self.running:
            for rule in self.rules:
                src = rule.get("src")
                dst = rule.get("dst")
                if src and dst:
                    try:
                        src_plc, src_dev = src.split(":")
                        dst_plc, dst_dev = dst.split(":")
                        
                        val = self.plc_access.read_device(src_plc, src_dev)
                        current_dst_val = self.plc_access.read_device(dst_plc, dst_dev)
                        
                        if val != current_dst_val:
                            self.plc_access.write_device(dst_plc, dst_dev, val)
                            logger.debug(f"[CC-Link] Copied {src} -> {dst} : {val}")
                    except Exception as e:
                        logger.error(f"CC-Link Copy Error ({src}->{dst}): {e}")

            time.sleep(self.interval)

    def start(self):
        if not self.rules:
            logger.warning("No CC-Link rules found.")
            return
            
        self.running = True
        self.thread = threading.Thread(target=self._copy_loop, daemon=True)
        self.thread.start()

    def stop(self):
        self.running = False
        if self.thread:
            self.thread.join()

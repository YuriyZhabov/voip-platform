import asyncio
import json
import logging
import base64
import urllib.request
import urllib.error
import time
import threading

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class StasisApp:
    """Приложение для работы с Asterisk ARI Stasis"""
    
    def __init__(self, host="freepbx-server", port=8088, username="livekit", password="livekit_password", app_name="livekit-agent"):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.app_name = app_name
        self.base_url = f"http://{host}:{port}/ari"
        self.auth_header = base64.b64encode(f"{username}:{password}".encode()).decode()
        self.running = False
        
    def start(self):
        """Запуск приложения"""
        self.running = True
        threading.Thread(target=self._event_loop).start()
        
    def stop(self):
        """Остановка приложения"""
        self.running = False
        
    def _event_loop(self):
        """Цикл обработки событий"""
        while self.running:
            try:
                # Получение списка каналов
                channels = self.get_channels()
                for channel in channels:
                    channel_id = channel.get('id')
                    state = channel.get('state')
                    caller_id = channel.get('caller', {}).get('number')
                    logger.info(f"Channel {channel_id} from {caller_id} is in state {state}")
                    
                    # Если канал в состоянии 'Up', воспроизводим приветственное сообщение
                    if state == 'Up':
                        self.play_sound(channel_id, 'hello-world')
                
                # Пауза между итерациями
                time.sleep(1)
            except Exception as e:
                logger.error(f"Error in event loop: {e}")
                time.sleep(5)
        
    def get_channels(self):
        """Получение списка активных каналов"""
        try:
            request = urllib.request.Request(
                f"{self.base_url}/channels",
                headers={"Authorization": f"Basic {self.auth_header}"}
            )
            with urllib.request.urlopen(request) as response:
                return json.loads(response.read().decode())
        except urllib.error.URLError as e:
            logger.error(f"Failed to get channels: {e}")
            return []
            
    def play_sound(self, channel_id, sound):
        """Воспроизведение звука на канале"""
        try:
            data = json.dumps({"media": f"sound:{sound}"}).encode()
            request = urllib.request.Request(
                f"{self.base_url}/channels/{channel_id}/play",
                data=data,
                headers={
                    "Authorization": f"Basic {self.auth_header}",
                    "Content-Type": "application/json"
                },
                method="POST"
            )
            with urllib.request.urlopen(request) as response:
                return json.loads(response.read().decode())
        except urllib.error.URLError as e:
            logger.error(f"Failed to play sound: {e}")
            return None

def main():
    """Основная функция"""
    app = StasisApp()
    app.start()
    
    try:
        # Держим приложение запущенным
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        app.stop()

if __name__ == "__main__":
    main()
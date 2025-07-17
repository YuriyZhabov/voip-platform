import asyncio
import json
import logging
import base64
import urllib.request
import urllib.error

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SimpleARIClient:
    """Простой клиент для работы с Asterisk ARI"""
    
    def __init__(self, host="freepbx-server", port=8088, username="livekit", password="livekit_password"):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.base_url = f"http://{host}:{port}/ari"
        self.auth_header = base64.b64encode(f"{username}:{password}".encode()).decode()
        
    def get_applications(self):
        """Получение списка приложений"""
        try:
            request = urllib.request.Request(
                f"{self.base_url}/applications",
                headers={"Authorization": f"Basic {self.auth_header}"}
            )
            with urllib.request.urlopen(request) as response:
                return json.loads(response.read().decode())
        except urllib.error.URLError as e:
            logger.error(f"Failed to get applications: {e}")
            return []
            
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

def main():
    """Основная функция"""
    client = SimpleARIClient()
    
    # Получение списка приложений
    applications = client.get_applications()
    logger.info(f"Applications: {applications}")
    
    # Получение списка каналов
    channels = client.get_channels()
    logger.info(f"Channels: {channels}")

if __name__ == "__main__":
    main()
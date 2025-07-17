#!/usr/bin/env python3
"""
Постоянный ARI клиент
"""

import asyncio
import aiohttp
import json
import logging
import signal
import sys

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class PersistentARIClient:
    def __init__(self):
        self.base_url = "http://freepbx-server:8088"
        self.username = "livekit-agent"
        self.password = "livekit_ari_secret"
        self.app_name = "livekit-agent"
        self.session = None
        self.ws = None
        self.running = True
        
    async def start(self):
        """Запуск клиента"""
        logger.info("🚀 Запуск постоянного ARI клиента...")
        
        self.session = aiohttp.ClientSession()
        
        try:
            await self.connect_websocket()
            await self.handle_events()
        except Exception as e:
            logger.error(f"❌ Ошибка в ARI клиенте: {e}")
        finally:
            await self.cleanup()
    
    async def connect_websocket(self):
        """Подключение к WebSocket"""
        ws_url = f"{self.base_url}/ari/events"
        params = {
            'api_key': self.username,
            'api_secret': self.password,
            'app': self.app_name
        }
        
        logger.info(f"Подключение к ARI WebSocket: {ws_url}")
        
        self.ws = await self.session.ws_connect(
            ws_url,
            params=params,
            auth=aiohttp.BasicAuth(self.username, self.password)
        )
        
        logger.info("✅ ARI WebSocket подключен!")
    
    async def handle_events(self):
        """Обработка событий"""
        logger.info("🎧 Начинаю прослушивание событий ARI...")
        
        try:
            while self.running:
                msg = await self.ws.receive()
                
                if msg.type == aiohttp.WSMsgType.TEXT:
                    try:
                        event = json.loads(msg.data)
                        await self.process_event(event)
                    except json.JSONDecodeError as e:
                        logger.error(f"Ошибка парсинга JSON: {e}")
                        
                elif msg.type == aiohttp.WSMsgType.ERROR:
                    logger.error(f"WebSocket ошибка: {self.ws.exception()}")
                    break
                    
                elif msg.type == aiohttp.WSMsgType.CLOSE:
                    logger.info("WebSocket соединение закрыто")
                    break
                    
        except Exception as e:
            logger.error(f"Ошибка обработки событий: {e}")
    
    async def process_event(self, event):
        """Обработка события"""
        event_type = event.get('type', 'unknown')
        logger.info(f"📨 Получено событие: {event_type}")
        
        if event_type == 'StasisStart':
            channel = event.get('channel', {})
            channel_id = channel.get('id')
            logger.info(f"🔥 Новый звонок в Stasis: {channel_id}")
            
        elif event_type == 'StasisEnd':
            channel = event.get('channel', {})
            channel_id = channel.get('id')
            logger.info(f"🔚 Звонок завершен: {channel_id}")
    
    async def cleanup(self):
        """Очистка ресурсов"""
        logger.info("🧹 Очистка ресурсов...")
        
        if self.ws:
            await self.ws.close()
        
        if self.session:
            await self.session.close()
    
    def stop(self):
        """Остановка клиента"""
        logger.info("🛑 Остановка ARI клиента...")
        self.running = False

async def main():
    """Основная функция"""
    client = PersistentARIClient()
    
    # Обработка сигналов для корректного завершения
    def signal_handler(signum, frame):
        logger.info(f"Получен сигнал {signum}")
        client.stop()
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        await client.start()
    except KeyboardInterrupt:
        logger.info("Получен Ctrl+C")
        client.stop()

if __name__ == "__main__":
    asyncio.run(main())
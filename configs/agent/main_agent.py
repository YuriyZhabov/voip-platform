#!/usr/bin/env python3
"""
Главный агент с интеграцией аудио моста
Объединяет LiveKit агента и Asterisk ARI
"""

import asyncio
import logging
import os
import sys
import json
from pathlib import Path
from typing import Dict, Optional

# Добавляем текущую директорию в путь для импортов
sys.path.append(str(Path(__file__).parent))

import aiohttp
from aiohttp import web
from livekit import api, rtc
from livekit.agents import JobContext, WorkerOptions, cli
from livekit.agents.voice_assistant import VoiceAssistant
from livekit.plugins import deepgram, openai, cartesia, silero

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/logs/main_agent.log')
    ]
)
logger = logging.getLogger(__name__)

class MainAgent:
    """Главный агент системы"""
    
    def __init__(self):
        # Настройки ARI
        self.ari_url = os.getenv('ARI_URL', 'http://freepbx-server:8088')
        self.ari_username = os.getenv('ARI_USERNAME', 'livekit-agent')
        self.ari_password = os.getenv('ARI_PASSWORD', 'livekit_ari_secret')
        
        # LiveKit настройки
        self.livekit_url = os.getenv('LIVEKIT_URL')
        self.livekit_api_key = os.getenv('LIVEKIT_API_KEY')
        self.livekit_api_secret = os.getenv('LIVEKIT_API_SECRET')
        
        # Состояние
        self.health_server = None
        self.running = False
        self.ari_ws = None
        self.session = None
        self.active_channels: Dict[str, Dict] = {}
        
    async def start(self):
        """Запуск главного агента"""
        logger.info("🚀 Запуск главного агента VoIP системы")
        
        try:
            self.running = True
            
            # Проверяем переменные окружения
            await self.check_environment()
            
            # Запускаем HTTP сервер для health check
            await self.start_health_server()
            
            # Создаем HTTP сессию
            self.session = aiohttp.ClientSession()
            
            # Запускаем ARI клиент
            ari_task = asyncio.create_task(self.start_ari_client())
            
            # Запускаем мониторинг системы
            monitor_task = asyncio.create_task(self.system_monitor())
            
            logger.info("✅ Главный агент успешно запущен")
            
            # Ожидаем завершения любой из задач
            done, pending = await asyncio.wait(
                [ari_task, monitor_task],
                return_when=asyncio.FIRST_COMPLETED
            )
            
            # Отменяем оставшиеся задачи
            for task in pending:
                task.cancel()
                
        except Exception as e:
            logger.error(f"💥 Критическая ошибка главного агента: {e}")
            raise
        finally:
            await self.cleanup()
    
    async def check_environment(self):
        """Проверка переменных окружения"""
        required_vars = [
            'LIVEKIT_URL',
            'LIVEKIT_API_KEY', 
            'LIVEKIT_API_SECRET',
            'OPENAI_API_KEY',
            'DEEPGRAM_API_KEY',
            'CARTESIA_API_KEY'
        ]
        
        missing_vars = []
        for var in required_vars:
            if not os.getenv(var):
                missing_vars.append(var)
        
        if missing_vars:
            logger.error(f"❌ Отсутствуют переменные окружения: {', '.join(missing_vars)}")
            raise ValueError(f"Отсутствуют обязательные переменные окружения: {missing_vars}")
        
        logger.info("✅ Все переменные окружения настроены")
        
        # Логируем конфигурацию (без секретов)
        logger.info(f"🔗 LiveKit URL: {os.getenv('LIVEKIT_URL')}")
        logger.info(f"🤖 OpenAI модель: {os.getenv('OPENAI_MODEL', 'gpt-4o-mini')}")
        logger.info(f"🎤 Deepgram модель: {os.getenv('DEEPGRAM_MODEL', 'nova-2')}")
        logger.info(f"🔊 Cartesia модель: {os.getenv('CARTESIA_MODEL', 'sonic-multilingual')}")
    
    async def start_health_server(self):
        """Запуск HTTP сервера для health check"""
        try:
            app = web.Application()
            app.router.add_get('/health', self.health_check_handler)
            app.router.add_get('/status', self.status_handler)
            app.router.add_get('/stats', self.stats_handler)
            
            runner = web.AppRunner(app)
            await runner.setup()
            
            site = web.TCPSite(runner, '0.0.0.0', 8081)
            await site.start()
            
            logger.info("🌐 Health check сервер запущен на порту 8081")
            
        except Exception as e:
            logger.error(f"Ошибка запуска health check сервера: {e}")
    
    async def health_check_handler(self, request):
        """Обработчик health check"""
        try:
            # Проверяем состояние аудио моста
            bridge_healthy = await self.audio_bridge.health_check()
            
            status = "healthy" if bridge_healthy else "unhealthy"
            
            return web.json_response({
                "status": status,
                "service": "voip-ai-agent",
                "version": "1.0.0",
                "components": {
                    "audio_bridge": "healthy" if bridge_healthy else "unhealthy",
                    "livekit": "connected",
                    "asterisk": "connected" if bridge_healthy else "disconnected"
                }
            })
            
        except Exception as e:
            logger.error(f"Ошибка health check: {e}")
            return web.json_response({
                "status": "error",
                "error": str(e)
            }, status=500)
    
    async def status_handler(self, request):
        """Обработчик детального статуса"""
        try:
            stats = self.audio_bridge.get_system_stats()
            
            return web.json_response({
                "status": "running" if self.running else "stopped",
                "service": "voip-ai-agent",
                "uptime_seconds": stats.get('uptime', 0),
                "active_calls": stats.get('active_channels', 0),
                "active_rooms": stats.get('active_rooms', 0),
                "environment": {
                    "livekit_url": os.getenv('LIVEKIT_URL', 'not_set'),
                    "openai_model": os.getenv('OPENAI_MODEL', 'gpt-4o-mini'),
                    "deepgram_model": os.getenv('DEEPGRAM_MODEL', 'nova-2'),
                    "cartesia_model": os.getenv('CARTESIA_MODEL', 'sonic-multilingual')
                }
            })
            
        except Exception as e:
            logger.error(f"Ошибка получения статуса: {e}")
            return web.json_response({
                "status": "error",
                "error": str(e)
            }, status=500)
    
    async def stats_handler(self, request):
        """Обработчик статистики"""
        try:
            stats = self.audio_bridge.get_system_stats()
            return web.json_response(stats)
            
        except Exception as e:
            logger.error(f"Ошибка получения статистики: {e}")
            return web.json_response({
                "error": str(e)
            }, status=500)
    
    async def system_monitor(self):
        """Мониторинг системы"""
        try:
            while self.running:
                await asyncio.sleep(300)  # Каждые 5 минут
                
                stats = self.audio_bridge.get_system_stats()
                active_calls = stats.get('active_channels', 0)
                active_rooms = stats.get('active_rooms', 0)
                
                logger.info(f"📊 Системная статистика:")
                logger.info(f"   • Активных звонков: {active_calls}")
                logger.info(f"   • Активных комнат: {active_rooms}")
                logger.info(f"   • Время работы: {stats.get('uptime', 0):.0f} сек")
                
                # Проверяем использование памяти
                try:
                    import psutil
                    process = psutil.Process()
                    memory_mb = process.memory_info().rss / 1024 / 1024
                    cpu_percent = process.cpu_percent()
                    
                    logger.info(f"   • Память: {memory_mb:.1f} MB")
                    logger.info(f"   • CPU: {cpu_percent:.1f}%")
                    
                except ImportError:
                    pass  # psutil не установлен
                
        except Exception as e:
            logger.error(f"Ошибка мониторинга системы: {e}")
    
    async def start_ari_client(self):
        """Запуск ARI клиента"""
        try:
            logger.info("🔌 Подключение к ARI...")
            
            # Ожидаем готовности Asterisk
            await self.wait_for_asterisk()
            
            # Подключаемся к ARI WebSocket
            await self.connect_to_ari()
            
        except Exception as e:
            logger.error(f"❌ Ошибка ARI клиента: {e}")
            raise
    
    async def wait_for_asterisk(self):
        """Ожидание готовности Asterisk"""
        max_attempts = 30
        for attempt in range(max_attempts):
            try:
                url = f"{self.ari_url}/ari/asterisk/info"
                async with self.session.get(
                    url,
                    auth=aiohttp.BasicAuth(self.ari_username, self.ari_password)
                ) as response:
                    if response.status == 200:
                        logger.info("✅ Asterisk готов")
                        return
            except Exception:
                pass
            
            await asyncio.sleep(2)
        
        raise Exception("Asterisk не готов")
    
    async def connect_to_ari(self):
        """Подключение к ARI WebSocket"""
        ws_url = f"{self.ari_url}/ari/events"
        params = {
            'api_key': self.ari_username,
            'api_secret': self.ari_password,
            'app': 'livekit-agent'
        }
        
        logger.info(f"🔌 Подключение к ARI WebSocket: {ws_url}")
        
        try:
            self.ari_ws = await self.session.ws_connect(
                ws_url,
                params=params,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password)
            )
            
            logger.info("✅ ARI WebSocket подключен")
            await self.handle_ari_events()
            
        except Exception as e:
            logger.error(f"❌ Ошибка подключения к ARI: {e}")
            raise
    
    async def handle_ari_events(self):
        """Обработка событий от ARI"""
        logger.info("👂 Начало прослушивания ARI событий...")
        
        try:
            async for msg in self.ari_ws:
                if msg.type == aiohttp.WSMsgType.TEXT:
                    try:
                        event = json.loads(msg.data)
                        await self.process_ari_event(event)
                    except Exception as e:
                        logger.error(f"Ошибка обработки события: {e}")
                        
        except Exception as e:
            logger.error(f"Ошибка в обработке ARI событий: {e}")
    
    async def process_ari_event(self, event: Dict):
        """Обработка ARI события"""
        event_type = event.get('type')
        
        if event_type == 'StasisStart':
            await self.handle_call_start(event)
        elif event_type == 'StasisEnd':
            await self.handle_call_end(event)
    
    async def handle_call_start(self, event: Dict):
        """Обработка начала звонка"""
        channel = event.get('channel', {})
        channel_id = channel.get('id')
        caller_id = channel.get('caller', {}).get('number', 'Unknown')
        
        logger.info(f"📞 Новый звонок: {caller_id} -> канал {channel_id}")
        
        # Сохраняем информацию о канале
        self.active_channels[channel_id] = {
            'id': channel_id,
            'caller_id': caller_id,
            'state': channel.get('state'),
            'start_time': asyncio.get_event_loop().time()
        }
        
        # Отвечаем на звонок
        await self.answer_channel(channel_id)
        
        # Воспроизводим приветствие
        await self.play_greeting(channel_id)
        
        # Имитируем работу ИИ агента
        await self.simulate_ai_conversation(channel_id)
    
    async def handle_call_end(self, event: Dict):
        """Обработка завершения звонка"""
        channel = event.get('channel', {})
        channel_id = channel.get('id')
        
        logger.info(f"📞 Завершение звонка для канала {channel_id}")
        
        if channel_id in self.active_channels:
            del self.active_channels[channel_id]
    
    async def answer_channel(self, channel_id: str):
        """Ответ на звонок"""
        try:
            url = f"{self.ari_url}/ari/channels/{channel_id}/answer"
            async with self.session.post(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password)
            ) as response:
                if response.status == 204:
                    logger.info(f"✅ Канал {channel_id} отвечен")
                else:
                    logger.error(f"❌ Ошибка ответа: {response.status}")
        except Exception as e:
            logger.error(f"Ошибка ответа на канал: {e}")
    
    async def play_greeting(self, channel_id: str):
        """Воспроизведение приветствия"""
        try:
            url = f"{self.ari_url}/ari/channels/{channel_id}/play"
            data = {"media": "sound:hello-world"}
            
            async with self.session.post(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password),
                json=data
            ) as response:
                if response.status == 201:
                    logger.info(f"🎵 Приветствие воспроизводится для {channel_id}")
                else:
                    logger.error(f"❌ Ошибка воспроизведения: {response.status}")
        except Exception as e:
            logger.error(f"Ошибка воспроизведения: {e}")
    
    async def simulate_ai_conversation(self, channel_id: str):
        """Имитация ИИ разговора"""
        try:
            logger.info(f"🤖 Имитация ИИ разговора для {channel_id}")
            
            # Ждем 10 секунд для демонстрации
            await asyncio.sleep(10)
            
            # Завершаем звонок
            await self.hangup_channel(channel_id)
            
        except Exception as e:
            logger.error(f"Ошибка имитации разговора: {e}")
    
    async def hangup_channel(self, channel_id: str):
        """Завершение звонка"""
        try:
            url = f"{self.ari_url}/ari/channels/{channel_id}"
            async with self.session.delete(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password)
            ) as response:
                if response.status == 204:
                    logger.info(f"📞 Канал {channel_id} завершен")
        except Exception as e:
            logger.error(f"Ошибка завершения канала: {e}")
    
    async def cleanup(self):
        """Очистка ресурсов"""
        logger.info("🧹 Завершение работы главного агента...")
        
        self.running = False
        
        # Закрываем WebSocket
        if self.ari_ws:
            await self.ari_ws.close()
        
        # Закрываем HTTP сессию
        if self.session:
            await self.session.close()
        
        logger.info("✅ Главный агент остановлен")

async def main():
    """Основная функция"""
    agent = MainAgent()
    
    try:
        await agent.start()
    except KeyboardInterrupt:
        logger.info("🛑 Получен сигнал прерывания")
    except Exception as e:
        logger.error(f"💥 Критическая ошибка: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
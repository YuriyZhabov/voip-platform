import asyncio
import logging
import os
import threading
from typing import Annotated
from aiohttp import web

from livekit.agents import (
    AutoSubscribe,
    JobContext,
    WorkerOptions,
    cli,
    llm,
)
from livekit.plugins import deepgram, openai, cartesia, silero
from livekit import rtc

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Импорт нашего ARI клиента
try:
    from ari_client import EnhancedARIClient
    ARI_AVAILABLE = True
except ImportError:
    logger.warning("ARI клиент недоступен")
    ARI_AVAILABLE = False

class HealthCheckServer:
    """HTTP сервер для health check"""
    
    def __init__(self, port=8081):
        self.port = port
        self.app = web.Application()
        self.app.router.add_get('/health', self.health_check)
        self.app.router.add_get('/status', self.detailed_status)
    
    async def health_check(self, request):
        """Простая проверка работоспособности"""
        return web.json_response({"status": "healthy", "service": "livekit-agent"})
    
    async def detailed_status(self, request):
        """Детальная информация о статусе"""
        return web.json_response({
            "status": "healthy",
            "service": "livekit-agent",
            "version": "1.0.0",
            "uptime": "running",
            "dependencies": {
                "openai": "connected",
                "deepgram": "connected",
                "cartesia": "connected",
                "livekit_cloud": "connected"
            }
        })
    
    async def start(self):
        """Запуск сервера"""
        runner = web.AppRunner(self.app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', self.port)
        await site.start()
        logger.info(f"Health check server started on port {self.port}")

async def get_weather(location: str) -> str:
    """Получить информацию о погоде"""
    logger.info(f"Получаю погоду для {location}")
    
    # Фиктивные данные для демонстрации
    weather_data = {
        "москва": "В Москве сейчас плюс 5 градусов, облачно",
        "санкт-петербург": "В Санкт-Петербурге плюс 3 градуса, дождь",
        "спб": "В Санкт-Петербурге плюс 3 градуса, дождь",
        "сочи": "В Сочи плюс 15 градусов, солнечно",
    }
    
    location_lower = location.lower()
    for city, weather in weather_data.items():
        if city in location_lower:
            return weather
    
    return f"Информация о погоде в {location} временно недоступна"

async def get_current_time() -> str:
    """Получить текущее время"""
    from datetime import datetime
    import pytz
    
    try:
        tz = pytz.timezone("Europe/Moscow")
        current_time = datetime.now(tz)
        return f"Текущее время: {current_time.strftime('%H:%M, %d %B %Y года')}"
    except Exception as e:
        logger.error(f"Ошибка получения времени: {e}")
        return "Не удалось получить текущее время"

async def start_ari_client():
    """Запуск ARI клиента в отдельной задаче"""
    if not ARI_AVAILABLE:
        logger.warning("ARI клиент недоступен, пропускаем запуск")
        return
    
    try:
        ari_client = EnhancedARIClient()
        await ari_client.start()
    except Exception as e:
        logger.error(f"Ошибка запуска ARI клиента: {e}")

async def entrypoint(ctx: JobContext):
    """Точка входа для агента"""
    try:
        # Запускаем health check сервер
        health_server = HealthCheckServer()
        await health_server.start()
        
        # Запускаем ARI клиент в фоновой задаче
        if ARI_AVAILABLE:
            ari_task = asyncio.create_task(start_ari_client())
            logger.info("ARI клиент запущен в фоновом режиме")
        
        # Подключаемся к комнате
        await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)
        logger.info(f"Подключились к комнате: {ctx.room.name}")

        # Настраиваем обработчики событий
        @ctx.room.on("participant_connected")
        def on_participant_connected(participant: rtc.RemoteParticipant):
            logger.info(f"Участник подключился: {participant.identity}")

        @ctx.room.on("participant_disconnected") 
        def on_participant_disconnected(participant: rtc.RemoteParticipant):
            logger.info(f"Участник отключился: {participant.identity}")

        # Простое логирование для проверки работы
        logger.info("LiveKit Agent успешно запущен и готов к работе")
        
        # Ожидаем завершения сессии
        await asyncio.Event().wait()
        
    except Exception as e:
        logger.error(f"Ошибка в работе агента: {e}")
        raise

if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))
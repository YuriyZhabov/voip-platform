import asyncio
import logging
import os
import datetime
from typing import Annotated
from aiohttp import web

from livekit.agents import (
    AutoSubscribe,
    JobContext,
    WorkerOptions,
    cli,
    llm,
    AgentSession,
    Agent,
)
from livekit.plugins import deepgram, openai, cartesia, silero
from livekit import rtc, api

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

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

async def entrypoint(ctx: JobContext):
    """Точка входа для агента"""
    try:
        # Запускаем health check сервер
        health_server = HealthCheckServer()
        await health_server.start()
        
        # Генерируем JWT токен для авторизации
        api_key = os.getenv("LIVEKIT_API_KEY")
        api_secret = os.getenv("LIVEKIT_API_SECRET")
        
        if not api_key or not api_secret:
            logger.error("LIVEKIT_API_KEY или LIVEKIT_API_SECRET не установлены")
            raise ValueError("Отсутствуют необходимые переменные окружения для LiveKit")
        
        logger.info(f"Генерация JWT токена для LiveKit с API ключом: {api_key[:5]}...")
        
        # Создаем токен с правами на подключение к комнате
        video_grants = api.VideoGrants(
            room_join=True,
            room="test",  # Имя комнаты, к которой подключаемся
            can_publish=True,
            can_subscribe=True,
            can_publish_data=True
        )
        
        token = (
            api.AccessToken(api_key=api_key, api_secret=api_secret)
            .with_identity("livekit-agent")
            .with_name("LiveKit Voice Agent")
            .with_ttl(datetime.timedelta(hours=6))
            .with_grants(video_grants)
            .to_jwt()
        )
        
        logger.info(f"JWT токен успешно сгенерирован: {token[:20]}...")
        
        # Устанавливаем токен в переменную окружения для использования в SDK
        os.environ["LIVEKIT_TOKEN"] = token
        
        # 1. Подключаемся к комнате как участник-бот с токеном
        await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY, token=token)
        logger.info(f"Подключились к комнате: {ctx.room.name}")
        
        # Ждем первого участника
        participant = await ctx.wait_for_participant()
        logger.info(f"Участник подключился: {participant.identity}")

        # 2. Создаём сессию с моделями
        session = AgentSession(
            stt=deepgram.STT(),                        # распознавание речи
            llm=openai.realtime.RealtimeModel(voice="alloy"),
            tts=cartesia.TTS(),                        # озвучка
        )

        # Инструкции для агента
        instructions = """
        Ты доброжелательный голосовой ассистент компании. 
        Ты можешь помочь с информацией о погоде и текущем времени.
        Отвечай кратко и по делу, но всегда вежливо.
        Если тебя спрашивают о погоде, используй функцию get_weather.
        Если тебя спрашивают о времени, используй функцию get_current_time.
        """

        # Определение инструментов
        tools = [
            {
                "type": "function",
                "function": {
                    "name": "get_weather",
                    "description": "Получить информацию о погоде в указанном месте",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "location": {
                                "type": "string",
                                "description": "Название города или места"
                            }
                        },
                        "required": ["location"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "get_current_time",
                    "description": "Получить текущее время",
                    "parameters": {
                        "type": "object",
                        "properties": {}
                    }
                }
            }
        ]

        # 3. Запускаем агента с инструкциями
        agent = Agent(instructions=instructions)
        
        # Обработчик вызова инструментов
        @agent.on("tool_called")
        async def on_tool_called(tool_call):
            logger.info(f"Вызов инструмента: {tool_call.name}")
            
            if tool_call.name == "get_weather":
                location = tool_call.arguments.get("location", "")
                result = await get_weather(location)
                await tool_call.respond(result)
            
            elif tool_call.name == "get_current_time":
                result = await get_current_time()
                await tool_call.respond(result)
            
            else:
                await tool_call.respond("Инструмент не найден")
        
        # Запускаем сессию
        await session.start(
            room=ctx.room,
            agent=agent,
        )

        # 4. Приветственное сообщение
        await session.generate_reply(instructions="Поздоровайся и спроси, чем помочь.")
        
        # Ожидаем завершения сессии
        await asyncio.Event().wait()
        
    except Exception as e:
        logger.error(f"Ошибка в работе агента: {e}")
        raise

if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))
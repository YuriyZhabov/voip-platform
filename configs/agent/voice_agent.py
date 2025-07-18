import asyncio
import logging
import os
from typing import Annotated

from livekit.agents import (
    AutoSubscribe,
    JobContext,
    WorkerOptions,
    cli,
    llm,
)
from livekit.agents.voice_assistant import VoiceAssistant
from livekit.plugins import deepgram, openai, cartesia, silero
from livekit import rtc

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

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
    """Точка входа для голосового агента"""
    try:
        # Подключаемся к комнате
        await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)
        logger.info(f"Подключились к комнате: {ctx.room.name}")

        # Настраиваем LLM
        initial_ctx = llm.ChatContext().append(
            role="system",
            text=(
                "Вы - дружелюбный голосовой помощник. "
                "Отвечайте кратко и по делу на русском языке. "
                "Вы можете помочь с информацией о погоде и времени. "
                "Будьте вежливы и полезны."
            ),
        )

        # Создаем голосового ассистента
        assistant = VoiceAssistant(
            vad=silero.VAD.load(),  # Детектор голосовой активности
            stt=deepgram.STT(),     # Распознавание речи
            llm=openai.LLM(),       # Языковая модель
            tts=cartesia.TTS(),     # Синтез речи
            chat_ctx=initial_ctx,
        )

        # Добавляем функции
        assistant.fnc_ctx.ai_functions.extend([
            llm.FunctionContext(
                get_weather,
                description="Получить информацию о погоде в указанном городе",
            ),
            llm.FunctionContext(
                get_current_time,
                description="Получить текущее время",
            ),
        ])

        # Запускаем ассистента
        assistant.start(ctx.room)
        logger.info("Голосовой ассистент запущен")

        # Приветствие при подключении участника
        @ctx.room.on("participant_connected")
        def on_participant_connected(participant: rtc.RemoteParticipant):
            logger.info(f"Участник подключился: {participant.identity}")
            # Отправляем приветствие
            asyncio.create_task(
                assistant.say("Привет! Я ваш голосовой помощник. Чем могу помочь?")
            )

        @ctx.room.on("participant_disconnected") 
        def on_participant_disconnected(participant: rtc.RemoteParticipant):
            logger.info(f"Участник отключился: {participant.identity}")

        # Ожидаем завершения сессии
        await asyncio.Event().wait()
        
    except Exception as e:
        logger.error(f"Ошибка в работе голосового агента: {e}")
        raise

if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))
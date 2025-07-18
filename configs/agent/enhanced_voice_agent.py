#!/usr/bin/env python3
"""
Улучшенный голосовой ИИ агент для работы с телефонными звонками
Интегрируется с Asterisk через ARI и обеспечивает полноценное голосовое взаимодействие
"""

import asyncio
import logging
import os
import json
from typing import Dict, Optional, Annotated
from datetime import datetime
import pytz

from livekit.agents import (
    AutoSubscribe,
    JobContext,
    WorkerOptions,
    cli,
    llm,
)
from livekit.agents.voice_assistant import VoiceAssistant
from livekit.plugins import deepgram, openai, cartesia, silero
from livekit import rtc, api

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class EnhancedVoiceAgent:
    """Улучшенный голосовой ИИ агент"""
    
    def __init__(self):
        self.active_assistants: Dict[str, VoiceAssistant] = {}
        self.room_contexts: Dict[str, Dict] = {}
        
    async def create_assistant_for_call(self, room_name: str, caller_id: str) -> VoiceAssistant:
        """Создание ассистента для конкретного звонка"""
        
        # Создаем персонализированный контекст
        chat_context = self.create_personalized_context(caller_id)
        
        # Создаем голосового ассистента
        assistant = VoiceAssistant(
            vad=silero.VAD.load(
                # Настройки для телефонного качества звука
                min_silence_duration=0.5,  # Минимальная пауза для определения конца речи
                min_speaking_duration=0.3,  # Минимальная длительность речи
            ),
            stt=deepgram.STT(
                # Оптимизация для русского языка и телефонного качества
                model="nova-2-phonecall",  # Модель для телефонных звонков
                language="ru",
                smart_format=True,
                punctuate=True,
                diarize=False,  # Отключаем диаризацию для одного говорящего
            ),
            llm=openai.LLM(
                model="gpt-4o-mini",
                temperature=0.7,
                max_tokens=150,  # Ограничиваем для быстрых ответов
            ),
            tts=cartesia.TTS(
                model="sonic-multilingual",
                language="ru",
                voice="87748186-23bb-4158-a1eb-332911b0b708",  # Русский голос
                speed=1.0,
                emotion=["friendly", "helpful"],
            ),
            chat_ctx=chat_context,
        )
        
        # Добавляем функции ассистента
        self.add_assistant_functions(assistant)
        
        # Сохраняем ассистента
        self.active_assistants[room_name] = assistant
        
        return assistant
    
    def create_personalized_context(self, caller_id: str) -> llm.ChatContext:
        """Создание персонализированного контекста для звонящего"""
        
        # Определяем время суток для приветствия
        moscow_tz = pytz.timezone('Europe/Moscow')
        current_time = datetime.now(moscow_tz)
        hour = current_time.hour
        
        if 6 <= hour < 12:
            greeting_time = "Доброе утро"
        elif 12 <= hour < 18:
            greeting_time = "Добрый день"
        elif 18 <= hour < 23:
            greeting_time = "Добрый вечер"
        else:
            greeting_time = "Доброй ночи"
        
        # Создаем контекст
        context = llm.ChatContext().append(
            role="system",
            text=(
                f"Вы - дружелюбный русскоговорящий ИИ ассистент компании Stellar Agents. "
                f"Сейчас {current_time.strftime('%H:%M, %d %B %Y года')}. "
                f"Вы разговариваете с абонентом {caller_id}. "
                f"Начните разговор с '{greeting_time}!'. "
                f"\nВаши возможности:\n"
                f"- Отвечать на общие вопросы\n"
                f"- Предоставлять информацию о погоде\n"
                f"- Сообщать текущее время\n"
                f"- Помогать с простыми задачами\n"
                f"- Поддерживать дружескую беседу\n"
                f"\nПравила общения:\n"
                f"- Говорите только на русском языке\n"
                f"- Отвечайте кратко и по делу (максимум 2-3 предложения)\n"
                f"- Будьте вежливы и дружелюбны\n"
                f"- Если не знаете ответ, честно скажите об этом\n"
                f"- Не используйте технические термины\n"
                f"- Говорите естественно, как живой человек\n"
            )
        )
        
        return context
    
    def add_assistant_functions(self, assistant: VoiceAssistant):
        """Добавление функций ассистенту"""
        
        # Функция получения погоды
        assistant.fnc_ctx.ai_functions.append(
            llm.FunctionContext(
                self.get_weather,
                description="Получить информацию о погоде в указанном городе России",
            )
        )
        
        # Функция получения времени
        assistant.fnc_ctx.ai_functions.append(
            llm.FunctionContext(
                self.get_current_time,
                description="Получить текущее время в Москве",
            )
        )
        
        # Функция получения информации о компании
        assistant.fnc_ctx.ai_functions.append(
            llm.FunctionContext(
                self.get_company_info,
                description="Получить информацию о компании Stellar Agents",
            )
        )
        
        # Функция завершения звонка
        assistant.fnc_ctx.ai_functions.append(
            llm.FunctionContext(
                self.end_call,
                description="Завершить звонок по просьбе пользователя",
            )
        )
    
    async def get_weather(self, city: Annotated[str, "Название города"]) -> str:
        """Получить информацию о погоде"""
        logger.info(f"Запрос погоды для города: {city}")
        
        # Данные о погоде (в реальной системе здесь был бы API вызов)
        weather_data = {
            "москва": "В Москве сейчас +2°C, облачно с прояснениями, ветер 3 м/с",
            "санкт-петербург": "В Санкт-Петербурге +1°C, небольшой дождь, ветер 5 м/с", 
            "спб": "В Санкт-Петербурге +1°C, небольшой дождь, ветер 5 м/с",
            "екатеринбург": "В Екатеринбурге -5°C, ясно, ветер 2 м/с",
            "новосибирск": "В Новосибирске -8°C, снег, ветер 4 м/с",
            "казань": "В Казани -2°C, облачно, ветер 3 м/с",
            "нижний новгород": "В Нижнем Новгороде 0°C, туман, ветер 1 м/с",
            "сочи": "В Сочи +12°C, солнечно, ветер 2 м/с",
            "краснодар": "В Краснодаре +8°C, переменная облачность, ветер 3 м/с",
        }
        
        city_lower = city.lower().strip()
        
        # Поиск города в данных
        for city_key, weather_info in weather_data.items():
            if city_key in city_lower or city_lower in city_key:
                return weather_info
        
        return f"К сожалению, у меня нет актуальной информации о погоде в городе {city}. Попробуйте спросить о Москве, Санкт-Петербурге или других крупных городах России."
    
    async def get_current_time(self) -> str:
        """Получить текущее время"""
        try:
            moscow_tz = pytz.timezone('Europe/Moscow')
            current_time = datetime.now(moscow_tz)
            
            # Форматируем время по-русски
            months = [
                "января", "февраля", "марта", "апреля", "мая", "июня",
                "июля", "августа", "сентября", "октября", "ноября", "декабря"
            ]
            
            weekdays = [
                "понедельник", "вторник", "среда", "четверг", 
                "пятница", "суббота", "воскресенье"
            ]
            
            month_name = months[current_time.month - 1]
            weekday_name = weekdays[current_time.weekday()]
            
            time_str = (
                f"Сейчас {current_time.strftime('%H:%M')}, "
                f"{weekday_name}, {current_time.day} {month_name} "
                f"{current_time.year} года"
            )
            
            return time_str
            
        except Exception as e:
            logger.error(f"Ошибка получения времени: {e}")
            return "Извините, не могу получить текущее время"
    
    async def get_company_info(self) -> str:
        """Получить информацию о компании"""
        return (
            "Stellar Agents - это инновационная компания, специализирующаяся на "
            "разработке ИИ решений для бизнеса. Мы создаем умных голосовых "
            "ассистентов и автоматизируем процессы обслуживания клиентов."
        )
    
    async def end_call(self, reason: Annotated[str, "Причина завершения звонка"] = "По просьбе пользователя") -> str:
        """Завершить звонок"""
        logger.info(f"Запрос на завершение звонка: {reason}")
        return "Хорошо, завершаю звонок. До свидания и хорошего дня!"

# Основная функция для запуска агента
async def entrypoint(ctx: JobContext):
    """Точка входа для улучшенного голосового агента"""
    try:
        logger.info(f"🚀 Запуск улучшенного голосового агента для комнаты: {ctx.room.name}")
        
        # Подключаемся к комнате
        await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)
        
        # Извлекаем информацию о звонящем из имени комнаты
        room_name = ctx.room.name
        caller_id = "Unknown"
        
        # Пытаемся извлечь caller_id из имени комнаты (формат: call-{channel_id}-{caller_id})
        if room_name.startswith("call-"):
            parts = room_name.split("-")
            if len(parts) >= 3:
                caller_id = parts[2]
        
        # Создаем агента
        agent = EnhancedVoiceAgent()
        assistant = await agent.create_assistant_for_call(room_name, caller_id)
        
        # Запускаем ассистента
        assistant.start(ctx.room)
        
        logger.info(f"✅ Голосовой ассистент запущен для звонящего: {caller_id}")
        
        # Обработчики событий комнаты
        @ctx.room.on("participant_connected")
        def on_participant_connected(participant: rtc.RemoteParticipant):
            logger.info(f"👤 Участник подключился: {participant.identity}")
            
            # Приветствие при подключении
            asyncio.create_task(
                assistant.say("Привет! Я ваш ИИ ассистент. Чем могу помочь?")
            )
        
        @ctx.room.on("participant_disconnected")
        def on_participant_disconnected(participant: rtc.RemoteParticipant):
            logger.info(f"👋 Участник отключился: {participant.identity}")
        
        # Ожидаем завершения сессии
        await asyncio.Event().wait()
        
    except Exception as e:
        logger.error(f"❌ Ошибка в работе голосового агента: {e}")
        raise
    finally:
        logger.info("🏁 Голосовой агент завершил работу")

if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))
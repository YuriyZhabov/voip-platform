#!/usr/bin/env python3
"""
Прямой агент для архитектуры B
Интеграция Asterisk → Direct Python Agent → AI Services
Без промежуточных слоев (ARI/LiveKit)
"""

import asyncio
import logging
import os
import sys
from typing import Optional, Dict, Any
import json
import websockets
import aiohttp
from datetime import datetime

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/logs/direct_agent.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class DirectVoIPAgent:
    """
    Прямой VoIP агент без промежуточных слоев
    Упрощенная архитектура для быстрого развертывания
    """
    
    def __init__(self):
        self.config = self._load_config()
        self.asterisk_host = os.getenv('ASTERISK_HOST', 'asterisk-test-b')
        self.asterisk_port = int(os.getenv('ASTERISK_AMI_PORT', '5038'))
        self.ami_username = os.getenv('AMI_USERNAME', 'admin')
        self.ami_secret = os.getenv('AMI_SECRET', 'amp111')
        
        # AI сервисы
        self.openai_key = os.getenv('OPENAI_TEST_API_KEY')
        self.deepgram_key = os.getenv('DEEPGRAM_TEST_API_KEY')
        
        # Состояние
        self.active_calls: Dict[str, Dict] = {}
        self.ami_connection: Optional[websockets.WebSocketServerProtocol] = None
        
    def _load_config(self) -> Dict[str, Any]:
        """Загрузка конфигурации"""
        return {
            'max_concurrent_calls': int(os.getenv('MAX_CONCURRENT_CALLS', '10')),
            'response_timeout': int(os.getenv('RESPONSE_TIMEOUT', '30')),
            'audio_format': os.getenv('AUDIO_FORMAT', 'wav'),
            'language': os.getenv('LANGUAGE', 'ru'),
            'ai_model': os.getenv('AI_MODEL', 'gpt-4o-mini'),
            'voice_model': os.getenv('VOICE_MODEL', 'nova-2')
        }
    
    async def start(self):
        """Запуск агента"""
        logger.info("Запуск Direct VoIP Agent (Архитектура B)")
        logger.info(f"Конфигурация: {self.config}")
        
        try:
            # Подключение к Asterisk AMI
            await self._connect_ami()
            
            # Запуск обработчиков
            await asyncio.gather(
                self._ami_event_handler(),
                self._health_check_loop(),
                self._cleanup_loop()
            )
            
        except Exception as e:
            logger.error(f"Ошибка запуска агента: {e}")
            raise
    
    async def _connect_ami(self):
        """Подключение к Asterisk Manager Interface"""
        logger.info(f"Подключение к Asterisk AMI: {self.asterisk_host}:{self.asterisk_port}")
        
        try:
            # Здесь должна быть реальная реализация AMI подключения
            # Для демонстрации используем заглушку
            logger.info("✓ AMI подключение установлено")
            
        except Exception as e:
            logger.error(f"Ошибка подключения к AMI: {e}")
            raise
    
    async def _ami_event_handler(self):
        """Обработчик событий AMI"""
        logger.info("Запуск обработчика AMI событий")
        
        while True:
            try:
                # Симуляция получения событий от Asterisk
                await asyncio.sleep(1)
                
                # Здесь должна быть реальная обработка AMI событий:
                # - Newchannel (новый канал)
                # - Hangup (завершение звонка)
                # - DialBegin/DialEnd (начало/конец набора)
                # - Bridge (соединение каналов)
                
            except Exception as e:
                logger.error(f"Ошибка в обработчике AMI: {e}")
                await asyncio.sleep(5)
    
    async def handle_incoming_call(self, call_id: str, caller_number: str):
        """Обработка входящего звонка"""
        logger.info(f"Входящий звонок: {call_id} от {caller_number}")
        
        if len(self.active_calls) >= self.config['max_concurrent_calls']:
            logger.warning(f"Превышен лимит звонков: {len(self.active_calls)}")
            await self._reject_call(call_id)
            return
        
        # Создание сессии звонка
        call_session = {
            'call_id': call_id,
            'caller_number': caller_number,
            'start_time': datetime.now(),
            'status': 'active',
            'conversation_history': []
        }
        
        self.active_calls[call_id] = call_session
        
        try:
            # Ответ на звонок
            await self._answer_call(call_id)
            
            # Приветствие
            await self._play_greeting(call_id)
            
            # Запуск обработки диалога
            await self._start_conversation(call_id)
            
        except Exception as e:
            logger.error(f"Ошибка обработки звонка {call_id}: {e}")
            await self._hangup_call(call_id)
    
    async def _answer_call(self, call_id: str):
        """Ответ на звонок"""
        logger.info(f"Отвечаем на звонок: {call_id}")
        
        # Команда Asterisk для ответа на звонок
        # Здесь должна быть реальная реализация через AMI
        await asyncio.sleep(0.1)  # Симуляция
        
    async def _play_greeting(self, call_id: str):
        """Воспроизведение приветствия"""
        greeting_text = "Здравствуйте! Это голосовой помощник. Чем могу помочь?"
        
        logger.info(f"Приветствие для звонка {call_id}: {greeting_text}")
        
        # Синтез речи и воспроизведение
        audio_file = await self._text_to_speech(greeting_text)
        await self._play_audio(call_id, audio_file)
    
    async def _start_conversation(self, call_id: str):
        """Запуск диалога с пользователем"""
        logger.info(f"Начало диалога для звонка: {call_id}")
        
        call_session = self.active_calls.get(call_id)
        if not call_session:
            return
        
        try:
            while call_session['status'] == 'active':
                # Ожидание речи пользователя
                user_speech = await self._listen_for_speech(call_id)
                
                if not user_speech:
                    continue
                
                # Распознавание речи
                user_text = await self._speech_to_text(user_speech)
                
                if not user_text:
                    await self._play_audio(call_id, "Извините, не расслышал. Повторите, пожалуйста.")
                    continue
                
                logger.info(f"Пользователь сказал: {user_text}")
                call_session['conversation_history'].append({
                    'role': 'user',
                    'content': user_text,
                    'timestamp': datetime.now()
                })
                
                # Генерация ответа через AI
                ai_response = await self._generate_ai_response(call_session['conversation_history'])
                
                if ai_response:
                    logger.info(f"AI ответ: {ai_response}")
                    call_session['conversation_history'].append({
                        'role': 'assistant',
                        'content': ai_response,
                        'timestamp': datetime.now()
                    })
                    
                    # Синтез и воспроизведение ответа
                    audio_file = await self._text_to_speech(ai_response)
                    await self._play_audio(call_id, audio_file)
                
                # Проверка на завершение разговора
                if any(word in user_text.lower() for word in ['до свидания', 'пока', 'завершить']):
                    await self._end_conversation(call_id)
                    break
                    
        except Exception as e:
            logger.error(f"Ошибка в диалоге {call_id}: {e}")
            await self._hangup_call(call_id)
    
    async def _listen_for_speech(self, call_id: str) -> Optional[bytes]:
        """Ожидание речи от пользователя"""
        # Здесь должна быть реальная реализация записи аудио через Asterisk
        await asyncio.sleep(2)  # Симуляция ожидания
        return b"fake_audio_data"  # Заглушка
    
    async def _speech_to_text(self, audio_data: bytes) -> Optional[str]:
        """Распознавание речи"""
        if not self.deepgram_key:
            logger.warning("Deepgram API ключ не настроен")
            return "Тестовый текст"  # Заглушка для тестирования
        
        try:
            # Здесь должна быть интеграция с Deepgram API
            logger.info("Распознавание речи через Deepgram")
            await asyncio.sleep(0.5)  # Симуляция обработки
            return "Тестовый распознанный текст"
            
        except Exception as e:
            logger.error(f"Ошибка распознавания речи: {e}")
            return None
    
    async def _generate_ai_response(self, conversation_history: list) -> Optional[str]:
        """Генерация ответа через AI"""
        if not self.openai_key:
            logger.warning("OpenAI API ключ не настроен")
            return "Это тестовый ответ от AI агента."
        
        try:
            # Подготовка контекста для AI
            messages = [
                {"role": "system", "content": "Вы - вежливый голосовой помощник. Отвечайте кратко и по делу."}
            ]
            
            for msg in conversation_history[-10:]:  # Последние 10 сообщений
                messages.append({
                    "role": msg['role'],
                    "content": msg['content']
                })
            
            # Здесь должна быть интеграция с OpenAI API
            logger.info("Генерация ответа через OpenAI")
            await asyncio.sleep(1)  # Симуляция обработки
            
            return "Понял вас. Это ответ от AI помощника в упрощенной архитектуре."
            
        except Exception as e:
            logger.error(f"Ошибка генерации AI ответа: {e}")
            return "Извините, произошла ошибка. Попробуйте еще раз."
    
    async def _text_to_speech(self, text: str) -> str:
        """Синтез речи"""
        logger.info(f"Синтез речи: {text[:50]}...")
        
        # Здесь должна быть интеграция с TTS сервисом
        await asyncio.sleep(0.3)  # Симуляция синтеза
        
        # Возвращаем путь к аудио файлу
        return f"/tmp/tts_{hash(text)}.wav"
    
    async def _play_audio(self, call_id: str, audio_file: str):
        """Воспроизведение аудио"""
        logger.info(f"Воспроизведение аудио для звонка {call_id}: {audio_file}")
        
        # Команда Asterisk для воспроизведения аудио
        await asyncio.sleep(1)  # Симуляция воспроизведения
    
    async def _end_conversation(self, call_id: str):
        """Завершение разговора"""
        logger.info(f"Завершение разговора: {call_id}")
        
        farewell = "До свидания! Хорошего дня!"
        audio_file = await self._text_to_speech(farewell)
        await self._play_audio(call_id, audio_file)
        
        await asyncio.sleep(2)
        await self._hangup_call(call_id)
    
    async def _hangup_call(self, call_id: str):
        """Завершение звонка"""
        logger.info(f"Завершение звонка: {call_id}")
        
        if call_id in self.active_calls:
            call_session = self.active_calls[call_id]
            call_session['status'] = 'ended'
            call_session['end_time'] = datetime.now()
            
            # Логирование статистики
            duration = call_session['end_time'] - call_session['start_time']
            logger.info(f"Статистика звонка {call_id}: длительность {duration}")
            
            del self.active_calls[call_id]
        
        # Команда Asterisk для завершения звонка
        await asyncio.sleep(0.1)
    
    async def _reject_call(self, call_id: str):
        """Отклонение звонка"""
        logger.info(f"Отклонение звонка: {call_id}")
        # Команда Asterisk для отклонения звонка
    
    async def _health_check_loop(self):
        """Цикл проверки здоровья системы"""
        while True:
            try:
                await asyncio.sleep(30)
                
                # Проверка состояния
                active_calls_count = len(self.active_calls)
                logger.info(f"Health check: активных звонков: {active_calls_count}")
                
                # Проверка подключения к Asterisk
                # Здесь должна быть реальная проверка AMI соединения
                
            except Exception as e:
                logger.error(f"Ошибка в health check: {e}")
    
    async def _cleanup_loop(self):
        """Цикл очистки устаревших данных"""
        while True:
            try:
                await asyncio.sleep(300)  # Каждые 5 минут
                
                # Очистка завершенных звонков старше 1 часа
                current_time = datetime.now()
                to_remove = []
                
                for call_id, session in self.active_calls.items():
                    if session['status'] == 'ended':
                        if (current_time - session.get('end_time', current_time)).seconds > 3600:
                            to_remove.append(call_id)
                
                for call_id in to_remove:
                    del self.active_calls[call_id]
                    logger.info(f"Очищена сессия звонка: {call_id}")
                
            except Exception as e:
                logger.error(f"Ошибка в cleanup: {e}")

async def main():
    """Главная функция"""
    agent = DirectVoIPAgent()
    
    try:
        await agent.start()
    except KeyboardInterrupt:
        logger.info("Получен сигнал остановки")
    except Exception as e:
        logger.error(f"Критическая ошибка: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
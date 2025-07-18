#!/usr/bin/env python3
"""
Аудио мост между Asterisk и LiveKit
Обеспечивает передачу аудио потока в реальном времени
"""

import asyncio
import logging
import json
import os
import websockets
import aiohttp
from typing import Dict, Optional
from livekit import api, rtc
from livekit.agents import JobContext, WorkerOptions, cli
from livekit.agents.voice_assistant import VoiceAssistant
from livekit.plugins import deepgram, openai, cartesia, silero

logger = logging.getLogger(__name__)

class AudioBridge:
    """Мост для передачи аудио между Asterisk и LiveKit"""
    
    def __init__(self):
        self.ari_url = os.getenv('ARI_URL', 'http://freepbx-server:8088')
        self.ari_username = os.getenv('ARI_USERNAME', 'livekit-agent')
        self.ari_password = os.getenv('ARI_PASSWORD', 'livekit_ari_secret')
        
        # LiveKit настройки
        self.livekit_url = os.getenv('LIVEKIT_URL')
        self.livekit_api_key = os.getenv('LIVEKIT_API_KEY')
        self.livekit_api_secret = os.getenv('LIVEKIT_API_SECRET')
        
        # Активные каналы и комнаты
        self.active_channels: Dict[str, Dict] = {}
        self.active_rooms: Dict[str, rtc.Room] = {}
        
        # WebSocket соединения
        self.ari_ws = None
        self.session = None
        
    async def start(self):
        """Запуск аудио моста"""
        logger.info("🌉 Запуск аудио моста Asterisk <-> LiveKit")
        
        try:
            self.session = aiohttp.ClientSession()
            await self.connect_to_ari()
            
        except Exception as e:
            logger.error(f"Ошибка запуска аудио моста: {e}")
            raise
    
    async def connect_to_ari(self):
        """Подключение к Asterisk ARI"""
        ws_url = f"{self.ari_url}/ari/events"
        params = {
            'api_key': self.ari_username,
            'api_secret': self.ari_password,
            'app': 'livekit-agent'
        }
        
        logger.info(f"🔌 Подключение к ARI: {ws_url}")
        
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
        """Обработка событий от Asterisk ARI"""
        logger.info("👂 Начало прослушивания ARI событий...")
        
        try:
            async for msg in self.ari_ws:
                if msg.type == aiohttp.WSMsgType.TEXT:
                    try:
                        event = json.loads(msg.data)
                        await self.process_ari_event(event)
                    except Exception as e:
                        logger.error(f"Ошибка обработки ARI события: {e}")
                        
        except Exception as e:
            logger.error(f"Ошибка в обработке ARI событий: {e}")
    
    async def process_ari_event(self, event: Dict):
        """Обработка конкретного ARI события"""
        event_type = event.get('type')
        
        if event_type == 'StasisStart':
            await self.handle_call_start(event)
        elif event_type == 'StasisEnd':
            await self.handle_call_end(event)
        elif event_type == 'ChannelStateChange':
            await self.handle_channel_state_change(event)
    
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
        
        # Создаем LiveKit комнату и запускаем ИИ агента
        await self.create_livekit_room_for_call(channel_id, caller_id)
    
    async def answer_channel(self, channel_id: str):
        """Ответ на входящий звонок"""
        try:
            url = f"{self.ari_url}/ari/channels/{channel_id}/answer"
            
            async with self.session.post(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password)
            ) as response:
                if response.status == 204:
                    logger.info(f"✅ Канал {channel_id} отвечен")
                else:
                    logger.error(f"❌ Ошибка ответа на канал {channel_id}: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка при ответе на канал {channel_id}: {e}")
    
    async def create_livekit_room_for_call(self, channel_id: str, caller_id: str):
        """Создание LiveKit комнаты для звонка"""
        try:
            room_name = f"call-{channel_id}"
            
            logger.info(f"🏠 Создание LiveKit комнаты: {room_name}")
            
            # Создаем комнату через LiveKit API
            room_service = api.RoomService()
            room_info = await room_service.create_room(
                api.CreateRoomRequest(name=room_name)
            )
            
            logger.info(f"✅ LiveKit комната создана: {room_name}")
            
            # Создаем аудио мост между Asterisk и LiveKit
            await self.setup_audio_bridge(channel_id, room_name)
            
            # Запускаем ИИ агента для этой комнаты
            await self.start_ai_agent_for_room(room_name, channel_id, caller_id)
            
        except Exception as e:
            logger.error(f"Ошибка создания LiveKit комнаты: {e}")
    
    async def setup_audio_bridge(self, channel_id: str, room_name: str):
        """Настройка аудио моста между Asterisk и LiveKit"""
        try:
            logger.info(f"🌉 Настройка аудио моста для канала {channel_id}")
            
            # Создаем внешний канал для передачи аудио в LiveKit
            external_channel_data = {
                "endpoint": f"Local/{room_name}@livekit-bridge",
                "app": "livekit-agent",
                "appArgs": f"bridge,{channel_id},{room_name}"
            }
            
            # Создаем внешний канал
            url = f"{self.ari_url}/ari/channels/externalMedia"
            async with self.session.post(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password),
                json=external_channel_data
            ) as response:
                if response.status == 201:
                    external_channel = await response.json()
                    external_channel_id = external_channel.get('id')
                    
                    logger.info(f"✅ Внешний канал создан: {external_channel_id}")
                    
                    # Создаем мост между каналами
                    await self.create_channel_bridge(channel_id, external_channel_id)
                    
                else:
                    logger.error(f"❌ Ошибка создания внешнего канала: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка настройки аудио моста: {e}")
    
    async def create_channel_bridge(self, channel1_id: str, channel2_id: str):
        """Создание моста между двумя каналами"""
        try:
            # Создаем мост
            bridge_data = {
                "type": "mixing",
                "name": f"bridge-{channel1_id}"
            }
            
            url = f"{self.ari_url}/ari/bridges"
            async with self.session.post(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password),
                json=bridge_data
            ) as response:
                if response.status == 201:
                    bridge = await response.json()
                    bridge_id = bridge.get('id')
                    
                    logger.info(f"🌉 Мост создан: {bridge_id}")
                    
                    # Добавляем каналы в мост
                    await self.add_channels_to_bridge(bridge_id, [channel1_id, channel2_id])
                    
                    # Сохраняем информацию о мосте
                    self.active_channels[channel1_id]['bridge_id'] = bridge_id
                    
                else:
                    logger.error(f"❌ Ошибка создания моста: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка создания моста каналов: {e}")
    
    async def add_channels_to_bridge(self, bridge_id: str, channel_ids: list):
        """Добавление каналов в мост"""
        try:
            for channel_id in channel_ids:
                url = f"{self.ari_url}/ari/bridges/{bridge_id}/addChannel"
                params = {"channel": channel_id}
                
                async with self.session.post(
                    url,
                    auth=aiohttp.BasicAuth(self.ari_username, self.ari_password),
                    params=params
                ) as response:
                    if response.status == 204:
                        logger.info(f"✅ Канал {channel_id} добавлен в мост {bridge_id}")
                    else:
                        logger.error(f"❌ Ошибка добавления канала {channel_id} в мост: {response.status}")
                        
        except Exception as e:
            logger.error(f"Ошибка добавления каналов в мост: {e}")
    
    async def start_ai_agent_for_room(self, room_name: str, channel_id: str, caller_id: str):
        """Запуск ИИ агента для конкретной комнаты"""
        try:
            logger.info(f"🤖 Запуск ИИ агента для комнаты {room_name}")
            
            # Создаем задачу для ИИ агента
            agent_task = asyncio.create_task(
                self.run_ai_agent(room_name, channel_id, caller_id)
            )
            
            # Сохраняем задачу для отслеживания
            self.active_channels[channel_id]['agent_task'] = agent_task
            
        except Exception as e:
            logger.error(f"Ошибка запуска ИИ агента: {e}")
    
    async def run_ai_agent(self, room_name: str, channel_id: str, caller_id: str):
        """Запуск ИИ агента в LiveKit комнате"""
        try:
            # Подключаемся к LiveKit комнате
            room = rtc.Room()
            
            # Настраиваем голосового ассистента с русскими настройками
            assistant = VoiceAssistant(
                vad=silero.VAD.load(),
                stt=deepgram.STT(
                    model="nova-2",
                    language="ru",
                    smart_format=True,
                    interim_results=True
                ),
                llm=openai.LLM(
                    model="gpt-4o-mini",
                    temperature=0.7
                ),
                tts=cartesia.TTS(
                    voice="87748186-23bb-4158-a1eb-332911b0b708",  # Русский голос
                    model="sonic-multilingual",
                    language="ru"
                ),
                chat_ctx=self.create_chat_context(caller_id)
            )
            
            # Добавляем функции для ИИ
            assistant.fnc_ctx.ai_functions.extend([
                self.create_weather_function(),
                self.create_time_function(),
                self.create_help_function()
            ])
            
            # Подключаемся к комнате
            await room.connect(
                url=self.livekit_url,
                token=self.generate_access_token(room_name, f"ai-agent-{channel_id}")
            )
            
            logger.info(f"🎤 ИИ агент подключен к комнате {room_name}")
            
            # Настраиваем обработчики событий комнаты
            @room.on("participant_connected")
            def on_participant_connected(participant: rtc.RemoteParticipant):
                logger.info(f"👤 Участник подключился: {participant.identity}")
            
            @room.on("participant_disconnected")
            def on_participant_disconnected(participant: rtc.RemoteParticipant):
                logger.info(f"👋 Участник отключился: {participant.identity}")
            
            @room.on("track_published")
            def on_track_published(publication: rtc.RemoteTrackPublication, participant: rtc.RemoteParticipant):
                logger.info(f"🎵 Трек опубликован: {publication.kind} от {participant.identity}")
            
            # Запускаем ассистента
            assistant.start(room)
            
            # Ждем небольшую паузу для инициализации
            await asyncio.sleep(2)
            
            # Приветствие на русском языке
            greeting_message = (
                f"Привет! Меня зовут Ассистент. "
                f"Я ваш голосовой помощник и готов помочь вам. "
                f"Вы можете спросить меня о погоде, времени или просто поговорить. "
                f"Как дела?"
            )
            
            await assistant.say(greeting_message)
            
            # Сохраняем комнату и ассистента
            self.active_rooms[channel_id] = {
                'room': room,
                'assistant': assistant,
                'start_time': asyncio.get_event_loop().time()
            }
            
            # Мониторинг активности звонка
            await self.monitor_call_activity(channel_id, room, assistant)
            
            logger.info(f"🏁 ИИ агент завершил работу для канала {channel_id}")
            
        except Exception as e:
            logger.error(f"Ошибка работы ИИ агента: {e}")
        finally:
            # Очистка ресурсов
            await self.cleanup_room_resources(channel_id)
    
    async def monitor_call_activity(self, channel_id: str, room: rtc.Room, assistant: VoiceAssistant):
        """Мониторинг активности звонка"""
        try:
            last_activity = asyncio.get_event_loop().time()
            silence_timeout = 300  # 5 минут тишины
            max_call_duration = 1800  # 30 минут максимум
            
            while channel_id in self.active_channels:
                current_time = asyncio.get_event_loop().time()
                call_duration = current_time - self.active_channels[channel_id].get('start_time', current_time)
                
                # Проверка максимальной длительности звонка
                if call_duration > max_call_duration:
                    logger.info(f"⏰ Звонок {channel_id} превысил максимальную длительность")
                    await assistant.say("Извините, время нашего разговора подходит к концу. До свидания!")
                    await asyncio.sleep(3)
                    await self.hangup_channel(channel_id)
                    break
                
                # Проверка активности участников
                if len(room.remote_participants) == 0:
                    silence_duration = current_time - last_activity
                    if silence_duration > silence_timeout:
                        logger.info(f"🔇 Звонок {channel_id} завершен из-за длительной тишины")
                        await self.hangup_channel(channel_id)
                        break
                else:
                    last_activity = current_time
                
                await asyncio.sleep(5)  # Проверяем каждые 5 секунд
                
        except Exception as e:
            logger.error(f"Ошибка мониторинга активности звонка: {e}")
    
    async def cleanup_room_resources(self, channel_id: str):
        """Очистка ресурсов комнаты"""
        try:
            if channel_id in self.active_rooms:
                room_data = self.active_rooms[channel_id]
                
                # Останавливаем ассистента
                if isinstance(room_data, dict) and 'assistant' in room_data:
                    room_data['assistant'].stop()
                
                # Отключаемся от комнаты
                room = room_data['room'] if isinstance(room_data, dict) else room_data
                if hasattr(room, 'disconnect'):
                    await room.disconnect()
                
                del self.active_rooms[channel_id]
                logger.info(f"🧹 Ресурсы комнаты для канала {channel_id} очищены")
                
        except Exception as e:
            logger.error(f"Ошибка очистки ресурсов комнаты: {e}")
    
    def create_weather_function(self):
        """Создание функции получения погоды"""
        from livekit.agents import llm
        
        async def get_weather(location: str) -> str:
            """Получить информацию о погоде"""
            logger.info(f"🌤️ Запрос погоды для: {location}")
            
            weather_data = {
                "москва": "В Москве сейчас плюс 2 градуса, облачно с прояснениями",
                "санкт-петербург": "В Санкт-Петербурге плюс 1 градус, небольшой дождь",
                "спб": "В Санкт-Петербурге плюс 1 градус, небольшой дождь",
                "сочи": "В Сочи плюс 12 градусов, солнечно",
                "екатеринбург": "В Екатеринбурге минус 5 градусов, снег",
                "новосибирск": "В Новосибирске минус 8 градусов, ясно",
                "казань": "В Казани минус 2 градуса, облачно"
            }
            
            location_lower = location.lower()
            for city, weather in weather_data.items():
                if city in location_lower:
                    return weather
            
            return f"К сожалению, информация о погоде в городе {location} сейчас недоступна. Попробуйте спросить о другом городе."
        
        return llm.FunctionContext(
            get_weather,
            description="Получить актуальную информацию о погоде в указанном городе России"
        )
    
    def create_time_function(self):
        """Создание функции получения времени"""
        from livekit.agents import llm
        import pytz
        from datetime import datetime
        
        async def get_current_time(timezone: str = "Europe/Moscow") -> str:
            """Получить текущее время"""
            try:
                tz = pytz.timezone(timezone)
                current_time = datetime.now(tz)
                
                # Форматируем время на русском языке
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
                
                return (
                    f"Сейчас {current_time.strftime('%H:%M')}, "
                    f"{weekday_name}, {current_time.day} {month_name} "
                    f"{current_time.year} года"
                )
                
            except Exception as e:
                logger.error(f"Ошибка получения времени: {e}")
                return "Извините, не удалось получить текущее время"
        
        return llm.FunctionContext(
            get_current_time,
            description="Получить текущее время и дату в московском часовом поясе"
        )
    
    def create_help_function(self):
        """Создание функции помощи"""
        from livekit.agents import llm
        
        async def get_help() -> str:
            """Получить справку о возможностях ассистента"""
            return (
                "Я могу помочь вам с различными вопросами:\n"
                "• Узнать погоду в любом городе России\n"
                "• Сообщить текущее время и дату\n"
                "• Поддержать обычный разговор\n"
                "• Ответить на общие вопросы\n\n"
                "Просто говорите со мной естественно, как с обычным собеседником!"
            )
        
        return llm.FunctionContext(
            get_help,
            description="Показать справку о возможностях голосового ассистента"
        )
    
    def create_chat_context(self, caller_id: str):
        """Создание контекста чата для ИИ"""
        from livekit.agents import llm
        
        return llm.ChatContext().append(
            role="system",
            text=(
                f"Вы - дружелюбный русскоговорящий ИИ ассистент. "
                f"Вы разговариваете с абонентом {caller_id}. "
                f"Отвечайте кратко, естественно и по-дружески. "
                f"Вы можете помочь с общими вопросами, рассказать о погоде или времени. "
                f"Говорите только на русском языке."
            )
        )
    
    def generate_access_token(self, room_name: str, identity: str) -> str:
        """Генерация токена доступа к LiveKit"""
        try:
            token = api.AccessToken(self.livekit_api_key, self.livekit_api_secret)
            token = token.with_identity(identity).with_name(identity)
            token = token.with_grants(
                api.VideoGrants(
                    room_join=True,
                    room=room_name,
                    can_publish=True,
                    can_subscribe=True
                )
            )
            return token.to_jwt()
            
        except Exception as e:
            logger.error(f"Ошибка генерации токена: {e}")
            raise
    
    async def handle_call_end(self, event: Dict):
        """Обработка завершения звонка"""
        channel = event.get('channel', {})
        channel_id = channel.get('id')
        
        logger.info(f"📞 Завершение звонка для канала {channel_id}")
        
        # Останавливаем ИИ агента
        if channel_id in self.active_channels:
            channel_info = self.active_channels.pop(channel_id)
            
            # Отменяем задачу агента если она есть
            if 'agent_task' in channel_info:
                channel_info['agent_task'].cancel()
            
            # Удаляем мост если он был создан
            if 'bridge_id' in channel_info:
                await self.cleanup_bridge(channel_info['bridge_id'])
        
        # Закрываем LiveKit комнату
        await self.cleanup_room_resources(channel_id)
    
    async def cleanup_bridge(self, bridge_id: str):
        """Очистка моста между каналами"""
        try:
            url = f"{self.ari_url}/ari/bridges/{bridge_id}"
            
            async with self.session.delete(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password)
            ) as response:
                if response.status == 204:
                    logger.info(f"🧹 Мост {bridge_id} удален")
                else:
                    logger.error(f"❌ Ошибка удаления моста {bridge_id}: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка очистки моста {bridge_id}: {e}")
    
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
                else:
                    logger.error(f"❌ Ошибка завершения канала {channel_id}: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка завершения канала {channel_id}: {e}")
    
    async def get_channel_info(self, channel_id: str) -> Optional[Dict]:
        """Получение информации о канале"""
        try:
            url = f"{self.ari_url}/ari/channels/{channel_id}"
            
            async with self.session.get(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password)
            ) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    logger.error(f"❌ Ошибка получения информации о канале {channel_id}: {response.status}")
                    return None
                    
        except Exception as e:
            logger.error(f"Ошибка получения информации о канале {channel_id}: {e}")
            return None
    
    async def health_check(self):
        """Проверка работоспособности системы"""
        try:
            # Проверяем подключение к ARI
            url = f"{self.ari_url}/ari/asterisk/info"
            
            async with self.session.get(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password)
            ) as response:
                if response.status == 200:
                    asterisk_info = await response.json()
                    logger.info(f"✅ Asterisk работает: {asterisk_info.get('version', 'unknown')}")
                    return True
                else:
                    logger.error(f"❌ Asterisk недоступен: {response.status}")
                    return False
                    
        except Exception as e:
            logger.error(f"Ошибка проверки работоспособности: {e}")
            return False
    
    async def periodic_health_check(self):
        """Периодическая проверка работоспособности"""
        while True:
            try:
                await asyncio.sleep(60)  # Проверяем каждую минуту
                
                is_healthy = await self.health_check()
                
                if not is_healthy:
                    logger.warning("⚠️ Система не работает корректно, попытка переподключения...")
                    await self.reconnect()
                
                # Логируем статистику
                active_calls = len(self.active_channels)
                active_rooms = len(self.active_rooms)
                
                if active_calls > 0 or active_rooms > 0:
                    logger.info(f"📊 Активных звонков: {active_calls}, активных комнат: {active_rooms}")
                    
            except Exception as e:
                logger.error(f"Ошибка периодической проверки: {e}")
    
    async def reconnect(self):
        """Переподключение к ARI"""
        try:
            logger.info("🔄 Переподключение к ARI...")
            
            # Закрываем старое соединение
            if self.ari_ws:
                await self.ari_ws.close()
            
            # Создаем новое соединение
            await self.connect_to_ari()
            
            logger.info("✅ Переподключение к ARI успешно")
            
        except Exception as e:
            logger.error(f"❌ Ошибка переподключения к ARI: {e}")
    
    def get_system_stats(self) -> Dict:
        """Получение статистики системы"""
        return {
            'active_channels': len(self.active_channels),
            'active_rooms': len(self.active_rooms),
            'uptime': asyncio.get_event_loop().time(),
            'channels': list(self.active_channels.keys()),
            'rooms': list(self.active_rooms.keys())
        }
    
    async def handle_channel_state_change(self, event: Dict):
        """Обработка изменения состояния канала"""
        channel = event.get('channel', {})
        channel_id = channel.get('id')
        new_state = channel.get('state')
        
        if channel_id in self.active_channels:
            old_state = self.active_channels[channel_id].get('state')
            self.active_channels[channel_id]['state'] = new_state
            
            logger.info(f"📊 Канал {channel_id}: {old_state} -> {new_state}")
    
    async def cleanup(self):
        """Очистка ресурсов"""
        logger.info("🧹 Очистка ресурсов аудио моста...")
        
        # Закрываем все активные комнаты
        for room in self.active_rooms.values():
            await room.disconnect()
        
        # Закрываем WebSocket соединения
        if self.ari_ws:
            await self.ari_ws.close()
        
        if self.session:
            await self.session.close()

async def main():
    """Основная функция"""
    # Настройка логирования
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler('/logs/audio_bridge.log')
        ]
    )
    
    logger.info("🚀 Запуск аудио моста Asterisk <-> LiveKit")
    
    bridge = AudioBridge()
    
    try:
        # Запускаем основной мост
        bridge_task = asyncio.create_task(bridge.start())
        
        # Запускаем периодическую проверку работоспособности
        health_task = asyncio.create_task(bridge.periodic_health_check())
        
        # Ожидаем завершения любой из задач
        done, pending = await asyncio.wait(
            [bridge_task, health_task],
            return_when=asyncio.FIRST_COMPLETED
        )
        
        # Отменяем оставшиеся задачи
        for task in pending:
            task.cancel()
            
    except KeyboardInterrupt:
        logger.info("🛑 Получен сигнал прерывания")
    except Exception as e:
        logger.error(f"💥 Критическая ошибка: {e}")
    finally:
        logger.info("🧹 Завершение работы аудио моста...")
        await bridge.cleanup()
        logger.info("✅ Аудио мост остановлен")

if __name__ == "__main__":
    asyncio.run(main())
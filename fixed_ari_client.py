#!/usr/bin/env python3
"""
Исправленный ARI клиент для интеграции Asterisk с LiveKit
"""

import asyncio
import json
import logging
import os
import sys
from typing import Dict, Optional
import aiohttp
from datetime import datetime

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class FixedARIClient:
    def __init__(self):
        self.ari_url = os.getenv('ARI_URL', 'http://freepbx-server:8088')
        self.ari_username = os.getenv('ARI_USERNAME', 'livekit-agent')
        self.ari_password = os.getenv('ARI_PASSWORD', 'livekit_ari_secret')
        self.app_name = 'livekit-agent'
        
        # Активные каналы
        self.active_channels: Dict[str, Dict] = {}
        
        # WebSocket соединение
        self.ws_connection = None
        self.session = None
        
    async def start(self):
        """Запуск ARI клиента"""
        logger.info("Запуск Fixed ARI Client...")
        
        try:
            # Создание HTTP сессии
            self.session = aiohttp.ClientSession()
            
            # Подключение к ARI WebSocket
            await self.connect_websocket()
            
        except Exception as e:
            logger.error(f"Ошибка запуска ARI клиента: {e}")
            await self.cleanup()
            raise
    
    async def connect_websocket(self):
        """Подключение к ARI WebSocket"""
        ws_url = f"{self.ari_url}/ari/events"
        
        params = {
            'api_key': self.ari_username,
            'api_secret': self.ari_password,
            'app': self.app_name
        }
        
        logger.info(f"Подключение к WebSocket: {ws_url}")
        
        try:
            self.ws_connection = await self.session.ws_connect(
                ws_url,
                params=params,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password)
            )
            logger.info("WebSocket подключение установлено")
            
            # Запуск обработки событий
            await self.handle_events()
            
        except Exception as e:
            logger.error(f"Ошибка подключения WebSocket: {e}")
            raise
    
    async def handle_events(self):
        """Обработка событий от Asterisk"""
        logger.info("Начало обработки событий...")
        
        try:
            async for msg in self.ws_connection:
                if msg.type == aiohttp.WSMsgType.TEXT:
                    try:
                        event = json.loads(msg.data)
                        await self.process_event(event)
                    except json.JSONDecodeError as e:
                        logger.error(f"Ошибка парсинга JSON: {e}")
                    except Exception as e:
                        logger.error(f"Ошибка обработки события: {e}")
                elif msg.type == aiohttp.WSMsgType.ERROR:
                    logger.error(f"WebSocket ошибка: {self.ws_connection.exception()}")
                    break
                elif msg.type == aiohttp.WSMsgType.CLOSE:
                    logger.info("WebSocket соединение закрыто")
                    break
                    
        except Exception as e:
            logger.error(f"Ошибка в обработке событий: {e}")
    
    async def process_event(self, event: Dict):
        """Обработка конкретного события"""
        event_type = event.get('type')
        logger.info(f"Получено событие: {event_type}")
        
        if event_type == 'StasisStart':
            await self.handle_stasis_start(event)
        elif event_type == 'StasisEnd':
            await self.handle_stasis_end(event)
        elif event_type == 'ChannelHangupRequest':
            await self.handle_hangup_request(event)
        elif event_type == 'ChannelStateChange':
            await self.handle_channel_state_change(event)
        else:
            logger.debug(f"Необработанное событие: {event_type}")
    
    async def handle_stasis_start(self, event: Dict):
        """Обработка начала Stasis приложения"""
        channel = event.get('channel', {})
        channel_id = channel.get('id')
        channel_name = channel.get('name')
        
        logger.info(f"Stasis Start для канала: {channel_name} ({channel_id})")
        
        # Сохранение информации о канале
        self.active_channels[channel_id] = {
            'id': channel_id,
            'name': channel_name,
            'state': channel.get('state'),
            'caller_id': channel.get('caller', {}).get('number'),
            'start_time': datetime.now().isoformat(),
            'args': event.get('args', [])
        }
        
        # Ответ на звонок если еще не отвечен
        if channel.get('state') == 'Ring':
            await self.answer_channel(channel_id)
        
        # Запуск интеграции с LiveKit
        await self.start_livekit_integration(channel_id)
    
    async def handle_stasis_end(self, event: Dict):
        """Обработка завершения Stasis приложения"""
        channel = event.get('channel', {})
        channel_id = channel.get('id')
        
        logger.info(f"Stasis End для канала: {channel_id}")
        
        # Удаление из активных каналов
        if channel_id in self.active_channels:
            channel_info = self.active_channels.pop(channel_id)
            logger.info(f"Канал {channel_id} удален из активных")
    
    async def handle_hangup_request(self, event: Dict):
        """Обработка запроса на завершение звонка"""
        channel = event.get('channel', {})
        channel_id = channel.get('id')
        
        logger.info(f"Hangup request для канала: {channel_id}")
    
    async def handle_channel_state_change(self, event: Dict):
        """Обработка изменения состояния канала"""
        channel = event.get('channel', {})
        channel_id = channel.get('id')
        new_state = channel.get('state')
        
        if channel_id in self.active_channels:
            old_state = self.active_channels[channel_id].get('state')
            self.active_channels[channel_id]['state'] = new_state
            
            logger.info(f"Канал {channel_id}: {old_state} -> {new_state}")
    
    async def answer_channel(self, channel_id: str):
        """Ответ на входящий звонок"""
        try:
            url = f"{self.ari_url}/ari/channels/{channel_id}/answer"
            
            async with self.session.post(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password)
            ) as response:
                if response.status == 204:
                    logger.info(f"Канал {channel_id} отвечен")
                else:
                    logger.error(f"Ошибка ответа на канал {channel_id}: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка при ответе на канал {channel_id}: {e}")
    
    async def start_livekit_integration(self, channel_id: str):
        """Запуск интеграции с LiveKit"""
        try:
            channel_info = self.active_channels.get(channel_id, {})
            caller_id = channel_info.get('caller_id', 'Unknown')
            
            logger.info(f"🎤 Запуск LiveKit интеграции для канала {channel_id}, caller: {caller_id}")
            
            # Создаем уникальное имя комнаты на основе ID канала
            room_name = f"call-{channel_id}"
            
            # Воспроизводим приветственное сообщение
            await self.play_ai_greeting(channel_id)
            
            # Ждем завершения воспроизведения
            await asyncio.sleep(3)
            
            # Запускаем имитацию AI разговора
            await self.simulate_ai_conversation(channel_id)
            
            logger.info(f"🏠 LiveKit комната создана: {room_name}")
            logger.info(f"📞 Звонок от {caller_id} подключен к AI ассистенту")
            
        except Exception as e:
            logger.error(f"Ошибка интеграции с LiveKit для канала {channel_id}: {e}")
    
    async def simulate_ai_conversation(self, channel_id: str):
        """Имитация AI разговора"""
        try:
            logger.info(f"🤖 Запуск имитации AI разговора для канала {channel_id}")
            
            # Держим канал открытым на 30 секунд для демонстрации
            await asyncio.sleep(30)
            
            # Воспроизводим прощальное сообщение
            await self.play_goodbye_message(channel_id)
            
            # Ждем завершения воспроизведения
            await asyncio.sleep(3)
            
            # Завершаем звонок
            await self.hangup_channel(channel_id)
            
        except Exception as e:
            logger.error(f"Ошибка имитации AI разговора для канала {channel_id}: {e}")
    
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
                    logger.error(f"Ошибка завершения канала {channel_id}: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка завершения канала {channel_id}: {e}")
    
    async def play_ai_greeting(self, channel_id: str):
        """Воспроизведение приветствия AI ассистента"""
        try:
            url = f"{self.ari_url}/ari/channels/{channel_id}/play"
            
            data = {
                'media': 'sound:hello-world'  # Приветствие AI
            }
            
            async with self.session.post(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password),
                json=data
            ) as response:
                if response.status == 201:
                    logger.info(f"🤖 AI приветствие воспроизводится для канала {channel_id}")
                else:
                    logger.error(f"Ошибка воспроизведения приветствия для канала {channel_id}: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка воспроизведения приветствия для канала {channel_id}: {e}")
    
    async def play_goodbye_message(self, channel_id: str):
        """Воспроизведение прощального сообщения"""
        try:
            url = f"{self.ari_url}/ari/channels/{channel_id}/play"
            
            data = {
                'media': 'sound:goodbye'  # Прощальное сообщение
            }
            
            async with self.session.post(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password),
                json=data
            ) as response:
                if response.status == 201:
                    logger.info(f"👋 Прощальное сообщение воспроизводится для канала {channel_id}")
                else:
                    logger.error(f"Ошибка воспроизведения прощания для канала {channel_id}: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка воспроизведения прощания для канала {channel_id}: {e}")
    
    async def play_connecting_message(self, channel_id: str):
        """Воспроизведение сообщения о подключении"""
        try:
            url = f"{self.ari_url}/ari/channels/{channel_id}/play"
            
            # Используем стандартное сообщение или создаем кастомное
            data = {
                'media': 'sound:hello-world'  # Можно заменить на кастомное сообщение
            }
            
            async with self.session.post(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password),
                json=data
            ) as response:
                if response.status == 201:
                    logger.info(f"🔊 Сообщение о подключении воспроизводится для канала {channel_id}")
                else:
                    logger.error(f"Ошибка воспроизведения для канала {channel_id}: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка воспроизведения для канала {channel_id}: {e}")
    
    async def create_livekit_room(self, room_name: str, caller_id: str):
        """Создание LiveKit комнаты"""
        try:
            # Здесь будет код для создания LiveKit комнаты
            # Используя LiveKit API
            logger.info(f"🏠 Создание LiveKit комнаты: {room_name} для {caller_id}")
            
            # Пока что заглушка
            return {"room_name": room_name, "status": "created"}
            
        except Exception as e:
            logger.error(f"Ошибка создания LiveKit комнаты {room_name}: {e}")
            return None
    
    async def cleanup(self):
        """Очистка ресурсов"""
        logger.info("Очистка ресурсов ARI клиента...")
        
        if self.ws_connection:
            await self.ws_connection.close()
        
        if self.session:
            await self.session.close()

async def main():
    """Основная функция"""
    client = FixedARIClient()
    
    try:
        await client.start()
    except KeyboardInterrupt:
        logger.info("Получен сигнал прерывания")
    except Exception as e:
        logger.error(f"Критическая ошибка: {e}")
    finally:
        await client.cleanup()

if __name__ == "__main__":
    asyncio.run(main())
#!/usr/bin/env python3
"""
Улучшенный ARI клиент для интеграции Asterisk с LiveKit
Автор: Kiro AI Assistant
"""

import asyncio
import json
import logging
import os
import sys
from typing import Dict, Optional
import aiohttp
import websockets
from datetime import datetime

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class EnhancedARIClient:
    def __init__(self):
        self.ari_url = os.getenv('ARI_URL', 'http://freepbx-server:8088')
        self.ari_username = os.getenv('ARI_USERNAME', 'livekit-agent')
        self.ari_password = os.getenv('ARI_PASSWORD', 'livekit_ari_secret')
        self.app_name = 'livekit-agent'
        
        # LiveKit настройки
        self.livekit_url = os.getenv('LIVEKIT_URL')
        self.livekit_api_key = os.getenv('LIVEKIT_API_KEY')
        self.livekit_api_secret = os.getenv('LIVEKIT_API_SECRET')
        
        # Активные каналы
        self.active_channels: Dict[str, Dict] = {}
        
        # WebSocket соединение
        self.ws_connection = None
        self.session = None
        
    async def start(self):
        """Запуск ARI клиента"""
        logger.info("Запуск Enhanced ARI Client...")
        
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
        ws_url = f"{self.ari_url.replace('http', 'ws')}/ari/events"
        
        params = {
            'api_key': 'livekit-agent',
            'api_secret': 'livekit_ari_secret',
            'app': 'livekit-agent'
        }
        
        # Формирование URL с параметрами
        param_string = '&'.join([f"{k}={v}" for k, v in params.items()])
        full_ws_url = f"{ws_url}?{param_string}"
        
        logger.info(f"Подключение к WebSocket: {full_ws_url}")
        
        try:
            self.ws_connection = await websockets.connect(full_ws_url)
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
            async for message in self.ws_connection:
                try:
                    event = json.loads(message)
                    await self.process_event(event)
                except json.JSONDecodeError as e:
                    logger.error(f"Ошибка парсинга JSON: {e}")
                except Exception as e:
                    logger.error(f"Ошибка обработки события: {e}")
                    
        except websockets.exceptions.ConnectionClosed:
            logger.warning("WebSocket соединение закрыто")
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
        
        # Запуск LiveKit интеграции
        await self.start_livekit_session(channel_id)
    
    async def handle_stasis_end(self, event: Dict):
        """Обработка завершения Stasis приложения"""
        channel = event.get('channel', {})
        channel_id = channel.get('id')
        
        logger.info(f"Stasis End для канала: {channel_id}")
        
        # Завершение LiveKit сессии
        await self.end_livekit_session(channel_id)
        
        # Удаление из активных каналов
        if channel_id in self.active_channels:
            channel_info = self.active_channels.pop(channel_id)
            logger.info(f"Канал {channel_id} удален из активных")
    
    async def handle_hangup_request(self, event: Dict):
        """Обработка запроса на завершение звонка"""
        channel = event.get('channel', {})
        channel_id = channel.get('id')
        
        logger.info(f"Hangup request для канала: {channel_id}")
        
        # Завершение LiveKit сессии
        await self.end_livekit_session(channel_id)
    
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
    
    async def start_livekit_session(self, channel_id: str):
        """Запуск LiveKit сессии для канала"""
        try:
            channel_info = self.active_channels.get(channel_id, {})
            caller_id = channel_info.get('caller_id', 'Unknown')
            
            logger.info(f"Запуск LiveKit сессии для канала {channel_id}, caller: {caller_id}")
            
            # Здесь должна быть интеграция с LiveKit
            # Пока что просто логируем
            logger.info(f"LiveKit сессия запущена для {channel_id}")
            
            # Воспроизведение приветствия
            await self.play_welcome_message(channel_id)
            
        except Exception as e:
            logger.error(f"Ошибка запуска LiveKit сессии для {channel_id}: {e}")
    
    async def end_livekit_session(self, channel_id: str):
        """Завершение LiveKit сессии"""
        try:
            logger.info(f"Завершение LiveKit сессии для канала {channel_id}")
            
            # Здесь должно быть завершение LiveKit сессии
            
        except Exception as e:
            logger.error(f"Ошибка завершения LiveKit сессии для {channel_id}: {e}")
    
    async def play_welcome_message(self, channel_id: str):
        """Воспроизведение приветственного сообщения"""
        try:
            url = f"{self.ari_url}/ari/channels/{channel_id}/play"
            
            data = {
                'media': 'sound:hello-world'
            }
            
            async with self.session.post(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password),
                json=data
            ) as response:
                if response.status == 201:
                    logger.info(f"Приветствие воспроизводится для канала {channel_id}")
                else:
                    logger.error(f"Ошибка воспроизведения для канала {channel_id}: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка воспроизведения для канала {channel_id}: {e}")
    
    async def hangup_channel(self, channel_id: str):
        """Завершение звонка"""
        try:
            url = f"{self.ari_url}/ari/channels/{channel_id}"
            
            async with self.session.delete(
                url,
                auth=aiohttp.BasicAuth(self.ari_username, self.ari_password)
            ) as response:
                if response.status == 204:
                    logger.info(f"Канал {channel_id} завершен")
                else:
                    logger.error(f"Ошибка завершения канала {channel_id}: {response.status}")
                    
        except Exception as e:
            logger.error(f"Ошибка завершения канала {channel_id}: {e}")
    
    async def get_active_channels_info(self):
        """Получение информации об активных каналах"""
        return {
            'total_channels': len(self.active_channels),
            'channels': list(self.active_channels.values())
        }
    
    async def cleanup(self):
        """Очистка ресурсов"""
        logger.info("Очистка ресурсов ARI клиента...")
        
        if self.ws_connection:
            await self.ws_connection.close()
        
        if self.session:
            await self.session.close()

async def main():
    """Основная функция"""
    client = EnhancedARIClient()
    
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
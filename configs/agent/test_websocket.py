#!/usr/bin/env python3
"""
Простой тест WebSocket подключения к ARI
"""

import asyncio
import websockets
import base64
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_websocket():
    """Тест WebSocket подключения"""
    
    # Настройки
    host = "freepbx-server"
    port = 8088
    username = "livekit-agent"
    password = "livekit_ari_secret"
    app_name = "livekit-agent"
    
    # Создание заголовка авторизации
    credentials = f"{username}:{password}"
    encoded_credentials = base64.b64encode(credentials.encode()).decode()
    
    # WebSocket URL
    ws_url = f"ws://{host}:{port}/ari/events?api_key={username}&api_secret={password}&app={app_name}"
    
    logger.info(f"Подключение к: {ws_url}")
    
    # Заголовки
    headers = {
        "Authorization": f"Basic {encoded_credentials}"
    }
    
    try:
        async with websockets.connect(ws_url) as websocket:
            logger.info("✅ WebSocket подключение успешно!")
            
            # Ожидаем событие в течение 5 секунд
            try:
                message = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                logger.info(f"✅ Получено сообщение: {message}")
            except asyncio.TimeoutError:
                logger.info("✅ WebSocket работает (нет событий за 5 сек)")
            
            return True
            
    except Exception as e:
        logger.error(f"❌ WebSocket ошибка: {e}")
        return False

if __name__ == "__main__":
    result = asyncio.run(test_websocket())
    exit(0 if result else 1)
#!/usr/bin/env python3
"""
Простой тест ARI подключения
"""

import asyncio
import aiohttp
import json
import websockets
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_ari_connection():
    """Тест подключения к ARI"""
    
    # Настройки подключения
    ari_url = "http://freepbx-server:8088"
    username = "livekit-agent"
    password = "livekit_ari_secret"
    app_name = "livekit-agent"
    
    try:
        # Тест HTTP API
        logger.info("Тестирование HTTP API...")
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{ari_url}/ari/asterisk/info",
                auth=aiohttp.BasicAuth(username, password)
            ) as response:
                if response.status == 200:
                    data = await response.json()
                    logger.info(f"✅ HTTP API работает: Asterisk {data.get('version')}")
                else:
                    logger.error(f"❌ HTTP API ошибка: {response.status}")
                    return False
        
        # Тест WebSocket
        logger.info("Тестирование WebSocket...")
        ws_url = f"{ari_url.replace('http', 'ws')}/ari/events?api_key=livekit-agent&api_secret=livekit_ari_secret&app=livekit-agent"
        
        try:
            async with websockets.connect(ws_url) as websocket:
                logger.info("✅ WebSocket подключение установлено")
                
                # Ожидаем событие в течение 5 секунд
                try:
                    message = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                    event = json.loads(message)
                    logger.info(f"✅ Получено событие: {event.get('type')}")
                except asyncio.TimeoutError:
                    logger.info("✅ WebSocket работает (нет событий за 5 сек)")
                
                return True
                
        except Exception as e:
            logger.error(f"❌ WebSocket ошибка: {e}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Общая ошибка: {e}")
        return False

async def main():
    """Основная функция"""
    logger.info("=== Тест ARI подключения ===")
    
    success = await test_ari_connection()
    
    if success:
        logger.info("🎉 ARI тест пройден успешно!")
    else:
        logger.error("💥 ARI тест провален!")
        
    return success

if __name__ == "__main__":
    result = asyncio.run(main())
    exit(0 if result else 1)
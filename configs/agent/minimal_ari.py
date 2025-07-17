#!/usr/bin/env python3
"""
Минимальный ARI клиент для тестирования
"""

import asyncio
import aiohttp
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_minimal_ari():
    """Минимальный тест ARI"""
    
    # Настройки
    base_url = "http://freepbx-server:8088"
    username = "livekit-agent"
    password = "livekit_ari_secret"
    app_name = "livekit-agent"
    
    try:
        async with aiohttp.ClientSession() as session:
            # 1. Тест базового подключения
            async with session.get(
                f"{base_url}/ari/asterisk/info",
                auth=aiohttp.BasicAuth(username, password)
            ) as response:
                if response.status == 200:
                    logger.info("✅ Базовое ARI подключение работает")
                else:
                    logger.error(f"❌ Базовое подключение не работает: {response.status}")
                    return False
            
            # 2. Попробуем зарегистрировать приложение через HTTP
            logger.info("Попытка регистрации приложения через HTTP...")
            
            # Создаем WebSocket соединение через aiohttp
            ws_url = f"{base_url}/ari/events"
            params = {
                'api_key': username,
                'api_secret': password,
                'app': app_name
            }
            
            try:
                async with session.ws_connect(
                    ws_url,
                    params=params,
                    auth=aiohttp.BasicAuth(username, password)
                ) as ws:
                    logger.info("✅ WebSocket подключение через aiohttp успешно!")
                    
                    # Ожидаем сообщение
                    try:
                        msg = await asyncio.wait_for(ws.receive(), timeout=5.0)
                        if msg.type == aiohttp.WSMsgType.TEXT:
                            data = json.loads(msg.data)
                            logger.info(f"✅ Получено событие: {data.get('type', 'unknown')}")
                        else:
                            logger.info("✅ WebSocket работает (получен не текстовый тип)")
                    except asyncio.TimeoutError:
                        logger.info("✅ WebSocket работает (нет событий за 5 сек)")
                    
                    return True
                    
            except Exception as e:
                logger.error(f"❌ WebSocket через aiohttp ошибка: {e}")
                return False
                
    except Exception as e:
        logger.error(f"❌ Общая ошибка: {e}")
        return False

if __name__ == "__main__":
    result = asyncio.run(test_minimal_ari())
    if result:
        print("🎉 Минимальный ARI тест успешен!")
    else:
        print("💥 Минимальный ARI тест провален!")
    exit(0 if result else 1)
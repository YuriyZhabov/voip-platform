#!/usr/bin/env python3
import os
import asyncio
import logging
from urllib.parse import urlparse, urljoin
import aiohttp
from livekit import api

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

async def test_connection():
    """Тестирование подключения к LiveKit Cloud"""
    # Получаем параметры подключения из переменных окружения
    api_key = os.environ.get("LIVEKIT_API_KEY")
    api_secret = os.environ.get("LIVEKIT_API_SECRET")
    ws_url = os.environ.get("LIVEKIT_URL")
    
    if not api_key or not api_secret or not ws_url:
        logger.error("Не заданы необходимые переменные окружения")
        return
    
    logger.info(f"API Key: {api_key}")
    logger.info(f"API Secret: {'*' * len(api_secret)}")
    logger.info(f"WebSocket URL: {ws_url}")
    
    # Создаем JWT токен для агента
    agent_token = (
        api.AccessToken(api_key=api_key, api_secret=api_secret)
        .with_grants(api.VideoGrants(agent=True))
        .to_jwt()
    )
    logger.info(f"JWT токен для агента: {agent_token[:20]}...")
    
    # Создаем JWT токен для обычного клиента
    client_token = (
        api.AccessToken(api_key=api_key, api_secret=api_secret)
        .with_identity("test-client")
        .with_name("Test Client")
        .with_grants(api.VideoGrants(room_join=True, room="test"))
        .to_jwt()
    )
    logger.info(f"JWT токен для клиента: {client_token[:20]}...")
    
    # Формируем URL для подключения агента
    parse = urlparse(ws_url)
    scheme = parse.scheme
    if scheme.startswith("http"):
        scheme = scheme.replace("http", "ws")
    
    base = f"{scheme}://{parse.netloc}{parse.path}".rstrip("/") + "/"
    agent_url = urljoin(base, "agent")
    logger.info(f"URL для подключения агента: {agent_url}")
    
    # Формируем URL для подключения клиента
    client_url = urljoin(base, "rtc")
    logger.info(f"URL для подключения клиента: {client_url}")
    
    # Пробуем подключиться как агент
    logger.info("Пробуем подключиться как агент...")
    try:
        async with aiohttp.ClientSession() as session:
            headers = {"Authorization": f"Bearer {agent_token}"}
            async with session.ws_connect(agent_url, headers=headers, autoping=True) as ws:
                logger.info("Успешное подключение как агент!")
                await ws.close()
    except Exception as e:
        logger.error(f"Ошибка при подключении как агент: {e}")
    
    # Пробуем подключиться как клиент
    logger.info("Пробуем подключиться как клиент...")
    try:
        async with aiohttp.ClientSession() as session:
            headers = {"Authorization": f"Bearer {client_token}"}
            async with session.ws_connect(client_url, headers=headers, autoping=True) as ws:
                logger.info("Успешное подключение как клиент!")
                await ws.close()
    except Exception as e:
        logger.error(f"Ошибка при подключении как клиент: {e}")

if __name__ == "__main__":
    asyncio.run(test_connection())
import asyncio
import logging
from ari_client import ARIClient

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

async def handle_ari_event(event):
    """Обработка события ARI"""
    event_type = event.get('type')
    logger.info(f"Received ARI event: {event_type}")
    
    if event_type == 'StasisStart':
        # Новый звонок поступил в Stasis-приложение
        channel_id = event.get('channel', {}).get('id')
        caller_id = event.get('channel', {}).get('caller', {}).get('number')
        extension = event.get('channel', {}).get('dialplan', {}).get('exten')
        
        logger.info(f"New call from {caller_id} to {extension} (channel: {channel_id})")
        
        # Здесь можно добавить логику обработки звонка
        # Например, воспроизвести приветственное сообщение
        client.play_sound(channel_id, 'hello-world')
        
    elif event_type == 'StasisEnd':
        # Звонок завершился
        channel_id = event.get('channel', {}).get('id')
        logger.info(f"Call ended (channel: {channel_id})")

async def main():
    """Основная функция"""
    global client
    client = ARIClient(host="freepbx-server", port=8088, username="livekit", password="livekit_password")
    
    while True:
        try:
            await client.connect()
            await client.listen_events(handle_ari_event)
        except Exception as e:
            logger.error(f"Error in ARI client: {e}")
            await asyncio.sleep(5)  # Пауза перед повторным подключением

if __name__ == "__main__":
    asyncio.run(main())
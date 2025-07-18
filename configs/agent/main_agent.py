#!/usr/bin/env python3
"""
Главный агент с интеграцией аудио моста
Объединяет LiveKit агента и Asterisk ARI
"""

import asyncio
import logging
import os
import sys
from pathlib import Path

# Добавляем текущую директорию в путь для импортов
sys.path.append(str(Path(__file__).parent))

from audio_bridge import AudioBridge
from aiohttp import web

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/logs/main_agent.log')
    ]
)
logger = logging.getLogger(__name__)

class MainAgent:
    """Главный агент системы"""
    
    def __init__(self):
        self.audio_bridge = AudioBridge()
        self.health_server = None
        self.running = False
        
    async def start(self):
        """Запуск главного агента"""
        logger.info("🚀 Запуск главного агента VoIP системы")
        
        try:
            self.running = True
            
            # Проверяем переменные окружения
            await self.check_environment()
            
            # Запускаем HTTP сервер для health check
            await self.start_health_server()
            
            # Запускаем аудио мост
            bridge_task = asyncio.create_task(self.audio_bridge.start())
            
            # Запускаем периодическую проверку работоспособности
            health_task = asyncio.create_task(self.audio_bridge.periodic_health_check())
            
            # Запускаем мониторинг системы
            monitor_task = asyncio.create_task(self.system_monitor())
            
            logger.info("✅ Главный агент успешно запущен")
            
            # Ожидаем завершения любой из задач
            done, pending = await asyncio.wait(
                [bridge_task, health_task, monitor_task],
                return_when=asyncio.FIRST_COMPLETED
            )
            
            # Отменяем оставшиеся задачи
            for task in pending:
                task.cancel()
                
        except Exception as e:
            logger.error(f"💥 Критическая ошибка главного агента: {e}")
            raise
        finally:
            await self.cleanup()
    
    async def check_environment(self):
        """Проверка переменных окружения"""
        required_vars = [
            'LIVEKIT_URL',
            'LIVEKIT_API_KEY', 
            'LIVEKIT_API_SECRET',
            'OPENAI_API_KEY',
            'DEEPGRAM_API_KEY',
            'CARTESIA_API_KEY'
        ]
        
        missing_vars = []
        for var in required_vars:
            if not os.getenv(var):
                missing_vars.append(var)
        
        if missing_vars:
            logger.error(f"❌ Отсутствуют переменные окружения: {', '.join(missing_vars)}")
            raise ValueError(f"Отсутствуют обязательные переменные окружения: {missing_vars}")
        
        logger.info("✅ Все переменные окружения настроены")
        
        # Логируем конфигурацию (без секретов)
        logger.info(f"🔗 LiveKit URL: {os.getenv('LIVEKIT_URL')}")
        logger.info(f"🤖 OpenAI модель: {os.getenv('OPENAI_MODEL', 'gpt-4o-mini')}")
        logger.info(f"🎤 Deepgram модель: {os.getenv('DEEPGRAM_MODEL', 'nova-2')}")
        logger.info(f"🔊 Cartesia модель: {os.getenv('CARTESIA_MODEL', 'sonic-multilingual')}")
    
    async def start_health_server(self):
        """Запуск HTTP сервера для health check"""
        try:
            app = web.Application()
            app.router.add_get('/health', self.health_check_handler)
            app.router.add_get('/status', self.status_handler)
            app.router.add_get('/stats', self.stats_handler)
            
            runner = web.AppRunner(app)
            await runner.setup()
            
            site = web.TCPSite(runner, '0.0.0.0', 8081)
            await site.start()
            
            logger.info("🌐 Health check сервер запущен на порту 8081")
            
        except Exception as e:
            logger.error(f"Ошибка запуска health check сервера: {e}")
    
    async def health_check_handler(self, request):
        """Обработчик health check"""
        try:
            # Проверяем состояние аудио моста
            bridge_healthy = await self.audio_bridge.health_check()
            
            status = "healthy" if bridge_healthy else "unhealthy"
            
            return web.json_response({
                "status": status,
                "service": "voip-ai-agent",
                "version": "1.0.0",
                "components": {
                    "audio_bridge": "healthy" if bridge_healthy else "unhealthy",
                    "livekit": "connected",
                    "asterisk": "connected" if bridge_healthy else "disconnected"
                }
            })
            
        except Exception as e:
            logger.error(f"Ошибка health check: {e}")
            return web.json_response({
                "status": "error",
                "error": str(e)
            }, status=500)
    
    async def status_handler(self, request):
        """Обработчик детального статуса"""
        try:
            stats = self.audio_bridge.get_system_stats()
            
            return web.json_response({
                "status": "running" if self.running else "stopped",
                "service": "voip-ai-agent",
                "uptime_seconds": stats.get('uptime', 0),
                "active_calls": stats.get('active_channels', 0),
                "active_rooms": stats.get('active_rooms', 0),
                "environment": {
                    "livekit_url": os.getenv('LIVEKIT_URL', 'not_set'),
                    "openai_model": os.getenv('OPENAI_MODEL', 'gpt-4o-mini'),
                    "deepgram_model": os.getenv('DEEPGRAM_MODEL', 'nova-2'),
                    "cartesia_model": os.getenv('CARTESIA_MODEL', 'sonic-multilingual')
                }
            })
            
        except Exception as e:
            logger.error(f"Ошибка получения статуса: {e}")
            return web.json_response({
                "status": "error",
                "error": str(e)
            }, status=500)
    
    async def stats_handler(self, request):
        """Обработчик статистики"""
        try:
            stats = self.audio_bridge.get_system_stats()
            return web.json_response(stats)
            
        except Exception as e:
            logger.error(f"Ошибка получения статистики: {e}")
            return web.json_response({
                "error": str(e)
            }, status=500)
    
    async def system_monitor(self):
        """Мониторинг системы"""
        try:
            while self.running:
                await asyncio.sleep(300)  # Каждые 5 минут
                
                stats = self.audio_bridge.get_system_stats()
                active_calls = stats.get('active_channels', 0)
                active_rooms = stats.get('active_rooms', 0)
                
                logger.info(f"📊 Системная статистика:")
                logger.info(f"   • Активных звонков: {active_calls}")
                logger.info(f"   • Активных комнат: {active_rooms}")
                logger.info(f"   • Время работы: {stats.get('uptime', 0):.0f} сек")
                
                # Проверяем использование памяти
                try:
                    import psutil
                    process = psutil.Process()
                    memory_mb = process.memory_info().rss / 1024 / 1024
                    cpu_percent = process.cpu_percent()
                    
                    logger.info(f"   • Память: {memory_mb:.1f} MB")
                    logger.info(f"   • CPU: {cpu_percent:.1f}%")
                    
                except ImportError:
                    pass  # psutil не установлен
                
        except Exception as e:
            logger.error(f"Ошибка мониторинга системы: {e}")
    
    async def cleanup(self):
        """Очистка ресурсов"""
        logger.info("🧹 Завершение работы главного агента...")
        
        self.running = False
        
        # Очищаем ресурсы аудио моста
        await self.audio_bridge.cleanup()
        
        logger.info("✅ Главный агент остановлен")

async def main():
    """Основная функция"""
    agent = MainAgent()
    
    try:
        await agent.start()
    except KeyboardInterrupt:
        logger.info("🛑 Получен сигнал прерывания")
    except Exception as e:
        logger.error(f"💥 Критическая ошибка: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
import aiohttp
import asyncio
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)

class WeatherTool:
    """Инструмент для получения погоды"""
    
    @staticmethod
    async def get_weather(location: str) -> Dict[str, Any]:
        """Получить погоду для указанного местоположения"""
        try:
            # Здесь можно интегрировать реальный API погоды
            # Например, OpenWeatherMap или Яндекс.Погода
            
            # Фиктивные данные для демонстрации
            weather_data = {
                "москва": {
                    "temperature": 5,
                    "description": "облачно",
                    "humidity": 65,
                    "wind_speed": 3.2
                },
                "санкт-петербург": {
                    "temperature": 3,
                    "description": "дождь",
                    "humidity": 80,
                    "wind_speed": 4.1
                },
                "спб": {
                    "temperature": 3,
                    "description": "дождь", 
                    "humidity": 80,
                    "wind_speed": 4.1
                },
                "сочи": {
                    "temperature": 15,
                    "description": "солнечно",
                    "humidity": 55,
                    "wind_speed": 2.1
                }
            }
            
            location_lower = location.lower()
            for city, data in weather_data.items():
                if city in location_lower:
                    return data
                    
            return {"error": f"Данные о погоде для {location} не найдены"}
            
        except Exception as e:
            logger.error(f"Ошибка получения погоды: {e}")
            return {"error": str(e)}

class TimeTools:
    """Инструменты для работы со временем"""
    
    @staticmethod
    def get_current_time(timezone: str = "Europe/Moscow") -> str:
        """Получить текущее время"""
        from datetime import datetime
        import pytz
        
        try:
            tz = pytz.timezone(timezone)
            current_time = datetime.now(tz)
            return current_time.strftime("%H:%M, %d %B %Y года")
        except Exception as e:
            logger.error(f"Ошибка получения времени: {e}")
            return "Не удалось получить время"

class SystemTools:
    """Системные инструменты"""
    
    @staticmethod
    async def check_system_health() -> Dict[str, Any]:
        """Проверить состояние системы"""
        try:
            # Проверка подключения к Redis
            import redis
            r = redis.Redis(host='redis-cache', port=6379, decode_responses=True)
            redis_status = r.ping()
            
            return {
                "redis": "online" if redis_status else "offline",
                "timestamp": TimeTools.get_current_time(),
                "status": "healthy"
            }
        except Exception as e:
            logger.error(f"Ошибка проверки системы: {e}")
            return {
                "status": "error",
                "error": str(e)
            }
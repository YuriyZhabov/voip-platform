import logging
import os
from pathlib import Path

class AgentConfig:
    """Конфигурация агента"""
    
    # Пути
    BASE_DIR = Path(__file__).parent
    LOG_DIR = BASE_DIR / "logs"
    DATA_DIR = BASE_DIR / "data"
    
    # LiveKit
    LIVEKIT_URL = os.getenv("LIVEKIT_URL", "wss://voice-mz90cpgw.livekit.cloud")
    LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
    LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")
    
    # OpenAI
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
    OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    OPENAI_TEMPERATURE = float(os.getenv("OPENAI_TEMPERATURE", "0.7"))
    
    # Deepgram
    DEEPGRAM_API_KEY = os.getenv("DEEPGRAM_API_KEY")
    DEEPGRAM_MODEL = os.getenv("DEEPGRAM_MODEL", "nova-2")
    DEEPGRAM_LANGUAGE = os.getenv("DEEPGRAM_LANGUAGE", "ru")
    
    # Cartesia
    CARTESIA_API_KEY = os.getenv("CARTESIA_API_KEY")
    CARTESIA_MODEL = os.getenv("CARTESIA_MODEL", "sonic-multilingual")
    CARTESIA_VOICE = os.getenv("CARTESIA_VOICE", "87748186-23bb-4158-a1eb-332911b0b708")
    CARTESIA_LANGUAGE = os.getenv("CARTESIA_LANGUAGE", "ru")
    
    @classmethod
    def setup_logging(cls):
        """Настройка логирования"""
        cls.LOG_DIR.mkdir(exist_ok=True)
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(cls.LOG_DIR / "agent.log"),
                logging.StreamHandler()
            ]
        )
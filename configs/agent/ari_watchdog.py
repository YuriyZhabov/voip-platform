#!/usr/bin/env python3
"""
ARI Watchdog - автоматический перезапуск ARI клиента при сбое
"""
import asyncio
import logging
import subprocess
import time
import requests
from datetime import datetime

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ARIWatchdog:
    def __init__(self):
        self.asterisk_host = "freepbx-server"
        self.asterisk_port = 8088
        self.ari_username = "livekit-agent"
        self.ari_password = "livekit_ari_secret"
        self.check_interval = 30  # Проверка каждые 30 секунд
        self.restart_delay = 5    # Задержка перед перезапуском
        self.max_restart_attempts = 3
        self.restart_count = 0
        self.last_restart_time = 0
        
    def check_ari_registration(self):
        """Проверяет, зарегистрировано ли ARI приложение"""
        try:
            url = f"http://{self.asterisk_host}:{self.asterisk_port}/ari/applications"
            response = requests.get(
                url,
                auth=(self.ari_username, self.ari_password),
                timeout=10
            )
            
            if response.status_code == 200:
                apps = response.json()
                for app in apps:
                    if app.get('name') == 'livekit-agent':
                        logger.debug("ARI приложение livekit-agent зарегистрировано")
                        return True
                        
            logger.warning("ARI приложение livekit-agent не найдено")
            return False
            
        except Exception as e:
            logger.error(f"Ошибка проверки ARI регистрации: {e}")
            return False
    
    def kill_existing_ari_processes(self):
        """Убивает существующие процессы ARI клиента"""
        try:
            # Ищем и убиваем процессы ARI клиента
            result = subprocess.run(
                ["pgrep", "-f", "fixed_ari_client.py"],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                pids = result.stdout.strip().split('\n')
                for pid in pids:
                    if pid:
                        try:
                            subprocess.run(["kill", "-9", pid], check=True)
                            logger.info(f"Убит процесс ARI клиента с PID {pid}")
                        except subprocess.CalledProcessError:
                            pass
                            
        except Exception as e:
            logger.error(f"Ошибка при убийстве процессов ARI: {e}")
    
    def start_ari_client(self):
        """Запускает ARI клиент"""
        try:
            # Сначала убиваем старые процессы
            self.kill_existing_ari_processes()
            
            # Ждем немного
            time.sleep(self.restart_delay)
            
            # Запускаем новый процесс
            process = subprocess.Popen(
                ["python", "/app/fixed_ari_client.py"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                preexec_fn=None
            )
            
            logger.info(f"ARI клиент запущен с PID {process.pid}")
            
            # Ждем немного и проверяем, что процесс не упал сразу
            time.sleep(3)
            if process.poll() is None:
                logger.info("ARI клиент успешно запущен")
                return True
            else:
                logger.error("ARI клиент упал сразу после запуска")
                return False
                
        except Exception as e:
            logger.error(f"Ошибка запуска ARI клиента: {e}")
            return False
    
    def should_restart(self):
        """Проверяет, можно ли перезапускать (защита от частых перезапусков)"""
        current_time = time.time()
        
        # Если прошло больше 5 минут с последнего перезапуска, сбрасываем счетчик
        if current_time - self.last_restart_time > 300:
            self.restart_count = 0
        
        # Не более 3 перезапусков за 5 минут
        if self.restart_count >= self.max_restart_attempts:
            logger.warning(f"Достигнут лимит перезапусков ({self.max_restart_attempts})")
            return False
            
        return True
    
    async def run(self):
        """Основной цикл watchdog"""
        logger.info("🐕 ARI Watchdog запущен")
        
        while True:
            try:
                # Проверяем регистрацию ARI приложения
                if not self.check_ari_registration():
                    logger.warning("⚠️ ARI приложение не зарегистрировано")
                    
                    if self.should_restart():
                        logger.info("🔄 Перезапуск ARI клиента...")
                        
                        if self.start_ari_client():
                            self.restart_count += 1
                            self.last_restart_time = time.time()
                            
                            # Ждем немного и проверяем регистрацию
                            await asyncio.sleep(10)
                            
                            if self.check_ari_registration():
                                logger.info("✅ ARI клиент успешно перезапущен и зарегистрирован")
                            else:
                                logger.error("❌ ARI клиент перезапущен, но не зарегистрирован")
                        else:
                            logger.error("❌ Не удалось перезапустить ARI клиент")
                    else:
                        logger.warning("⏸️ Перезапуск отложен из-за лимита попыток")
                
                # Ждем до следующей проверки
                await asyncio.sleep(self.check_interval)
                
            except Exception as e:
                logger.error(f"Ошибка в watchdog: {e}")
                await asyncio.sleep(self.check_interval)

async def main():
    """Главная функция"""
    watchdog = ARIWatchdog()
    await watchdog.run()

if __name__ == "__main__":
    asyncio.run(main())
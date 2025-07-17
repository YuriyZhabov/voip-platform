#!/usr/bin/env python3
import os
import sys
import json
import logging
import subprocess
import urllib.request
import urllib.error
import base64
import time

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    filename='/logs/start_agent.log'
)
logger = logging.getLogger(__name__)

# Параметры ARI
ARI_HOST = "freepbx-server"
ARI_PORT = 8088
ARI_USERNAME = "livekit"
ARI_PASSWORD = "livekit_password"
ARI_BASE_URL = f"http://{ARI_HOST}:{ARI_PORT}/ari"
ARI_AUTH_HEADER = base64.b64encode(f"{ARI_USERNAME}:{ARI_PASSWORD}".encode()).decode()

def log_to_file(message):
    """Запись сообщения в лог-файл"""
    with open('/logs/start_agent.log', 'a') as f:
        f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - {message}\n")

def start_livekit_agent(caller_id, extension):
    """Запуск LiveKit агента"""
    try:
        log_to_file(f"Starting LiveKit agent for call from {caller_id} to {extension}")
        
        # Запуск LiveKit агента
        cmd = [
            "python", "/app/agent.py", "start",
            "--caller", caller_id,
            "--extension", extension
        ]
        
        # Запуск процесса в фоновом режиме
        subprocess.Popen(
            cmd,
            stdout=open('/logs/livekit_agent.log', 'a'),
            stderr=subprocess.STDOUT,
            close_fds=True
        )
        
        log_to_file("LiveKit agent started successfully")
        return True
    except Exception as e:
        log_to_file(f"Error starting LiveKit agent: {e}")
        return False

def play_sound(channel_id, sound):
    """Воспроизведение звука на канале"""
    try:
        data = json.dumps({"media": f"sound:{sound}"}).encode()
        request = urllib.request.Request(
            f"{ARI_BASE_URL}/channels/{channel_id}/play",
            data=data,
            headers={
                "Authorization": f"Basic {ARI_AUTH_HEADER}",
                "Content-Type": "application/json"
            },
            method="POST"
        )
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode())
    except urllib.error.URLError as e:
        log_to_file(f"Failed to play sound: {e}")
        return None

def main():
    """Основная функция"""
    # Получение параметров из командной строки
    if len(sys.argv) < 4:
        log_to_file("Usage: start_agent.py <channel_id> <caller_id> <extension>")
        return
    
    channel_id = sys.argv[1]
    caller_id = sys.argv[2]
    extension = sys.argv[3]
    
    log_to_file(f"Received call from {caller_id} to {extension} (channel: {channel_id})")
    
    # Воспроизведение приветственного сообщения
    play_sound(channel_id, "welcome")
    
    # Запуск LiveKit агента
    start_livekit_agent(caller_id, extension)

if __name__ == "__main__":
    main()
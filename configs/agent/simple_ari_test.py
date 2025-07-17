#!/usr/bin/env python3
"""
Простой тест ARI подключения
"""

import requests
import json
import time

# Настройки ARI
ARI_URL = "http://freepbx-server:8088"
ARI_USERNAME = "livekit-agent"
ARI_PASSWORD = "livekit_ari_secret"
APP_NAME = "livekit-agent"

def test_ari_connection():
    """Тест подключения к ARI"""
    try:
        # Тест базового подключения
        url = f"{ARI_URL}/ari/asterisk/info"
        response = requests.get(url, auth=(ARI_USERNAME, ARI_PASSWORD))
        
        if response.status_code == 200:
            print("✅ ARI подключение работает")
            info = response.json()
            print(f"Asterisk версия: {info.get('version', 'unknown')}")
            return True
        else:
            print(f"❌ Ошибка ARI подключения: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Ошибка подключения к ARI: {e}")
        return False

def register_ari_app():
    """Регистрация ARI приложения"""
    try:
        import websocket
        
        # WebSocket URL для ARI
        ws_url = f"ws://freepbx-server:8088/ari/events?api_key={ARI_USERNAME}&api_secret={ARI_PASSWORD}&app={APP_NAME}"
        
        print(f"Подключение к WebSocket: {ws_url}")
        
        def on_message(ws, message):
            print(f"Получено сообщение: {message}")
        
        def on_error(ws, error):
            print(f"Ошибка WebSocket: {error}")
        
        def on_close(ws, close_status_code, close_msg):
            print("WebSocket соединение закрыто")
        
        def on_open(ws):
            print("✅ ARI приложение зарегистрировано")
        
        ws = websocket.WebSocketApp(ws_url,
                                  on_open=on_open,
                                  on_message=on_message,
                                  on_error=on_error,
                                  on_close=on_close)
        
        # Запуск в отдельном потоке на 10 секунд
        import threading
        def run_ws():
            ws.run_forever()
        
        thread = threading.Thread(target=run_ws)
        thread.daemon = True
        thread.start()
        
        time.sleep(10)
        ws.close()
        
        return True
        
    except ImportError:
        print("❌ websocket-client не установлен")
        return False
    except Exception as e:
        print(f"❌ Ошибка регистрации ARI приложения: {e}")
        return False

if __name__ == "__main__":
    print("=== Тест ARI подключения ===")
    
    if test_ari_connection():
        print("\n=== Регистрация ARI приложения ===")
        register_ari_app()
    
    print("\n=== Тест завершен ===")
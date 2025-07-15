#!/bin/bash

# Скрипт инициализации LiveKit Agent

echo "Initializing LiveKit Agent..."

# Создаем необходимые директории
mkdir -p data/agent
mkdir -p data/logs/agent

# Устанавливаем права доступа
chmod -R 755 data/agent
chmod -R 755 data/logs/agent

echo "Agent directories created successfully!"

# Проверяем переменные окружения
if [ -f .env ]; then
    echo "✓ .env file found"
    
    # Проверяем ключевые переменные
    source .env
    
    if [ -z "$LIVEKIT_API_KEY" ]; then
        echo "✗ LIVEKIT_API_KEY not set!"
        exit 1
    else
        echo "✓ LIVEKIT_API_KEY is set"
    fi
    
    if [ -z "$OPENAI_API_KEY" ]; then
        echo "✗ OPENAI_API_KEY not set!"
        exit 1
    else
        echo "✓ OPENAI_API_KEY is set"
    fi
    
    if [ -z "$DEEPGRAM_API_KEY" ]; then
        echo "✗ DEEPGRAM_API_KEY not set!"
        exit 1
    else
        echo "✓ DEEPGRAM_API_KEY is set"
    fi
    
    if [ -z "$CARTESIA_API_KEY" ]; then
        echo "✗ CARTESIA_API_KEY not set!"
        exit 1
    else
        echo "✓ CARTESIA_API_KEY is set"
    fi
    
else
    echo "✗ .env file not found!"
    exit 1
fi

# Проверяем файлы агента
if [ -f configs/agent/agent.py ]; then
    echo "✓ agent.py found"
else
    echo "✗ agent.py not found!"
    exit 1
fi

if [ -f configs/agent/requirements.txt ]; then
    echo "✓ requirements.txt found"
else
    echo "✗ requirements.txt not found!"
    exit 1
fi

if [ -f configs/agent/Dockerfile ]; then
    echo "✓ Dockerfile found"
else
    echo "✗ Dockerfile not found!"
    exit 1
fi

echo "LiveKit Agent initialization completed!"
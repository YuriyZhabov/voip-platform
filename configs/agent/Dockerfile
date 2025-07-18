# Используем официальный Python образ
ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim

# Предотвращаем создание .pyc файлов
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Устанавливаем рабочую директорию
WORKDIR /app

# Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    software-properties-common \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Копируем requirements.txt
COPY requirements.txt .

# Устанавливаем Python зависимости
RUN pip install --no-cache-dir -r requirements.txt

# Создаем непривилегированного пользователя
RUN groupadd -r agent && useradd -r -g agent agent

# Копируем код приложения
COPY . .

# Создаем необходимые директории
RUN mkdir -p /data /logs && \
    chown -R agent:agent /app /data /logs

# Переключаемся на непривилегированного пользователя
USER agent

# Устанавливаем переменные окружения
ENV PYTHONPATH=/app

# Экспонируем порт для health check
EXPOSE 8081

# Команда по умолчанию
ENTRYPOINT ["python", "main_agent.py"]
CMD []
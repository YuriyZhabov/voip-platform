# Руководство: подключение к LiveKit Cloud и запуск диалога с ИИ-агентом (Python)

Перед вами пошаговая инструкция, которая охватывает три ключевых блока:  
1. Подготовка проекта в LiveKit Cloud.  
2. Генерация токенов и подключение клиента.  
3. Создание и запуск голосового ИИ-агента на Python.  

В примерах используются только открытые бесплатные инструменты LiveKit и плагинов.

## 1  Создание проекта в LiveKit Cloud

### 1.1   Регистрация и первоначальная настройка
1. Перейдите на https://cloud.livekit.io и зарегистрируйтесь (достаточно GitHub / Google-аккаунта).  
2. Нажмите «Create Project», задайте имя и выберите ближайший регион, чтобы минимизировать задержку[1].  
3. После создания откройте вкладку **Settings → API Keys** и нажмите «Add API Key» — сервис сгенерирует:  
   * `LIVEKIT_URL` (формата `wss://.livekit.cloud`)  
   * `LIVEKIT_API_KEY` (начинается с `API`)  
   * `LIVEKIT_API_SECRET` (один раз показывается в UI)  

Сохраните значения — они потребуются бэкенду и клиентам[2][1].

### 1.2   Установка CLI (опционально)
CLI упрощает генерацию токенов и шаблонных проектов:  

```bash
# macOS / Linux
brew install livekit-cli        # либо
curl -sSL https://get.livekit.io/cli | bash
# Авторизация
lk cloud auth                   # откроется браузер, выберите созданный проект
```

После авторизации команды `lk token`, `lk app create` автоматически подставляют URL, API Key, Secret[3][4].

## 2  Получение токена и подключение клиента

### 2.1   Мини-сервер для генерации токена (Python)
Установите пакет `livekit-api`:

```bash
pip install livekit-api python-dotenv
```

Создайте файл `.env` рядом с кодом:

```
LIVEKIT_URL=wss://.livekit.cloud
LIVEKIT_API_KEY=
LIVEKIT_API_SECRET=
```

Файл `token_server.py`:

```python
import os, datetime
from fastapi import FastAPI
from livekit import api
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

@app.get("/getToken")
def get_token(room: str = "demo", identity: str = "user"):
    video_grants = api.VideoGrants(room_join=True, room=room)
    token = (
        api.AccessToken()                     # читает ключи из env
        .with_identity(identity)
        .with_ttl(datetime.timedelta(hours=1))
        .with_grants(video_grants)
        .to_jwt()
    )
    return {"token": token}
```

Запуск:

```bash
uvicorn token_server:app --host 0.0.0.0 --port 8000
```

### 2.2   Подключение Web-клиента (React / vanilla JS)

```js
import { Room } from 'livekit-client';

async function connect() {
  const res   = await fetch('/getToken?room=demo&identity=alice');
  const { token } = await res.json();
  const room  = new Room();
  await room.connect('wss://.livekit.cloud', token);
  console.log(`joined ${room.name} as ${room.localParticipant.identity}`);
}
```

## 3  Запуск ИИ-агента (Agents SDK v1)

### 3.1   Установка зависимостей

```bash
pip install "livekit-agents[openai,deepgram,cartesia]"  # ИИ-провайдеры
```

Понадобятся ключи моделей:  
`OPENAI_API_KEY`, `DEEPGRAM_API_KEY`, `CARTESIA_API_KEY` (добавьте в `.env`).

### 3.2   Код агента

```python
import os, asyncio
from livekit import agents, rtc
from livekit.agents import AgentSession, Agent
from livekit.plugins import openai, deepgram, cartesia
from dotenv import load_dotenv

load_dotenv()

async def entrypoint(ctx: agents.JobContext):
    # 1. Подключаемся к комнате как участник-бот
    await ctx.connect(auto_subscribe=rtc.AutoSubscribe.AUDIO_ONLY)
    participant = await ctx.wait_for_participant()   # ждём первого человека

    # 2. Создаём сессию с моделями
    session = AgentSession(
        stt = deepgram.STT(),                        # распознавание речи
        llm = openai.realtime.RealtimeModel(voice="alloy"),
        tts = cartesia.TTS(),                        # озвучка
    )

    # 3. Запускаем агента с инструкциями
    await session.start(
        room   = ctx.room,
        agent  = Agent(instructions="Ты доброжелательный ассистент."),
    )

    # 4. Приветственное сообщение
    await session.generate_reply(instructions="Поздоровайся и спроси, чем помочь.")

if __name__ == '__main__':
    agents.cli.run_app(agents.WorkerOptions(entrypoint_fnc=entrypoint))
```

Запуск:

```bash
python agent.py dev          # dev = hot-reload + подробные логи
```

### 3.3   Проверка
1. Откройте клиент (браузер) и подключитесь к комнате `demo` с уникальным `identity`.  
2. Как только человек войдёт, агент подключится, проговорит приветствие и начнёт диалог в режиме реального времени[5][6][7].

## 4  Частые вопросы и лучшие практики

| Вопрос | Краткий ответ |
|------|---------------|
| **Можно ли использовать только текст без голоса?** | Да. Удалите `stt/tts` и работайте через события `data` либо чат-сообщения API[8]. |
| **Как добавить функцию вызова инструментов (function calling)?** | В `RealtimeModel` укажите `tools=[...]`, а в агенте подпишитесь на `on("tool_called")` — далее вызывайте собственный Python-код и передавайте результат обратно[9]. |
| **Что делать c модерацией?** | Используйте JWT-гранты `roomAdmin` и вызывайте серверный API `LiveKitAPI.room.mute_published_track` или `disconnect_participant`[2][10]. |
| **Как писать логи разговоров?** | Вешайте обработчики `session.on("user_speech_committed")` и `...agent_speech_committed`, сохраняйте текст + timestamp в БД или облачное хранилище[11][12]. |
| **Как увеличить масштаб?** | Запускайте воркеры агента в Kubernetes; LiveKit Cloud автоматически балансирует задания по доступным воркерам через WebSocket-канал[13]. |

## 5  Мини-чек-лист для продакшна

1. **Безопасность**: храните `API_SECRET` лишь на сервере, токены выдавайте по HTTPS[14].  
2. **TTL токена**: ограничьте 1–2 ч; по истечении — запрашивайте новый[15].  
3. **Лимиты моделей**: следите за затратами через панели LiveKit Metrics и OpenAI Usage.  
4. **Webhooks**: подпишитесь на `room_finished` для автоматической очистки ресурсов[16].  
5. **Логирование**: включите `LK_LOG_LEVEL=info` и собирайте stdout через систему-агрегатор.

### Итог

* LiveKit Cloud предоставляет готовый WebRTC-бэкенд; нужен лишь URL + ключи.  
* Токены доступа (JWT) формируются на бэкенде или CLI и передаются клиентам.  
* Framework **LiveKit Agents** позволяет за 30–40 строк кода собрать голосового ассистента, поддерживающего STT → LLM → TTS или мультимодальные модели OpenAI Realtime.  

Следуя этому руководству, вы запустите полный цикл: клиент → облако → ИИ-агент — без необходимости управлять собственным медиа-сервером.
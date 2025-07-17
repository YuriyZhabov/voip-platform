import re

def validate_livekit_url(url):
    """Валидация формата URL для LiveKit Cloud"""
    pattern = r'^wss://[a-zA-Z0-9\-]+\.livekit\.cloud$'
    return re.match(pattern, url) is not None
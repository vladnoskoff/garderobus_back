import os
from dotenv import load_dotenv

# Загрузка переменных окружения из .env файла
load_dotenv()

# Настройки базы данных
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:Inoskoff11@192.168.1.148:5432/smart-closet")

# API-ключи
OPENAI_API_KEY = os.getenv("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")

OPENAI_API_KEYY = "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"
ESP_DISPLAY_IP = os.getenv("ESP_DISPLAY_IP", "http://192.168.1.100")

OPENWEATHER_API_KEY = "b12505dfa3865989452161d336d8ee5c"

# Другие настройки
APP_NAME = "Smart Closet"
DEBUG = os.getenv("DEBUG", "False").lower() == "true"

HUGGINGFACE_API_KEY = "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"
SEGMIND_API_KEY = "SG_37d704a36997b82a"
TEST_PERSON_IMAGE_URL = "http://aapanel-api.noksovsteam.ru/chkaf/clothes_images/static/test_mannequin.png"

UPLOADCARE_PUBLIC_KEY = "9bbcfab1a72a8d1311ba"
UPLOADCARE_SECRET_KEY = "0ac770a85532060f0ed9"
import os
from pathlib import Path
from dotenv import load_dotenv

# Загрузка переменных окружения из .env файла
load_dotenv()

# Базовые пути
BASE_DIR = Path(__file__).resolve().parent
CLOTHES_IMAGE_DIR = BASE_DIR / os.getenv("CLOTHES_IMAGE_DIR", "clothes_images")
MANNEQUIN_IMAGE_DIR = BASE_DIR / os.getenv("MANNEQUIN_IMAGE_DIR", "mannequins")
CLOTHES_IMAGE_URL_PREFIX = os.getenv("CLOTHES_IMAGE_URL_PREFIX", "/clothes_images")
MANNEQUIN_IMAGE_URL_PREFIX = os.getenv("MANNEQUIN_IMAGE_URL_PREFIX", "/mannequins")
TEST_PERSON_IMAGE_URL = os.getenv(
    "TEST_PERSON_IMAGE_URL",
    "http://aapanel-api.noksovsteam.ru/chkaf/clothes_images/static/test_mannequin.png",
)

# Создание директорий, если они отсутствуют
for directory in (CLOTHES_IMAGE_DIR, MANNEQUIN_IMAGE_DIR):
    directory.mkdir(parents=True, exist_ok=True)

# Настройки базы данных
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:Inoskoff11@192.168.1.148:5432/smart-closet",
)

# API-ключи
OPENAI_API_KEY = os.getenv(
    "OPENAI_API_KEY",
    "sk-proj-meOKTsNkP_Gp17p9tWbHCNBT8Y2qidUHCQFkrZ6bRB_R0yUB3qi0OIvILCAs-"
    "SobJ5yqq8nr2lT3BlbkFJ4j5ALz62zsZLzf0m2q97QoMbSt_RZWUpBtCG7jh7f4yFfQSpxWgsuX42dizTtDpiiymu0ID0kA",
)
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY", "b12505dfa3865989452161d336d8ee5c")
HUGGINGFACE_API_KEY = os.getenv("HUGGINGFACE_API_KEY", "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")
SEGMIND_API_KEY = os.getenv("SEGMIND_API_KEY", "SG_37d704a36997b82a")
UPLOADCARE_PUBLIC_KEY = os.getenv("UPLOADCARE_PUBLIC_KEY", "9bbcfab1a72a8d1311ba")
UPLOADCARE_SECRET_KEY = os.getenv("UPLOADCARE_SECRET_KEY", "0ac770a85532060f0ed9")

# Прокси-настройки
SOCKS_PROXY_URL = os.getenv("SOCKS_PROXY_URL", "socks5://127.0.0.1:10808")
ENABLE_SOCKS_PROXY = os.getenv("ENABLE_SOCKS_PROXY", "false").lower() == "true"

# Другие настройки
APP_NAME = os.getenv("APP_NAME", "Smart Closet")
ESP_DISPLAY_IP = os.getenv("ESP_DISPLAY_IP", "http://192.168.1.100")
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

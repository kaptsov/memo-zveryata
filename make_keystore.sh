#!/bin/bash
# Скрипт создания release keystore для Мемо Зверята
# Запускать один раз. Keystore нужен для подписи release APK для RuStore.

set -e

KEYSTORE_FILE="memo_zveryata_release.keystore"
KEY_ALIAS="memo_zveryata"

if [ -f "$KEYSTORE_FILE" ]; then
    echo "Keystore уже существует: $KEYSTORE_FILE"
    exit 0
fi

echo "Создаём release keystore..."
echo "Заполни данные об организации (можно оставить пустыми, кроме пароля)."
echo ""

keytool -genkey -v \
    -keystore "$KEYSTORE_FILE" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000

echo ""
echo "Keystore создан: $KEYSTORE_FILE"
echo ""
echo "Следующий шаг — прописать пути в export_presets.cfg:"
echo "  keystore/release=\"res://memo_zveryata_release.keystore\""
echo "  keystore/release_user=\"$KEY_ALIAS\""
echo "  keystore/release_password=\"<твой_пароль>\""
echo ""
echo "ВАЖНО: Никогда не публикуй keystore и пароли в git!"
echo "Добавь в .gitignore:"
echo "  *.keystore"
echo "  keystore_password.txt"

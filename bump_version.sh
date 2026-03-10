#!/bin/bash
# bump_version.sh — инкрементирует номер сборки перед экспортом.
#
# Использование: ./bump_version.sh [--minor]
#   (без флагов) — инкрементирует patch: v0.4.1 → v0.4.2
#   --minor      — инкрементирует minor и сбрасывает patch: v0.4.x → v0.5.0
#
# Обновляет:
#   - scripts/ui/main_menu.gd     : BUILD_VERSION
#   - export_presets.cfg          : version/code (Android versionCode)
#                                   version/name (строка для магазина)
#
# Платформы для экспорта (делать после bump_version.sh):
#   Android : Project → Export → Android → Export Project
#   Windows : Project → Export → Windows Desktop → Export Project → build/windows/
#   Web     : Project → Export → Web → Export Project → build/web/
#             (Web: мультиплеер не работает — только соло и локальная игра)

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPORT_CFG="$PROJECT_DIR/export_presets.cfg"
MAIN_MENU="$PROJECT_DIR/scripts/ui/main_menu.gd"

# --- Читаем текущее BUILD_VERSION из main_menu.gd ---
CURRENT_FULL=$(grep '^const BUILD_VERSION' "$MAIN_MENU" | sed 's/.*"\(.*\)".*/\1/')
# Ожидаемый формат: vMAJOR.MINOR или vMAJOR.MINOR.PATCH
MAJOR=$(echo "$CURRENT_FULL" | sed 's/v\([0-9]*\)\..*/\1/')
MINOR=$(echo "$CURRENT_FULL" | sed 's/v[0-9]*\.\([0-9]*\).*/\1/')
PATCH=$(echo "$CURRENT_FULL" | sed -n 's/v[0-9]*\.[0-9]*\.\([0-9]*\)/\1/p')
PATCH="${PATCH:-0}"

# --- Читаем текущий version/code из export_presets.cfg ---
CURRENT_CODE=$(grep 'version/code=' "$EXPORT_CFG" | sed 's/version\/code=//')
NEW_CODE=$((CURRENT_CODE + 1))

# --- Вычисляем новую версию ---
if [[ "$1" == "--minor" ]]; then
    MINOR=$((MINOR + 1))
    PATCH=0
else
    PATCH=$((PATCH + 1))
fi

NEW_VERSION="v${MAJOR}.${MINOR}.${PATCH}"

echo "Версия: ${CURRENT_FULL} → ${NEW_VERSION}  (versionCode: ${CURRENT_CODE} → ${NEW_CODE})"

# --- Обновляем export_presets.cfg ---
sed -i '' "s/version\/code=${CURRENT_CODE}/version\/code=${NEW_CODE}/" "$EXPORT_CFG"
sed -i '' "s/version\/name=\"[^\"]*\"/version\/name=\"${NEW_VERSION}\"/" "$EXPORT_CFG"

# --- Обновляем main_menu.gd ---
sed -i '' "s/const BUILD_VERSION: String = \"[^\"]*\"/const BUILD_VERSION: String = \"${NEW_VERSION}\"/" "$MAIN_MENU"

echo "Готово! Текущая версия: ${NEW_VERSION}"

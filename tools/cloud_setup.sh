#!/usr/bin/env bash
# Scinode: подготовка облачной среды Claude Code.
# Вставляется в настройки среды: меню среды → Edit → Setup script.
# Каждый шаг независим: если один не удался, остальные всё равно выполняются.

log() { echo "[scinode-setup] $*"; }

# 1. Flutter (stable)
if [ ! -x "$HOME/flutter/bin/flutter" ]; then
  log "Ставлю Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter" \
    || log "Не удалось скачать Flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"
flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version >/dev/null 2>&1 || log "Flutter пока не готов"

# 2. Системные инструменты: Java (эмулятор Firestore), poppler (PDF → картинки),
#    TeX Live (проверка выгрузки .tex). ~400 МБ, ставится один раз.
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null 2>&1 || log "apt-get update не прошёл"
  apt-get install -y --no-install-recommends \
    openjdk-17-jre-headless poppler-utils \
    texlive-latex-base texlive-latex-recommended texlive-lang-cyrillic \
    texlive-fonts-recommended cm-super >/dev/null 2>&1 \
    || log "Не все системные пакеты установились"
fi

# 3. Инструменты тестов правил Firestore (~/rules-tools)
mkdir -p "$HOME/rules-tools"
cd "$HOME/rules-tools" || exit 0
[ -f package.json ] || npm init -y >/dev/null 2>&1
npm install --no-audit --no-fund \
  firebase-tools@13 @firebase/rules-unit-testing@3 firebase@10 >/dev/null 2>&1 \
  || log "Не удалось поставить firebase-tools"
npx --yes firebase setup:emulators:firestore >/dev/null 2>&1 || true

# 4. Python для будущей аналитики (этап B)
python3 -m pip install --quiet --disable-pip-version-check \
  pandas networkx matplotlib jinja2 requests 2>/dev/null \
  || log "Python-пакеты не установились"

# 5. Пакеты проекта (если репозиторий уже на месте)
for d in /home/user/scinode "$PWD"; do
  if [ -f "$d/pubspec.yaml" ]; then
    (cd "$d" && flutter pub get >/dev/null 2>&1) || true
    break
  fi
done

log "Готово"
exit 0

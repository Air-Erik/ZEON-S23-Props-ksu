#!/usr/bin/env bash
set -euo pipefail

# ====== ПАРАМЕТРЫ (можно править) ======
IP="${1:-}"
MODID="zb_s23_props"
MODEL="SM-S918B"
DEVICE="dm3q"
PRODUCT="dm3qxx"
ANDROID_REL="13"
BUILD_ID="TP1A.220624.014"
INCREMENTAL="S918BXXU1AWBD"
FINGERPRINT="samsung/${PRODUCT}/${DEVICE}:${ANDROID_REL}/${BUILD_ID}/${INCREMENTAL}:user/release-keys"
SERIAL="R58N10ABCDEF"
DEVICE_NAME_HUMAN="Galaxy S23 Ultra"

# ====== проверка IP ======
if [[ -z "$IP" ]]; then
  echo "usage: $0 <BLISS_IP>"
  exit 1
fi

# ====== вспомогательные ======
say() { echo -e "\033[1;36m[INFO]\033[0m $*"; }
die() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

# ====== подключение ADB ======
say "Подключаюсь к ${IP}:5555…"
adb connect "${IP}:5555" >/dev/null || true
adb wait-for-device

say "Перезапуск adbd в root-режиме…"
adb root >/dev/null || true
sleep 1
adb wait-for-device

# ====== пути на устройстве ======
BASE="/data/adb/ksu"
BB="${BASE}/bin/busybox"
IMG_CUR="${BASE}/modules.img"
IMG_UPD="${BASE}/modules_update.img"
MNT="/data/local/tmp/ksu_modupd"

# ====== проверка busybox/resetprop ======
adb shell "[ -x ${BB} ] && [ -x ${BASE}/bin/resetprop ]" \
  || die "На устройстве нет ${BB} / resetprop. Проверь установку KernelSU."

# ====== выбрать, какой образ править ======
TARGET_IMG=""
USE_UPDATE_FLAG=0
if adb shell "[ -f ${IMG_UPD} ]"; then
  TARGET_IMG="${IMG_UPD}"; USE_UPDATE_FLAG=1
  say "Найден ${IMG_UPD} — кладём модуль в стейджинг и поставим флаг update."
elif adb shell "[ -f ${IMG_CUR} ]"; then
  TARGET_IMG="${IMG_CUR}"
  say "Нет modules_update.img — работаем прямо с ${IMG_CUR}."
else
  die "Не найден ни ${IMG_UPD}, ни ${IMG_CUR}. Запусти BlissOS один раз или установи любой модуль через GUI."
fi

# ====== локальная временная папка с файлами модуля ======
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK" >/dev/null 2>&1 || true' EXIT

cat > "${WORK}/module.prop" <<EOF
id=${MODID}
name=ZB S23 Ultra Props
version=1.1
versionCode=2
author=Erik
description=Spoofs props to Samsung Galaxy S23 Ultra (${MODEL}). Cosmetic only; no Play Integrity bypass.
EOF

cat > "${WORK}/system.prop" <<EOF
# --- Device identity (global) ---
ro.product.manufacturer=samsung
ro.product.brand=samsung
ro.product.model=${MODEL}
ro.product.device=${DEVICE}
ro.product.name=${PRODUCT}

# --- System view (About экран) ---
ro.product.system.manufacturer=samsung
ro.product.system.brand=samsung
ro.product.system.model=${MODEL}
ro.product.system.device=${DEVICE}
ro.product.system.name=${PRODUCT}

# --- BlissOS "визитка" для About ---
ro.product.bliss.manufacturer=samsung
ro.product.bliss.brand=samsung
ro.product.bliss.model=${MODEL}
ro.product.bliss.device=${DEVICE}
ro.product.bliss.name=${PRODUCT}

# --- Build meta (global) ---
ro.build.id=${BUILD_ID}
ro.build.display.id=${BUILD_ID}.${INCREMENTAL}
ro.build.version.incremental=${INCREMENTAL}
ro.build.product=${DEVICE}
ro.build.description=${PRODUCT}-user ${ANDROID_REL} ${BUILD_ID} ${INCREMENTAL} release-keys
ro.build.fingerprint=${FINGERPRINT}

# --- Fingerprints per-partition ---
ro.system.build.fingerprint=${FINGERPRINT}
ro.product.build.fingerprint=${FINGERPRINT}
ro.vendor.build.fingerprint=${FINGERPRINT}
ro.odm.build.fingerprint=${FINGERPRINT}
ro.system_ext.build.fingerprint=${FINGERPRINT}
EOF

cat > "${WORK}/post-fs-data.sh" <<'EOF'
#!/system/bin/sh
MODDIR="${0%/*}"
LOG="$MODDIR/props.log"

# Конфиг (синхронизирован с system.prop)
MODEL="SM-S918B"
DEVICE="dm3q"
PRODUCT="dm3qxx"
ANDROID_REL="13"
BUILD_ID="TP1A.220624.014"
INCREMENTAL="S918BXXU1AWBD"
FP="samsung/${PRODUCT}/${DEVICE}:${ANDROID_REL}/${BUILD_ID}/${INCREMENTAL}:user/release-keys"
SER="R58N10ABCDEF"

RP="/data/adb/ksu/bin/resetprop"
[ -x "$RP" ] || RP=resetprop

echo "[ZB] post-fs-data start $(date)" > "$LOG"
echo "[ZB] using: $(command -v "$RP" || echo notfound)" >> "$LOG"

apply() {
  k="$1"; v="$2"
  if command -v "$RP" >/dev/null 2>&1; then
    "$RP" -n "$k" "$v" && echo "[+] $k=$v" >> "$LOG" || echo "[!] FAIL $k" >> "$LOG"
  else
    echo "[!] resetprop not found, skip $k" >> "$LOG"
  fi
}

# визитка
apply ro.product.manufacturer samsung
apply ro.product.brand samsung
apply ro.product.model "$MODEL"
apply ro.product.device "$DEVICE"
apply ro.product.name "$PRODUCT"

# system view
apply ro.product.system.manufacturer samsung
apply ro.product.system.brand samsung
apply ro.product.system.model "$MODEL"
apply ro.product.system.device "$DEVICE"
apply ro.product.system.name "$PRODUCT"

# BlissOS About
apply ro.product.bliss.manufacturer samsung
apply ro.product.bliss.brand samsung
apply ro.product.bliss.model "$MODEL"
apply ro.product.bliss.device "$DEVICE"
apply ro.product.bliss.name "$PRODUCT"

# серийник (косметика)
apply ro.serialno "$SER"
apply ro.boot.serialno "$SER"

# build и fingerprint
apply ro.build.id "$BUILD_ID"
apply ro.build.display.id "${BUILD_ID}.${INCREMENTAL}"
apply ro.build.version.incremental "$INCREMENTAL"
apply ro.build.product "$DEVICE"
apply ro.build.description "${PRODUCT}-user ${ANDROID_REL} ${BUILD_ID} ${INCREMENTAL} release-keys"
apply ro.build.fingerprint "$FP"

for part in system product vendor odm system_ext; do
  apply "ro.${part}.build.fingerprint" "$FP"
done

echo "[ZB] done" >> "$LOG"
exit 0
EOF
# подставим актуальные значения в скрипт
sed -i \
  -e "s/SM-S918B/${MODEL}/g" \
  -e "s/dm3q/${DEVICE}/g" \
  -e "s/dm3qxx/${PRODUCT}/g" \
  -e "s/13/${ANDROID_REL}/" \
  -e "s/TP1A.220624.014/${BUILD_ID}/g" \
  -e "s/S918BXXU1AWBD/${INCREMENTAL}/g" \
  -e "s/R58N10ABCDEF/${SERIAL}/g" \
  "${WORK}/post-fs-data.sh"
chmod 0755 "${WORK}/post-fs-data.sh"

cat > "${WORK}/service.sh" <<'EOF'
#!/system/bin/sh
MODDIR="${0%/*}"
LOG="$MODDIR/props.log"
NAME="__DEVICE_NAME__"

# ждём полной загрузки, чтобы Settings-провайдер был доступен
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 3

# пользовательское имя устройства и BT-имя
settings put global device_name "$NAME"
settings put secure bluetooth_name "$NAME"

# закрепим через persist (на случай перезаписей)
setprop persist.sys.device_name "$NAME"
setprop persist.bluetooth.name "$NAME"

echo "[ZB] service.sh set device_name='$NAME' at $(date)" >> "$LOG"
EOF
# подставляем читаемое имя из параметра скрипта
sed -i "s/__DEVICE_NAME__/${DEVICE_NAME_HUMAN//\//\\/}/" "${WORK}/service.sh"
chmod 0755 "${WORK}/service.sh"

# ====== монтируем образ и копируем файлы ======
say "Монтирую ${TARGET_IMG} в ${MNT}…"
adb shell "mkdir -p ${MNT} && ${BB} mount -t ext4 -o loop ${TARGET_IMG} ${MNT}" \
  || die "Не удалось смонтировать образ модулей."

say "Копирую модуль ${MODID}…"
adb shell "mkdir -p ${MNT}/${MODID}"
adb push "${WORK}/module.prop"     "${MNT}/${MODID}/" >/dev/null
adb push "${WORK}/system.prop"     "${MNT}/${MODID}/" >/dev/null
adb push "${WORK}/post-fs-data.sh" "${MNT}/${MODID}/" >/dev/null
adb push "${WORK}/service.sh"      "${MNT}/${MODID}/" >/dev/null

say "Выставляю права…"
adb shell "chown -R root:root ${MNT}/${MODID} && \
           chmod 0755 ${MNT}/${MODID} && \
           chmod 0755 ${MNT}/${MODID}/post-fs-data.sh ${MNT}/${MODID}/service.sh && \
           chmod 0644 ${MNT}/${MODID}/module.prop ${MNT}/${MODID}/system.prop && \
           rm -f ${MNT}/${MODID}/disable ${MNT}/${MODID}/remove"

say "Размонтирую образ…"
adb shell "sync; ${BB} umount ${MNT}; rmdir ${MNT} 2>/dev/null || true"

# ====== триггер обновления (если работали с modules_update.img) ======
if [[ $USE_UPDATE_FLAG -eq 1 ]]; then
  say "Ставлю флаг обновления KernelSU…"
  adb shell "touch ${BASE}/update"
fi

# ====== ребут и финальная проверка ======
say "Перезагружаю устройство…"
adb reboot
adb wait-for-device
adb root >/dev/null || true
sleep 1
adb wait-for-device

say "Проверяю установку…"
adb shell "ls -l /data/adb/modules/${MODID} || echo '(!) нет каталога модуля'"
adb shell "cat /data/adb/modules/${MODID}/props.log 2>/dev/null || echo '(!) нет props.log (проверь после полной загрузки)'"
adb shell "getprop | grep -E 'ro\\.(product|build)\\.|fingerprint' | head -n 30"
adb shell 'settings get global device_name; settings get secure bluetooth_name' || true
say "Готово."

#!/system/bin/sh
MODDIR="${0%/*}"
LOG="$MODDIR/props.log"
FP="samsung/dm3qxx/dm3q:13/TP1A.220624.014/S918BXXU1AWBD:user/release-keys"

RESETPROP="/data/adb/ksu/bin/resetprop"
[ -x "$RESETPROP" ] || RESETPROP="resetprop"

echo "[ZB] post-fs-data start $(date)" > "$LOG"
echo "[ZB] using: $(command -v "$RESETPROP" || echo notfound)" >> "$LOG"

apply() {
  key="$1"; val="$2"
  if command -v "$RESETPROP" >/dev/null 2>&1; then
    "$RESETPROP" -n "$key" "$val" \
      && echo "[+] $key=$val" >> "$LOG" \
      || echo "[!] FAIL $key" >> "$LOG"
  else
    echo "[!] resetprop not found, skip $key" >> "$LOG"
  fi
}

# визитка
apply ro.product.manufacturer samsung
apply ro.product.brand samsung
apply ro.product.model SM-S918B
apply ro.product.device dm3q
apply ro.product.name dm3qxx

# базовые build-поля
apply ro.build.id TP1A.220624.014
apply ro.build.display.id TP1A.220624.014.S918BXXU1AWBD
apply ro.build.version.incremental S918BXXU1AWBD
apply ro.build.product dm3q
apply ro.build.description "dm3qxx-user 13 TP1A.220624.014 S918BXXU1AWBD release-keys"
apply ro.build.fingerprint "$FP"

# зеркалим отпечаток по разделам
for part in system product vendor odm system_ext; do
  apply "ro.${part}.build.fingerprint" "$FP"
done

echo "[ZB] done" >> "$LOG"
exit 0

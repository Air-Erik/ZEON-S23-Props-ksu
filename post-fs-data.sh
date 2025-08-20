#!/system/bin/sh
# KernelSU/Magisk early boot stage
MODDIR="${0%/*}"
LOG="$MODDIR/props.log"
FP="samsung/dm3qxx/dm3q:13/TP1A.220624.014/S918BXXU1AWBD:user/release-keys"

echo "[ZB] post-fs-data start $(date)" > "$LOG"

apply() {
  key="$1"; val="$2"
  if command -v resetprop >/dev/null 2>&1; then
    resetprop "$key" "$val" && echo "[+] $key=$val" >> "$LOG" || echo "[!] FAIL $key" >> "$LOG"
  else
    # На случай отсутствия resetprop просто логируем;
    # system.prop уже подменил значения на раннем этапе.
    echo "[i] resetprop not found, system.prop covers $key" >> "$LOG"
  fi
}

# Зеркалим fingerprint по разделам (повтор harmless)
for part in system product vendor odm system_ext; do
  apply "ro.${part}.build.fingerprint" "$FP"
done

# Подстраховка: убедимся, что глобальный fingerprint совпал
apply "ro.build.fingerprint" "$FP"

echo "[ZB] done" >> "$LOG"
exit 0

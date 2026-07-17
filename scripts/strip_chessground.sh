#!/bin/bash
# 裁剪 chessground 包的多余棋子贴图，只保留 merida 系列
# 可在 flutter pub get 之后运行，节省 ~26MB 安装包体积

CHESSGROUND=$(find /root/.pub-cache /opt/flutter/.pub-cache ~/.pub-cache -path "*/chessground-5.*/assets" -type d 2>/dev/null | head -1)

if [ -z "$CHESSGROUND" ]; then
  echo "chessground assets not found in pub cache"
  exit 0
fi

echo "Found chessground at: $CHESSGROUND"
echo "Before: $(du -sh "$CHESSGROUND" | cut -f1)"

# 删除非 merida 的所有棋子系列（保留 boards）
for dir in "$CHESSGROUND"/piece_sets/*/; do
  name=$(basename "$dir")
  if [ "$name" != "merida" ]; then
    rm -rf "$dir"
    echo "  Removed: $name"
  fi
done

# 删除 merida 的超高清 4.0x（手机用不到）
rm -rf "$CHESSGROUND/piece_sets/merida/4.0x"
echo "  Removed: merida/4.0x"

echo "After: $(du -sh "$CHESSGROUND" | cut -f1)"
echo "Done! Saved ~26MB."

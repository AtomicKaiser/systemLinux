#!/bin/sh
# Strip a staged live image down to kernel + installer essentials: docs, man/info pages,
# translations, debug info and test/desktop leftovers. Compilers, build tools and language
# runtimes are removed by profiles.sh (they are post-install profiles).
# usage: strip-live.sh STAGE
set -eu
S=${1:?usage: strip-live.sh STAGE}
cd "$S"
rm -rf usr/share/doc usr/share/man usr/share/info usr/share/gtk-doc usr/share/locale usr/share/help \
       usr/share/bash-completion usr/share/zsh usr/share/vim/vim*/doc usr/share/gdb usr/share/applications \
       usr/share/icons usr/share/fonts usr/share/themes usr/share/sounds usr/share/X11 \
       usr/lib/debug usr/lib/firmware lib/firmware \
       usr/lib/python3*/test usr/lib/python3*/idlelib usr/lib/python3*/tkinter usr/lib/python3*/turtledemo \
       usr/lib/python3*/site-packages/*/tests usr/share/gcc-data/*/*/python \
       etc/X11 etc/cron.daily etc/cups etc/bluetooth
find . -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
find usr/lib usr/lib64 usr/bin usr/libexec -type f \( -name '*.debug' -o -name '*.pyc' \) -delete 2>/dev/null || true

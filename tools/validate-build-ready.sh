#!/bin/sh
# Build-ready check: confirms an installed systemLinux (after `get --profile build-toolchain`,
# `get --profile common-build-deps`, and optionally `get --profile lang-runtimes`) can compile
# small autotools, CMake and Meson projects, plus C++, Go, Python and Perl.
# usage: tools/validate-build-ready.sh        exit status 0 = ready, 1 = something required is missing
# Checklist (what is verified): cc/c++/ld/ar/make/patch, pkgconf, autoconf/automake/libtool/m4,
# cmake+ninja, meson, flex/bison, curl-or-wget/tar/xz, a C and C++ compile+run, an autotools build,
# a CMake+Ninja build, a Meson build. Optional (reported, not required): go, python3, perl, rustc/cargo.
# shellcheck disable=SC2016
set -u
FAIL=0
WORK=$(mktemp -d "${TMPDIR:-/tmp}/build-ready.XXXXXX") || exit 1
trap 'rm -rf "$WORK"' EXIT
ok() { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=1; }
need() { for c in "$@"; do if command -v "$c" >/dev/null 2>&1; then ok "$c"; else bad "$c missing"; fi; done; }
want() { for c in "$@"; do if command -v "$c" >/dev/null 2>&1; then ok "$c (optional)"; else printf '  skip  %s not installed (optional)\n' "$c"; fi; done; }
step() { # step NAME COMMAND...: run in the work dir, quietly
    name=$1; shift
    if ( cd "$WORK" && "$@" ) >"$WORK/log" 2>&1; then ok "$name"; else bad "$name (see below)"; sed 's/^/        /' "$WORK/log" | tail -15; fi
}

echo "== tools"
need cc c++ ld ar make patch pkgconf tar xz bison flex m4 autoconf automake libtool cmake ninja meson
if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then ok "curl or wget"; else bad "curl or wget missing"; fi
want go python3 perl rustc cargo

echo "== compile"
mkdir -p "$WORK/c" "$WORK/auto" "$WORK/cm" "$WORK/ms"
printf '#include <stdio.h>\nint main(void){puts("ok");return 0;}\n' > "$WORK/c/t.c"
printf '#include <iostream>\nint main(){std::cout<<"ok\\n";}\n' > "$WORK/c/t.cpp"
step "C compile and run" sh -c 'cc c/t.c -o c/t && ./c/t'
step "C++ compile and run" sh -c 'c++ c/t.cpp -o c/tp && ./c/tp'
step "pkgconf runs" pkgconf --version

echo "== autotools"
printf 'int main(void){return 0;}\n' > "$WORK/auto/main.c"
printf 'AC_INIT([t],[1])\nAM_INIT_AUTOMAKE([foreign])\nAC_PROG_CC\nAC_CONFIG_FILES([Makefile])\nAC_OUTPUT\n' > "$WORK/auto/configure.ac"
printf 'bin_PROGRAMS = t\nt_SOURCES = main.c\n' > "$WORK/auto/Makefile.am"
step "autoreconf, configure, make, make install (DESTDIR)" sh -c 'cd auto && autoreconf -fi && ./configure --prefix=/usr && make && make install DESTDIR="$PWD/stage" && test -x stage/usr/bin/t'

echo "== cmake + ninja"
printf 'cmake_minimum_required(VERSION 3.10)\nproject(t C)\nadd_executable(t main.c)\ninstall(TARGETS t DESTINATION bin)\n' > "$WORK/cm/CMakeLists.txt"
printf 'int main(void){return 0;}\n' > "$WORK/cm/main.c"
step "cmake -G Ninja, build, install" sh -c 'cmake -S cm -B cm/build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr && cmake --build cm/build && DESTDIR="$PWD/cm/stage" cmake --install cm/build && test -x cm/stage/usr/bin/t'

echo "== meson"
printf "project('t','c')\nexecutable('t','main.c',install:true)\n" > "$WORK/ms/meson.build"
printf 'int main(void){return 0;}\n' > "$WORK/ms/main.c"
step "meson setup, compile, install" sh -c 'meson setup ms/build ms --prefix=/usr && meson compile -C ms/build && DESTDIR="$PWD/ms/stage" meson install -C ms/build && test -x ms/stage/usr/bin/t'

echo "== optional language runtimes"
if command -v go >/dev/null 2>&1; then
    mkdir -p "$WORK/go"; printf 'package main\nfunc main(){}\n' > "$WORK/go/m.go"
    step "go build" sh -c 'cd go && go build -o m m.go'
fi
if command -v python3 >/dev/null 2>&1; then step "python3" python3 -c 'import sys, zlib'; fi
if command -v perl >/dev/null 2>&1; then step "perl" perl -e 'print "ok\n"'; fi

echo
if [ "$FAIL" = 0 ]; then echo "build-ready: yes"; else echo "build-ready: NO (install the missing profiles: get --profile build-toolchain; get --profile common-build-deps)"; fi
exit "$FAIL"

#!/bin/sh
#
# Build the DEB or RPM packages for the distribution this script runs on,
# install them and run a smoke test.
#
# usage: build-packages.sh <distro tag, e.g. debian-13 or el9> <output dir>
#
set -eux

DIST="$1"
OUT="$2"

if [ -f /etc/debian_version ]; then
	GENERATOR=DEB
else
	GENERATOR=RPM
fi

cmake -S . -B build -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DCPACK_GENERATOR="$GENERATOR" \
	-DCPACK_RPM_PACKAGE_RELEASE_DIST=ON
cmake --build build
(cd build && cpack -G "$GENERATOR")

mkdir -p "$OUT"

if [ "$GENERATOR" = DEB ]; then
	# Same file names on every distribution: add the distribution tag,
	# e.g. softether-vpnserver_5.2.5189_amd64.deb -> softether-vpnserver_5.2.5189_debian-13_amd64.deb
	for f in build/*.deb; do
		name=$(basename "$f" .deb)
		cp "$f" "$OUT/${name%_*}_${DIST}_${name##*_}.deb"
	done
	apt-get install -y "$PWD"/build/*.deb
else
	# The RPM release already carries the distribution tag (e.g. 1.el9)
	cp build/*.rpm "$OUT/"
	dnf install -y build/*.rpm
	rpm -V softether-common softether-vpnbridge softether-vpnclient softether-vpncmd softether-vpnserver
fi

# Smoke test of the installed packages
ls -l /usr/lib/systemd/system/softether-vpnserver.service 2>/dev/null \
	|| ls -l /lib/systemd/system/softether-vpnserver.service
vpncmd /TOOLS /CMD Check | tee check.log
grep -q "All checks passed" check.log

ls -l "$OUT"

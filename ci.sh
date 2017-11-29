#!/bin/bash
#    Copyright (C) 2017 Daniel 'f0o' Preussker <f0o@devilcode.org>
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e
set -x

emerge-webrsync
cp /frr-gentoo/* /usr/portage/. -Rv

keyword=$(emerge --info | grep "ACCEPT_KEYWORDS=" | sed 's/ACCEPT_KEYWORDS=//g; s/"//g' | cut -d " " -f 1)
cpus=$(grep -c "^processor" /proc/cpuinfo)
if [ "x$cpus" == "x" ]; then
 cpus=1
fi

find /frr-gentoo -regex '.*\.ebuild$' -type f | sort -n | while read ebuild; do
 echo "=== Testing $ebuild"
 pkg=$(sed 's/\.ebuild//g'<<<"$ebuild" | rev | cut -d / -f 1,3 | rev)
 use=$( set +e; set +x; source $ebuild; echo $IUSE | sed 's/+//g ;s/ doc / /g' )
 echo "=$pkg $use" >> /etc/portage/package.use/$(cut -d "/" -f 2 <<<"$pkg")
 if grep 9999 <<<"$pkg"; then
  echo "=$pkg **" >> /etc/portage/package.accept_keywords
 else
  echo "=$pkg ~$keyword" >> /etc/portage/package.accept_keywords
 fi
 if git log -n1 | grep -wqs "~~CI DEPCLEAN~~"; then
  ( MAKEOPTS="-j$cpus" emerge -v "=$pkg" && emerge --depclean "=$pkg" && emerge --depclean ) || exit 2
 else
  ( MAKEOPTS="-j$cpus" emerge -v "=$pkg" && emerge --depclean "=$pkg" ) || exit 2
 fi
done

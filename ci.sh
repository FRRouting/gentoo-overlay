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

ARCH="$1"

find /frr-gentoo -regex '.*\.ebuild$' -type f | while read ebuild; do
 pkg=$(sed 's/\.ebuild//g'<<<"$ebuild" | rev | cut -d / -f 1,3 | rev)
 use=$( set +e; set +x; source $ebuild; echo $IUSE | sed 's/+//g ;s/ doc / /g' )
 if grep 9999 <<<"$pkg"; then
  extra="**"
 else
  extra=""
 fi
 ( ACCEPT_KEYWORDS="amd64 ~amd64 $extra" USE="$use" emerge -v "=$pkg" && emerge --unmerge "=$pkg" ) || exit 2
done


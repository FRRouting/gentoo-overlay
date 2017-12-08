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

run_portage() {
 echo "=== Building: $1 ==="
 ebuild=$(find /frr-gentoo -type f -name "$1.ebuild")
 pkg=$(sed 's/\.ebuild//g'<<<"$ebuild" | rev | cut -d / -f 1,3 | rev)
 use=$( set +e; set +x; source $ebuild; echo $IUSE | sed 's/+//g ;s/ doc / /g' )
 echo "=$pkg $use" >> /etc/portage/package.use/$(cut -d "/" -f 2 <<<"$pkg")
 if grep 9999 <<<"$pkg"; then
  echo "=$pkg **" >> /etc/portage/package.accept_keywords
 else
  echo "=$pkg ~$keyword" >> /etc/portage/package.accept_keywords
 fi
 ( set +e; set +x; MAKEOPTS="-j$cpus" emerge -v "=$pkg" && emerge --depclean "=$pkg" ) 2>&1 | tee -a /portage.log | grep ">>> "
 ret=$?
 echo "=== Built: $1 / Exit: $ret ==="
 return $ret
}

run_preflight() {
 echo "=== Running Pre-Flight Checks ==="
 ebuild=$(find /frr-gentoo -type f -name "$EBUILD.ebuild")
 keywords=$( set +e; set +x; source $ebuild; echo $KEYWORDS )
 tkeyword=$( cut -d - -f 2 <<<"$TARGET" )
 skip=0;
 for k in $keywords; do
  if [ "$k" == "$tkeyword" ] && ! grep -qs "~" <<< "$k"; then
   skip=1
   break;
  fi
 done
 if [ $skip -eq 0 ]; then
  sudo apt-get update -qq
  sudo apt-get -y -o Dpkg::Options::="--force-confnew" install docker-ce
  sudo docker pull gentoo/$TARGET
  sudo docker run -t -i -v $(pwd):/frr-gentoo gentoo/$TARGET /frr-gentoo/ci.sh $EBUILD
 else
  echo "Skipping stable ebuild"
 fi
}

set -e
set -x

if [ "x$1" == "x_preflight" ]; then
 run_preflight
 exit $?
fi

profile=$(ls -la /etc/portage/make.profile | rev | cut -d " " -f 1 | rev)
if grep '^../../usr/portage/gentoo/' <<< "$profile"; then
 rm -v /etc/portage/make.profile
 echo 'PORTDIR=/usr/portage' >> /etc/portage/make.conf
 ln -v -s $(sed 's!../../usr/portage/gentoo/!/usr/portage/!' <<<"$profile") /etc/portage/make.profile
fi
emerge-webrsync
cp /frr-gentoo/* /usr/portage/. -Rv

ebuild="$1"
keyword=$(emerge --info | grep "ACCEPT_KEYWORDS=" | sed 's/ACCEPT_KEYWORDS=//g; s/"//g' | cut -d " " -f 1)
cpus=$(grep -c "^processor" /proc/cpuinfo)
if [ "x$cpus" == "x" ]; then
 cpus=1
fi

if [ "x$ebuild" == "x" ]; then
 find /frr-gentoo -regex '.*\.ebuild$' -type f | sort -n | while read ebuild; do
  run_portage $(sed 's/\.ebuild//g'<<<"$ebuild" | rev | cut -d / -f 1 | rev)
  if ! [ $? -eq 0 ]; then
   cat /portage.log
   exit 3
  fi
 done
else
 run_portage "$ebuild"
 if ! [ $? -eq 0 ]; then
  cat /portage.log
  exit 3
 fi
fi

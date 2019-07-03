#!/bin/bash

set -f
set -e
set -u
set -o pipefail

declare ORIGINAL=' \[ -z "$PS1" \] && return '
ORIGINAL="${ORIGINAL// /[[:space:]]*}"

declare REPLACEMENT='case $- in
    *i*) ;;
      *) return;;
esac'
REPLACEMENT="${REPLACEMENT//
/\\n}"

declare -r -a FIX_FILES=( /etc/bash.bashrc /etc/skel/.bashrc /root/.bashrc )

sed -i -e 's/^'"$ORIGINAL"'$/'"$REPLACEMENT"'/' "${FIX_FILES[@]}"

echo 'export PYTHONPATH=$PYTHONPATH:/opt/drake/lib/python3.6/site-packages' >> /root/.bashrc
echo 'source "$HOME"/catkin_ws/devel/setup.bash' >> /root/.bashrc

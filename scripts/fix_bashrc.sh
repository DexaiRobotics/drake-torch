#!/bin/bash

set -euf -o pipefail

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

cat <<'EOF' >> /root/.bashrc
if [[ -f $HOME/catkin_ws/devel/setup.bash ]]; then
    echo "found $HOME/catkin_ws/devel/setup.bash. sourcing..."
    source $HOME/catkin_ws/devel/setup.bash
elif [[ -f /opt/ros/$ROS_DISTRO/setup.bash ]]; then
    echo "found /opt/ros/$ROS_DISTRO/setup.bash. sourcing..."
    source /opt/ros/$ROS_DISTRO/setup.bash
fi
EOF

#!/bin/bash
set -eufo pipefail

declare ORIGINAL=' \[ -z "$PS1" \] && return '
ORIGINAL="${ORIGINAL// /[[:space:]]*}"

# need to source bashrc in a non-interactive shell to get paths correct
declare REPLACEMENT='case $- in
    *i*) ;;
      *) return;;
esac'
REPLACEMENT="${REPLACEMENT//
/\\n}"

declare -r -a FIX_FILES=( /etc/bash.bashrc /etc/skel/.bashrc /root/.bashrc )

sed -i -e 's/^'"$ORIGINAL"'$/'"$REPLACEMENT"'/' "${FIX_FILES[@]}"

cat <<'EOF' > /root/environment.sh

# this adds py3 to $PYTHONPATH
if [[ -f /opt/ros/${ROS_DISTRO}/setup.bash ]]; then
  echo "found /opt/ros/${ROS_DISTRO}/setup.bash. sourcing..."
  source /opt/ros/${ROS_DISTRO}/setup.bash
fi

# this script is only present after catkin workspace has been built
# with catkin_make and does not exist before catkin_make
# on melodic this sets $PYTHONPATH to two py27 locations and then py3
# but we want py3 first
if [[ -f $HOME/catkin_ws/devel/setup.bash ]]; then
  echo "found $HOME/catkin_ws/devel/setup.bash. sourcing..."
  source $HOME/catkin_ws/devel/setup.bash
fi

if [[ $ROS_DISTRO == "melodic" ]]; then
  # reorder $PYTHONPATH by moving py3 to the front (remove + prepend)
  py3path="/opt/ros/melodic/lib/python3/dist-packages"
  export PYTHONPATH=`echo $PYTHONPATH | tr ":" "\n" | grep -v $py3path | tr "\n" ":"`
  export PYTHONPATH=$py3path:$PYTHONPATH
  # finally append py27 path if not present (useful before catkin_make is run)
  if ! grep -q /opt/ros/melodic/lib/python2.7/dist-packages <<< "$PYTHONPATH"; then
    export PYTHONPATH=$PYTHONPATH:/opt/ros/melodic/lib/python2.7/dist-packages/
  fi
fi

if [[ $(lsb_release -sc) == "focal" ]]; then
  alias python=python3
fi

. activate

EOF

echo "source /root/environment.sh" >> /root/.bashrc

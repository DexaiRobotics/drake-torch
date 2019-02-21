#!/bin/bash
set -e

# setup the xterm session
Xvfb :20 -screen 0 1366x768x16 &> /dev/null &
x11vnc -passwd TestVNC -display :20 -N -forever &> /dev/null &

# run setup.sh to build rl_cartpole
cd /src/examples/rl_cartpole

# start the visualizer
# /opt/drake/bin/drake-visualizer &> /dev/null &

exec "$@"

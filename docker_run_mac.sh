
#! /bin/bash
echo "Drake Docker container for MAC"
if [ "$#" != "1" ]; then
  echo "Please supply a relative path to a directory to mount as /src."
  exit 1
else
  DISPLAY=":20"
  echo $DISPLAY
  docker run -it -e DISPLAY=$DISPLAY -p 5920:5920 -p 8097:8097\
              --rm -v "$(pwd)/$1":/src drake-torch:latest \
              /bin/bash -c "cd /src && /bin/bash"
fi

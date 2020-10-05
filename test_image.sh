#! /bin/bash
# image ID/tag is the required positional argument

docker run -v "$(pwd)/in_container_scripts:/root/scripts" $1 bash -ic "/root/scripts/run_tests.sh"

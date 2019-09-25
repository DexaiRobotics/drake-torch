
#! /bin/bash
echo "Testing Drake-Torch Docker containers..."
docker run -it drake-torch:cuda_test
cuda_test_result=$(echo $?)
if [[ $cuda_test_result != 0  ]]; then
    echo "test_installation.py=$cuda_test_result; test failed for drake-torch:cuda!"
    exit 1
else
    echo "test_installation.py=$cuda_test_result; test passed for drake-torch:cuda!"
fi
docker run -it drake-torch:cpu_test
cpu_test_result=$(echo $?)
if [[ $cpu_test_result != 0  ]]; then
    echo "test_installation.py=$cpu_test_result; test failed for drake-torch:cpu!"
    exit 2
else
    echo "test_installation.py=$cpu_test_result; test passed for drake-torch:cpu!"
fi
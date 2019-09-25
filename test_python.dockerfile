ARG BASE_IMAGE
FROM $BASE_IMAGE
SHELL ["/bin/bash", "-c"]
COPY tests/test_installation.py $HOME
CMD export PYTHONPATH=$PYTHONPATH:/opt/drake/lib/python3.6/site-packages && python3 test_installation.py

###############################################################################
#   Copyright (C) 2026 Shane Daley, M0VUB aka ShaYmez. <shane@freestar.network>
#
#   Dockerfile for the HBlink4 engine image (installer project).
#   HBlink4 source is Copyright (C) 2016-2025 Cortney T. Buffington, N0MJS.
###############################################################################
#
# Build context is the HBlink4 git checkout (/opt/HBlink4).
# Runtime deps only — do not pip install Cortney's full requirements.txt
# (that file includes pytest).

ARG PYTHON_IMAGE=python:3.14-slim-bookworm
FROM ${PYTHON_IMAGE}

WORKDIR /opt/HBlink4

RUN pip install --no-cache-dir \
        'dmr_utils3>=0.1.29' \
        'typing-extensions>=4.7.1'

COPY hblink4/ /opt/HBlink4/hblink4/

CMD ["python", "-u", "hblink4/hblink.py", "config/config.json"]

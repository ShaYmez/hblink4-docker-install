###############################################################################
#   Copyright (C) 2026 Shane Daley, M0VUB aka ShaYmez. <shane@freestar.network>
#
#   Dockerfile for the HBlink4 dashboard image (installer project).
#   HBlink4 source is Copyright (C) 2016-2025 Cortney T. Buffington, N0MJS.
###############################################################################
#
# Build context is the HBlink4 git checkout (/opt/HBlink4).
# Copies dashboard/ (including static/) and hblink4/ (RepeaterMatcher peek).

ARG PYTHON_IMAGE=python:3.14-slim-bookworm
FROM ${PYTHON_IMAGE}

WORKDIR /opt/HBlink4

COPY requirements-dashboard.txt /tmp/requirements-dashboard.txt
RUN pip install --no-cache-dir -r /tmp/requirements-dashboard.txt \
 && rm -f /tmp/requirements-dashboard.txt

COPY dashboard/ /opt/HBlink4/dashboard/
COPY hblink4/ /opt/HBlink4/hblink4/

CMD ["python", "-u", "dashboard/server.py"]

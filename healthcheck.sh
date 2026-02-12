#!/bin/bash
# Simple health check — verify node process is running
pgrep -f "openclaw node" > /dev/null 2>&1 || exit 1

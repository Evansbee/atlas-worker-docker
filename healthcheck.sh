#!/bin/bash

# Check if OpenClaw node process is running
if pgrep -f "openclaw node host" > /dev/null; then
    echo "OpenClaw node host is running"
    exit 0
else
    echo "OpenClaw node host is not running"
    exit 1
fi
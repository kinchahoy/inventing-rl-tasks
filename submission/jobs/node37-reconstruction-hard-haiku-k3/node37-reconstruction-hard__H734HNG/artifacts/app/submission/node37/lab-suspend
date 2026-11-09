#!/bin/sh
# Lab stand-in for `systemctl suspend`: a VM under test must not sleep.
logger -t lab-suspend "suspend requested"
date -u +%s > /var/lib/node37/suspend-requested

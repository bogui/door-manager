#!/bin/sh
# Substitute credentials from environment into Asterisk config before startup.
# Requires: envsubst (from gettext-base package, present on Debian/Ubuntu images).
# Note: only pjsip.conf and manager.conf are templated — extensions.conf is not touched.
set -e

envsubst '${PANEL_PASSWORD}${TEST_PASSWORD}' \
  < /templates/pjsip.conf > /etc/asterisk/pjsip.conf

envsubst '${AMI_PASSWORD}' \
  < /templates/manager.conf > /etc/asterisk/manager.conf

exec asterisk -f

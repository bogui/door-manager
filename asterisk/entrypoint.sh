#!/bin/sh
# Substitute credentials from environment into Asterisk config before startup.
# Uses sed — no external dependencies required.
# Note: only pjsip.conf and manager.conf are templated — extensions.conf is not touched.
set -e

sed \
  -e "s|\${PANEL_PASSWORD}|${PANEL_PASSWORD}|g" \
  -e "s|\${TEST_PASSWORD}|${TEST_PASSWORD}|g" \
  /templates/pjsip.conf > /etc/asterisk/pjsip.conf

sed \
  -e "s|\${AMI_PASSWORD}|${AMI_PASSWORD}|g" \
  /templates/manager.conf > /etc/asterisk/manager.conf

exec asterisk -f

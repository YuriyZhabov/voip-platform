#!/bin/bash
set -e

echo "Removing existing database..."
rm -f /var/lib/asterisk/astdb.sqlite3

echo "Setting permissions..."
chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk /var/run/asterisk

echo "Setting max files open to 1000"
ulimit -n 1000

echo "Starting Asterisk 22 without xmldoc..."
exec "$@"
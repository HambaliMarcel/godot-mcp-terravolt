#!/usr/bin/env sh
# Reads commit message from stdin (--msg-filter). Strip CRLF then drop Cursor Agent trailer.
tr -d '\015' | grep -vE '^Co-authored-by:.*cursoragent@cursor\.com'

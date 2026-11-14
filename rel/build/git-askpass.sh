#!/bin/sh
# Read only the ephemeral build secret; never store a credential in the image.
case "$1" in
  "Username for 'https://github.com': ")
    printf '%s\n' x-access-token
    ;;
  "Password for 'https://x-access-token@github.com': ")
    cat "${GITHUB_BUILD_SECRET_FILE:-/run/secrets/github_token}"
    ;;
  *)
    exit 1
    ;;
esac

#!/bin/bash
# get commit and appropriate mozjs tar
# thanks to https://github.com/mozilla-spidermonkey/spidermonkey-embedding-examples/blob/esr91/tools/get_sm.sh

DOWNLOAD="false"
VALID_ARGUMENTS=$# # Returns the count of arguments that are in short or long options

if [ "$VALID_ARGUMENTS" -ne 1 ] && [ "$VALID_ARGUMENTS" -ne 2 ]
then
  echo "Run with: ./get_sm.sh lts-version [download]"
  exit 2
fi

re='^[0-9]+$'
if ! [[ $1 =~ $re ]] ; then
   echo "Warning: lts-version is not a number, using 102 as default value!" >&2;
   LTS=102
else
  LTS=$1
fi

if [ "$2" == "download" ]; then
  DOWNLOAD="true"
fi

case "$OSTYPE" in
  msys*)    #echo "Windows detected -> Setting IFS=$'\\r\n'"
            IFS=$'\r\n'
            ;;
  *)        #echo "Other OS detected -> Setting IFS=$'\\n'"
            IFS=$'\n'
            ;;
esac

if [ "$LTS" -eq 91 ]; then
  # EOL Spidermonkey versions
  DOWNLOAD_URL="https://archive.mozilla.org/pub/firefox/releases/91.13.0esr/source/firefox-91.13.0esr.source.tar.xz"
  # download old version from Mozilla archive server
  if [ "$DOWNLOAD" == "true" ]; then
    curl -s -L -O -J "$DOWNLOAD_URL"
  fi
else
  repo="mozilla-esr$LTS"
  jobs=( $(curl -s "https://treeherder.mozilla.org/api/project/$repo/push/?full=true&count=10" | jq 'try .results[].id') )

  for i in "${jobs[@]}"
  do
      task_id=$(curl -s "https://treeherder.mozilla.org/api/jobs/?push_id=$i" | jq -r '.results[] | select(.[] == "spidermonkey-sm-package-linux64/opt") | .[14]')
      if [ -n "${task_id}" ]; then
          echo "Task id ($task_id)"
          tar_file=$(curl -s "https://firefox-ci-tc.services.mozilla.com/api/queue/v1/task/$task_id/runs/0/artifacts" | jq -r '.artifacts[] | select(.name | contains("tar.xz")) | .name')
          echo "Tar at https://firefox-ci-tc.services.mozilla.com/api/queue/v1/task/$task_id/runs/0/artifacts/$tar_file"
          if [ "$DOWNLOAD" == "true" ]; then
            DOWNLOAD_URL="https://firefox-ci-tc.services.mozilla.com/api/queue/v1/task/$task_id/runs/0/artifacts/$tar_file"
            curl -s -L -O -J "$DOWNLOAD_URL"
          fi
          break
      fi
  done
fi

# Set env variables for GH action
if [ "$CI" == "true" ] && [ "$DOWNLOAD" == "true" ]; then
  echo "MOZJS_TAR=$(basename "$DOWNLOAD_URL")" >> $GITHUB_ENV
  if [ "$LTS" -eq 91 ]; then
    echo "MOZJS_DIR=$(basename "$DOWNLOAD_URL" esr.source.tar.xz)" >> $GITHUB_ENV
  else
    echo "MOZJS_DIR=$(basename "$DOWNLOAD_URL" .tar.xz)" >> $GITHUB_ENV
  fi
fi

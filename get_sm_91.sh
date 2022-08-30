#!/bin/bash
# get commit and appropriate mozjs tar
# thanks to https://github.com/mozilla-spidermonkey/spidermonkey-embedding-examples/blob/esr91/tools/get_sm.sh

case "$OSTYPE" in
  msys*)    echo "Windows detected -> Setting IFS=$'\\r\n'"
            IFS=$'\r\n'
            ;;
  *)        echo "Other OS detected -> Setting IFS=$'\\n'"
            IFS=$'\n'
            ;;
esac

repo=mozilla-esr91
jobs=( $(curl -s "https://treeherder.mozilla.org/api/project/$repo/push/?full=true&count=10" | jq '.results[].id') )

for i in "${jobs[@]}"
do
    task_id=$(curl -s "https://treeherder.mozilla.org/api/jobs/?push_id=$i" | jq -r '.results[] | select(.[] == "spidermonkey-sm-package-linux64/opt") | .[14]')
    if [ -n "${task_id}" ]; then
        echo "Task id ($task_id)"
        tar_file=$(curl -s "https://firefox-ci-tc.services.mozilla.com/api/queue/v1/task/$task_id/runs/0/artifacts" | jq -r '.artifacts[] | select(.name | contains("tar.xz")) | .name')
        echo "Tar at https://firefox-ci-tc.services.mozilla.com/api/queue/v1/task/$task_id/runs/0/artifacts/$tar_file"
        if [ "$CI" = "true" ]; then
          echo "MOZJS_TAR=$(basename "$tar_file")" >> $GITHUB_ENV
          echo "MOZJS_DIR=$(basename "$tar_file" .tar.xz)" >> $GITHUB_ENV
        fi
        if [ "${1}" = "download" ]; then
          curl -s -L -O -J "https://firefox-ci-tc.services.mozilla.com/api/queue/v1/task/$task_id/runs/0/artifacts/$tar_file"
        fi
        break
    fi
done
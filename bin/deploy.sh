#!/usr/bin/env bash

set -e

bundle exec ruby scripts/deploy.rb

git config user.name  "Yohei Yasukawa"
git config user.email "yohei@yasslab.jp"

git add -f README.md
git add -f instances.csv

# マージコミットメッセージから PR番号を抽出
PR_NUMBER=$(git log -1 --pretty=%B | grep -oE '#[0-9]+' | head -1 || echo "")

# コミットメッセージを動的に生成
if [ -n "$PR_NUMBER" ]; then
    COMMIT_MSG="Deploy from actions (PR $PR_NUMBER)"
else
    COMMIT_MSG="Deploy from actions"
fi

git commit --quiet -m    "$COMMIT_MSG"
git push --force --quiet "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}" main:gh-pages

# 公開のあとに、行の数だけサーバーが実際にあるかを確かめる
# 作成の失敗は終了コードに出ないため、ここで初めて気づける
# 公開の後に置くのは、1台の失敗で他の道場の IP まで止めないため
bundle exec ruby scripts/verify_created.rb

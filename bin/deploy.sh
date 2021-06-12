#!/usr/bin/env bash

set -e

bundle exec ruby ruby_scripts/deploy.rb 

git config user.name "Github Actions"
git config user.email "noreply@yasslab.jp"

git add -f README.md
git add -f instances.csv

git commit --quiet -m "Deploy from actions"
git push --force --quiet "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}" master:gh-pages

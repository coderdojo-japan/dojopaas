#!/usr/bin/env bash

set -e

# if [[ "false" != "$TRAVIS_PULL_REQUEST" ]]; then
# 	echo "Not deploying pull requests."
# 	exit
# fi

# if [[ "master" != "$TRAVIS_BRANCH" ]]; then
# 	echo "Not on the 'master' branch."
# 	exit
# fi

bundle exec ruby ruby_scripts/deploy.rb 

# rm -fr .git
# rm -fr .gitignore

# git init
git config user.name "Github Actions"
git config user.email "noreply@yasslab.jp"

git add -f README.md
git add -f instances.csv

git commit --quiet -m "Deploy from actions"
git push --force --quiet "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}" master:gh-pages

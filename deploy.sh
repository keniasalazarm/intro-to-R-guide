#!/bin/bash
set -e # Exit with nonzero exit code if anything fails

SOURCE_BRANCH="master"
TARGET_BRANCH="gh-pages"

function doCompile {
  ./build.sh
}

# Pull requests and commits to other branches shouldn't try to deploy, just build to verify
if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo "Skipping deploy; just doing a build."
    doCompile
    exit 0
fi

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Now let's go have some fun with the cloned repo
git config --global user.name "Travis CI"
git config --global user.email "$COMMIT_AUTHOR_EMAIL"

# Get the deploy key by using Travis's stored variables to decrypt deploy_key.enc
ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in intro-to-r-deploy.enc -out intro-to-r-deploy -d
chmod 600 intro-to-r-deploy
eval `ssh-agent -s`
ssh-add intro-to-r-deploy

# Clone the existing gh-pages for this repo into out/
# Create a new empty branch if gh-pages doesn't exist yet (should only happen on first deply)
git clone $REPO out
cd out

# set up for git subtree deploy
git checkout -b $TARGET_BRANCH
sed -i -- '/_book/d' .gitignore
git add .gitignore
git commit -m 'allow dist files'
git subtree add --squash --prefix _book $SSH_REPO $TARGET_BRANCH

# Run our compile script
doCompile

# # If there are no changes to the compiled out (e.g. this is a README update) then just bail.
# if [ -z `git diff --exit-code` ]; then
#     echo "No changes to the output on this push; exiting."
#     exit 0
# fi

# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
git add _book
git commit -m "Deploy to GitHub Pages: ${SHA}"

# Now that we're all set up, we can push.
git subtree push --squash --prefix _book $SSH_REPO $TARGET_BRANCH
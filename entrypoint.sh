#!/usr/bin/env bash
set -e

if [[ "${DEBUG}" -eq "true" ]]; then
    set -x
fi

GIT_USERNAME="${INPUT_GIT_USERNAME:-${GIT_USERNAME:-"git"}}"
GIT_SSH_PRIVATE_KEY="${INPUT_GIT_SSH_PRIVATE_KEY}"
GIT_PUSH_ARGS="${INPUT_GIT_PUSH_ARGS:-"--tags --force --prune"}"
GIT_SSH_NO_VERIFY_HOST=${INPUT_GIT_SSH_NO_VERIFY_HOST}
GIT_SSH_KNOWN_HOSTS=${INPUT_GIT_SSH_KNOWN_HOSTS}
GIT_SSH_COMMAND_OPTS="ssh"
REMOTE="${INPUT_REMOTE:-"$*"}"
SOURCE_BRANCH="${INPUT_SOURCE_BRANCH:-"*"}"
REMOTE_BRANCH="${INPUT_REMOTE_BRANCH:-"${SOURCE_BRANCH}"}"
HAS_CHECKED_OUT="$(git rev-parse --is-inside-work-tree 2>/dev/null || /bin/true)"

if [[ "${HAS_CHECKED_OUT}" != "true" ]]; then
    echo "WARNING: repo not checked out; attempting checkout" > /dev/stderr
    echo "WARNING: this may result in missing commits in the remote mirror" > /dev/stderr
    echo "WARNING: this behavior is deprecated and will be removed in a future release" > /dev/stderr
    echo "WARNING: to remove this warning add the following to your yml job steps:" > /dev/stderr
    echo " - uses: actions/checkout@v1" > /dev/stderr
    if [[ "${SRC_REPO}" -eq "" ]]; then
        echo "WARNING: SRC_REPO env variable not defined" > /dev/stderr
        SRC_REPO="https://github.com/${GITHUB_REPOSITORY}.git" > /dev/stderr
        echo "Assuming source repo is ${SRC_REPO}" > /dev/stderr
     fi
    git init > /dev/null
    git remote add origin "${SRC_REPO}"
    git fetch --all > /dev/null 2>&1
fi

if [[ ! -d ~/.ssh ]]; then
    mkdir -p ~/.ssh
fi

# create private key file
if [[ -n "${GIT_SSH_PRIVATE_KEY}" ]]; then
    echo "${GIT_SSH_PRIVATE_KEY}" > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
    GIT_SSH_COMMAND="-i ~/.ssh/id_rsa -o IdentitiesOnly=yes"
fi

# create publickey file
if [[ -n "${GIT_SSH_PUBLIC_KEY}" ]]; then
    echo "${GIT_SSH_PUBLIC_KEY}" > ~/.ssh/id_rsa.pub
    chmod 644 ~/.ssh/id_rsa.pub
fi

# configure host key check settings
if [[ -n "${GIT_SSH_KNOWN_HOSTS}" ]]; then
    echo "${GIT_SSH_KNOWN_HOSTS}" > ~/.ssh/known_hosts
    GIT_SSH_COMMAND+=" -o UserKnownHostsFile=~/.ssh/known_hosts"
elif [[ "${GIT_SSH_NO_VERIFY_HOST}" == "true" ]]; then
    GIT_SSH_COMMAND+="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
else
    echo "WARNING: no known_hosts set and host verification is enabled (the default)"
    echo "WARNING: this job will fail due to host verification issues"
    echo "Please either provide the GIT_SSH_KNOWN_HOSTS or GIT_SSH_NO_VERIFY_HOST inputs"
    exit 1
fi

# configure git global settings 
git config --global credential.username "${GIT_USERNAME}"
git config --global core.sshCommand "${GIT_SSH_COMMAND}"
git config --global core.askPass /cred-helper.sh
git config --global credential.helper cache

# add target repo as 'mirror'
git remote add mirror "${REMOTE}"
git push ${GIT_PUSH_ARGS} mirror "refs/remotes/origin/${SOURCE_BRANCH}:refs/heads/${REMOTE_BRANCH}"

# clean up
git remote remove mirror

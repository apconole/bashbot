#!/bin/bash

setup_git_root() {
    if [ "X$GIT_REPO_ROOT" == "X" ]; then
        GIT_REPO_ROOT="$(pwd)/repositories/"
    fi

    /bin/mkdir -p "$GIT_REPO_ROOT"
}

find_command() {
    local SENDER="$1"
    local CHANNEL="$2"
    local REPO="$3"
    shift 3

    setup_git_root
    if [ ! -e "$GIT_REPO_ROOT/$REPO" ]; then
        message_post $CHANNEL "Sorry, $SENDER, but I don't see repo $REPO"
        return
    fi

    pushd "$GIT_REPO_ROOT"
    message_post $CHANNEL "Not yet ready."
    popd
}

fixes_command() {
    local SENDER="$1"
    local CHANNEL="$2"
    local REPO="$3"
    local SHA="$4"
    shift 4

    # validate sha1
    if [[ ! $SHA =~ ^[0-9a-fA-F]{12}$ ]]; then
        message_post $CHANNEL "Sorry, $SENDER, but format a sha as 12-hex digits"
        return
    fi

    setup_git_root
    if [ ! -e "$GIT_REPO_ROOT/$REPO" ]; then
        message_post $CHANNEL "Sorry, $SENDER, but I don't see repo $REPO"
        return
    fi

    local SUBJ=$(git --git-dir="$GIT_REPO_ROOT/$REPO/.git" log --format="%s" $SHA)
    if [ "X$SUBJ" == "X" ]; then
        message_post $CHANNEL "Sorry, $SENDER, no such sha found."
        return
    fi

    SUBJ=$(echo $SUBJ | head -n 1)
    message_post $CHANNEL "$SENDER: searching fixes tree for '$SUBJ'"
    (
        pushd "$GIT_REPO_ROOT/$REPO"
        local DONE=false
        local FOUND_SHAS=()
        local SEARCH_SHAS=($SHA )
        while [ "X$DONE" == "Xfalse" ]; do
            local NEXT_SEARCH=()
            for needle in "${SEARCH_SHAS[@]}"; do
                for newsha in $(git log --grep="Fixes: $needle" --format="%H"); do
                    FOUND_SHAS+=("$newsha")
                    NEXT_SEARCH+=($newsha)
                done
            done

            if [ ${#NEXT_SEARCH[@]} -eq 0 ]; then
                DONE="true"
            fi

            SEARCH_SHAS=NEXT_SEARCH
        done
        if [ ${#FOUND_SHAS[@]} -eq 0 ]; then
            message_post $CHANNEL "$SENDER: you got 99-problems, but a fix ain't one"
        else
            message_post $CHANNEL "$SENDER: check your private messages, ${#FOUND_SHAS[@]} fixes"
            message_post $SENDER "SHAS: ${FOUND_SHAS[@]}"
        fi
        popd
    ) &
}

add_command() {
    local SENDER="$1"
    local CHANNEL="$2"
    local REPO_NAME="$3"
    local REPO_URL="$4"

    setup_git_root
    if [ -e "$GIT_REPO_ROOT/$REPO_NAME" ]; then
        message_post $CHANNEL "$SENDER, sorry that exists already"
        return
    fi

    (pushd "$GIT_REPO_ROOT"
     message_post $CHANNEL "Okay $SENDER, I am cloning $REPO_URL as $REPO_NAME"
     git clone "$REPO_URL" "$REPO_NAME" >/dev/null 2>&1 </dev/null
     message_post $CHANNEL "$SENDER, '$REPO_NAME' is cloned."
     popd) &
}

update_command() {
    local SENDER="$1"
    local CHANNEL="$2"
    local REPO_NAME="$3"

    setup_git_root
    if [ ! -e "$GIT_REPO_ROOT/$REPO_NAME" ]; then
        message_post $CHANNEL "$SENDER: no such repo '$REPO_NAME'"
        return
    fi

    (pushd "$GIT_REPO_ROOT/$REPO_NAME"
     git pull >/dev/null 2>&1
     popd
     message_post $CHANNEL "$SENDER: pulled for '$REPO_NAME'") &
}

git_command() {
    GIT_CMD="$1"
    shift

    if [ "$GIT_CMD" == "add" ]; then
        add_command $*
    elif [ "$GIT_CMD" == "find" ]; then
        find_command $*
    elif [ "$GIT_CMD" == "fixes" ]; then
        fixes_command $*
    elif [ "$GIT_CMD" == "update" ]; then
        update_command $*
    fi
}

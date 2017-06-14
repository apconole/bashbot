#!/bin/bash

karma_db_exists() {
    if [ ! -e karma.db ]; then
        sqlite3 karma.db <<EOF
CREATE TABLE karma (
   channel TEXT NOT NULL,
   thing TEXT NOT NULL,
   score INTEGER DEFAULT 0
);
EOF
    fi
}

karma_db_get() {
    CHANNEL=$1
    THING=$2

    shift 2

    OUT=$1

    karma_db_exists

    RESULT=$(echo "select score from karma where channel=\"$CHANNEL\" and thing=\"$THING\";" | sqlite3 karma.db 2>/dev/null)

    if [ "$RESULT" == "" ]; then
        echo "insert into karma(channel, thing) values (\"$CHANNEL\", \"$THING\");" | sqlite3 karma.db 2>/dev/null
        RESULT="0"
    fi

    eval $OUT=$RESULT
}

karma_db_set() {
    CHANNEL=$1
    THING=$2
    VALUE=$3

    shift 3

    karma_db_exists

    RESULT=$(echo "select score from karma where channel=\"$CHANNEL\" and thing=\"$THING\";" | sqlite3 karma.db 2>/dev/null)

    if [ "$RESULT" == "" ]; then
        echo "insert into karma(channel, thing, score) values (\"$CHANNEL\", \"$THING\", $VALUE);" | sqlite3 karma.db 2>/dev/null
    else
        echo "update karma set score=$VALUE where channel=\"$CHANNEL\" and thing=\"$THING\";" | sqlite3 karma.db 2>/dev/null
    fi
}

karma_command() {
    
    CMD=$1
    shift

    [ "$CMD" == "" ] && \
        message_post $CHANNEL "Karma requires one of (get,set,++,--)" \
        && return

    if [ "$CMD" == "get" ]; then
        [ "$1" == "" ] && message_post $CHANNEL "Please provide a <thing>" \
            && return
        karma_db_get $CHANNEL $1 score
    elif [ "$CMD" == "set" ]; then
        [ "$1" == "" ] && message_post $CHANNEL "Please provide a <thing>" \
            && return
        [ "$2" == "" ] && message_post $CHANNEL "Please provide a value" \
            && return
        karma_db_set $CHANNEL $1 $2
    elif [ "$CMD" == "++" ]; then
        karma_db_get $CHANNEL $1 score
        score=$((score+1))
        karma_db_set $CHANNEL $1 $score
    elif [ "$CMD" == "--" ]; then
        karma_db_get $CHANNEL $1 score
        score=$((score-1))
        karma_db_set $CHANNEL $1 $score
    elif [ "$CMD" == "+=" ]; then
        karma_db_get $CHANNEL $1 score
        newval=$2
        score=$((score+newval))
        karma_db_set $CHANNEL $1 $score
    elif [ "$CMD" == "-=" ]; then
        karma_db_get $CHANNEL $1 score
        newval=$2
        score=$((score-newval))
        karma_db_set $CHANNEL $1 $score
    else
        message_post $CHANNEL "unknown karma command"
    fi

    message_post $CHANNEL "karma: for $1, score is now $score"
}

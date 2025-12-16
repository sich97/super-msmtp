#!/usr/bin/env sh

QUEUEDIR=/var/spool/msmtp

# Set secure permissions on created directories and files
umask 077

# Change to queue directory (create it if necessary)
if [ ! -d "$QUEUEDIR" ]; then
        logrun mkdir -p "$QUEUEDIR" -- -t msmtp -p local2.err || exit $?
fi

# Create new unique filenames of the form
# MAILFILE:  ccyy-mm-dd-hh.mm.ss[-x].mail
# MSMTPFILE: ccyy-mm-dd-hh.mm.ss[-x].msmtp
# where x is a consecutive number only appended if you send more than one
# mail per second.
BASE="$(date +%Y-%m-%d-%H.%M.%S)"
if [ -f "$QUEUEDIR"/"$BASE.mail" ] || [ -f "$QUEUEDIR"/"$BASE.msmtp" ]; then
        TMP="$BASE"
        i=1
        while [ -f "$TMP-$i.mail" ] || [ -f "$TMP-$i.msmtp" ]; do
                i=$((i + 1))
        done
        BASE="$BASE-$i"
fi
MAILFILE="$QUEUEDIR"/"$BASE.mail"
MSMTPFILE="$QUEUEDIR"/"$BASE.msmtp"

# Write command line to $MSMTPFILE
logrun tee "$MSMTPFILE" -- -t msmtp -p local2.err <<<"$@" || exit $?

# Write the mail to $MAILFILE
EMAIL_BODY=$(cat)
logrun tee "$MAILFILE" -- -t msmtp -p local2.err <<<"$EMAIL_BODY" || exit $?

# If we are online, run the queue immediately.
# Replace the test with something suitable for your site.
#ping -c 1 -w 2 SOME-IP-ADDRESS > /dev/null
#if [ $? -eq 0 ]; then
#       msmtp-runqueue.sh > /dev/null &
#fi

logger -t "msmtp" -p "local2.info" "Queued $(echo $MAILFILE)"
exit 0
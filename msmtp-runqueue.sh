#!/usr/bin/env sh

QUEUEDIR="/var/spool/msmtp"
LOCKFILE="$QUEUEDIR/.lock"
MAXWAIT=120

OPTIONS=$*

# eat some options that would cause msmtp to return 0 without sendmail mail
case "$OPTIONS" in
        *--help*)
        echo "$0: send mails in $QUEUEDIR"
        echo "Options are passed to msmtp"
        exit 0
        ;;
        *--version*)
        echo "$0: unknown version"
        exit 0
        ;;
esac

# wait for a lock that another instance has set
WAIT=0
while [ -e "$LOCKFILE" ] && [ "$WAIT" -lt "$MAXWAIT" ]; do
        sleep 1
        WAIT="$((WAIT + 1))"
done
if [ -e "$LOCKFILE" ]; then
        logger -t msmtp -p local2.err "Timeout ($MAXWAIT) when waiting for lockfile to be released at $LOCKFILE"
        exit 1
fi

# change into $QUEUEDIR
cd "$QUEUEDIR" || exit 1

# check for empty queuedir
if [ "$(echo ./*.mail)" = './*.mail' ]; then
        echo "No mails in $QUEUEDIR"
        exit 0
fi

# lock the $QUEUEDIR
logrun touch "$LOCKFILE" -- -t msmtp -p local2.err || exit $?
trap 'logrun rm -f "$LOCKFILE" -- -t msmtp -p local2.err || exit $?' EXIT

# process all mails
for MAILFILE in *.mail; do
        MSMTPFILE="$(echo $MAILFILE | sed -e 's/mail/msmtp/')"
        logger -t msmtp -p local2.info "Sending $MAILFILE to $(sed -e 's/^.*-- \(.*$\)/\1/' $MSMTPFILE)"
        if [ ! -f "$MSMTPFILE" ]; then
                logger -t msmtp -p local2.err "No corresponding file $MSMTPFILE found"
                echo "No corresponding file $MSMTPFILE found"
                continue
        fi
        logrun msmtp $OPTIONS $(cat "$MSMTPFILE") -- -t msmtp -p local2.err < "$MAILFILE" || continue
        logger -t msmtp -p local2.info "Successfully sent $MAILFILE to $(sed -e 's/^.*-- \(.*$\)/\1/' $MSMTPFILE)"
        logrun rm "$MAILFILE" "$MSMTPFILE" -- -t msmtp -p local2.err || exit $?
done

exit 0

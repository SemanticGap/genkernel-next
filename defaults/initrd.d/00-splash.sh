#!/bin/sh

. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-devmgr.sh

splash() {
    return 0
}

# this redefines splash()
[ -e "${INITRD_SPLASH}" ] && . "${INITRD_SPLASH}"

is_fbsplash() {
    if [ -e "${INITRD_SPLASH}" ] && [ "${FBSPLASH}" = '1' ]
    then
        return 0
    fi
    return 1
}

is_plymouth() {
    if [ "${PLYMOUTH}" = '1' ] && [ "${QUIET}" = '1' ] \
        && [ -e "${PLYMOUTHD_BIN}" ]
    then
        return 0
    fi
    return 1
}

is_plymouth_started() {
    [ -n "${PLYMOUTH_FAILURE}" ] && return 1
    is_plymouth && "${PLYMOUTH_BIN}" --ping 2>/dev/null && return 0
    return 1
}

splash_init() {
    if is_udev; then
        # if udev, we can load the splash earlier
        # In the plymouth case, udev will load KMS automatically
        splashcmd init
    fi
}

splashcmd() {
    # plymouth support
    local cmd="${1}"
    shift

    case "${cmd}" in
        init)
        is_fbsplash && _fbsplash_init "${1}"
        is_plymouth && _plymouth_init
        ;;

        exit)
        is_fbsplash && _fbsplash_exit
        ;;

        verbose)
        _fbsplash_hide
        _plymouth_hide
        ;;

        quiet)
        _fbsplash_show
        _plymouth_show
        ;;

        set_msg)
        _fbsplash_message "${1}"
        _plymouth_message "${1}"
        ;;

        hasroot)
        _fbsplash_newroot "${1}"
        _plymouth_newroot "${1}"
        ;;

        log)
        _fbsplash_log "${1}"
        # no plymouth support?
        ;;

        progress)
        _fbsplash_progress "${1}"
        # no plymouth support?
        ;;

        step_progress)
        _splash_step_progress
        ;;

        update_svc)
        _fbsplash_update_svc "${1}" "${2}"
        # no plymouth support?
        ;;
    esac
}

SPLASH_PROGRESS_CURRENT_STEP=0

_splash_step_progress() {
    SPLASH_PROGRESS_CURRENT_STEP=$(($SPLASH_PROGRESS_CURRENT_STEP + 1))
    if [ "${SPLASH_PROGRESS_CURRENT_STEP}" -gt "${SPLASH_PROGRESS_STEPS}" ]; then
        warn_msg "\$SPLASH_PROGRESS_STEPS needs to be increased to at least ${SPLASH_PROGRESS_CURRENT_STEP}"
    else
        _fbsplash_progress ${SPLASH_PROGRESS_CURRENT_STEP}
    fi
}

# Courtesy of dracut. Licensed under GPL-2.
# Taken from: dracut/modules.d/90crypt/crypt-lib.sh
# ask_for_password
#
# Wraps around plymouth ask-for-password and adds fallback to tty password ask
# if plymouth is not present.
#
# --cmd command
#   Command to execute. Required.
# --prompt prompt
#   Password prompt. Note that function already adds ':' at the end.
#   Recommended.
# --tries n
#   How many times repeat command on its failure.  Default is 3.
# --ply-[cmd|prompt|tries]
#   Command/prompt/tries specific for plymouth password ask only.
# --tty-[cmd|prompt|tries]
#   Command/prompt/tries specific for tty password ask only.
# --tty-echo-off
#   Turn off input echo before tty command is executed and turn on after.
#   It's useful when password is read from stdin.
ask_for_password() {
    local cmd; local prompt; local tries=3
    local ply_cmd; local ply_prompt; local ply_tries=3
    local tty_cmd; local tty_prompt; local tty_tries=3
    local ret

    while [ $# -gt 0 ]; do
        case "$1" in
            --cmd) ply_cmd="$2"; tty_cmd="$2" shift;;
            --ply-cmd) ply_cmd="$2"; shift;;
            --tty-cmd) tty_cmd="$2"; shift;;
            --prompt) ply_prompt="$2"; tty_prompt="$2" shift;;
            --ply-prompt) ply_prompt="$2"; shift;;
            --tty-prompt) tty_prompt="$2"; shift;;
            --tries) ply_tries="$2"; tty_tries="$2"; shift;;
            --ply-tries) ply_tries="$2"; shift;;
            --tty-tries) tty_tries="$2"; shift;;
            --tty-echo-off) tty_echo_off=yes;;
        esac
        shift
    done

    { flock -s 9;
        # Prompt for password with plymouth, if installed and running.
        if is_plymouth_started
        then
            "${PLYMOUTH_BIN}" ask-for-password \
                --prompt="$ply_prompt" \
                --number-of-tries=$ply_tries \
                --command="$ply_cmd"
            ret=$?
        else
            splashcmd verbose
            if [ "$tty_echo_off" = yes ]; then
                stty_orig="$(stty -g)"
                stty -echo
            fi

            local i=1
            while [ $i -le $tty_tries ]; do
                [ -n "$tty_prompt" ] && \
                printf "$tty_prompt [$i/$tty_tries]:" >&2
            eval "$tty_cmd" && ret=0 && break
            ret=$?
            i=$(($i+1))
            [ -n "$tty_prompt" ] && printf '\n' >&2
            done

            [ "$tty_echo_off" = yes ] && stty $stty_orig

            # no need for: splashcmd quiet
            # since fbsplash does not support it
            if [ $ret -ne 0 ] && is_fbsplash
            then
                splashcmd set_msg 'Disk unlocked.'
            fi
        fi
    } 9>/.console_lock

    [ $ret -ne 0 ] && bad_msg "Wrong password"
    return $ret
}

prompt_user() {
    # $1 = variable whose value is the path (examples: "REAL_ROOT",
    #      "LUKS_KEYDEV")
    # $2 = label
    # $3 = optional explanations for failure

    eval local oldvalue='$'${1}

    [ $# != 2 -a $# != 3 ] && \
        bad_msg "Bad invocation of function prompt_user."
        bad_msg "Please file a bug report with this message" && exit 1
    [ -n "${3}" ] && local explnt=" or : ${3}" || local explnt="."

    splashcmd verbose
    bad_msg "Could not find the ${2} in ${oldvalue}${explnt}"
    bad_msg "Please specify another value or:"
    bad_msg "- press Enter for the same"
    bad_msg '- type "shell" for a shell'
    bad_msg '- type "q" to skip...'
    echo -n "${2}(${oldvalue}) :: "
    read ${1}
    case $(eval echo '$'${1}) in
        'q')
            eval ${1}'='${oldvalue}
            warn_msg "Skipping step, this will likely cause a boot failure."
            break
            ;;
        'shell')
            eval ${1}'='${oldvalue}
            warn_msg "To leave and try again just press <Ctrl>+D"
            run_shell
            ;;
        '')
            eval ${1}'='${oldvalue}
            ;;
    esac
    splashcmd quiet
}

_plymouth_init() {
    good_msg "Enabling Plymouth"
    mkdir -p /run/plymouth || return 1

    # Make sure that udev is done loading tty and drm
    if is_udev
    then
        udevadm trigger --action=add --attr-match=class=0x030000 \
            >/dev/null 2>&1
        udevadm trigger --action=add --subsystem-match=graphics \
            --subsystem-match=drm --subsystem-match=tty \
            >/dev/null 2>&1
        udevadm settle
    fi

    local consoledev=
    local other=
    read consoledev other < /sys/class/tty/console/active
    consoledev=${consoledev:-tty0}
    "${PLYMOUTHD_BIN}" --attach-to-session --pid-file /run/plymouth/pid \
        || {
        PLYMOUTH_FAILURE=1;
        return 1;
    }
    _plymouth_show
    good_msg "Plymouth enabled"
}

_plymouth_hide() {
    is_plymouth_started && "${PLYMOUTH_BIN}" --hide-splash
}

_plymouth_show() {
    is_plymouth_started && "${PLYMOUTH_BIN}" --show-splash
}

_plymouth_message() {
    is_plymouth_started && "${PLYMOUTH_BIN}" --update="${1}"
}

_plymouth_newroot() {
    is_plymouth_started && "${PLYMOUTH_BIN}" --newroot="${1}"
}

_fbsplash_theme() {
    echo "${CMDLINE}" |
      sed -e 's: :\n:g' |
      grep splash |
      cut -d "=" -f 2 |
      sed -e 's:,:\n:g' |
      grep theme |
      cut -d ":" -f 2
}

is_fbsplash_started() {
    [ -e "${SPLASH_FIFO}" ] && [ -e "${SPLASH_PID_FILE}" ] && [ -d /proc/`cat "${SPLASH_PID_FILE}"` ]
}

_fbsplash_init() {
    is_fbsplash_started && return

    local TYPE="${1:-bootup}"

    mount -t tmpfs -osize=1k none "${SPLASH_CACHE}" || bad_msg "Error mounting tmpfs at ${SPLASH_CACHE}"

    "${SPLASH_BIN}" -t `_fbsplash_theme` --pidfile "${SPLASH_PID_FILE}" --type "${TYPE}"

    if [[ "${TYPE}" = "bootup" ]]; then
        splashcmd update_svc kernel svc_started
        splashcmd update_svc kernel-modules svc_inactive_start
        splashcmd update_svc rootfs svc_inactive_start
        splashcmd step_progress
    fi
}

_fbsplash_cmd() {
    is_fbsplash && is_fbsplash_started && echo "${@}" >> "${SPLASH_FIFO}"
}

_fbsplash_kill() {
    kill `cat "${SPLASH_PID_FILE}"`
}

_fbsplash_exit() {
    _fbsplash_cmd "exit staysilent"
}

_fbsplash_show() {
    _fbsplash_cmd "set mode silent"
}

_fbsplash_hide() {
    _fbsplash_cmd "set mode verbose"
}

_fbsplash_message() {
    #splash set_msg "${1}"
    _fbsplash_cmd "set message ${1}"
}

_fbsplash_log() {
    _fbsplash_cmd "log ${1}"
}

_fbsplash_progress() {
    _fbsplash_cmd "progress $(($1 * $SPLASH_PROGRESS_STEP_SIZE))"
}

_fbsplash_update_svc() {
    local service="${1}"
    local state="${2}"
    _fbsplash_cmd "update_svc ${service} ${state}"
}

_fbsplash_newroot() {
    local newroot="${1}"

    if ! mount -obind "${SPLASH_CACHE}" "${newroot}"/"${SPLASH_CACHE}"; then
        bad_msg "Failed to mount ${SPLASH_CACHE} in new root."
        _fbsplash_kill
        umount "${SPLASH_CACHE}"
    fi
}
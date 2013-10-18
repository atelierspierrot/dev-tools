#!/bin/bash
#
# DevTools - Packages development & deployment facilities
# Copyleft (c) 2013 Pierre Cassat and contributors
# <www.ateliers-pierrot.fr> - <contact@ateliers-pierrot.fr>
# License GPL-3.0 <http://www.opensource.org/licenses/gpl-3.0.html>
# Sources <http://github.com/atelierspierrot/dev-tools>
#
# Global help : `dev-tools.sh -h`
# Action help : `dev-tools.sh -h action`
# Action usage : `dev-tools.sh [-vix] -p=PROJECT_PATH [action options] action`
#

###### First paths
declare -rx _REALPATH="$0"
declare -rx _REALDIRPATH="`dirname $_REALPATH`"
declare -rx _DEVTOOLS_CONFIGFILE="dev-tools.conf"
declare -rx _DEVTOOLS_ACTIONSDIR="dev-tools-actions"

#### findRequirements ( path , info string )
# search for a relative or root path
# this needs to be defined first as it is used to find the library
findRequirements() {
    REQFILE="$1"
    ROOTREQFILE="${_REALDIRPATH}/${REQFILE}"
    REQINFO="$2"
    if [ -e "$REQFILE" ]; then
        echo "$REQFILE"
        return 0
    elif [ -e "$ROOTREQFILE" ]; then
        echo "$ROOTREQFILE"
        return 0
    else
        PADDER=$(printf '%0.1s' "#"{1..1000})
        printf "\n### %*.*s\n    %s\n    %s\n%*.*s\n\n" 0 $(($(tput cols)-4)) "ERROR! $PADDER" \
            "Unable to find required $REQINFO '$REQFILE'!" \
            "Sent in '$0' line '${LINENO}' by '`whoami`' - pwd is '`pwd`'" \
            0 $(tput cols) "$PADDER";
        exit 1
    fi
}

######## Inclusion of the config
declare -rx CFGFILE=`findRequirements "${_DEVTOOLS_CONFIGFILE}" "configuration file"`
if [ -f "$CFGFILE" ]; then source "$CFGFILE"; else echo "$CFGFILE"; exit 1; fi

######## Inclusion of the lib
declare -rx LIBFILE=`findRequirements "${DEFAULT_BASHLIBRARY_PATH}" "bash library"`
if [ -f "$LIBFILE" ]; then source "$LIBFILE"; else echo "$LIBFILE"; exit 1; fi

######## Path of the actions
declare -rx _BASEDIR=`findRequirements "${_DEVTOOLS_ACTIONSDIR}" "actions directory"`
if [ ! -d "$_BASEDIR" ]; then echo "$_BASEDIR"; exit 1; fi

#### load_actions_infos ()
# load the available actions in $ACTIONS_LIST
# load the available actions synopsis in $ACTIONS_SYNOPSIS
# load the available actions synopsis in $ACTIONS_DESCRIPTIONS
# this needs to be defined here as it is used for strings below
load_actions_infos () {
    ACTIONS_LIST=()
    ACTIONS_SYNOPSIS=()
    ACTIONS_DESCRIPTIONS=()
    export SCRIPTMAN=true
    for action in $_BASEDIR/*.sh; do
        ACTION_SYNOPSIS=''
        ACTION_DESCRIPTION=''
        ACTION_LONGDESCRIPTION=''
        ACTION_CFGVARS=''
        myaction=${action##$_BASEDIR/}
        pos=${#ACTIONS_LIST[@]}
        source "${action}"
        ACTIONS_LIST[$pos]="${myaction%%.sh}"
        if [ -n "$ACTION_SYNOPSIS" ]; then
            ACTIONS_SYNOPSIS[$pos]="${ACTION_SYNOPSIS}"
        fi
        if [ -n "$ACTION_DESCRIPTION" ]; then
            ACTIONS_DESCRIPTIONS[$pos]="${ACTION_DESCRIPTION}"
        fi
        if [ -n "$ACTION_CFGVARS" ]; then
            ACTIONS_CFGVARS=("${ACTIONS_CFGVARS[@]}" "${ACTION_CFGVARS[@]}")
        fi
    done
    export ACTIONS_LIST ACTIONS_SYNOPSIS ACTIONS_DESCRIPTIONS ACTIONS_CFGVARS
    export SCRIPTMAN=false
}

#### script settings ##########################

# bash-lib settings
MANPAGE_NODEPEDENCY=true
COMMON_OPTIONS_ARGS="p:${COMMON_OPTIONS_ARGS}"

# paths
declare -x _BACKUP_DIR="${_BASEDIR}/backup/"
declare -x _PROJECT="project"
declare -x _TARGET=`pwd`
declare -x SCRIPTMAN=false

# per action vars
declare -x ACTION
declare -x ACTION_FILE

# all actions vars
declare -xa ACTIONS_LIST=() && declare -xa ACTIONS_SYNOPSIS=() && declare -xa ACTIONS_DESCRIPTIONS=() &&
    declare -xa ACTIONS_CFGVARS=( DEFAULT_CONFIG_FILE DEFAULT_BASHLIBRARY_PATH ) && \
    load_actions_infos;

# script infos
declare -x NAME="DevTools - Packages development & deployment facilities"
declare -x SYNOPSIS="$LIB_SYNOPSIS_ACTION"
declare -x DEPLOY_HELP="Run option '-h' for help.";
declare -x DEPLOY_ACTIONS_HELP="Run option '-h action' for help about a specific action.";
declare -x SHORT_DESCRIPTION="This helper script will assist you in creating version tags of a git repository, deploying a project and its environment dependencies etc.\n\
\tRun option '<bold>-h action</bold>' to see the help about a specific action and use option '<bold>--dry-run</bold>' to make dry runs.";
declare -x SEE_ALSO="This tool is an open source stuff: <http://github.com/atelierspierrot/dev-tools>\n\
\tTo transmit a bug or an evolution: <http://github.com/atelierspierrot/dev-tools/issues>\n\
\tThis tool is base on the Bash Library: <http://github.com/atelierspierrot/bash-library>"

# actions infos
declare -rx ACTION_PRESENTATION_MASK="Help for action \"<bold>%s</bold>\"";
declare -rx ACTION_SYNOPSIS_MASK="~\$ <bold>${0}</bold>  -[<underline>COMMON OPTIONS</underline>]  %s  %s  --";
actionsstr=""
actionsdescription=""
actionssynopsis=""
for i in ${!ACTIONS_LIST[*]}; do
    itemstr=${ACTIONS_LIST[$i]}
    if [ "${#actionsstr}" == 0 ]; then
        actionsstr="${itemstr}"
    else
        actionsstr="${actionsstr} | ${itemstr}"
    fi
    actionsdescription="${actionsdescription}\n\n\t<bold>${itemstr}</bold>\n"
    itemdesc=${ACTIONS_DESCRIPTIONS[$i]}
    if [ -n "${itemdesc}" ]; then
        actionsdescription="${actionsdescription}\t${itemdesc}";
    fi
    itemsyn=${ACTIONS_SYNOPSIS[$i]}
    if [ -n "${itemsyn}" ]; then
        actionsdescription="${actionsdescription}\n\t`printf \"${ACTION_SYNOPSIS_MASK}\" \"${itemsyn}\" \"${itemstr}\"`";
        actionssynopsis="${actionssynopsis}\n\t... ${itemsyn} ${itemstr}"
    else
        actionsdescription="${actionsdescription}\n\t`printf \"${ACTION_SYNOPSIS_MASK}\" '' \"${itemstr}\"`";
    fi
done
declare -x DESCRIPTION="${SHORT_DESCRIPTION}\n\n<bold>AVAILABLE ACTIONS</bold>${actionsdescription}"
declare -x OPTIONS="Below is a list of common options available ; each action can accepts other options.\n\n\
\t<bold>-p | --project=PATH</bold>\tthe project path (default is 'pwd' - 'PATH' must exist)\n\
\t<bold>-d | --working-dir=PATH</bold>\tredefine the working directory (default is 'pwd' - 'PATH' must exist)\n\
\t<bold>-h | --help</bold>\t\tshow this information message \n\
\t<bold>-v | --verbose</bold>\t\tincrease script verbosity \n\
\t<bold>-q | --quiet</bold>\t\tdecrease script verbosity, nothing will be written unless errors \n\
\t<bold>-f | --force</bold>\t\tforce some commands to not prompt confirmation \n\
\t<bold>-i | --interactive</bold>\task for confirmation before any action \n\
\t<bold>-x | --debug</bold>\t\tsee commands to run but not run them actually\n\
\t<bold>--dry-run</bold>\t\talias of '-x'\n\
\n${OPTIONS_USAGE_INFOS}";
declare -x SYNOPSIS_ERROR="${0}  [-${COMMON_OPTIONS_ARGS}] [-x|--dry-run]  ... ${actionssynopsis}\n\
\t-p | --project=path <action : ${actionsstr}> --";

#### internal lib ##########################

#### action_file ( action name )
# find action file
action_file () {
    local ACTION="$1"
    if [ ! -z "$ACTION" ]; then
        ACTION_FILE="${_BASEDIR}/${ACTION}.sh"
        # hack to allow direct call of a file as action (with path from root)
        if [ ! -f "$ACTIONFILE" ]; then
            TMP_ACTIONFILE="${_REALDIRPATH}/${ACTION}"
            if [ -f "$TMP_ACTIONFILE" ]; then
                ACTION_FILE="$TMP_ACTIONFILE"
            fi
        fi    
    fi
    export ACTION_FILE
}

#### action_usage ( action name, action file )
# usage string per action
action_usage () {
    local ACTION_NAME="$1"
    local ACTION_FILE="$2"
    export SCRIPTMAN=true
    if [ -f $ACTION_FILE ]; then
        ACTION_SYNOPSIS=''
        ACTION_DESCRIPTION=''
        ACTION_OPTIONS=''
        ACTION_CFGVARS=''
        source "$ACTION_FILE"
        local TMP_USAGE="\n<bold>NAME</bold>\n\
\t`printf \"${ACTION_PRESENTATION_MASK}\" \"${ACTION_NAME}\"`\n\
\t${NAME}\n\n\
<bold>SYNOPSIS</bold>\n\
\t`printf \"${ACTION_SYNOPSIS_MASK}\" \"${ACTION_SYNOPSIS}\" \"${ACTION_NAME}\"`";
        if [ -n "${ACTION_DESCRIPTION}" ]; then
            TMP_USAGE="${TMP_USAGE}\n\n<bold>DESCRIIPTION</bold>\n\t${ACTION_DESCRIPTION}";
        fi
        if [ -n "${ACTION_OPTIONS}" ]; then
            TMP_USAGE="${TMP_USAGE}\n\n<bold>OPTIONS</bold>\n\t${ACTION_OPTIONS}";
        fi
        if [ -n "${ACTION_CFGVARS}" ]; then
            TMP_USAGE="${TMP_USAGE}\n\n<bold>ENVIRONMENT</bold>\n\tAvailable configuration variables: <${COLOR_NOTICE}>${ACTION_CFGVARS[@]}</${COLOR_NOTICE}>";
        fi
        if [ -n "${ACTION_FILE}" ]; then
            TMP_USAGE="${TMP_USAGE}\n\n<bold>FILE</bold>\n\t<underline>${ACTION_FILE}</underline>";
        fi
        local TMP_VERS="`library_info`"
        TMP_USAGE="${TMP_USAGE}\n\n<${COLOR_COMMENT}>${TMP_VERS}</${COLOR_COMMENT}>";
        parsecolortags "$TMP_USAGE"
    else
        error "Action file $ACTION_FILE not found!"
    fi
    export SCRIPTMAN=false
    return 0;
}

#### root_required ()
# ensure current user is root
root_required () {
    THISUSER=`whoami`
    if [ "$THISUSER" != "root" ]; then
        error "You need to run this as a 'sudo' user!"
    fi
}

#### targetdir_required ()
# ensure the project root directory is defined
targetdir_required () {
    if [ -z "$_TARGET" ]; then
        prompt 'Target directory of the project to work on' `pwd` ''
        export _TARGET=$USERRESPONSE
    fi
    if [ ! -d "$_TARGET" ]; then error "Unknown root directory '${_TARGET}' !"; fi
    load_target_config
}

#### backupdir_required ()
# ensure the project backup directory exists
backupdir_required () {
    if [ ! -d "${_BACKUP_DIR}" ]; then
        mkdir "${_BACKUP_DIR}" && chmod 775 "${_BACKUP_DIR}"
        if [ ! -d "${_BACKUP_DIR}" ]; then
            error "Backup directory '${_BACKUP_DIR}' can't be created (try to run this script as 'sudo') !"
        fi
    fi
}

#### trigger_event ( command )
## trigger a user defined command for an event
trigger_event () {
    iexec "$1"
}

#### load_target_config ()
# overwrite current deploy config with target's custom one if so
load_target_config () {
    target_configfile=$(realpath "${_TARGET}/${DEFAULT_CONFIG_FILE}")
    if [ -f "$target_configfile" ]; then
        source "$target_configfile"
    fi
    for p in "${ACTIONS_CFGVARS[@]}"; do
        export "$p"
    done
}

#### parsecomonoptions ( "$@" )
## over-writing of default function
parsecomonoptions () {
    local oldoptind=$OPTIND
    local options=$(getscriptoptions "$@")
    export ACTION=$(getlastargument $options)
    if [ ! -z $ACTION ]; then
        action_file $ACTION
        if [ ! -f "$ACTION_FILE" ]; then
            simple_error "unknown action '${ACTION}'"
        fi
    fi
    while getopts ":p:${COMMON_OPTIONS_ARGS}" OPTION $options; do
        OPTARG="${OPTARG#=}"
        case $OPTION in
        # common options
            h) 
                if [ -z $ACTION ]
                    then usage;
                    else action_usage $ACTION $ACTION_FILE;
                fi
                exit 0;;
            i) export INTERACTIVE=true; export QUIET=false;;
            v) export VERBOSE=true; export QUIET=false;;
            f) export FORCED=true;;
            x) export DEBUG=true; verecho "- debug option enabled: commands shown as 'debug >> \"cmd\"' are not executed";;
            q) export VERBOSE=false; export INTERACTIVE=false; export QUIET=true;;
            d) setworkingdir $OPTARG;;
            l) setlogfilename $OPTARG;;
            V) script_version; exit 0;;
            p) export _TARGET=$OPTARG;;
            -) case $OPTARG in
        # common options
                    project*) export _TARGET=$LONGOPTARG;;
                    help|man|usage) 
                        if [ -z $ACTION ]
                            then usage;
                            else action_usage $ACTION $ACTION_FILE;
                        fi
                        exit 0;;
                    vers*) script_version; exit 0;;
                    interactive) export INTERACTIVE=true; export QUIET=false;;
                    verbose) export VERBOSE=true; export QUIET=false;;
                    force) export FORCED=true;;
                    debug | dry-run*) export DEBUG=true; verecho "- debug option enabled: commands shown as 'debug >> \"cmd\"' are not executed";;
                    quiet) export VERBOSE=false; export INTERACTIVE=false; export QUIET=true;;
                    working-dir*) LONGOPTARG="`getlongoptionarg \"${OPTARG}\"`"; setworkingdir $LONGOPTARG;;
                    log*) LONGOPTARG="`getlongoptionarg \"${OPTARG}\"`"; setlogfilename $LONGOPTARG;;
        # library options
                    libhelp) clear; library_usage; exit 0;;
                    libvers*) library_version; exit 0;;
                    libdoc*) libdoc; exit 0;;
        # no error for others
                    *) rien=rien;;
                esac ;;
            \?) rien=rien;;
        esac
    done
    export OPTIND=$oldoptind
    return 0
}

#### first setup & options treatment ##########################

parsecomonoptions "$@"

if [ ! -z "$ACTION" ]
then
    PREACTION="EVENT_PRE_${ACTION}"
    POSTACTION="EVENT_POST_${ACTION}"
    # executing requested action
    if [ -f "$ACTION_FILE" ]
    then
        export _BASEDIR _BACKUP_DIR _PROJECT _TARGET
        if [ ! -z "${!PREACTION}" ]; then
            trigger_event "${!PREACTION}"
        fi
        source "$ACTION_FILE"
        if [ ! -z "${!POSTACTION}" ]; then
            trigger_event "${!POSTACTION}"
        fi
    else
        simple_error "unknown action '${ACTION}'"
    fi
else
    simple_error "no action to execute"
fi

exit 0
# Endfile
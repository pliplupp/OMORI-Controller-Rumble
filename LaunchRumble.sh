#!/bin/bash

# define colors as variables so the magic numbers don't drive me insane
Black=0
DarkRed=1
DarkGreen=2
DarkYellow=3
DarkBlue=4
DarkMagenta=5
DarkCyan=6
Gray=7
DarkGray=8
Red=9
Green=10
Yellow=11
Blue=12
Magenta=13
Cyan=14
White=15


# define the current dir for the config and quote paths
currentDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# default config variables
configFile=$currentDir/"config.txt"
isDebug=false
isAuto=false
selectedTheme="random"
aprilFools=$false
customThemeStr=$null
overrideOmoriPath=$null
launchMethod="steam"

# debug printer
function DebugMsg {
    local message=$1
    if [ $isDebug = true ]; then
        tput setaf 14
        echo "  [DBG]" "${message}"
        tput sgr0
    fi
}

# enables extended regex stuff
#shopt -s extglob

# ========================================================
#      C O N F I G   R E A D E R
# ========================================================
if [ -f $configFile ]; then 
    DebugMsg "config exists"

    while read line; do 
        #echo $line
        # ONLY read lines that aren't whitespace or comments
        if [[ ! $line =~ ^\ *# ]];
        then
            # this is all just adapted from the original powershell version
            # learning to do all this regex stuff in bash took me way longer than it should have
            # i might just be stupid though
            if [[ $line =~ ^(Debug).*=.?(.+) ]];
            then
                if [[ ${BASH_REMATCH[2]} =~ ^(true|1|yes)$ ]]; then isDebug=true; fi;
                DebugMsg $isDebug
            elif [[ $line =~ ^(Auto).*=.?(.+) ]];
            then
                if [[ ${BASH_REMATCH[2]} =~ ^(true|1|yes)$ ]]; then isAuto=true; fi;
                DebugMsg $isAuto
            elif [[ $line =~ ^(Theme).*=.?(.+) ]];
            then
                selectedTheme=${BASH_REMATCH[2]}
                DebugMsg $selectedTheme
            elif [[ $line =~ ^(CustomTheme).*=.?(.+) ]];
            then
                customThemeStr=${BASH_REMATCH[2]}
            elif [[ $line =~ ^(AprilFools).*=.?(.+) ]];
            then
                if [[ ${BASH_REMATCH[2]} =~ ^(true|1|yes)$ ]]; then aprilFools=true; fi;
                DebugMsg $aprilFools
            elif [[ $line =~ ^(OmoriPath).*=.?(.+) ]];
            then
                if [[ ! ${BASH_REMATCH[2]} = '' ]]; then 
                    overrideOmoriPath=${BASH_REMATCH[2]};
                fi;
                DebugMsg $overrideOmoriPath
            elif [[ $line =~ ^(LaunchMethod).*=.?(.+) ]];
            then
                launchMethod=${BASH_REMATCH[2]}
                DebugMsg $launchMethod
            fi
        fi
    done < $configFile
else
    echo "no config lmao"
fi 


repoOwner='uniseth'
repoName='OMORI-Controller-Rumble'
steamAppId='1150690'
extractDir=$currentDir/'RumbleBridge_Extract'
bridgeExe=$currentDir/'RumbleBridge'
localModDir=$currentDir/'rumble'
logFile=$currentDir/'bridge_log.txt'
bridgeReady=false
modReady=false


# ========================================================
#                  A S C I I   A R T
# ========================================================
# Bash doesn't use commas to separate arrays, so those were removed
declare -a normalArt=(
        '__________________________________________________/\\\_________/\\\\\\___________________        '
        ' _________________________________________________\/\\\________\////\\\___________________       '
        '  _________________________________________________\/\\\___________\/\\\___________________      '
        '   __/\\/\\\\\\\___/\\\____/\\\____/\\\\\__/\\\\\___\/\\\___________\/\\\________/\\\\\\\\__     '
        '    _\/\\\/////\\\_\/\\\___\/\\\__/\\\///\\\\\///\\\_\/\\\\\\\\\_____\/\\\______/\\\/////\\\_    '
        '     _\/\\\___\///__\/\\\___\/\\\_\/\\\_\//\\\__\/\\\_\/\\\////\\\____\/\\\_____/\\\\\\\\\\\__   '
        '      _\/\\\_________\/\\\___\/\\\_\/\\\__\/\\\__\/\\\_\/\\\__\/\\\____\/\\\____\//\\///////___  '
        '       _\/\\\_________\//\\\\\\\\\__\/\\\__\/\\\__\/\\\_\/\\\\\\\\\___/\\\\\\\\\__\//\\\\\\\\\\_ '
        '        _\///___________\/////////___\///___\///___\///__\/////////___\/////////____\//////////__'
)
declare -a aprilFoolsArt=(
        '_________________/\\\\\\_____/\\\________________________________________________________        '
        ' ________________\////\\\____\/\\\________________________________________________________       '
        '  ___________________\/\\\____\/\\\________________________________________________________      '
        '   _____/\\\\\\\\_____\/\\\____\/\\\___________/\\\\\__/\\\\\____/\\\____/\\\__/\\/\\\\\\\__     '
        '    ___/\\\/////\\\____\/\\\____\/\\\\\\\\\___/\\\///\\\\\///\\\_\/\\\___\/\\\_\/\\\/////\\\_    '
        '     __/\\\\\\\\\\\_____\/\\\____\/\\\////\\\_\/\\\_\//\\\__\/\\\_\/\\\___\/\\\_\/\\\___\///__   '
        '      _\//\\///////______\/\\\____\/\\\__\/\\\_\/\\\__\/\\\__\/\\\_\/\\\___\/\\\_\/\\\_________  '
        '       __\//\\\\\\\\\\__/\\\\\\\\\_\/\\\\\\\\\__\/\\\__\/\\\__\/\\\_\//\\\\\\\\\__\/\\\_________ '
        '        ___\//////////__\/////////__\/////////___\///___\///___\///___\/////////___\///__________ '
)


declare -a currentThemeColors=(
    $DarkCyan
    $DarkCyan
    $Cyan
    $Cyan
    $White
    $Magenta
    $White
    $Cyan
    $DarkCyan
)
# TODO: implement themes, only the default works right now
echo ''
for i in {0..8}
do
    color=${currentThemeColors[i]}
    tput setaf $color
    echo "${normalArt[i]}"
done


tput setaf $DarkGray
echo ''
echo '                    >> O M O R I   C O N T R O L L E R <<'
echo '============================================================'

quotesFile=$currentDir/'quotes.txt'
quoteToDisplay="Waiting for something to happen?"

if [ -f $quotesFile ]
then
    declare -a quotes
    IFS=$'\n'
    while read quoteLine
    do
        if [[  $quoteLine =~ (.*) ]]
        then
            quotes+=(${BASH_REMATCH[1]})
        fi
    done < $quotesFile
    numQuotes=${#quotes[@]}
    quote=$(($(bc <<< $RANDOM) % $numQuotes))
    quoteToDisplay=${quotes[quote]}
fi

tput setaf $DarkYellow
echo $quoteToDisplay









##echo "aaaa"

#echo $launchMethod


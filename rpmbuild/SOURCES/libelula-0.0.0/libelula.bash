#!/bin/bash
# Copyright (c) 2018 Jorge Casas Hernán <jorgeksas@gmail.com>

VERSION="0.0.0"

CONFIG_PATH="/etc/libelula/libelula.conf"

####################### FUNCTIONS #######################

# Print action to stdout.
# Params: $1 -> Text to specify action.
# Return: None.
function print_action
{
	DOTS_ACTION="    "
	echo -n "${1}$DOTS_ACTION"
	{
	while true; do
		sleep 1
		DOTS_ACTION=`echo ".${DOTS_ACTION}" | sed "s/.$//"`
		echo -en "\r${1}$DOTS_ACTION"
		
		if [ "$DOTS_ACTION" == "... " ]; then
			sleep 1
			DOTS_ACTION="    "
			echo -en "\r${1}$DOTS_ACTION"
		fi
	done
	} &
	PRINT_ACTION_PID=$!
}

# Print end action to stdout.
# Params: $1 -> Text to specify action.
# Params: $2 -> Result text.
# Return: None.
function end_action
{
	kill -9 $PRINT_ACTION_PID &> /dev/null
	wait $PRINT_ACTION_PID &> /dev/null
	echo -e "\r${1}... $2"
}

# Check if format version is correct.
# Params: $1 -> Version to check.
# Return: 0 if version is correct, !0 if invalid.
function check_format_version
{
	COMPLETE_VERSION=$1

	echo $COMPLETE_VERSION | grep "_" &> /dev/null # Check if version has low bar "_" (illegal allowed version) or not
	if [ $? != 0 ]; then
		echo $COMPLETE_VERSION | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[a-zA-Z]+[0-9]+-[0-9]+$" &> /dev/null # Check if is non oficial version
		RETURN=$?
		
		if [ $RETURN != 0 ]; then
			echo $COMPLETE_VERSION | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$" &> /dev/null # Check if is oficial version
			RETURN=$?
		fi
	else
		echo $COMPLETE_VERSION | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+_[0-9]+\.[a-zA-Z]+[0-9]+-[0-9]+$" &> /dev/null # Check if is non oficial version
		RETURN=$?
		
		if [ $RETURN != 0 ]; then
			echo $COMPLETE_VERSION | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+_[0-9]+-[0-9]+$" &> /dev/null # Check if is oficial version
			RETURN=$?
		fi
	fi
	
	return $RETURN
}

# Fill variables with parts of version.
# Params: $1 -> Version to parse.
# Return: Fill the next variables.
#	VERSION_WITHOUT_RELEASE: Complete version without release number.
#	MAJOR_VERSION: Number that indicates major number.
#	MINOR_VERSION: Number that indicates minor number.
#	MICRO_VERSION: Number that indicates micro number.
#	RELEASE: Number that indicates release number.
#	NON_OFICIAL: String with the DEV or RC part of de version. For example "rc6". This var is equals to "" if is oficial var.
#	NON_OFICIAL_NAME: NON_OFICIAL part without the final number. For example "rc".
#	NON_OFICIAL_NUMBER: Number of NON_OFICIAL. For example "6".
function get_parts_of_version
{
	COMPLETE_VERSION=$1
	VERSION_WITHOUT_RELEASE=`echo $COMPLETE_VERSION | awk -F "-" '{print $1}'`
	MAJOR_VERSION=`echo $COMPLETE_VERSION | awk -F "." '{print $1}'`
	MINOR_VERSION=`echo $COMPLETE_VERSION | awk -F "." '{print $2}'`
	MICRO_VERSION=`echo $COMPLETE_VERSION | awk -F "." '{print $3}' | awk -F "-" '{print $1}'`
	RELEASE=`echo $COMPLETE_VERSION | awk -F "-" '{print $2}'`
	NON_OFICIAL=`echo $COMPLETE_VERSION | awk -F "-" '{print $1}' | awk -F "." '{print $4}'`

	if [ "$NON_OFICIAL" != "" ]; then
		NON_OFICIAL_NUMBER=`echo $NON_OFICIAL | grep -Eo '[0-9]+$'`
		NON_OFICIAL_NAME=`echo $NON_OFICIAL | awk -F "$NON_OFICIAL_NUMBER" '{print $1}'`
	fi

	return 0
}

function visual_svn_url_to_correct_url
{
	echo $1 | sed "s,/\!/,/svn/," | sed "s,#SWE_atmcns,SWE_atmcns," | sed "s,/view/head/,/,"
}

# Generate RPM $PKG_NAME from $SOURCES_PATH with version $VERSION on current directory.
function generate_rpm
{
	if [ -e /root/rpmbuild ] && [ ! -e $RPMBUILD_BACKUP ]; then
		mv /root/rpmbuild $RPMBUILD_BACKUP
	fi

	rm -rf /root/rpmbuild
	mkdir -p /root/rpmbuild/SOURCES
	mkdir -p /root/rpmbuild/SPECS

	cp -r ${SOURCES_PATH}/SOURCES/${PKG_NAME}-0.0.0 /root/rpmbuild/SOURCES/${PKG_NAME}-${VERSION_WITHOUT_RELEASE}
	cp ${SOURCES_PATH}/SPECS/${PKG_NAME}.spec /root/rpmbuild/SPECS

	# Remove .svn dirs from sources
	for SVN_TRASH_DIR in `find /root/rpmbuild/SOURCES -type d -name ".svn"`; do
		rm -rf $SVN_TRASH_DIR
	done

	# Replace __SOFTWARE_VERSION__ macro with software version
	find /root/rpmbuild -type f -exec sed -i "s/__SOFTWARE_VERSION__/${MAJOR_VERSION}.${MINOR_VERSION}.${MICRO_VERSION}/g" {} \;
	
	CURRENT_DIR=`pwd`
	cd /root/rpmbuild/SOURCES
	tar czf ${PKG_NAME}-${VERSION_WITHOUT_RELEASE}.tar.gz ${PKG_NAME}-${VERSION_WITHOUT_RELEASE}
	cd $CURRENT_DIR
	
	sed -i "s/%global major_version .*/%global major_version $MAJOR_VERSION/" /root/rpmbuild/SPECS/${PKG_NAME}.spec
	sed -i "s/%global minor_version .*/%global minor_version $MINOR_VERSION/" /root/rpmbuild/SPECS/${PKG_NAME}.spec
	sed -i "s/%global micro_version .*/%global micro_version $MICRO_VERSION/" /root/rpmbuild/SPECS/${PKG_NAME}.spec

	if [ "$NON_OFICIAL" != "" ]; then
		# It can be rc_version is commented or non exists
		grep "%global rc_version" /root/rpmbuild/SPECS/${PKG_NAME}.spec &> /dev/null
		if [ $? = 0 ]; then
			sed -i "s/%global rc_version .*/%global rc_version ${NON_OFICIAL_NUMBER}/" /root/rpmbuild/SPECS/${PKG_NAME}.spec
			sed -i "s/#%global rc_version/%global rc_version/" /root/rpmbuild/SPECS/${PKG_NAME}.spec
		else
			MICRO_VERSION_NUM_LINE=`grep -n "%global micro_version" /root/rpmbuild/SPECS/${PKG_NAME}.spec | awk -F ":" '{print $1}'`
			sed -i "${MICRO_VERSION_NUM_LINE}a %global rc_version ${NON_OFICIAL_NUMBER}" /root/rpmbuild/SPECS/${PKG_NAME}.spec
		fi

		sed -i "s/Version:.*%{major_version}.%{minor_version}.%{micro_version}.*/Version: %{major_version}.%{minor_version}.%{micro_version}.${NON_OFICIAL_NAME}%{rc_version}/" /root/rpmbuild/SPECS/${PKG_NAME}.spec
	else
		sed -i "/%global rc_version/d" /root/rpmbuild/SPECS/${PKG_NAME}.spec
		sed -i "s/Version:.*%{major_version}.%{minor_version}.%{micro_version}.*/Version: %{major_version}.%{minor_version}.%{micro_version}/" /root/rpmbuild/SPECS/${PKG_NAME}.spec
	fi

	sed -i "s/Release:[\t ]*[0-9]/Release: ${RELEASE}/" /root/rpmbuild/SPECS/${PKG_NAME}.spec

	echo "`date` STARTING ${PKG_NAME} RPM PACKAGING..." &>> $LOG_PATH
	
	export DEBUG
	
	if [ $GENERATE_SRPM = 0 ]; then
		rpmbuild -ba /root/rpmbuild/SPECS/${PKG_NAME}.spec &>> $LOG_PATH
		GENERATION_OK=$?
	else
		rpmbuild -bb /root/rpmbuild/SPECS/${PKG_NAME}.spec &>> $LOG_PATH
		GENERATION_OK=$?
	fi
	
	echo "`date` ${PKG_NAME} RPM PACKAGING ENDED." &>> $LOG_PATH

	if [ $GENERATION_OK = 0 ]; then
		RPM_GENERATED=`ls /root/rpmbuild/RPMS/*/ | awk -F " " {'print $1'}`

		if [ -f ./$RPM_GENERATED ]; then
			rm -f ./$RPM_GENERATED &> /dev/null
		fi
		
		mv /root/rpmbuild/RPMS/*/$RPM_GENERATED .

		if [ $GENERATE_SRPM = 0 ]; then
			SRPM_GENERATED=`ls /root/rpmbuild/SRPMS/`

			if [ -f ./$SRPM_GENERATED ]; then
				rm -f ./$SRPM_GENERATED &> /dev/null
			fi
			
			mv /root/rpmbuild/SRPMS/$SRPM_GENERATED .
		fi
	fi
	
	rm -rf /root/rpmbuild
	
	if [ -e $RPMBUILD_BACKUP ]; then
		mv $RPMBUILD_BACKUP /root/rpmbuild
	fi

	return $GENERATION_OK
}

# Check all user parameters before starting software generation loop. Show error message if error.
# Params: $1 -> List of params except list commands and list versions.
# Return: 0-> All correct, !0 -> otherwise
function check_general_user_vars
{
	ALL_CORRECT=0

	if [ $EUID != 0 ]; then
		echo "ERROR: Libelula must be run as root."
		ALL_CORRECT=1
	elif [ ! -f "$CONFIG_PATH" ]; then
		echo "ERROR: Config file is needed on $CONFIG_PATH path."
		ALL_CORRECT=1
	elif [ ! -f "$SW_JSON_PATH" ]; then
		echo "ERROR: Software parameters json file does not exist."
		ALL_CORRECT=1
	elif ! ${EXC_PATH}/parsejson.py $SW_JSON_PATH "" > /dev/null 2>> $LOG_PATH; then
		echo "ERROR: $SW_JSON_PATH file is malformed. Check JSON syntax."
		ALL_CORRECT=1
	elif [ `${EXC_PATH}/parsejson.py $SW_JSON_PATH "" 2> /dev/null` == "duplicated" ]; then
		echo "ERROR: Detected duplicated names in $SW_JSON_PATH file."
		ALL_CORRECT=1
	elif pwd | grep -e "^/root/rpmbuild" &> /dev/null; then
		echo "ERROR: You can not generate from /root/rpmbuild directory."
		ALL_CORRECT=1
	elif [ `echo $LIST_COMMANDS | awk -F',' '{print NF}'` != `echo $LIST_VERSIONS | awk -F',' '{print NF}'` ]; then
		echo "ERROR: The number of RPMs to be generated does not match the number of versions indicated."
		ALL_CORRECT=1
	elif echo $LIST_COMMANDS | grep "," &> /dev/null && echo $1 | grep -e "--[a-z]" &> /dev/null; then
		echo "ERROR: Optional parameters are only allowed for a single RPM to be generated."
		ALL_CORRECT=1
	fi

	if [ $ALL_CORRECT != 0 ]; then
		echo ""
	fi

	return $ALL_CORRECT
}

# Check all user vars for a specific software are correct. Show error message if error.
# Return: 0-> All correct, !0 -> otherwise
function check_user_vars_for_specific_sw
{
	ALL_CORRECT=0
	
	NUM_SW_TO_GENERATE=`echo $PKG_NAME | wc -w`
	if [ $NUM_SW_TO_GENERATE = 0 ]; then
		echo "${DISPLAY_NAME}ERROR: Software does not exist."
		ALL_CORRECT=1
	elif [ $NUM_SW_TO_GENERATE != 1 ]; then
		echo "${DISPLAY_NAME}ERROR: $0 only supports to generate one rpm on each selected software."
		ALL_CORRECT=1
	elif ! echo "$SOURCES_PATH" | grep ".rpm$" &> /dev/null; then
		if [ ! -d $SOURCES_PATH ]; then
			echo "${DISPLAY_NAME}ERROR: Sources path does not exist."
			ALL_CORRECT=1
		elif ! echo $SOURCES_PATH | grep -e "^\/" &> /dev/null; then
			echo "${DISPLAY_NAME}ERROR: Sources path must be specified as absolute path."
			ALL_CORRECT=1
		elif echo $SOURCES_PATH | grep -e "^/root/rpmbuild" &> /dev/null; then
			echo "${DISPLAY_NAME}ERROR: The sources path can not be in /root/rpmbuild directory."
			ALL_CORRECT=1
		fi
	fi

	if [ $ALL_CORRECT = 0 ]; then
		if ! echo "$SOURCES_PATH" | grep ".rpm$" &> /dev/null; then
			if [ ! -d ${SOURCES_PATH}/SOURCES/${PKG_NAME}-0.0.0 ]; then
				echo "${DISPLAY_NAME}ERROR: No SOURCES with the name ${PKG_NAME} has been found."
				ALL_CORRECT=1
			fi
			
			if [ ! -f ${SOURCES_PATH}/SPECS/${PKG_NAME}.spec ]; then
				echo "${DISPLAY_NAME}ERROR: No SPECS with the name ${PKG_NAME} has been found."
				ALL_CORRECT=1
			fi

			grep "%global major_version" ${SOURCES_PATH}/SPECS/${PKG_NAME}.spec &> /dev/null
			if [ $? != 0 ]; then
				echo "${DISPLAY_NAME}ERROR: SPEC version format is not valid."
				ALL_CORRECT=1
			fi
		fi

		if [ "$TAG_SVN" != "" ]; then
			svn log --non-interactive --no-auth-cache --username $COMPANY_USER --password $SVN_PASS $TAG_SVN &> /dev/null
			if [ $? != 0 ]; then
				echo "${DISPLAY_NAME}ERROR: The SVN tag URL can not be accessed."
				ALL_CORRECT=1
			fi
		fi
		
		if [ "$BRANCH_SVN" != "" ]; then
			svn log --non-interactive --no-auth-cache --username $COMPANY_USER --password $SVN_PASS $BRANCH_SVN &> /dev/null
			if [ $? != 0 ]; then
				echo "${DISPLAY_NAME}ERROR: The SVN branch URL can not be accessed."
				ALL_CORRECT=1
			fi
		fi
	fi

	check_format_version $VERSION
	if [ $? != 0 ]; then
		echo "${DISPLAY_NAME}ERROR: Version format is incorrect."
		ALL_CORRECT=1
	fi

	if [ "$TARGET_PATH" != "" ] && [ ! -d $TARGET_PATH ]; then
		echo "${DISPLAY_NAME}ERROR: Destination path does not exist."
		ALL_CORRECT=1
	fi

	return $ALL_CORRECT
}

# Exit correctly when user aborted.
# Params: None.
# Return: None.
function user_aborted {
	if [ "$START_SPECIFIC_SW_ACTIONS" == "0" ]; then
		rm -rf /root/rpmbuild
		
		if [ -e $RPMBUILD_BACKUP ]; then
			mv $RPMBUILD_BACKUP /root/rpmbuild
		fi

		echo -e "ABORTED\n"
	fi
	
	exit
}

######################### MAIN #########################

# Traps to work correctly with Libelula threads.
trap "user_aborted" INT TERM
trap "kill 0" EXIT

##### Load global variables from config file #####
source $CONFIG_PATH

COMPANY_USER=`echo $COMPANY_USER_MAIL | awk -F "@" {'print $1'}`
PHRASE_SELECTED=""

SVN_PASS=$COMPANY_USER_PASS
if [ "$SVN_LOCAL_PASS" != "" ]; then
	SVN_PASS=$SVN_LOCAL_PASS
fi

##### Load phrases if phrases.txt file exists #####
	
if [ -e ${EXC_PATH}/phrases.txt ]; then
	PHRASES_INDEX=0
	
	while read PHRASE_LINE; do
		PHRASES_ARRAY[$PHRASES_INDEX]=$PHRASE_LINE
		PHRASES_INDEX=$(expr $PHRASES_INDEX + 1)
	done < $EXC_PATH/phrases.txt
	PHRASE_SELECTED=${PHRASES_ARRAY[$(($RANDOM%$PHRASES_INDEX))]}
fi

echo " _     _ _          _       _       "
echo "| |   (_) |__   ___| |_   _| | __ _ "
echo "| |   | | '_ \ / _ \ | | | | |/ _\` | by Jorge Casas Hernán"
echo "| |___| | |_) |  __/ | |_| | | (_| |"
echo "|_____|_|_.__/ \___|_|\__,_|_|\__,_| $PHRASE_SELECTED"
echo ""

if echo $* | grep "\-\-about" &> /dev/null; then
	echo -e "About Libelula:\n\n\tTool for the automation of Company RPMs generations.\n\n\tOriginal idea, designed and implemented by Jorge Casas Hernán.\n\n\tVERSION: $VERSION\n"
elif [ $# -lt 2 ]; then
	echo -e "Usage:"
	echo -e "\t- Using parameters:\n"
	echo -e "\t\t$0 <Sources path or SVN URL or RPM to rename version> <RPM version>\n"
	echo -e "\t\tOptional parameters:"
	echo -e "\t\t\t--name <Source pkg name to generate>"
	echo -e "\t\t\t--branch <SVN branch to tag URL>"
	echo -e "\t\t\t--tag <SVN base tag URL>"
	echo -e "\t\t\t--dest <RPM destination path>"
	echo -e "\t\t\t--update-repo"
	echo -e "\t\t\t--srpm"
	echo -e "\t\t\t--debug"
	echo -e "\t\t\t--checksum-file <Checksum file path>"
	echo -e "\t\t\t--pre-gen-cmd <Pre-generation command>"
	echo -e "\t\t\t--post-gen-cmd <Post-generation command>"
	echo -e "\t\t\t--send-mail <yes/no/confirm>"
	echo -e "\t\t\t--mail-subject <Mail subject>"
	echo -e "\t\t\t--mail-header <Mail header content>"
	echo -e "\t\t\t--mail-footer <Mail footer content>"
	echo -e "\t\t\t--to <Emails TO (',' separated)>"
	echo -e "\t\t\t--cc <Emails CC (',' separated)>"
	echo -e "\t\t\t--mail-note <Mail note>"
	echo -e "\t\t\t--mail-base-link <Mail base link>\n"
	echo -e "\t\t\t--about\n"
	echo -e "\t- Using config file:\n"
	echo -e "\t\tTo generate one RPM:\n"
	echo -e "\t\t\t$0 <RPM name> <RPM version> (You can use optional parameters here)\n"
	echo -e "\t\tTo generate multiple RPMs:\n"
	echo -e "\t\t\t$0 <RPM 1 name>,<RPM 2 name>,... <RPM 1 version>,<RPM 2 version>,...\n"
else
	LIST_COMMANDS=$1
	LIST_VERSIONS=$2

	shift
	shift
		
	check_general_user_vars	$*
	if [ $? = 0 ]; then
		typeset -i SW_INDEX=1
		SW_TOTAL=`echo $LIST_COMMANDS | awk -F',' '{print NF}'`
		GLOBAL_SEND_MAIL="no"
		GLOBAL_MAIL_SUBJECT=""
        	GLOBAL_MAIL_TO=""
        	GLOBAL_MAIL_CC=""
		GLOBAL_OK=0
		
		while [ $SW_INDEX -le $SW_TOTAL ]; do
			##### Fill variables #####
			
			COMMAND=`echo $LIST_COMMANDS | awk -F',' "{print \\\$${SW_INDEX}}"`
			VERSION=`echo $LIST_VERSIONS | awk -F',' "{print \\\$${SW_INDEX}}"`
			TAG_SVN=""
			BRANCH_SVN=""
			TARGET_PATH=""
			UPDATE_REPO=1
			PKG_NAME=""
			DEBUG="no"
			GENERATE_SRPM=1
			CHECKSUM_PATH=""
			PRE_GEN_CMD=""
			POST_GEN_CMD=""
			SEND_MAIL="no"
			MAIL_TO=""
			MAIL_CC=""
			MAIL_BASE_LINK=""
			MAIL_SUBJECT=""
			MAIL_HEADER=""
			MAIL_FOOTER=""
			MAIL_NOTE=""
			START_SPECIFIC_SW_ACTIONS=0
			ERRORS_ON_ACTIONS=1
			DISPLAY_NAME=""
			
			${EXC_PATH}/parsejson.py ${SW_JSON_PATH} "${COMMAND}" > /tmp/.sw_param.txt
			if cat /tmp/.sw_param.txt 2> /dev/null | grep "^name=" &> /dev/null; then
				SOURCES_PATH=`cat /tmp/.sw_param.txt | grep "^rpm-sources=" | awk -F "rpm-sources=" {'print $2'}`
				PKG_NAME=`cat /tmp/.sw_param.txt | grep "^rpm-name=" | awk -F "rpm-name=" {'print $2'}`
				BRANCH_SVN=`cat /tmp/.sw_param.txt | grep "^branch-to-tag=" | awk -F "branch-to-tag=" {'print $2'}`
				TAG_SVN=`cat /tmp/.sw_param.txt | grep "^tag=" | awk -F "tag=" {'print $2'}`
				TARGET_PATH=`cat /tmp/.sw_param.txt | grep "^rpm-destination=" | awk -F "rpm-destination=" {'print $2'}`
				CHECKSUM_PATH=`cat /tmp/.sw_param.txt | grep "^checksum-file=" | awk -F "checksum-file=" {'print $2'}`
				PRE_GEN_CMD=`cat /tmp/.sw_param.txt | grep "^pre-gen-cmd=" | awk -F "pre-gen-cmd=" {'print $2'}`
				POST_GEN_CMD=`cat /tmp/.sw_param.txt | grep "^post-gen-cmd=" | awk -F "post-gen-cmd=" {'print $2'}`
				
				if cat /tmp/.sw_param.txt | grep "^update-repo=" | awk -F "update-repo=" {'print $2'} | grep -i "yes" &> /dev/null; then
					UPDATE_REPO=0
				fi
				
				if cat /tmp/.sw_param.txt | grep "^generate-srpm=" | awk -F "generate-srpm=" {'print $2'} | grep -i "yes" &> /dev/null; then
					GENERATE_SRPM=0
				fi
				
				if cat /tmp/.sw_param.txt | grep "^debug=" | awk -F "debug=" {'print $2'} | grep -i "yes" &> /dev/null; then
					DEBUG="yes"
				fi
				
				if cat /tmp/.sw_param.txt | grep "^send-mail=" | awk -F "send-mail=" {'print $2'} | grep -i "yes\|confirm" &> /dev/null; then
					SEND_MAIL=`cat /tmp/.sw_param.txt | grep "^send-mail=" | awk -F "send-mail=" {'print $2'}`
					MAIL_SUBJECT=`cat /tmp/.sw_param.txt | grep "^mail-subject=" | awk -F "mail-subject=" {'print $2'}`
					MAIL_HEADER=`cat /tmp/.sw_param.txt | grep "^mail-header=" | awk -F "mail-header=" {'print $2'}`
					MAIL_FOOTER=`cat /tmp/.sw_param.txt | grep "^mail-footer=" | awk -F "mail-footer=" {'print $2'}`
					MAIL_TO=`cat /tmp/.sw_param.txt | grep "^mail-to=" | awk -F "mail-to=" {'print $2'}`
					MAIL_CC=`cat /tmp/.sw_param.txt | grep "^mail-cc=" | awk -F "mail-cc=" {'print $2'}`
					MAIL_NOTE=`cat /tmp/.sw_param.txt | grep "^mail-note=" | awk -F "mail-note=" {'print $2'}`
				fi
				
				MAIL_BASE_LINK=`cat /tmp/.sw_param.txt | grep "^mail-link=" | awk -F "mail-link=" {'print $2'}`

				if echo $LIST_COMMANDS | grep "," &> /dev/null; then
					DISPLAY_NAME="${COMMAND}: "
				fi
			else
				SOURCES_PATH=$COMMAND
			fi
			
			while [ $# != 0 ]; do
				case "$1" in
					"--name" )
						shift
						PKG_NAME=$1
						;;
					"--branch" )
						shift
						BRANCH_SVN=$1
						;;
					"--tag" )
						shift
						TAG_SVN=$1
						;;
					"--dest" )
						shift
						TARGET_PATH=$1
						;;
					"--update-repo" )
						UPDATE_REPO=0
						;;
					"--srpm" )
						GENERATE_SRPM=0
						;;
					"--debug" )
						DEBUG="yes"
						;;
					"--checksum-file" )
						shift
						CHECKSUM_PATH=$1
						;;
					"--pre-gen-cmd" )
						shift
						PRE_GEN_CMD=$1
						;;
					"--post-gen-cmd" )
						shift
						POST_GEN_CMD=$1
						;;
					"--send-mail" )
						shift
						SEND_MAIL=$1
						;;
					"--mail-subject" )
						shift
						MAIL_SUBJECT=$1
						;;
					"--mail-header" )
						shift
						MAIL_HEADER=$1
						;;
					"--mail-footer" )
						shift
						MAIL_FOOTER=$1
						;;
					"--to" )
						shift
						MAIL_TO=$1
						;;
					"--cc" )
						shift
						MAIL_CC=$1
						;;
					"--mail-base-link" )
						shift
						MAIL_BASE_LINK=$1
						;;
					"--mail-note" )
						shift
						MAIL_NOTE=$1
						;;
					* )
						echo "${DISPLAY_NAME}ERROR: $1 option not recognized."
						START_SPECIFIC_SW_ACTIONS=1
						;;
				esac

				shift
			done
			
			##### If SOURCES are on SVN repository, download to local #####
			
			if [ $START_SPECIFIC_SW_ACTIONS = 0 ]; then
				echo $SOURCES_PATH | grep -e "^http" &> /dev/null
				if [ $? = 0 ]; then
					SOURCES_PATH=`visual_svn_url_to_correct_url $SOURCES_PATH`
					svn log --non-interactive --no-auth-cache --username $COMPANY_USER --password $SVN_PASS $SOURCES_PATH &> /dev/null
					if [ $? != 0 ]; then
						echo "${DISPLAY_NAME}ERROR: The SVN repository can not be accessed."
						START_SPECIFIC_SW_ACTIONS=1
					else
						print_action "${DISPLAY_NAME}Downloading sources from SVN"
						rm -rf $SOURCES_TEMP
						svn co --no-auth-cache --username $COMPANY_USER --password $SVN_PASS $SOURCES_PATH $SOURCES_TEMP &> /dev/null
						if [ $? = 0 ]; then
							end_action "${DISPLAY_NAME}Downloading sources from SVN" "OK"
						else
							end_action "${DISPLAY_NAME}Downloading sources from SVN" "ERROR"
							START_SPECIFIC_SW_ACTIONS=1
						fi
						SOURCES_PATH=$SOURCES_TEMP
					fi
				fi

				echo $BRANCH_SVN | grep -e "^http" &> /dev/null
				if [ $? = 0 ]; then
					BRANCH_SVN=`visual_svn_url_to_correct_url $BRANCH_SVN`
				fi
				
				echo $TAG_SVN | grep -e "^http" &> /dev/null
				if [ $? = 0 ]; then
					TAG_SVN=`visual_svn_url_to_correct_url $TAG_SVN`
				fi
			fi
			

			if [ "$PKG_NAME" == "" ]; then
				if echo "$SOURCES_PATH" | grep ".rpm$" &> /dev/null; then
					PKG_NAME=`rpm -qpi $SOURCES_PATH | grep ^Name | awk -F ": " {'print $2'} | awk -F " " {'print $1'}`
				else
					PKG_NAME=`ls $SOURCES_PATH/SPECS 2> /dev/null | awk -F ".spec" {'print $1'}`
				fi
			fi

			##### Parse variables to check all are correct, if downloading code operation was successfull #####
			
			if [ $START_SPECIFIC_SW_ACTIONS = 0 ]; then
				check_user_vars_for_specific_sw
				START_SPECIFIC_SW_ACTIONS=$?
			fi
			
			###### Start actions for the specific software if parameters are correct #####

			if [ $START_SPECIFIC_SW_ACTIONS = 0 ]; then
				
				if [ $UPDATE_REPO = 0 ]; then
					print_action "${DISPLAY_NAME}Updating SVN repository"
					svn up --non-interactive --no-auth-cache --username $COMPANY_USER --password $SVN_PASS $SOURCES_PATH &> /dev/null
					if [ $? = 0 ]; then
						end_action "${DISPLAY_NAME}Updating SVN repository" "OK"
					else
						end_action "${DISPLAY_NAME}Updating SVN repository" "ERROR"
						ERRORS_ON_ACTIONS=0
					fi
				fi

				if [ "$TAG_SVN" != "" ] && [ $ERRORS_ON_ACTIONS != 0 ]; then
					print_action "${DISPLAY_NAME}Creating tag on SVN"
					
					if [ "$BRANCH_SVN" == "" ]; then
						svn cp --non-interactive --no-auth-cache --username $COMPANY_USER --password $SVN_PASS $SOURCES_PATH $TAG_SVN/$VERSION -m "Tagged version" &> /dev/null
						SVN_TAG_RESULT=$?
					else
						svn cp --non-interactive --no-auth-cache --username $COMPANY_USER --password $SVN_PASS $BRANCH_SVN $TAG_SVN/$VERSION -m "Tagged version" &> /dev/null
						SVN_TAG_RESULT=$?
					fi
					
					if [ $SVN_TAG_RESULT = 0 ]; then
						end_action "${DISPLAY_NAME}Creating tag on SVN" "OK"
					else
						end_action "${DISPLAY_NAME}Creating tag on SVN" "ERROR"
						ERRORS_ON_ACTIONS=0
					fi
				fi

				if [ "$PRE_GEN_CMD" != "" ] && [ $ERRORS_ON_ACTIONS != 0 ]; then
					print_action "${DISPLAY_NAME}Executing pre-generation command"
					eval "$PRE_GEN_CMD" &>> $LOG_PATH
					if [ $? = 0 ]; then
						end_action "${DISPLAY_NAME}Executing pre-generation command" "OK"
					else
						end_action "${DISPLAY_NAME}Executing pre-generation command" "ERROR. See $LOG_PATH for details."
						ERRORS_ON_ACTIONS=0

						if [ "$TAG_SVN" != "" ]; then
							print_action "${DISPLAY_NAME}Undoing tag on SVN due to pre-generation command error"
							svn rm --non-interactive --no-auth-cache --username $COMPANY_USER --password $SVN_PASS $TAG_SVN/$VERSION -m "Undone tag version due to pre-generation command error" &> /dev/null
							if [ $? = 0 ]; then
								end_action "${DISPLAY_NAME}Undoing tag on SVN due to pre-generation command error" "OK"
							else
								end_action "${DISPLAY_NAME}Undoing tag on SVN due to pre-generation command error" "ERROR"
							fi
						fi
					fi
				fi	

				if [ $ERRORS_ON_ACTIONS != 0 ]; then
					get_parts_of_version $VERSION
					
					if echo "$SOURCES_PATH" | grep ".rpm$" &> /dev/null; then
						print_action "${DISPLAY_NAME}Rebuilding RPM with new version"
						if [ -e /root/rpmbuild ] && [ ! -e $RPMBUILD_BACKUP ]; then
							mv /root/rpmbuild $RPMBUILD_BACKUP
						fi
					
						rm -rf /root/rpmbuild

						rpmrebuild -p --change-spec-preamble="sed -e 's/^Version:.*/Version: $VERSION_WITHOUT_RELEASE/'; sed -e 's/Release:[\t ]*[0-9]/Release: ${RELEASE}/'" $SOURCES_PATH &>> $LOG_PATH
						if [ $? = 0 ]; then
							RPM_GENERATED=`ls /root/rpmbuild/RPMS/*/ | awk -F " " {'print $1'}`

							if [ -f ./$RPM_GENERATED ]; then
							        rm -f ./$RPM_GENERATED &> /dev/null
							fi
							
							mv /root/rpmbuild/RPMS/*/$RPM_GENERATED .	

							rm -rf /root/rpmbuild
						
							if [ -e $RPMBUILD_BACKUP ]; then
								mv $RPMBUILD_BACKUP /root/rpmbuild
							fi

							end_action "${DISPLAY_NAME}Rebuilding RPM with new version" "OK"
						else
							end_action "${DISPLAY_NAME}Rebuilding RPM with new version" "ERROR. See $LOG_PATH for details."
							ERRORS_ON_ACTIONS=0
						fi
					else
						print_action "${DISPLAY_NAME}Generating RPM"
						generate_rpm
						if [ $? = 0 ]; then
							end_action "${DISPLAY_NAME}Generating RPM" "OK"
						else
							end_action "${DISPLAY_NAME}Generating RPM" "ERROR. See $LOG_PATH for details."
							ERRORS_ON_ACTIONS=0
						fi
					fi

					if [ "$TAG_SVN" != "" ] && [ $ERRORS_ON_ACTIONS = 0 ]; then
						print_action "${DISPLAY_NAME}Undoing tag on SVN due to generation error"
						svn rm --non-interactive --no-auth-cache --username $COMPANY_USER --password $SVN_PASS $TAG_SVN/$VERSION -m "Undone tag version due to generation error" &> /dev/null
						if [ $? = 0 ]; then
							end_action "${DISPLAY_NAME}Undoing tag on SVN due to generation error" "OK"
						else
							end_action "${DISPLAY_NAME}Undoing tag on SVN due to generation error" "ERROR"
						fi
					fi
				fi	

				if [ "$POST_GEN_CMD" != "" ] && [ $ERRORS_ON_ACTIONS != 0 ]; then
					print_action "${DISPLAY_NAME}Executing post-generation command"
					eval "$POST_GEN_CMD" &>> $LOG_PATH
					if [ $? = 0 ]; then
						end_action "${DISPLAY_NAME}Executing post-generation command" "OK"
					else
						end_action "${DISPLAY_NAME}Executing post-generation command" "ERROR. See $LOG_PATH for details."
						ERRORS_ON_ACTIONS=0

						if [ "$TAG_SVN" != "" ]; then
							print_action "${DISPLAY_NAME}Undoing tag on SVN due to post-generation command error"
							svn rm --non-interactive --no-auth-cache --username $COMPANY_USER --password $SVN_PASS $TAG_SVN/$VERSION -m "Undone tag version due to post-generation command error" &> /dev/null
							if [ $? = 0 ]; then
								end_action "${DISPLAY_NAME}Undoing tag on SVN due to post-generation command error" "OK"
							else
								end_action "${DISPLAY_NAME}Undoing tag on SVN due to post-generation command error" "ERROR"
							fi
						fi
					fi
				fi
					

				
				if [ "$TARGET_PATH" != "" ] && [ $ERRORS_ON_ACTIONS != 0 ]; then
					print_action "${DISPLAY_NAME}Copying RPM generated to destination folder"

					if [ -f ${TARGET_PATH}/${RPM_GENERATED} ]; then
						rm -f ${TARGET_PATH}/${RPM_GENERATED} &> /dev/null
					fi
					
					cp $RPM_GENERATED $TARGET_PATH &> /dev/null
					if [ $? = 0 ]; then
						end_action "${DISPLAY_NAME}Copying RPM generated to destination folder" "OK"
					else
						end_action "${DISPLAY_NAME}Copying RPM generated to destination folder" "ERROR. The RPM is left in the current directory."
						ERRORS_ON_ACTIONS=0
					fi
				fi
				
				if [ $ERRORS_ON_ACTIONS != 0 ]; then
					PKG_SUM=`sum $RPM_GENERATED | awk -F " " {'print $1'}`

					if [ "$CHECKSUM_PATH" != "" ]; then
						print_action "${DISPLAY_NAME}Adding RPM checksum to checksum file"
						if [ ! -f $CHECKSUM_PATH ]; then
							touch $CHECKSUM_PATH &> /dev/null
						fi

						sed -i "/${RPM_GENERATED}/d" $CHECKSUM_PATH &> /dev/null
						echo "`date +%d/%m/%Y` - $PKG_SUM - $RPM_GENERATED" >> $CHECKSUM_PATH 2> /dev/null
						if [ $? = 0 ]; then
							end_action "${DISPLAY_NAME}Adding RPM checksum to checksum file" "OK"
						else
							end_action "${DISPLAY_NAME}Adding RPM checksum to checksum file" "ERROR"
						fi
					fi

					echo "${DISPLAY_NAME}${RPM_GENERATED} generated! SUM: $PKG_SUM"
				else
					GLOBAL_OK=1
				fi
			else
				GLOBAL_OK=1
			fi
			
			if [ -d $SOURCES_TEMP ]; then
				rm -rf $SOURCES_TEMP
			fi

			if echo $SEND_MAIL | grep -i "yes\|confirm" &> /dev/null && [ $SW_INDEX = 1 ]; then
				GLOBAL_SEND_MAIL=$SEND_MAIL
			fi

			if echo $GLOBAL_SEND_MAIL | grep -i "yes\|confirm" &> /dev/null && [ $GLOBAL_OK = 0 ]; then
				if [ $SW_INDEX = 1 ]; then
					rm -f ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
					cp ${EXC_PATH}/mail/${MAIL_GLOBAL_TEMPLATE_FILE} ${EXC_PATH}/mail/${MAIL_FINAL_FILE}

					GLOBAL_MAIL_SUBJECT=$MAIL_SUBJECT
					GLOBAL_MAIL_SUBJECT=${GLOBAL_MAIL_SUBJECT/SOFTWARE_NAME/$PKG_NAME}
					GLOBAL_MAIL_SUBJECT=${GLOBAL_MAIL_SUBJECT/SOFTWARE_VERSION/$VERSION}
					GLOBAL_MAIL_SUBJECT=${GLOBAL_MAIL_SUBJECT/RPM_FILENAME/$RPM_GENERATED}

					MAIL_HEADER=${MAIL_HEADER/SOFTWARE_NAME/$PKG_NAME}
					MAIL_HEADER=${MAIL_HEADER/SOFTWARE_VERSION/$VERSION}
					MAIL_HEADER=${MAIL_HEADER/RPM_FILENAME/$RPM_GENERATED}
					MAIL_HEADER=${MAIL_HEADER//\//\\/}

					MAIL_FOOTER=${MAIL_FOOTER/SOFTWARE_NAME/$PKG_NAME}
					MAIL_FOOTER=${MAIL_FOOTER/SOFTWARE_VERSION/$VERSION}
					MAIL_FOOTER=${MAIL_FOOTER/RPM_FILENAME/$RPM_GENERATED}
					MAIL_FOOTER=${MAIL_FOOTER//\//\\/}

					sed -i "s/MAIL_HEADER/$MAIL_HEADER/g" ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
					sed -i "s/MAIL_FOOTER/$MAIL_FOOTER/g" ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
					
					if [ "$MAIL_NOTE" != "" ]; then
						MAIL_NOTE=${MAIL_NOTE//\//\\/}
						sed -i "s/MAIL_NOTE/NOTA: $MAIL_NOTE/g" ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
					else
						sed -i "s/MAIL_NOTE//g" ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
					fi
					
					GLOBAL_MAIL_TO=$MAIL_TO
					GLOBAL_MAIL_CC=$MAIL_CC
				fi

				typeset -i MAIL_LINKS_END=`grep -n "LINKS_END" ${EXC_PATH}/mail/${MAIL_FINAL_FILE} | awk -F ":" {'print $1'}`
				MAIL_LINKS_END=${MAIL_LINKS_END}-1
				sed -ie "${MAIL_LINKS_END}r ${EXC_PATH}/mail/${MAIL_PKG_TEMPLATE_FILE}" ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
				sed -i "s/RPM_GENERATED/$RPM_GENERATED/g" ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
				sed -i "s/PKG_NAME/$PKG_NAME/g" ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
				sed -i "s/PKG_VERSION/$VERSION/g" ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
				sed -i "s/PKG_SUM/$PKG_SUM/g" ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
				sed -i "s,PKG_LINK,$MAIL_BASE_LINK/$RPM_GENERATED,g" ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
			fi
			
			echo ""
			SW_INDEX=$SW_INDEX+1
		done

		if echo $GLOBAL_SEND_MAIL | grep -i "yes\|confirm" &> /dev/null; then
			if [ "$SEND_EMAIL_BINARY_PATH" == "" ]; then
				echo "You do not have configured any binary to send emails, please configure one in $CONFIG_PATH"
			else if [ $GLOBAL_OK != 0 ]; then
				echo "Errors have been detected, so mail will not be sent."
			else
				if [ $GLOBAL_SEND_MAIL == "confirm" ]; then
					echo -n "All right. "
					while ! echo $GLOBAL_SEND_MAIL | grep -i "yes\|no" &> /dev/null; do
						echo -n "Send notification mail? (yes/no): "
						read GLOBAL_SEND_MAIL
					done
				fi

				if [ $GLOBAL_SEND_MAIL == "yes" ]; then
					print_action "Preparing and sending mail"
					# Use thrid
					sleep 5
					${EXC_PATH}/mail/sendmail.py "$GLOBAL_MAIL_SUBJECT" "${EXC_PATH}/mail/${MAIL_FINAL_FILE}" "$GLOBAL_MAIL_TO" "$GLOBAL_MAIL_CC" "$COMPANY_USER_MAIL" "$COMPANY_USER_PASS" &>> $LOG_PATH
					if [ $? = 0 ]; then
						end_action "Preparing and sending mail" "OK"
					else
						end_action "Preparing and sending mail" "ERROR. See $LOG_PATH for details."
					fi
					kill -9 `ps -ef | grep davmail | grep -v grep | awk -F " " {'print $2'}` &>> $LOG_PATH &
				fi
			fi
			
			echo ""
		fi
		rm -f ${EXC_PATH}/mail/${MAIL_FINAL_FILE}
	fi
fi

exit 0

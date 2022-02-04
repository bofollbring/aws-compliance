#!/usr/bin/env bash

#
#        @(#) aws_compliance 0.1  -  02/02/2022 >
#

######################################################################
#                                                                    #
#                       ENVIRONMENT SECTION                          #
#                                                                    #
######################################################################
### Set up terminal erase key
case $TERM in
vt*|kmcapc85)   ERASE_CHAR='^h' ;;
*)              ERASE_CHAR='^?' ;;
esac

stty erase $ERASE_CHAR

shopt -s xpg_echo   ### turns on '-e' for echo
shopt -s extglob    ### turn on ksh-like extended pattern matches
set +o histexpand   ### turn off ! history expansion

### Set path
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/root/bin

######################################################################
#                                                                    #
#                        VARIABLE SECTION                            #
#                                                                    #
######################################################################

### Version information
AWS_COMPLIANCE_VERSION=0.1

### Running Variables
CURRENT_SCRIPT=`basename $0`
CURRENT_DIRECTORY=`pwd`

### Colour Variables
BLACK="\e[30m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[37m"
RESET_FORMATTING="\e[0m"

### Default boolean values
VERBOSE="false"

### Array Variables
declare -a PREREQUISITES=("curl" "unzip" "jq")
declare -a REGION_ACCOUNT_LONG_NAMES=("US East (N. Virginia)" "US East (Ohio)" "US West (N. California)" "US West (Oregon)" "Africa (Cape Town)" "Canada (Central)" "Europe (Frankfurt)" "Europe (Ireland)" "Europe (London)" "Europe (Milan)" "Europe (Paris)" "Europe (Stockholm)" "Asia Pacific (Hong Kong)" "Asia Pacific (Tokyo)" "Asia Pacific (Seoul)" "Asia Pacific (Osaka)" "Asia Pacific (Singapore)" "Asia Pacific (Sydney)" "Asia Pacific (Mumbai)" "Middle East (Bahrain)" "South America (São Paulo)")
declare -a REGION_ACCOUNT_SHORT_NAMES=("us-east-1" "us-east-2" "us-west-1" "us-west-2" "af-south-1" "ca-central-1" "eu-central-1" "eu-west-1" "eu-west-2" "eu-south-1" "eu-west-3" "eu-north-1" "ap-east-1" "ap-northeast-1" "ap-northeast-2" "ap-northeast-3" "ap-southeast-1" "ap-southeast-2" "ap-south-1" "me-south-1" "sa-east-1")
declare -a REGIONS=("ap-southeast-1" "ap-southeast-2" "ap-south-1" "ap-northeast-1" "ap-northeast-2" "ap-northeast-3" "ca-central-1" "eu-central-1" "eu-north-1" "eu-west-1" "eu-west-2" "eu-west-3" "sa-east-1" "us-east-1" "us-east-2" "us-west-1" "us-west-2")
declare -A REGION_ACCOUNT_IDS=(["us-east-1"]=127311923021 ["us-east-2"]=033677994240 ["us-west-1"]=027434742980 ["us-west-2"]=797873946194 ["af-south-1"]=098369216593 ["ca-central-1"]=985666609251 ["eu-central-1"]=054676820928 ["eu-west-1"]=156460612806 ["eu-west-2"]=652711504416 ["eu-south-1"]=635631232127 ["eu-west-3"]=009996457667 ["eu-north-1"]=897822967062 ["ap-east-1"]=754344448648 ["ap-northeast-1"]=582318560864 ["ap-northeast-2"]=600734575887 ["ap-northeast-3"]=383597477331 ["ap-southeast-1"]=114774131450 ["ap-southeast-2"]=783225319266 ["ap-south-1"]=718504428378 ["me-south-1"]=076674570225 ["sa-east-1"]=507241528517)

#############################################################
##                                                         ##
##         Do OS Checks To See If OS IS Supported          ##
##                                                         ##
#############################################################

### OS Variables
#
# /etc/os-release will give us access to:
#
# (ALL OS)
# NAME
# VERSION
# ID
# ID_LIKE
# VERSION_ID
# PRETTY_NAME
# HOME_URL
# BUG_REPORT_URL
#
# (RHEL|CENTOS|ORACLE|FEDORA)
# ANSI_COLOR
# CPE_NAME
# REDHAT_SUPPORT_PRODUCT
# REDHAT_SUPPORT_PRODUCT_VERSION
#
# (DEBIAN|UBUNTU)
# SUPPORT_URL
# PRIVACY_POLICY_URL
# VERSION_CODENAME
. /etc/os-release

### Set the OS type based on ID
case "$ID" in
    centos|rhel|fedora)
        OS="rhel"
        ### OS Specific Variables
        case "${ID}" in
            centos)
                OS_NAME="centos"
                OS_FAMILY="redhat"
                OS_DIST_NAME="centos"
                OS_FULL_NAME="CentOS"
                ;;
            rhel)
                OS_NAME="redhat"
                OS_FAMILY="redhat"
                OS_DIST_NAME="rhel"
                OS_FULL_NAME="Red Hat"
                ;;
            fedora)
                OS_NAME="fedora"
                OS_FAMILY="fedora"
                OS_DIST_NAME="fedora"
                OS_FULL_NAME="Fedora"
                ;;
            ol)
                OS_NAME="oracle"
                OS_FAMILY="redhat"
                OS_DIST_NAME="oraclelinux"
                OS_FULL_NAME="Oracle Linux"
                ;;
            *)
                echo "${ID} not yet supported"
                exit 1
        esac
        OS_FULL_VERSION=`cat /etc/${OS_NAME}-release | sed 's/[^0-9]*//' | cut -d'.' -f1-2 | cut -d' ' -f1`
        OS_VERSION=`echo ${OS_FULL_VERSION} | cut -d'.' -f1`
        ;;
    ubuntu|debian)
        OS="debian"
        ### OS Specific Variables
        case "${ID}" in
            debian)
                OS_NAME="debian"
                OS_FAMILY="debian"
                OS_DIST_NAME="debian"
                OS_FULL_NAME="Debian"
                OS_FULL_VERSION=`cat /etc/debian_version`
                ;;
            ubuntu)
                OS_NAME="ubuntu"
                OS_FAMILY="debian"
                OS_DIST_NAME="ubuntu"
                OS_FULL_NAME="Ubuntu"
                OS_FULL_VERSION=${VERSION_ID}
                ;;
            *)
                echo "${ID} not yet supported"
                exit 1
        esac
        OS_TYPE="debian"
        OS_VERSION=`echo ${OS_FULL_VERSION} | cut -d'.' -f1`
        OS_VERSION_CODENAME=${VERSION_CODENAME}
        ;;
    *)
        OS="unknown"
        exit 1
esac

### OS Specific Variables
case "$OS" in
    rhel)
        PM="yum"
        PACKAGE_MANAGER="rpm"
        PACKAGE_CHECK_COMMAND="${PACKAGE_MANAGER} -q"
        PACKAGE_SILENT_SWITCH="-q"
        ;;
    debian)
        PM="apt"
        PACKAGE_MANAGER="dpkg"
        PACKAGE_CHECK_COMMAND="${PACKAGE_MANAGER} -s"
        PACKAGE_SILENT_SWITCH="-qq"
        ;;
    *)
        echo "Unsupported OS: ${ID}"
        exit
esac

######################################################################
######################################################################
##                                                                  ##
##                                                                  ##
##                         FUNCTION SECTION                         ##
##                                                                  ##
##                                                                  ##
######################################################################
######################################################################

### Main function
function main {

    ### Clear screen
    clear

    if [[ "$DEBUG" == "true" ]]; then
        echo "###############################################"
        echo "#          Entering: main function            #"
        echo "###############################################"
        sleep 2
    fi

    ### Initial Setup
    initial_setup

    if [[ "$SKIP" != "true" ]]; then
        ### Prefill AWS Resources
        prefill_aws_resources
    fi

    ### Get account
    get_account_info

    ### Start menu system
    main_menu

}

######################################################################
#                                                                    #
#                        INITIAL SETUP SECTION                       #
#                                                                    #
######################################################################

### Function to do initial setup
function initial_setup {

    if [[ "$DEBUG" == "true" ]]; then
        echo "###############################################"
        echo "#      Entering: initial_setup function       #"
        echo "###############################################"
        sleep 2
    fi

    ### Install the prerequisites
    install_prerequisites

    ### Install aws_cli
    install_aws_cli

    ### Set profile
    set_aws_profile

    ### Set region
    set_aws_region

}

#----------------------------------------------------------------------
# Function: install_prerequisites
# Purpose:  Used to install prerequisites to installing aws_cli.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function install_prerequisites {

    if [[ "$DEBUG" == "true" ]]; then
        echo "###############################################"
        echo "#  Entering: install_prerequisites function   #"
        echo "###############################################"
        sleep 2
    fi

    ### Iterate prerequisite packages and install them
    for PREREQUISITE_PACKAGE in "${PREREQUISITES[@]}"; do
        ${PACKAGE_CHECK_COMMAND} ${PREREQUISITE_PACKAGE} > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            if [[ "$DEBUG" == "true" ]]; then
                echo "DEBUG!!!"
                echo "Installing prerequisite package ${PREREQUISITE_PACKAGE}"
                echo ""
            fi
            ### Turn off cursor
            tput civis

            ### Start the loading animation in background and grab the pid
            start_daemon "Installing ${PREREQUISITE_PACKAGE}. Please wait"

            ### Run command(s) to install prerequisite
            run_command "${PM} install ${PREREQUISITE_PACKAGE} ${PACKAGE_SILENT_SWITCH} -y${SUFFIX}" ${LINENO}
            ### End the loading animation

            end_daemon "Installing ${PREREQUISITE_PACKAGE}. Please wait"

            ### Turn on cursor
            tput cnorm
        else
            if [[ "$DEBUG" == "true" ]]; then
                echo "DEBUG!!!"
                echo "Prerequisite package ${PREREQUISITE_PACKAGE} already installed"
                echo ""
            fi
        fi
    done

}

#----------------------------------------------------------------------
# Function: install_aws_cli
# Purpose:  Used to install aws_cli.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function install_aws_cli {
    if [[ "$DEBUG" == "true" ]]; then
        echo "###############################################"
        echo "#     Entering: install_aws_cli function      #"
        echo "###############################################"
        sleep 2
    fi

    if ! command -v aws &> /dev/null
    then
        if [[ "$DEBUG" == "true" ]]; then
            echo "DEBUG!!!"
            echo "Installing aws_cli"
            echo ""
        fi

        echo ""
        ### Turn off cursor
        tput civis

        ### Start the loading animation in background and grab the pid
        start_daemon "Installing awscli. Please wait"

        ### Run command(s) to install awscli
        run_command "cd /tmp" ${LINENO}
        run_command "curl --silent \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\"${SUFFIX}" ${LINENO}
        run_command "unzip -qq awscliv2.zip${SUFFIX}" ${LINENO}
        run_command "aws/install${SUFFIX}" ${LINENO}
        run_command "rm -rf /tmp/aws*${SUFFIX}" ${LINENO}

        ### End the loading animation
        end_daemon "Installing awscli. Please wait"

        ### Turn on cursor
        tput cnorm
        echo ""
        if ! command -v aws &> /dev/null
        then
            echo "awscli failed to install"
            exit 0
        else
            echo "Enter AWS Configuration"
        fi

        ### Run initial configuration
        run_command "aws configure" ${LINENO}

        sleep 2
    else
        if [[ "$DEBUG" == "true" ]]; then
            echo "DEBUG!!!"
            echo "aws_cli already installed"
            echo ""
        fi
    fi

}

#----------------------------------------------------------------------
# Function: set_aws_profile
# Purpose:  Used to set the AWS_PROFILE.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function set_aws_profile {
    if [[ "$DEBUG" == "true" ]]; then
        echo "###############################################"
        echo "#     Entering: set_aws_profile function      #"
        echo "###############################################"
        sleep 2
    fi

    AWS_CONFIGURE_LIST=`aws configure list`

    PROFILE=`echo "${AWS_CONFIGURE_LIST}" | grep profile | sed 's/^  *\(profile\)/\1/g' | sed 's/   */;/g' | cut -d';' -f2`
    PROFILE_TYPE=`echo "${AWS_CONFIGURE_LIST}" | grep profile | sed 's/^  *\(profile\)/\1/g' | sed 's/   */;/g' | cut -d';' -f3`
    PROFILE_TYPE=`echo "${AWS_CONFIGURE_LIST}" | grep profile | sed 's/^  *\(profile\)/\1/g' | sed 's/   */;/g' | cut -d';' -f4`
    ACCESS_KEY=`echo "${AWS_CONFIGURE_LIST}" | grep access_key | sed 's/access_key   *//g' | sed 's/  .*//g'`
    SECRET_KEY=`echo "${AWS_CONFIGURE_LIST}" | grep secret_key | sed 's/secret_key   *//g' | sed 's/  .*//g'`

    if [ -n "$DEBUG" ]; then
        echo "DEBUG!!!"
        echo "PROFILE: ${PROFILE}"
        echo "PROFILE_TYPE: ${PROFILE_TYPE}"
        echo "ACCESS_KEY: ${ACCESS_KEY}"
        echo "SECRET_KEY: ${SECRET_KEY}"
        echo ""
    fi

    ### First check if we already have AWS_PROFILE
    if [ -z ${AWS_PROFILE} ]; then
        if [ -n "$DEBUG" ]; then
            echo "DEBUG!!!"
            echo "We don't have AWS_PROFILE"
            echo ""
        fi

        ### Check if we have aws configuration
        if [ "$PROFILE" == "<not set>" ] && [ "$ACCESS_KEY" == "<not set>" ] && [ "$SECRET_KEY" == "<not set>" ] && [ "$REGION" == "<not set>" ]; then
            if [ -n "$DEBUG" ]; then
                echo "DEBUG!!!"
                echo "We need to run aws configure"
                echo ""
            fi

            ### Run initial configuration
            run_command "aws configure" ${LINENO}
        else
            if [ -n "$DEBUG" ]; then
                echo "DEBUG!!!"
                echo "At least one value was not <not set>"
                echo ""
            fi
    
            ### Check if we have default profile
            if [ "$PROFILE" == "<not set>" ]; then

                if [ -n "$DEBUG" ]; then
                    echo "DEBUG!!!"
                    echo "We are using default profile"
                    echo ""
                fi
                AWS_PROFILE="default"
                AWS_PROFILE_ARG=""
            fi
        fi
    else
        if [ -n "$DEBUG" ]; then
            echo "DEBUG!!!"
            echo "We have an AWS_PROFILE"
            echo ""
        fi
        AWS_PROFILE_ARG=" --profile ${AWS_PROFILE}"
    fi
}

#----------------------------------------------------------------------
# Function: set_aws_region
# Purpose:  Used to set the AWS_REGION.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function set_aws_region {
    if [[ "$DEBUG" == "true" ]]; then
        echo "###############################################"
        echo "#     Entering: set_aws_region function       #"
        echo "###############################################"
        sleep 2
    fi

    REGION=`aws configure get region`

    if [ -n "$DEBUG" ]; then
        echo "DEBUG!!!"
        echo "REGION: ${REGION}"
        echo ""
    fi

    ### First check if we already have AWS_REGION
    if [ -z "$AWS_REGION" ] && [ -z "$AWS_DEFAULT_REGION" ]; then

        ### Check region from aws configure command
        if [ -z "$REGION" ]; then

            if [ -n "$DEBUG" ]; then
                echo "DEBUG!!!"
                echo "We need to select a region..."
            fi

            select_aws_region_menu

        else

            if [ -n "$DEBUG" ]; then
                echo "DEBUG!!!"
                echo "We have AWS_REGION..."
            fi

            AWS_REGION=${REGION}
            AWS_REGION_ARG=" --region ${AWS_REGION}"

        fi
    else
        
        if [ -n "$AWS_REGION" ]; then
            if [ -n "$DEBUG" ]; then
                echo "DEBUG!!!"
                echo "We have AWS_DEFAULT_REGION..."
            fi

            AWS_REGION=${AWS_DEFAULT_REGION}
            AWS_REGION_ARG=" --region ${AWS_REGION}"
        else
            if [ -n "$DEBUG" ]; then
                echo "DEBUG!!!"
                echo "We have AWS_REGION..."
            fi

            AWS_REGION_ARG=" --region ${AWS_REGION}"
        fi
    fi
}

#----------------------------------------------------------------------
# Function: select_aws_profile
# Purpose:  Used to select the AWS_PROFILE to work with.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function select_aws_profile {
    if [[ "$DEBUG" == "true" ]]; then
        echo "###############################################"
        echo "#    Entering: select_aws_profile function    #"
        echo "###############################################"
        sleep 2
    fi

    clear
    print_menu_header
    echo ""
    echo "Select profile:"
    select PROFILE in $PROFILES
    do
        AWS_PROFILE=$PROFILE
        if [[ "$AWS_PROFILE" == "default" ]]; then
            AWS_PROFILE_LINE=""
        else
            AWS_PROFILE_LINE=" --profile ${AWS_PROFILE}"
        fi
        AWS_REGION=`cat ${AWS_CONFIG_FILE} | sed -n -e "/\[${AWS_PROFILE}\]/,/\[/ p" | sed '$ d'| sed 's/ //g' | grep region | cut -d'=' -f2`
        if [[ "$AWS_REGION" == "" ]]; then
            AWS_REGION=`aws configure get region --profile ${AWS_PROFILE}`
            echo "AWS_REGION: ${AWS_REGION}"
            if [[ "${AWS_REGION}" == "" ]]; then
                select_aws_profile
            fi
            #select_aws_region
        fi
        break
    done
    
}

#----------------------------------------------------------------------
# Function: select_aws_region
# Purpose:  Used to select the AWS_PROFILE to work with.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function select_aws_region {
    if [[ "$DEBUG" == "true" ]]; then
        echo "###############################################"
        echo "#    Entering: select_aws_region function     #"
        echo "###############################################"
        sleep 2
    fi

    clear
    print_menu_header
    echo ""
    echo "Select region:"
    select REGION in "${REGIONS[@]}"
    do
        AWS_REGION=$REGION
        break
    done

}

######################################################################
#                                                                    #
#                       AWS CLI COMMAND SECTION                      #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: prefill_aws_resources
# Purpose:  Used to select the AWS_PROFILE to work with.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function prefill_aws_resources {
    if [[ "$DEBUG" == "true" ]]; then
        echo "###############################################"
        echo "#  Entering: prefill_aws_resources function   #"
        echo "###############################################"
        sleep 2
    fi

    clear
    print_menu_header "Fetching AWS Resources"
    echo ""

    ###################################################
    #                    API GATEWAY                  #
    ###################################################
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Fetching API Gateway Resouces. Please wait"

    JSON_APIGATEWAY_GET_REST_APIS=`aws apigateway get-rest-apis${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    APIGATEWAY_REST_API_NAMES=(`jq -r '.items[].name' <<<"$JSON_APIGATEWAY_GET_REST_APIS"`)
    APIGATEWAY_REST_API_IDS=(`jq -r '.items[].id' <<<"$JSON_APIGATEWAY_GET_REST_APIS"`)
    
    if [ "$APIGATEWAY_REST_API_NAMES" == "" ]; then
        APIGATEWAY="${RED}Not in use${RESET_FORMATTING}"
    else
        APIGATEWAY="${GREEN}In use    ${RESET_FORMATTING}"
    fi

    ### End the loading animation
    end_daemon "        Fetching API Gateway Resouces. Done          "

    echo ""

    ###################################################
    #                        ASG                      #
    ###################################################
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Fetching ASG Resouces. Please wait"

    JSON_ASG_DESCRIBE_AUTO_SCALING_GROUPS=`aws autoscaling describe-auto-scaling-groups${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    ASG_AUTO_SCALING_GROUP_NAMES=(`jq -r '.AutoScalingGroups[].AutoScalingGroupName' <<<"$JSON_ASG_DESCRIBE_AUTO_SCALING_GROUPS"`)

    if [ "$ASG_AUTO_SCALING_GROUP_NAMES" == "" ]; then
        ASG="${RED}Not in use${RESET_FORMATTING}"
    else
        ASG="${GREEN}In use    ${RESET_FORMATTING}"
    fi

    ### End the loading animation
    end_daemon "        Fetching ASG Resouces. Done          "

    echo ""

    ###################################################
    #                     CloudFront                  #
    ###################################################
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Fetching CloudFront Resouces. Please wait"

    JSON_CLOUDFRONT_LIST_DISTRIBUTIONS=`aws cloudfront list-distributions${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    CLOUDFRONT_DISTRIBUTION_IDS=(`jq -r '.DistributionList.Items[].Id' <<<"$JSON_CLOUDFRONT_LIST_DISTRIBUTIONS"`)

    if [ "$CLOUDFRONT_DISTRIBUTION_IDS" == "" ]; then
        CLOUDFRONT="${RED}Not in use${RESET_FORMATTING}"
    else
        CLOUDFRONT="${GREEN}In use    ${RESET_FORMATTING}"
    fi

    ### End the loading animation
    end_daemon "        Fetching CloudFront Resouces. Done          "

    echo ""

    ###################################################
    #                  CloudFormation                 #
    ###################################################
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Fetching CloudFormation Resouces. Please wait"

    JSON_CLOUDFORMATION_DESCRIBE_STACKS=`aws cloudformation describe-stacks${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    CLOUDFORMATION_STACK_NAMES=(`jq -r '.Stacks[].StackName' <<<"$JSON_CLOUDFORMATION_DESCRIBE_STACKS"`)
    

    if [ "$CLOUDFORMATION_STACK_NAMES" == "" ]; then
        CLOUDFORMATION="${RED}Not in use${RESET_FORMATTING}"
    else
        CLOUDFORMATION="${GREEN}In use    ${RESET_FORMATTING}"
    fi

    ### End the loading animation
    end_daemon "        Fetching CloudFormation Resouces. Done          "

    echo ""

    ###################################################
    #                    CloudTrail                   #
    ###################################################
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Fetching CloudTrail Resouces. Please wait"

    JSON_CLOUDTRAIL_DESCRIBE_TRAILS=`aws cloudtrail describe-trails${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    CLOUDTRAIL_TRAIL_NAMES=(`jq -r '.trailList[].Name' <<<"$JSON_CLOUDTRAIL_DESCRIBE_TRAILS"`)

    if [ "$CLOUDTRAIL_TRAIL_NAMES" == "" ]; then
        CLOUDTRAIL="${RED}Not in use${RESET_FORMATTING}"
    else
        CLOUDTRAIL="${GREEN}In use    ${RESET_FORMATTING}"
    fi

    ### End the loading animation
    end_daemon "        Fetching CloudTrail Resouces. Done          "

    echo ""

    ###################################################
    #                    CloudWatch                   #
    ###################################################
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Fetching CloudWatch Resouces. Please wait"

    JSON_CLOUDWATCH_DESCRIBE_ALARMS=`aws cloudwatch describe-alarms${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    CLOUDWATCH_ALARM_NAMES=(`jq -r '.MetricAlarms[].AlarmName' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`)

    if [ "$CLOUDWATCH_ALARM_NAMES" == "" ]; then
        CLOUDWATCH="${RED}Not in use${RESET_FORMATTING}"
    else
        CLOUDWATCH="${GREEN}In use    ${RESET_FORMATTING}"
    fi

    ### End the loading animation
    end_daemon "        Fetching CloudWatch Resouces. Done          "

    echo ""

    ###################################################
    #                     DynamoDB                   #
    ###################################################
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Fetching DynamoDB Resouces. Please wait"

    JSON_DYNAMODB_LIST_TABLES=`aws dynamodb list-tables${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    DYNAMODB_TABLE_NAMES=(`jq -r '.TableNames[]' <<<"$JSON_DYNAMODB_LIST_TABLES"`)

    if [ "$DYNAMODB_TABLE_NAMES" == "" ]; then
        DYNAMODB="${RED}Not in use${RESET_FORMATTING}"
    else
        DYNAMODB="${GREEN}In use    ${RESET_FORMATTING}"
    fi

    ### End the loading animation
    end_daemon "        Fetching DynamoDB Resouces. Done          "

    echo ""

    ###################################################
    #                    ElastiCache                  #
    ###################################################
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Fetching ElastiCache Resouces. Please wait"

    JSON_ELASTICACHE_DESCRIBE_CACHE_CLUSTERS=`aws elasticache describe-cache-clusters${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    ELASTICACHE_CACHE_CLUSTER_IDS=(`jq -r '.CacheClusters[].CacheClusterId' <<<"$JSON_ELASTICACHE_DESCRIBE_CACHE_CLUSTERS"`)

    if [ "$ELASTICACHE_CACHE_CLUSTER_IDS" == "" ]; then
        ELASTICACHE="${RED}Not in use${RESET_FORMATTING}"
    else
        ELASTICACHE="${GREEN}In use    ${RESET_FORMATTING}"
    fi

    ### End the loading animation
    end_daemon "        Fetching ElastiCache Resouces. Done          "

    echo ""

    ###################################################
    #                       ELB                       #
    ###################################################
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Fetching ELB Resouces. Please wait"

    JSON_ELB_DESCRIBE_LOAD_BALANCERS=`aws elb describe-load-balancers${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    ELB_LOAD_BALANCER_NAMES=(`jq -r '.LoadBalancerDescriptions[].LoadBalancerName' <<<"$JSON_ELB_DESCRIBE_LOAD_BALANCERS"`)

    if [ "$ELB_LOAD_BALANCER_NAMES" == "" ]; then
        ELB="${RED}Not in use${RESET_FORMATTING}"
    else
        ELB="${GREEN}In use    ${RESET_FORMATTING}"
    fi

    ### End the loading animation
    end_daemon "        Fetching ELB Resouces. Done          "

    echo ""

    ###################################################
    #                      ELBv2                      #
    ###################################################
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Fetching ELBv2 Resouces. Please wait"

    JSON_ELBV2_DESCRIBE_LOAD_BALANCERS=`aws elbv2 describe-load-balancers${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    ELBV2_LOAD_BALANCER_NAMES=(`jq -r '.LoadBalancers[].LoadBalancerName' <<<"$JSON_ELBV2_DESCRIBE_LOAD_BALANCERS"`)
    
    if [ "$ELBV2_LOAD_BALANCER_NAMES" == "" ]; then
        ELBV2="${RED}Not in use${RESET_FORMATTING}"
    else
        ELBV2="${GREEN}In use    ${RESET_FORMATTING}"
    fi

    ### End the loading animation
    end_daemon "        Fetching ELBv2 Resouces. Done          "

    echo ""

    ### Turn on cursor
    tput cnorm
}

#----------------------------------------------------------------------
# Function: get_account_info
# Purpose:  Used to get the STS account info.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function get_account_info {
    if [[ "$DEBUG" == "true" ]]; then
        echo "###############################################"
        echo "#    Entering: get_account_info function      #"
        echo "###############################################"
        sleep 2
    fi

    if [ -n "$DEBUG" ]; then
        clear
        print_menu_header "Fetching AWS Resources"
        echo ""
    fi

    ### Turn off cursor
    tput civis

    ###################################################
    #                        STS                      #
    ###################################################
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Fetching STS Resouces. Please wait"

    JSON_STS_GET_CALLER_IDENTITY=`aws sts get-caller-identity${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    STS_USER_ID=(`jq -r '.UserId' <<<"$JSON_STS_GET_CALLER_IDENTITY"`)
    STS_ACCOUNT=(`jq -r '.Account' <<<"$JSON_STS_GET_CALLER_IDENTITY"`)
    STS_ARN=(`jq -r '.Arn' <<<"$JSON_STS_GET_CALLER_IDENTITY"`)

    AWS_CONFIGURE_LIST_PROFILES=(`aws configure list-profiles`)

    ### End the loading animation
    end_daemon "        Fetching STS Resouces. Done          "

    ### Sleep to show last message
    sleep 2

    ### Turn on cursor
    tput cnorm
}

###################################################
#                  CloudFormation                 #
###################################################
#----------------------------------------------------------------------
# Function: cloudformation_enable_disable_termination_protection
# Purpose:  Used to enable/disable stack termination protection.
# Args:     name of the stack, state of current protection
# Returns:  null 
#----------------------------------------------------------------------
function cloudformation_enable_disable_termination_protection {
    CLOUDFORMATION_STACK_NAME=$1
    TERMINATION_PROTECTION_ENABLED=$2

    if [ "$TERMINATION_PROTECTION_ENABLED" == "false" ]; then
        SWITCH="--enable-termination-protection"
        ACTION="Enabling"
    else
        SWITCH="--no-enable-termination-protection"
        ACTION="Disabling"
    fi

    clear
    print_menu_header "CloudFormation Stack - ${CLOUDFORMATION_STACK_NAME}"

    echo ""

    ### Turn off cursor
    tput civis
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        ${ACTION} Termination Protection on CloudFormation Stack - ${CLOUDFORMATION_STACK_NAME}. Please wait"
    
    ### Run command(s) to update cloudformation stack termination protection
    run_command "aws cloudformation update-termination-protection --stack-name ${CLOUDFORMATION_STACK_NAME} ${SWITCH}${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

    ### Update the JSON object so changes show
    #JSON_CLOUDFORMATION_DESCRIBE_STACK=`aws cloudformation describe-stacks --stack-name ${CLOUDFORMATION_STACK_NAME}${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    
    ### End the loading animation
    end_daemon "        ${ACTION} Termination Protection on CloudFormation Stack - ${CLOUDFORMATION_STACK_NAME}. Done          "

    ### Turn on cursor
    tput cnorm

    ### Allow message to be seen
    sleep 2
}

#----------------------------------------------------------------------
# Function: cloudformation_sync_drift
# Purpose:  Used to sync stack drift.
# Args:     name of the stack
# Returns:  null 
#----------------------------------------------------------------------
function cloudformation_sync_drift {
    CLOUDFORMATION_STACK_NAME=$1

    clear
    print_menu_header "CloudFormation Stack - ${CLOUDFORMATION_STACK_NAME}"

    echo ""

    ### Turn off cursor
    tput civis
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Syncing drift on CloudFormation Stack - ${CLOUDFORMATION_STACK_NAME}. Please wait"
    
    ### Fetch the stack drift id
    STACK_DRIFT_DETECTION_ID=`aws cloudformation detect-stack-drift --stack-name ${CLOUDFORMATION_STACK_NAME} --output text --query 'StackDriftDetectionId'${AWS_PROFILE_ARG} --region ${AWS_REGION}`

    ### Run command(s) to update cloudformation stack sync
    run_command "aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id ${STACK_DRIFT_DETECTION_ID} --query '{DetectionStatus: DetectionStatus, StackDriftStatus: StackDriftStatus}'${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

    ### Update the JSON object so changes show
    #JSON_CLOUDFORMATION_DESCRIBE_STACK=`aws cloudformation describe-stacks --stack-name ${CLOUDFORMATION_STACK_NAME}${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    
    ### End the loading animation
    end_daemon "        Syncing drift on CloudFormation Stack - ${CLOUDFORMATION_STACK_NAME}. Done          "

    ### Turn on cursor
    tput cnorm

    ### Allow message to be seen
    sleep 2
}

###################################################
#                    CloudTrail                   #
###################################################
#----------------------------------------------------------------------
# Function: cloudtrail_enable_disable_global_service_events
# Purpose:  Used to enable/disable trail global service events.
# Args:     name of the trail, state of current global service event
# Returns:  null 
#----------------------------------------------------------------------
function cloudtrail_enable_disable_global_service_events {
    CLOUDTRAIL_TRAIL_NAME=$1
    INCLUDE_GLOBAL_SERVICE_EVENTS=$2

    if [ "$INCLUDE_GLOBAL_SERVICE_EVENTS" == "false" ]; then
        SWITCH="--include-global-service-events"
        ACTION="Enabling"
    else
        SWITCH="--no-include-global-service-events"
        ACTION="Disabling"
    fi

    clear
    print_menu_header "CloudTrail Trail - ${CLOUDTRAIL_TRAIL_NAME}"

    echo ""

    ### Turn off cursor
    tput civis
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        ${ACTION} Include Global Service Events on CloudTrail Trail - ${CLOUDTRAIL_TRAIL_NAME}. Please wait"
    
    ### Run command(s) to update cloudformation stack termination protection
    run_command "aws cloudtrail update-trail --name ${CLOUDTRAIL_TRAIL_NAME} ${SWITCH}${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

    ### Update the JSON object so changes show
    JSON_CLOUDTRAIL_DESCRIBE_TRAILS=`aws cloudtrail describe-trails${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    
    ### End the loading animation
    end_daemon "        ${ACTION} Include Global Service Events on CloudTrail Trail - ${CLOUDTRAIL_TRAIL_NAME}. Done          "

    ### Turn on cursor
    tput cnorm

    ### Allow message to be seen
    sleep 2
}

#----------------------------------------------------------------------
# Function: cloudtrail_enable_disable_multi_region_trail
# Purpose:  Used to enable/disable trail multi region trail.
# Args:     name of the trail, state of current multi region trail
# Returns:  null 
#----------------------------------------------------------------------
function cloudtrail_enable_disable_multi_region_trail {
    CLOUDTRAIL_TRAIL_NAME=$1
    IS_MULTI_REGION_TRAIL$2

    if [ "$IS_MULTI_REGION_TRAIL" == "false" ]; then
        SWITCH="--is-multi-region-trail"
        ACTION="Enabling"
    else
        SWITCH="--no-is-multi-region-trail"
        ACTION="Disabling"
    fi

    clear
    print_menu_header "CloudTrail Trail - ${CLOUDTRAIL_TRAIL_NAME}"

    echo ""

    ### Turn off cursor
    tput civis
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        ${ACTION} Multi Region Trail on CloudTrail Trail - ${CLOUDTRAIL_TRAIL_NAME}. Please wait"
    
    ### Run command(s) to update cloudformation stack termination protection
    run_command "aws cloudtrail update-trail --name ${CLOUDTRAIL_TRAIL_NAME} ${SWITCH}${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

    ### Update the JSON object so changes show
    JSON_CLOUDTRAIL_DESCRIBE_TRAILS=`aws cloudtrail describe-trails${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    
    ### End the loading animation
    end_daemon "        ${ACTION} Multi Region Trail on CloudTrail Trail - ${CLOUDTRAIL_TRAIL_NAME}. Done          "

    ### Turn on cursor
    tput cnorm

    ### Allow message to be seen
    sleep 2
}

#----------------------------------------------------------------------
# Function: cloudtrail_enable_disable_log_file_validation_enabled
# Purpose:  Used to enable/disable trail log file validation enabled.
# Args:     name of the trail, state of current log file validation 
#           enabled
# Returns:  null 
#----------------------------------------------------------------------
function cloudtrail_enable_disable_log_file_validation_enabled {
    CLOUDTRAIL_TRAIL_NAME=$1
    LOG_FILE_VALIDATION_ENABLED=$2

    if [ "$LOG_FILE_VALIDATION_ENABLED" == "false" ]; then
        SWITCH="--enable-log-file-validation"
        ACTION="Enabling"
    else
        SWITCH="--no-enable-log-file-validation"
        ACTION="Disabling"
    fi

    clear
    print_menu_header "CloudTrail Trail - ${CLOUDTRAIL_TRAIL_NAME}"

    echo ""

    ### Turn off cursor
    tput civis
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        ${ACTION} Log File Validation Enabled on CloudTrail Trail - ${CLOUDTRAIL_TRAIL_NAME}. Please wait"
    
    ### Run command(s) to update cloudformation stack termination protection
    run_command "aws cloudtrail update-trail --name ${CLOUDTRAIL_TRAIL_NAME} ${SWITCH}${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

    ### Update the JSON object so changes show
    JSON_CLOUDTRAIL_DESCRIBE_TRAILS=`aws cloudtrail describe-trails${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    
    ### End the loading animation
    end_daemon "        ${ACTION} Log File Validation Enabled on CloudTrail Trail - ${CLOUDTRAIL_TRAIL_NAME}. Done          "

    ### Turn on cursor
    tput cnorm

    ### Allow message to be seen
    sleep 2
}

###################################################
#                    CloudWatch                   #
###################################################
#----------------------------------------------------------------------
# Function: cloudwatch_alarm
# Purpose:  Used to create a cloudwatch alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_alarm {
    CLOUDWATCH_ALARM_NAME="$1"; shift
    CLOUDWATCH_ALARM_TOPIC_NAME="$1"; shift
    CLOUDWATCH_FILTER_PATTERN="$1"; shift
    CLOUDWATCH_METRIC_NAME="$1"; shift
    CLOUDWATCH_METRIC_NAMESPACE="$1"; shift
    CLOUDWATCH_METRIC_VALUE="$1"; shift
    CLOUDWATCH_ALARM_DESCRIPTION="$1"; shift
    CLOUDWATCH_STATISTIC="$1"; shift
    CLOUDWATCH_PERIOD="$1"; shift
    CLOUDWATCH_EVALUATION_PERIOD="$1"; shift
    CLOUDWATCH_THRESHOLD="$1"; shift
    CLOUDWATCH_COMPARISON_OPERATOR="$1"; shift
    CLOUDWATCH_TREAT_MISSING_DATA="$1"

    clear
    print_menu_header "CloudWatch Alarms"

    echo ""

    ### Turn off cursor
    tput civis
    
    ### Start the loading animation in background and grab the pid
    start_daemon "        Create CloudWatch Alarm - ${CLOUDWATCH_ALARM_NAME}. Please wait"
    
    ### Create SNS Topic
    CLOUDWATCH_TOPIC_ARN=$(aws sns create-topic --name ${CLOUDWATCH_ALARM_TOPIC_NAME} --query "TopicArn" --output text${AWS_PROFILE_ARG} --region ${AWS_REGION})

    if [ -n "$DEBUG" ]; then
        echo "        CLOUDWATCH_ALARM_NAME: ${CLOUDWATCH_ALARM_NAME}"
        echo "        CLOUDWATCH_ALARM_TOPIC_NAME: ${CLOUDWATCH_ALARM_TOPIC_NAME}"
        echo "        CLOUDWATCH_FILTER_PATTERN: ${CLOUDWATCH_FILTER_PATTERN}"
        echo "        CLOUDWATCH_METRIC_NAME: ${CLOUDWATCH_METRIC_NAME}"
        echo "        CLOUDWATCH_METRIC_NAMESPACE: ${CLOUDWATCH_METRIC_NAMESPACE}"
        echo "        CLOUDWATCH_METRIC_VALUE: ${CLOUDWATCH_METRIC_VALUE}"
        echo "        CLOUDWATCH_ALARM_DESCRIPTION: ${CLOUDWATCH_ALARM_DESCRIPTION}"
        echo "        CLOUDWATCH_STATISTIC: ${CLOUDWATCH_STATISTIC}"
        echo "        CLOUDWATCH_PERIOD: ${CLOUDWATCH_PERIOD}"
        echo "        CLOUDWATCH_EVALUATION_PERIOD: ${CLOUDWATCH_EVALUATION_PERIOD}"
        echo "        CLOUDWATCH_THRESHOLD: ${CLOUDWATCH_THRESHOLD}"
        echo "        CLOUDWATCH_COMPARISON_OPERATOR: ${CLOUDWATCH_COMPARISON_OPERATOR}"
        echo "        CLOUDWATCH_TREAT_MISSING_DATA: ${CLOUDWATCH_TREAT_MISSING_DATA}"
        echo ""

        echo "aws sns create-topic --name \"${CLOUDWATCH_ALARM_TOPIC_NAME}\" --query \"TopicArn\" --outputtext${AWS_PROFILE_ARG} --region ${AWS_REGION}"
        echo "aws logs create-log-group --log-group-name ${CLOUDWATCH_ALARM_NAME}${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}"
        echo "aws sns subscribe --topic-arn ${CLOUDWATCH_TOPIC_ARN} --protocol \"email\" --notification-endpoint ${EMAIL}${AWS_PROFILE_ARG} --region ${AWS_REGION}"
        echo "aws logs put-metric-filter --filter-name \"${CLOUDWATCH_ALARM_NAME}\" --log-group-name \"${CLOUDWATCH_ALARM_NAME}\" --filter-pattern ${CLOUDWATCH_FILTER_PATTERN} --metric-transformation metricName=\"${CLOUDWATCH_METRIC_NAME}\",metricNamespace=\"${CLOUDWATCH_METRIC_NAMESPACE}\",metricValue=\"${CLOUDWATCH_METRIC_VALUE}\"${AWS_PROFILE_ARG} --region ${AWS_REGION}"
        echo "aws cloudwatch put-metric-alarm --alarm-name \"${CLOUDWATCH_ALARM_NAME}\" --alarm-description \"${CLOUDWATCH_ALARM_DESCRIPTION}\" --alarm-actions ${CLOUDWATCH_TOPIC_ARN} --metric-name \"${CLOUDWATCH_METRIC_NAME}\" --namespace \"${CLOUDWATCH_METRIC_NAMESPACE}\" --statistic \"${CLOUDWATCH_STATISTIC}\" --period ${CLOUDWATCH_PERIOD} --evaluation-periods ${CLOUDWATCH_EVALUATION_PERIOD} --threshold ${CLOUDWATCH_THRESHOLD} --comparison-operator \"${CLOUDWATCH_COMPARISON_OPERATOR}\" --treat-missing-data \"${CLOUDWATCH_TREAT_MISSING_DATA}\"${AWS_PROFILE_ARG} --region ${AWS_REGION}"

        sleep 4
    fi
    
    ### Run command to create log group
    run_command "aws logs create-log-group --log-group-name ${CLOUDWATCH_ALARM_NAME}${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

    ### Run command to create sns subscription
    run_command "aws sns subscribe --topic-arn ${CLOUDWATCH_TOPIC_ARN} --protocol \"email\" --notification-endpoint ${EMAIL}${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

    ### Run command to create metric filter
    run_command "aws logs put-metric-filter --filter-name \"${CLOUDWATCH_ALARM_NAME}\" --log-group-name \"${CLOUDWATCH_ALARM_NAME}\" --filter-pattern ${CLOUDWATCH_FILTER_PATTERN} --metric-transformation metricName=\"${CLOUDWATCH_METRIC_NAME}\",metricNamespace=\"${CLOUDWATCH_METRIC_NAMESPACE}\",metricValue=\"${CLOUDWATCH_METRIC_VALUE}\"${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

    ### Run command to create metric alarm
    run_command "aws cloudwatch put-metric-alarm --alarm-name \"${CLOUDWATCH_ALARM_NAME}\" --alarm-description \"${CLOUDWATCH_ALARM_DESCRIPTION}\" --alarm-actions ${CLOUDWATCH_TOPIC_ARN} --metric-name \"${CLOUDWATCH_METRIC_NAME}\" --namespace \"${CLOUDWATCH_METRIC_NAMESPACE}\" --statistic \"${CLOUDWATCH_STATISTIC}\" --period ${CLOUDWATCH_PERIOD} --evaluation-periods ${CLOUDWATCH_EVALUATION_PERIOD} --threshold ${CLOUDWATCH_THRESHOLD} --comparison-operator \"${CLOUDWATCH_COMPARISON_OPERATOR}\" --treat-missing-data \"${CLOUDWATCH_TREAT_MISSING_DATA}\"${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

    ### Update the JSON object so changes show
    JSON_CLOUDWATCH_DESCRIBE_ALARMS=`aws cloudwatch describe-alarms${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    
    ### End the loading animation
    end_daemon "        Create CloudWatch Alarm - ${CLOUDWATCH_ALARM_NAME}. Done          "

    ### Turn on cursor
    tput cnorm

    ### Allow message to be seen
    sleep 2

}

#----------------------------------------------------------------------
# Function: cloudwatch_vpc_changes_alarm
# Purpose:  Used to create vpc_changes alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_vpc_changes_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="vpc-changes-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.eventName = CreateVpc) || ($.eventName = DeleteVpc) || ($.eventName = ModifyVpcAttribute) || ($.eventName = AcceptVpcPeeringConnection) || ($.eventName = CreateVpcPeeringConnection) || ($.eventName = DeleteVpcPeeringConnection) || ($.eventName = RejectVpcPeeringConnection) || ($.eventName = AttachClassicLinkVpc) || ($.eventName = DetachClassicLinkVpc) || ($.eventName = DisableVpcClassicLink) || ($.eventName = EnableVpcClassicLink)}'"
    CLOUDWATCH_METRIC_NAME="VpcEventCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers when changes are made to a VPC."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=300
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_security_group_changes_alarm
# Purpose:  Used to create security_group_changes alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_security_group_changes_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="security-group-changes-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup)"
    CLOUDWATCH_METRIC_NAME="SecurityGroupEventCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers when changes are made to Security Groups."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=300
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_s3_bucket_changes_alarm
# Purpose:  Used to create s3_bucket_changes alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_s3_bucket_changes_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="s3-bucket-changes-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.eventSource = s3.amazonaws.com) && (($.eventName = PutBucketAcl) || ($.eventName = PutBucketPolicy) || ($.eventName = PutBucketCors) || ($.eventName = PutBucketLifecycle) || ($.eventName = PutBucketReplication) || ($.eventName = DeleteBucketPolicy) || ($.eventName = DeleteBucketCors) || ($.eventName = DeleteBucketLifecycle) || ($.eventName = DeleteBucketReplication))}'"
    CLOUDWATCH_METRIC_NAME="S3BucketActivityEventCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers when changes are made to an S3 Bucket."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=300
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_route_table_changes_alarm
# Purpose:  Used to create route_table_changes alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_route_table_changes_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="route-table-changes-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.eventName = AssociateRouteTable) || ($.eventName = CreateRoute) || ($.eventName = CreateRouteTable) || ($.eventName = DeleteRoute) || ($.eventName = DeleteRouteTable) || ($.eventName = ReplaceRoute) || ($.eventName = ReplaceRouteTableAssociation) || ($.eventName = DisassociateRouteTable)}'"
    CLOUDWATCH_METRIC_NAME="VpcRouteTableEventCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers when changes are made to a VPC's Route Table."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=300
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_root_usage_alarm
# Purpose:  Used to create root_usage alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_root_usage_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="root-usage-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.userIdentity.type = \"Root\") && ($.userIdentity.invokedBy NOT EXISTS) && ($.eventType != \"AwsServiceEvent\")}'"
    CLOUDWATCH_METRIC_NAME="RootUserEventCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers if a root user uses the account."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=60
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_network_acl_changes_alarm
# Purpose:  Used to create network_acl_changes alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_network_acl_changes_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="network-acl-changes-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation)}'"
    CLOUDWATCH_METRIC_NAME="NetworkAclEventCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers when changes are made to Network ACLs."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=300
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_internet_gateway_changes_alarm
# Purpose:  Used to create internet_gateway_changes alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_internet_gateway_changes_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="internet-gateway-changes-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.eventName = CreateCustomerGateway) || ($.eventName = DeleteCustomerGateway) || ($.eventName = AttachInternetGateway) || ($.eventName = CreateInternetGateway) || ($.eventName = DeleteInternetGateway) || ($.eventName = DetachInternetGateway)}'"
    CLOUDWATCH_METRIC_NAME="GatewayEventCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers when changes are made to an Internet Gateway in a VPC."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=300
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_ec2_instance_changes_alarm
# Purpose:  Used to create ec2_instance_changes alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_ec2_instance_changes_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="ec2-instance-changes-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.eventName = RunInstances) || ($.eventName = RebootInstances) || ($.eventName = StartInstances) || ($.eventName = StopInstances) || ($.eventName = TerminateInstances)}'"
    CLOUDWATCH_METRIC_NAME="EC2InstanceEventCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers when changes are made to EC2 Instances."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=300
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_ec2_large_instance_changes_alarm
# Purpose:  Used to create ec2_large_instance_changes alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_ec2_large_instance_changes_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="ec2-large-instance-changes-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{(($.eventName = RunInstances) || ($.eventName = RebootInstances) || ($.eventName = StartInstances) || ($.eventName = StopInstances) || ($.eventName = TerminateInstances)) && (($.requestParameters.instanceType = *.32xlarge) || ($.requestParameters.instanceType = *.24xlarge) || ($.requestParameters.instanceType = *.18xlarge) || ($.requestParameters.instanceType = *.16xlarge) || ($.requestParameters.instanceType = *.12xlarge) || ($.requestParameters.instanceType = *.10xlarge) || ($.requestParameters.instanceType = *.9xlarge) || ($.requestParameters.instanceType = *.8xlarge) || ($.requestParameters.instanceType = *.4xlarge))}'"
    CLOUDWATCH_METRIC_NAME="EC2LargeInstanceEventCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers when changes are made to large size EC2 Instances."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=300
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_failed_console_logins_alarm
# Purpose:  Used to create failed_console_logins alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_failed_console_logins_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="failed-console-logins-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.eventName = ConsoleLogin) && ($.errorMessage = \"Failed authentication\")}'"
    CLOUDWATCH_METRIC_NAME="ConsoleLoginFailures"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers if there are AWS Management Console authentication failures."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=300
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_no_mfa_console_logins_alarm
# Purpose:  Used to create no_mfa_console_logins alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_no_mfa_console_logins_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="no-mfa-console-logins-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.responseElements.ConsoleLogin != \"Failure\") && ($.additionalEventData.SamlProviderArn NOT EXISTS)}'"
    CLOUDWATCH_METRIC_NAME="ConsoleSigninWithoutMFA"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers if there is a Management Console sign-in without MFA."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=60
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_disabled_deleted_cmks_alarm
# Purpose:  Used to create disabled_deleted_cmks alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_disabled_deleted_cmks_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="disabled-deleted-cmks-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.eventSource = kms.amazonaws.com) &&  (($.eventName=DisableKey) || ($.eventName=ScheduleKeyDeletion))}'"
    CLOUDWATCH_METRIC_NAME="KMSCustomerKeyDeletion"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers if customer created CMKs get disabled or scheduled for deletion."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=60
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_cloudtrail_changes_alarm
# Purpose:  Used to create cloudtrail_changes alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_cloudtrail_changes_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="cloudtrail-changes-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging)}'"
    CLOUDWATCH_METRIC_NAME="CloudTrailEventCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers when changes are made to CloudTrail."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=300
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_config_changes_alarm
# Purpose:  Used to create config_changes alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_config_changes_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="config-changes-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.eventName = PutConfigurationRecorder) || ($.eventName = StopConfigurationRecorder) || ($.eventName = DeleteDeliveryChannel) || ($.eventName = PutDeliveryChannel)}'"
    CLOUDWATCH_METRIC_NAME="CloudTrailEventCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers when changes are made to AWS Config."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=300
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

#----------------------------------------------------------------------
# Function: cloudwatch_unauthorized_api_calls_alarm
# Purpose:  Used to create unauthorized_api_calls alarm.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_unauthorized_api_calls_alarm {
    CLOUDWATCH_ALARM_NAME=$1

    CLOUDWATCH_ALARM_TOPIC_NAME="unauthorized-api-calls-alarm-action"
    CLOUDWATCH_FILTER_PATTERN="'{($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\")}'"
    CLOUDWATCH_METRIC_NAME="UnauthorizedAttemptCount"
    CLOUDWATCH_METRIC_NAMESPACE="CloudTrailMetrics"
    CLOUDWATCH_METRIC_VALUE="1"
    CLOUDWATCH_ALARM_DESCRIPTION="A CloudWatch Alarm that triggers if Multiple unauthorized actions or logins attempted."
    CLOUDWATCH_STATISTIC="Sum"
    CLOUDWATCH_PERIOD=60
    CLOUDWATCH_EVALUATION_PERIOD=1
    CLOUDWATCH_THRESHOLD=1
    CLOUDWATCH_COMPARISON_OPERATOR="GreaterThanOrEqualToThreshold"
    CLOUDWATCH_TREAT_MISSING_DATA="notBreaching"

    cloudwatch_alarm "${CLOUDWATCH_ALARM_NAME}" "${CLOUDWATCH_ALARM_TOPIC_NAME}" "${CLOUDWATCH_FILTER_PATTERN}" "${CLOUDWATCH_METRIC_NAME}" "${CLOUDWATCH_METRIC_NAMESPACE}" "${CLOUDWATCH_METRIC_VALUE}" "${CLOUDWATCH_ALARM_DESCRIPTION}" "${CLOUDWATCH_STATISTIC}" "${CLOUDWATCH_PERIOD}" "${CLOUDWATCH_EVALUATION_PERIOD}" "${CLOUDWATCH_THRESHOLD}" "${CLOUDWATCH_COMPARISON_OPERATOR}" "${CLOUDWATCH_TREAT_MISSING_DATA}"
}

###################################################
#                        ELB                      #
###################################################
#----------------------------------------------------------------------
# Function: elb_enable_disable_access_log_enabled
# Purpose:  Used to enable/disable elb access log enable.
# Args:     name of the elb, state of current access log enable
# Returns:  null 
#----------------------------------------------------------------------
function elb_enable_disable_access_log_enabled {
    ELB_LOAD_BALANCER_NAME=$1
    ACCESS_LOG_ENABLED=$2
    ELB_LOAD_BALANCER_NAME_LOW=`to_lower $ELB_LOAD_BALANCER_NAME`

    if [ "$ACCESS_LOG_ENABLED" == "false" ]; then
        ELB_ACCESS_LOG_S3_BUCKET="${ELB_LOAD_BALANCER_NAME_LOW}-elb-logging-bucket"
        ELB_ACCESS_LOG_POLICY_FILE="${ELB_ACCESS_LOG_S3_BUCKET}-policy.json"
        ELB_ACCESS_LOG_ATTRIBUTES="{\"AccessLog\":{\"Enabled\":true,\"EmitInterval\":60,\"S3BucketName\":\"${ELB_ACCESS_LOG_S3_BUCKET}\"}"
        JSON_S3_BUCKET_POLICY=`jq '.' elb-access-logging-policy-template.json`
        POLICY=`cat templates/elb-access-logging-policy-template.json | sed "s/elb-account-id/${REGION_ACCOUNT_IDS[${AWS_REGION}]}/g" | sed "s/bucket-name/${ELB_ACCESS_LOG_S3_BUCKET}/g" | sed "s/your-aws-account-id/${STS_ACCOUNT}/g" | sed "s/prefix/testing/g" > ${ELB_ACCESS_LOG_POLICY_FILE}`

        ### Set JSON values
        #jq '.Statement[].Resource = "arn:aws:s3:::'${ELB_ACCESS_LOG_S3_BUCKET}'/AWSLogs/'${STS_ACCOUNT}/*'" | .Statement[].Principal.AWS = "'${STS_ACCOUNT}'"' <<<"$JSON_S3_BUCKET_POLICY" > ${ELB_ACCESS_LOG_POLICY_FILE}

        if [ -n "$DEBUG" ]; then
            echo "        ELB_LOAD_BALANCER_NAME: ${ELB_LOAD_BALANCER_NAME}"
            echo "        ACCESS_LOG_ENABLED: ${ACCESS_LOG_ENABLED}"
            echo "        ELB_ACCESS_LOG_S3_BUCKET: ${ELB_ACCESS_LOG_S3_BUCKET}"
            echo "        ELB_ACCESS_LOG_POLICY_FILE: ${ELB_ACCESS_LOG_POLICY_FILE}"
            echo "        ELB_ACCESS_LOG_ATTRIBUTES: ${ELB_ACCESS_LOG_ATTRIBUTES}"
            echo "        JSON_S3_BUCKET_POLICY: ${JSON_S3_BUCKET_POLICY}"
            echo ""
            cat ${ELB_ACCESS_LOG_POLICY_FILE}
            echo ""
            echo "        aws s3api create-bucket --bucket ${ELB_ACCESS_LOG_S3_BUCKET} --create-bucket-configuration LocationConstraint=${AWS_REGION}${AWS_PROFILE_ARG} --region ${AWS_REGION}"
            echo "        aws s3api put-bucket-policy --bucket ${ELB_ACCESS_LOG_S3_BUCKET} --policy file://${ELB_ACCESS_LOG_POLICY_FILE}${AWS_PROFILE_ARG} --region ${AWS_REGION}"
            echo "        aws elb modify-load-balancer-attributes --load-balancer-name ${ELB_LOAD_BALANCER_NAME} --load-balancer-attributes ${ELB_ACCESS_LOG_ATTRIBUTES}${AWS_PROFILE_ARG} --region ${AWS_REGION}"
            echo ""
        fi

        echo ""

        clear
        print_menu_header "ELB Load Balancer - ${ELB_LOAD_BALANCER_NAME}"

        echo ""

        ### Turn off cursor
        tput civis
    
        ### Start the loading animation in background and grab the pid
        start_daemon "        Enable access log for ELB Load Balancer - ${ELB_LOAD_BALANCER_NAME}. Please wait"
    
        ### Run command to create new access logging bucket
        run_command "aws s3api create-bucket --bucket ${ELB_ACCESS_LOG_S3_BUCKET} --create-bucket-configuration LocationConstraint=${AWS_REGION}${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

        ### Run command to delete policy attached to bucket
        run_command "aws s3api delete-bucket-policy --bucket ${ELB_ACCESS_LOG_S3_BUCKET}${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

        ### Run command to attach access policy to bucket
        run_command "aws s3api put-bucket-policy --bucket ${ELB_ACCESS_LOG_S3_BUCKET} --policy file://${ELB_ACCESS_LOG_POLICY_FILE}${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

        ### Run command to modify elb attribute
        run_command "aws elb modify-load-balancer-attributes --load-balancer-name ${ELB_LOAD_BALANCER_NAME} --load-balancer-attributes ${ELB_ACCESS_LOG_ATTRIBUTES}${AWS_PROFILE_ARG} --region ${AWS_REGION}${SUFFIX}" ${LINENO}

        ### Update the JSON object so changes show
        #JSON_CLOUDTRAIL_DESCRIBE_TRAILS=`aws cloudtrail describe-trails${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    
        ### End the loading animation
        end_daemon "        Enable access log for ELB Load Balancer - ${ELB_LOAD_BALANCER_NAME}. Done          "

        ### Turn on cursor
        tput cnorm

        ### Allow message to be seen
        sleep 2
    fi
}

######################################################################
#                                                                    #
#                                                                    #
#                                                                    #
#                            MENU SECTION                            #
#                                                                    #
#                                                                    #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: main_menu
# Purpose:  Used to display the main menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function main_menu {

    while true ; do
        clear
        print_menu_header "Main Menu"
        
        echo "
            1. AWS CloudFormation - ${CLOUDFORMATION}    9. AWS DynamoDB     - ${DYNAMODB}

            2. AWS CloudTrail     - ${CLOUDTRAIL}   10. AWS ElastiCache  - ${ELASTICACHE}

            3. AWS CloudWatch     - ${CLOUDWATCH}

            4. AWS ELB            - ${ELB}

            5. AWS ELBv2          - ${ELBV2}

            6. AWS API Gateway    - ${APIGATEWAY}

            7. AWS ASG            - ${ASG}

            8. AWS CloudFront     - ${CLOUDFRONT}




            "
            if [[ ${#AWS_CONFIGURE_LIST_PROFILES[@]} -gt 1 ]]; then
                print "    P. Change Profile"
            fi

            echo "
	
            R. Change Region
	
            E. Exit


            ${MAGENTA}Please enter option :  ${RESET_FORMATTING}\c" ;

        read OPTION

    	case $OPTION in

    		'') ;;  # nothing entered - redisplay menu

    		1)  clr ; cloudformation_stacks_menu ;;

    		2)  clr ; cloudtrail_trails_menu ;;

    		3)  clr ; cloudwatch_alarms_menu ;;

            4)  clr ; elb_load_balancers_menu ;;

            5)  clr ; elbv2_load_balancers_menu ;;

            6)  clr ; apigateway_clusters_menu ;;

            7)  clr ; asg_auto_scaling_groups_menu ;;

            8)  clr ; cloudfront_distributions_menu ;;

            9)  clr ; dynamodb_tables_menu ;;

            10)  clr ; elasticache_cache_clusters_menu ;;
		
            [Pp]|[Pp]rofile) 
                            clr
                            select_profile_menu
                            if [[ "$SKIP" != "true" ]]; then
                                prefill_aws_resources
                            fi
                            ;;
		
            [Rr]|[Rr]egion) 
                            clr
                            select_aws_region_menu
                            if [[ "$SKIP" != "true" ]]; then
                                prefill_aws_resources
                            fi
                            ;;

            [EeQq]|[Ee]xit|[Qq]uit) echo "\n" ; exit ;;

            *)  clr ; wr_err "  Invalid option! ==> $OPTION" ;;

	    esac
    done
}

#----------------------------------------------------------------------
# Function: select_profile_menu
# Purpose:  Used to display the select profile menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function select_profile_menu {

    while true ; do
        clear
        print_menu_header "Select Profile Menu"
    
        LONGEST_NAME=0
        MENU_ITEM=1

        ### Iterate profile names
        for PROFILE_NAME in "${AWS_CONFIGURE_LIST_PROFILES[@]}"; do

            BEGINNING_PADDING=$(number_padding ${MENU_ITEM})

            PROFILE_PRINT_NAME=$(is_selected ${PROFILE_NAME} ${AWS_PROFILE})

            print "    ${MENU_ITEM}.${BEGINNING_PADDING}${PROFILE_PRINT_NAME}"
            MENU_ITEM=`expr $MENU_ITEM + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

    	case $OPTION in

    		'') ;;  # nothing entered - redisplay menu

            [1-9]|[1-9][0-9]) clr ; if [ $OPTION -gt ${#AWS_CONFIGURE_LIST_PROFILES[@]} ]; then wr_err "Invalid option! ==> $OPTION" ; else AWS_PROFILE=${AWS_CONFIGURE_LIST_PROFILES[$OPTION-1]} ; if [[ "${AWS_CONFIGURE_LIST_PROFILES[$OPTION-1]}" != "default" ]] ; then AWS_PROFILE_ARG=" --profile ${AWS_CONFIGURE_LIST_PROFILES[$OPTION-1]}" ; else AWS_PROFILE_ARG="" ; fi ; AWS_REGION=`aws configure get region --profile ${AWS_CONFIGURE_LIST_PROFILES[$OPTION-1]}` ; break ; fi ;;
		
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

	    esac
    done
}

#----------------------------------------------------------------------
# Function: select_aws_region_menu
# Purpose:  Used to display the select region menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function select_aws_region_menu {

    while true ; do
        clear
        print_menu_header "Select Region Menu"
    
        PADDING=""
        PADDING_CHAR=" "
        LONGEST_NAME=0
        INDEX=0
        MENU_ITEM=1

        for REGION_ACCOUNT_SHORT_NAME in "${REGION_ACCOUNT_SHORT_NAMES[@]}"; do

            ### Find the longest name
            let NAME_LENGTH=${#REGION_ACCOUNT_SHORT_NAME}+2 
            if [ ${NAME_LENGTH} -gt ${LONGEST_NAME} ]; then
                LONGEST_NAME=${NAME_LENGTH}
            fi
        done

        ### Iterate region names
        for REGION_ACCOUNT_SHORT_NAME in "${REGION_ACCOUNT_SHORT_NAMES[@]}"; do

            END_PADDING=""
            COUNT=0

            ### Get number padding
            BEGINNING_PADDING=$(number_padding ${MENU_ITEM})

            ### Get selection
            PRINT_NAME=$(is_selected ${REGION_ACCOUNT_SHORT_NAME} ${AWS_REGION})

            ### Get end padding
            END_PADDING=$(loop_padding ${LONGEST_NAME} ${#PRINT_NAME} " ")
            print "    ${MENU_ITEM}.${BEGINNING_PADDING}${PRINT_NAME} ${END_PADDING}- ${REGION_ACCOUNT_LONG_NAMES[$INDEX]}"
            MENU_ITEM=`expr $MENU_ITEM + 1`
            INDEX=`expr $INDEX + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

    	case $OPTION in

    		'') ;;  # nothing entered - redisplay menu

            [1-9]|1[0-9]|2[0-1]) AWS_REGION=${REGION_ACCOUNT_SHORT_NAMES[$OPTION-1]} ;  break ;;
		
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

	    esac
    done
}

######################################################################
#                                                                    #
#                      CLOUDFORMATION MENU SECTION                   #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: cloudformation_stacks_menu
# Purpose:  Used to display the cloudformation stacks menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudformation_stacks_menu {
    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "CloudFormation Stacks"

        for CLOUDFORMATION_STACK_NAME in "${CLOUDFORMATION_STACK_NAMES[@]}"
        do
            padding $MENU_ITEM"." 4 " " ${CLOUDFORMATION_STACK_NAME}
			MENU_ITEM=`expr $MENU_ITEM + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            [1-9]|[1-9][0-9]) if [ $OPTION -gt ${#CLOUDFORMATION_STACK_NAMES[@]} ]; then continue; else cloudformation_stack_menu ${CLOUDFORMATION_STACK_NAMES[$OPTION-1]}; fi ;;
            
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

#----------------------------------------------------------------------
# Function: cloudformation_stack_menu
# Purpose:  Used to display the cloudformation stack menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudformation_stack_menu {

    CLOUDFORMATION_STACK_NAME=$1

    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "CloudFormation Stack - ${CLOUDFORMATION_STACK_NAME}"
        
        echo ""

        ### Turn off cursor
        tput civis
            
        ### Start the loading animation in background and grab the pid
        start_daemon "        Fetching configuration for CloudFormation Stack - ${CLOUDFORMATION_STACK_NAME}. Please wait"
    
        ### Fetch the JSON object for stack
        JSON_CLOUDFORMATION_DESCRIBE_STACK=`aws cloudformation describe-stacks --stack-name ${CLOUDFORMATION_STACK_NAME}${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    
        ### End the loading animation
        end_daemon "        Fetching configuration for CloudFormation Stack - ${CLOUDFORMATION_STACK_NAME}. Done          "

        ### Turn on cursor
        tput cnorm

        TERMINATION_PROTECTION_ENABLED=`jq -r ".Stacks[] | select (.StackName == \"${CLOUDFORMATION_STACK_NAME}\") | .EnableTerminationProtection" <<<"$JSON_CLOUDFORMATION_DESCRIBE_STACK"`
        DRIFT_INFORMATION=`jq -r ".Stacks[] | select (.StackName == \"${CLOUDFORMATION_STACK_NAME}\") | .DriftInformation | .StackDriftStatus" <<<"$JSON_CLOUDFORMATION_DESCRIBE_STACK"`

        clear
        print_menu_header "CloudFormation Stack - ${CLOUDFORMATION_STACK_NAME}"
        
        echo ""

        if [ -n "$DEBUG" ]; then
            echo "        TERMINATION_PROTECTION_ENABLED: ${TERMINATION_PROTECTION_ENABLED}"
            echo "        DRIFT_INFORMATION: ${DRIFT_INFORMATION}"
            echo ""
        fi

        if [ "$TERMINATION_PROTECTION_ENABLED" == "false" ]; then
            print_compliance_line 1 EnableTerminationProtection TERMINATION_PROTECTION_ENABLED fail
        else
            print_compliance_line 1 EnableTerminationProtection TERMINATION_PROTECTION_ENABLED pass
        fi
                
        if [ "$DRIFT_INFORMATION" == "IN_SYNC" ]; then
            print_compliance_line 2 StackDriftStatus DRIFT_INFORMATION pass
        else
            print_compliance_line 2 StackDriftStatus DRIFT_INFORMATION fail
        fi

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            1)  clr ; cloudformation_enable_disable_termination_protection ${CLOUDFORMATION_STACK_NAME} $TERMINATION_PROTECTION_ENABLED ;;

    		2)  clr ; cloudformation_sync_drift ${CLOUDFORMATION_STACK_NAME} ;;
                
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

######################################################################
#                                                                    #
#                        CLOUDTRAIL MENU SECTION                     #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: cloudtrail_trails_menu
# Purpose:  Used to display the cloudtrails trails menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudtrail_trails_menu {
    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "CloudTrail Trails"
        
        for CLOUDTRAIL_TRAIL_NAME in "${CLOUDTRAIL_TRAIL_NAMES[@]}"
        do
            padding $MENU_ITEM"." 4 " " ${CLOUDTRAIL_TRAIL_NAME}
			MENU_ITEM=`expr $MENU_ITEM + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            [1-9]|[1-9][0-9]) if [ $OPTION -gt ${#CLOUDTRAIL_TRAIL_NAMES[@]} ]; then continue; else cloudtrail_trail_menu ${CLOUDTRAIL_TRAIL_NAMES[$OPTION-1]}; fi ;;
            
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

#----------------------------------------------------------------------
# Function: cloudtrail_trail_menu
# Purpose:  Used to display the cloudtrail trail menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudtrail_trail_menu {
    
    CLOUDTRAIL_TRAIL_NAME=$1

    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "CloudTrail Trail - ${CLOUDTRAIL_TRAIL_NAME}"
        
        echo ""

        INCLUDE_GLOBAL_SERVICE_EVENTS=`jq -r ".trailList[] | select (.Name == \"${CLOUDTRAIL_TRAIL_NAME}\") | .IncludeGlobalServiceEvents" <<<"$JSON_CLOUDTRAIL_DESCRIBE_TRAILS"`
        IS_MULTI_REGION_TRAIL=`jq -r ".trailList[] | select (.Name == \"${CLOUDTRAIL_TRAIL_NAME}\") | .IsMultiRegionTrail" <<<"$JSON_CLOUDTRAIL_DESCRIBE_TRAILS"`
        LOG_FILE_VALIDATION_ENABLED=`jq -r ".trailList[] | select (.Name == \"${CLOUDTRAIL_TRAIL_NAME}\") | .LogFileValidationEnabled" <<<"$JSON_CLOUDTRAIL_DESCRIBE_TRAILS"`

        if [ -n "$DEBUG" ]; then
            echo "        INCLUDE_GLOBAL_SERVICE_EVENTS: ${INCLUDE_GLOBAL_SERVICE_EVENTS}"
            echo "        IS_MULTI_REGION_TRAIL: ${IS_MULTI_REGION_TRAIL}"
            echo "        LOG_FILE_VALIDATION_ENABLED: ${LOG_FILE_VALIDATION_ENABLED}"
            echo ""
        fi

        if [ "$INCLUDE_GLOBAL_SERVICE_EVENTS" == "false" ]; then
            print_compliance_line 1 IncludeGlobalServiceEvents INCLUDE_GLOBAL_SERVICE_EVENTS fail
        else
            print_compliance_line 1 IncludeGlobalServiceEvents INCLUDE_GLOBAL_SERVICE_EVENTS pass
        fi
                
        if [ "$IS_MULTI_REGION_TRAIL" == "false" ]; then
            print_compliance_line 2 IsMultiRegionTrail IS_MULTI_REGION_TRAIL fail
        else
            print_compliance_line 2 IsMultiRegionTrail IS_MULTI_REGION_TRAIL pass
        fi

        if [ "$LOG_FILE_VALIDATION_ENABLED" == "false" ]; then
            print_compliance_line 3 LogFileValidationEnabled LOG_FILE_VALIDATION_ENABLED fail
        else
            print_compliance_line 3 LogFileValidationEnabled LOG_FILE_VALIDATION_ENABLED pass
        fi

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            1)  clr ; cloudtrail_enable_disable_global_service_events ${CLOUDTRAIL_TRAIL_NAME} ${INCLUDE_GLOBAL_SERVICE_EVENTS} ;;

    		2)  clr ; cloudtrail_enable_disable_multi_region_trail ${CLOUDTRAIL_TRAIL_NAME} ${IS_MULTI_REGION_TRAIL} ;;

            3)  clr ; cloudtrail_enable_disable_log_file_validation_enabled ${CLOUDTRAIL_TRAIL_NAME} ${LOG_FILE_VALIDATION_ENABLED} ;;
                
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

######################################################################
#                                                                    #
#                        CLOUDWATCH MENU SECTION                     #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: cloudwatch_alarms_menu
# Purpose:  Used to display the cloudwatch alarms menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudwatch_alarms_menu {
    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "CloudWatch Alarms"
        
        VPC_CHANGES=`jq -e 'any(.MetricAlarms[]; .AlarmName == "vpc_changes")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        SECURITY_GROUP_CHANGES=`jq -e 'any(.MetricAlarms[]; .AlarmName == "security_group_changes")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        S3_BUCKET_CHANGES=`jq -e 'any(.MetricAlarms[]; .AlarmName == "s3_bucket_changes")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        ROUTE_TABLE_CHANGES=`jq -e 'any(.MetricAlarms[]; .AlarmName == "route_table_changes")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        ROOT_USAGE=`jq -e 'any(.MetricAlarms[]; .AlarmName == "root_usage")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        NETWORK_ACL_CHANGES=`jq -e 'any(.MetricAlarms[]; .AlarmName == "network_acl_changes")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        INTERNET_GATEWAY_CHANGES=`jq -e 'any(.MetricAlarms[]; .AlarmName == "internet_gateway_changes")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        EC2_INSTANCE_CHANGES=`jq -e 'any(.MetricAlarms[]; .AlarmName == "ec2_instance_changes")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        EC2_LARGE_INSTANCE_CHANGES=`jq -e 'any(.MetricAlarms[]; .AlarmName == "ec2_large_instance_changes")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        FAILED_CONSOLE_LOGINS=`jq -e 'any(.MetricAlarms[]; .AlarmName == "failed_console_logins")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        NO_MFA_CONSOLE_LOGINS=`jq -e 'any(.MetricAlarms[]; .AlarmName == "no_mfa_console_logins")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        DISABLED_DELETED_CMKS=`jq -e 'any(.MetricAlarms[]; .AlarmName == "disabled_deleted_cmks")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        CLOUDTRAIL_CHANGES=`jq -e 'any(.MetricAlarms[]; .AlarmName == "cloudtrail_changes")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        CONFIG_CHANGES=`jq -e 'any(.MetricAlarms[]; .AlarmName == "config_changes")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`
        UNAUTHORIZED_API_CALLS=`jq -e 'any(.MetricAlarms[]; .AlarmName == "unauthorized_api_calls")' <<<"$JSON_CLOUDWATCH_DESCRIBE_ALARMS"`

        if [ -n "$DEBUG" ]; then
            echo "        VPC_CHANGES: ${VPC_CHANGES}"
            echo "        SECURITY_GROUP_CHANGES: ${SECURITY_GROUP_CHANGES}"
            echo "        S3_BUCKET_CHANGES: ${S3_BUCKET_CHANGES}"
            echo "        ROUTE_TABLE_CHANGES: ${ROUTE_TABLE_CHANGES}"
            echo "        ROOT_USAGE: ${ROOT_USAGE}"
            echo "        NETWORK_ACL_CHANGES: ${NETWORK_ACL_CHANGES}"
            echo "        INTERNET_GATEWAY_CHANGES: ${INTERNET_GATEWAY_CHANGES}"
            echo "        EC2_INSTANCE_CHANGES: ${EC2_INSTANCE_CHANGES}"
            echo "        EC2_LARGE_INSTANCE_CHANGES: ${EC2_LARGE_INSTANCE_CHANGES}"
            echo "        FAILED_CONSOLE_LOGINS: ${FAILED_CONSOLE_LOGINS}"
            echo "        NO_MFA_CONSOLE_LOGINS: ${NO_MFA_CONSOLE_LOGINS}"
            echo "        DISABLED_DELETED_CMKS: ${DISABLED_DELETED_CMKS}"
            echo "        CLOUDTRAIL_CHANGES: ${CLOUDTRAIL_CHANGES}"
            echo "        CONFIG_CHANGES: ${CONFIG_CHANGES}"
            echo "        UNAUTHORIZED_API_CALLS: ${UNAUTHORIZED_API_CALLS}"
            echo ""
        fi

        if [[ "$VPC_CHANGES" == "true" ]]; then
            print_compliance_line 1 vpc_changes VPC_CHANGES pass
        else
            print_compliance_line 1 vpc_changes VPC_CHANGES fail
        fi

        if [[ "$SECURITY_GROUP_CHANGES" == "true" ]]; then
            print_compliance_line 2 security_group_changes SECRITY_GROUP_CHANGES pass
        else
            print_compliance_line 2 security_group_changes SECRITY_GROUP_CHANGES fail
        fi

        if [[ "$S3_BUCKET_CHANGES" == "true" ]]; then
            print_compliance_line 3 s3_bucket_changes S3_BUCKET_CHANGES pass
        else
            print_compliance_line 3 s3_bucket_changes S3_BUCKET_CHANGES fail
        fi

        if [[ "$ROUTE_TABLE_CHANGES" == "true" ]]; then
            print_compliance_line 4 route_table_changes ROUTE_TABLE_CHANGES pass
        else
            print_compliance_line 4 route_table_changes ROUTE_TABLE_CHANGES fail
        fi

        if [[ "$ROOT_USAGE" == "true" ]]; then
            print_compliance_line 5 root_usage ROOT_USAGE pass
        else
            print_compliance_line 5 root_usage ROOT_USAGE fail
        fi

        if [[ "$NETWORK_ACL_CHANGES" == "true" ]]; then
            print_compliance_line 6 network_acl_changes NETWORK_ACL_CHANGES pass
        else
            print_compliance_line 6 network_acl_changes NETWORK_ACL_CHANGES fail
        fi

        if [[ "$INTERNET_GATEWAY_CHANGES" == "true" ]]; then
            print_compliance_line 7 internet_gateway_changes INTERNET_GATEWAY_CHANGES pass
        else
            print_compliance_line 7 internet_gateway_changes INTERNET_GATEWAY_CHANGES fail
        fi

        if [[ "$EC2_INSTANCE_CHANGES" == "true" ]]; then
            print_compliance_line 8 ec2_instance_changes EC2_INSTANCE_CHANGES pass
        else
            print_compliance_line 8 ec2_instance_changes EC2_INSTANCE_CHANGES fail
        fi

        if [[ "$EC2_LARGE_INSTANCE_CHANGES" == "true" ]]; then
            print_compliance_line 9 ec2_large_instance_changes EC2_LARGE_INSTANCE_CHANGES pass
        else
            print_compliance_line 9 ec2_large_instance_changes EC2_LARGE_INSTANCE_CHANGES fail
        fi

        if [[ "$FAILED_CONSOLE_LOGINS" == "true" ]]; then
            print_compliance_line 10 failed_console_logins FAILED_CONSOLE_LOGINS pass
        else
            print_compliance_line 10 failed_console_logins FAILED_CONSOLE_LOGINS fail
        fi

        if [[ "$NO_MFA_CONSOLE_LOGINS" == "true" ]]; then
            print_compliance_line 11 no_mfa_console_logins NO_MFA_CONSOLE_LOGINS pass
        else
            print_compliance_line 11 no_mfa_console_logins NO_MFA_CONSOLE_LOGINS fail
        fi
        
        if [[ "$DISABLED_DELETED_CMKS" == "true" ]]; then
            print_compliance_line 12 disabled_deleted_cmks DISABLED_DELETED_CMKS pass
        else
            print_compliance_line 12 disabled_deleted_cmks DISABLED_DELETED_CMKS fail
        fi

        if [[ "$CLOUDTRAIL_CHANGES" == "true" ]]; then
            print_compliance_line 13 cloudtrail_changes CLOUDTRAIL_CHANGES pass
        else
            print_compliance_line 13 cloudtrail_changes CLOUDTRAIL_CHANGES fail
        fi

        if [[ "$CONFIG_CHANGES" == "true" ]]; then
            print_compliance_line 14 config_changes CONFIG_CHANGES pass
        else
            print_compliance_line 14 config_changes CONFIG_CHANGES fail
        fi

        if [[ "$UNAUTHORIZED_API_CALLS" == "true" ]]; then
            print_compliance_line 15 unauthorized_api_calls UNAUTHORIZED_API_CALLS pass
        else
            print_compliance_line 15 unauthorized_api_calls UNAUTHORIZED_API_CALLS fail
        fi

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            1) cloudwatch_vpc_changes_alarm "vpc_changes" ;;

            2) cloudwatch_security_group_changes_alarm "security_group_changes" ;;

            3) cloudwatch_s3_bucket_changes_alarm "s3_bucket_changes" ;;

            4) cloudwatch_route_table_changes_alarm "route_table_changes" ;;

            5) cloudwatch_root_usage_alarm "root_usage" ;;

            6) cloudwatch_network_acl_changes_alarm "network_acl_changes" ;;

            7) cloudwatch_internet_gateway_changes_alarm "internet_gateway_changes" ;;

            8) cloudwatch_ec2_instance_changes_alarm "ec2_instance_changes" ;;

            9) cloudwatch_ec2_large_instance_changes_alarm "ec2_large_instance_changes" ;;

            10) cloudwatch_failed_console_logins_alarm "failed_console_logins" ;;

            11) cloudwatch_no_mfa_console_logins_alarm "no_mfa_console_logins" ;;

            12) cloudwatch_disabled_deleted_cmks_alarm "disabled_deleted_cmks" ;;

            13) cloudwatch_cloudtrail_changes_alarm "cloudtrail_changes" ;;

            14) cloudwatch_config_changes_alarm "config_changes" ;;

            15) cloudwatch_unauthorized_api_calls_alarm "unauthorized_api_calls" ;;
            
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

######################################################################
#                                                                    #
#                           ELB MENU SECTION                         #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: elb_load_balancers_menu
# Purpose:  Used to display the elb load balancers menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function elb_load_balancers_menu {
    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "ELB Load Balancers"
        
        for ELB_LOAD_BALANCER_NAME in "${ELB_LOAD_BALANCER_NAMES[@]}"
        do
            padding $MENU_ITEM"." 4 " " ${ELB_LOAD_BALANCER_NAME}
			MENU_ITEM=`expr $MENU_ITEM + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            [1-9]|[1-9][0-9]) if [ $OPTION -gt ${#ELB_LOAD_BALANCER_NAMES[@]} ]; then continue; else elb_load_balancer_menu ${ELB_LOAD_BALANCER_NAMES[$OPTION-1]}; fi ;;
            
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

#----------------------------------------------------------------------
# Function: elb_load_balancer_menu
# Purpose:  Used to display the elb load balancer menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function elb_load_balancer_menu {
    
    ELB_LOAD_BALANCER_NAME=$1

    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "ELB Load Balancer - ${ELB_LOAD_BALANCER_NAME}"
        
        echo ""

        ### Turn off cursor
        tput civis
            
        ### Start the loading animation in background and grab the pid
        start_daemon "        Fetching configuration for ELB Load Balancer - ${ELB_LOAD_BALANCER_NAME}. Please wait"
    
        ### Fetch the JSON object for elb
        JSON_ELB_DESCRIBE_LOAD_BALANCER_ATTRIBUTES=`aws elb describe-load-balancer-attributes --load-balancer-name ${ELB_LOAD_BALANCER_NAME}${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    
        ### End the loading animation
        end_daemon "        Fetching configuration for ELB Load Balancer - ${ELB_LOAD_BALANCER_NAME}. Done          "

        ### Turn on cursor
        tput cnorm

        ACCESS_LOG_ENABLED=`jq -r ".LoadBalancerAttributes | .AccessLog | .Enabled" <<<"$JSON_ELB_DESCRIBE_LOAD_BALANCER_ATTRIBUTES"`
        
        clear
        print_menu_header "ELB Load Balancer - ${ELB_LOAD_BALANCER_NAME}"
        
        if [ -n "$DEBUG" ]; then
            echo "        ACCESS_LOG_ENABLED: ${ACCESS_LOG_ENABLED}"
            echo ""
        fi

        if [ "$ACCESS_LOG_ENABLED" == "false" ]; then
            print_compliance_line 1 AccessLog ACCESS_LOG_ENABLED fail
        else
            print_compliance_line 1 AccessLog ACCESS_LOG_ENABLED pass
        fi

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            1)  clr ; elb_enable_disable_access_log_enabled ${ELB_LOAD_BALANCER_NAME} ${ACCESS_LOG_ENABLED} ;;

            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

######################################################################
#                                                                    #
#                          ELBv2 MENU SECTION                        #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: elbv2_load_balancers_menu
# Purpose:  Used to display the elbv2 load balancers menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function elbv2_load_balancers_menu {
    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "ELBv2 Load Balancers"
        
        for ELBV2_LOAD_BALANCER_NAME in "${ELBV2_LOAD_BALANCER_NAMES[@]}"
        do
            padding $MENU_ITEM"." 4 " " ${ELBV2_LOAD_BALANCER_NAME}
			MENU_ITEM=`expr $MENU_ITEM + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            [1-9]|[1-9][0-9]) if [ $OPTION -gt ${#ELBV2_LOAD_BALANCER_NAMES[@]} ]; then continue; else elbv2_load_balancer_menu ${ELBV2_LOAD_BALANCER_NAMES[$OPTION-1]}; fi ;;
            
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

#----------------------------------------------------------------------
# Function: elbv2_load_balancer_menu
# Purpose:  Used to display the elbv2 load balancer menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function elbv2_load_balancer_menu {
    
    ELBV2_LOAD_BALANCER_NAME=$1

    ELBV2_LOAD_BALANCER_ARN=`jq -r ".LoadBalancers[] | select (.LoadBalancerName == \"${ELBV2_LOAD_BALANCER_NAME}\") | .LoadBalancerArn" <<<"$JSON_ELBV2_DESCRIBE_LOAD_BALANCERS"`

    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "ELB Load Balancer - ${ELBV2_LOAD_BALANCER_NAME}"
        
        echo ""

        ### Turn off cursor
        tput civis
            
        ### Start the loading animation in background and grab the pid
        start_daemon "        Fetching configuration for ELBv2 Load Balancer - ${ELBV2_LOAD_BALANCER_NAME}. Please wait"
    
        ### Fetch the JSON object for elb
        JSON_ELBV2_DESCRIBE_LOAD_BALANCER_ATTRIBUTES=`aws elbv2 describe-load-balancer-attributes --load-balancer-arn ${ELBV2_LOAD_BALANCER_ARN}${AWS_PROFILE_ARG} --region ${AWS_REGION}`
    
        ### End the loading animation
        end_daemon "        Fetching configuration for ELBv2 Load Balancer - ${ELBV2_LOAD_BALANCER_NAME}. Done          "

        ### Turn on cursor
        tput cnorm

        ACCESS_LOG_S3_ENABLED=`jq -r ".Attributes[] | select (.Key == \"access_logs.s3.enabled\") | .Value" <<<"$JSON_ELBV2_DESCRIBE_LOAD_BALANCER_ATTRIBUTES"`
        DELETION_PROTECTION_ENABLED=`jq -r ".Attributes[] | select (.Key == \"deletion_protection.enabled\") | .Value" <<<"$JSON_ELBV2_DESCRIBE_LOAD_BALANCER_ATTRIBUTES"`
        
        clear
        print_menu_header "ELB Load Balancer - ${ELBV2_LOAD_BALANCER_NAME}"

        if [ -n "$DEBUG" ]; then
            echo "        ELBV2_LOAD_BALANCER_ARN: ${ELBV2_LOAD_BALANCER_ARN}"
            echo "        ACCESS_LOG_S3_ENABLED: ${ACCESS_LOG_S3_ENABLED}"
            echo ""
        fi

        if [ "$ACCESS_LOG_S3_ENABLED" == "false" ]; then
            print_compliance_line 1 access_logs.s3.enabled ACCESS_LOG_S3_ENABLED fail
        else
            print_compliance_line 1 access_logs.s3.enabled ACCESS_LOG_S3_ENABLED pass
        fi

        if [ "$DELETION_PROTECTION_ENABLED" == "false" ]; then
            print_compliance_line 2 deletion_protection.enabled DELETION_PROTECTION_ENABLED fail
        else
            print_compliance_line 2 deletion_protection.enabled DELETION_PROTECTION_ENABLED pass
        fi

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            1)  clr ; elbv2_enable_disable_access_log_s3_enabled ${ELBV2_LOAD_BALANCER_NAME} ${ACCESS_LOG_S3_ENABLED} ;;

            2)  clr ; elbv2_enable_disable_deletion_protection_enabled ${ELBV2_LOAD_BALANCER_NAME} ${DELETION_PROTECTION_ENABLED} ;;

            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

######################################################################
#                                                                    #
#                       API GATEWAY MENU SECTION                     #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: apigateway_clusters_menu
# Purpose:  Used to display the api gateway clusters menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function apigateway_clusters_menu {
    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "API Gateway Clusters"
        
        for APIGATEWAY_REST_API_NAME in "${APIGATEWAY_REST_API_NAMES[@]}"
        do
            padding $MENU_ITEM"." 4 " " ${APIGATEWAY_REST_API_NAME}
			MENU_ITEM=`expr $MENU_ITEM + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            [1-9]|[1-9][0-9]) if [ $OPTION -gt ${#APIGATEWAY_REST_API_NAMES[@]} ]; then continue; else apigateway_cluster_menu ${APIGATEWAY_REST_API_NAMES[$OPTION-1]} ${APIGATEWAY_REST_API_IDS[$OPTION-1]}; fi ;;
            
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

#----------------------------------------------------------------------
# Function: apigateway_cluster_menu
# Purpose:  Used to display the api gateway cluster menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function apigateway_cluster_menu {

    APIGATEWAY_REST_API_NAME=$1
    APIGATEWAY_REST_API_ID=$2

    while true ; do
        MENU_ITEM=1

        clear
        print_menu_header "API Gateway Cluster - ${APIGATEWAY_REST_API_NAME}"
        
        echo "
            1. Stages Certificates

          
          




        "
        ### Print footer
        print_menu_footer

        read OPTION

    	case $OPTION in

    		''|[Bb]|[Bb]ack) break ;;

    		1)  clr ; apigateway_cluster_certificate_menu ${APIGATEWAY_REST_API_NAMES[$OPTION-1]} ${APIGATEWAY_REST_API_IDS[$OPTION-1]} ;;

            [EeQq]|[Ee]xit|[Qq]uit) echo "\n" ; exit ;;

            *)  clr ; wr_err "  Invalid option! ==> $OPTION" ;;

	    esac

    done
}

#----------------------------------------------------------------------
# Function: apigateway_cluster_certificate_menu
# Purpose:  Used to display the api gateway cluster certificate 
#           menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function apigateway_cluster_certificate_menu {

    APIGATEWAY_REST_API_NAME=$1
    APIGATEWAY_REST_API_ID=$2

    if [[ "$DEBUG" == "true" ]]; then
        echo "APIGATEWAY_REST_API_NAME: ${APIGATEWAY_REST_API_NAME}"
        echo "APIGATEWAY_REST_API_ID: ${APIGATEWAY_REST_API_ID}"
        echo ""
        echo "aws apigateway get-stages --rest-api-id ${APIGATEWAY_REST_API_ID}${AWS_PROFILE_ARG} --region ${AWS_REGION}"
        sleep 2
    fi

    while true ; do
        MENU_ITEM=1

        clear
        print_menu_header "API Gateway Cluster Stages Certificate- ${APIGATEWAY_REST_API_NAME}"
        
        echo ""

        ### Turn off cursor
        tput civis
            
        ### Start the loading animation in background and grab the pid
        start_daemon "        Fetching configuration for API Gateway Cluster - ${APIGATEWAY_REST_API_NAME}. Please wait"
    
        ### Fetch the JSON object for apigateway
        JSON_APIGATEWAY_GET_STAGES=`aws apigateway get-stages --rest-api-id ${APIGATEWAY_REST_API_ID}${AWS_PROFILE_ARG} --region ${AWS_REGION}`

        ### End the loading animation
        end_daemon "        Fetching configuration for ELBv2 Load Balancer - ${ELBV2_LOAD_BALANCER_NAME}. Done          "

        ### Turn on curs
        
        clear
        print_menu_header "API Gateway Cluster - ${APIGATEWAY_REST_API_NAME}"

        JSON_APIGATEWAY_STAGE_NAMES=`jq -r ".item[] | .stageName" <<<"$JSON_APIGATEWAY_GET_STAGES"`

        ### Get the certificate for each stage
        for JSON_APIGATEWAY_STAGE_NAME in ${JSON_APIGATEWAY_STAGE_NAMES[@]}; do
            
            ### Fetch the JSON object for stage
            CLIENT_CERTIFICATE_ID=`jq -r ".item[] | select (.stageName == \"${JSON_APIGATEWAY_GET_STAGE_NAME}\") | .clientCertificateId" <<<"${JSON_APIGATEWAY_GET_STAGES}"`

            if [ "$CLIENT_CERTIFICATE_ID" == "" ]; then
                print_compliance_line ${MENU_ITEM} ${JSON_APIGATEWAY_STAGE_NAME} CLIENT_CERTIFICATE_ID fail
            else
                print_compliance_line ${MENU_ITEM} ${JSON_APIGATEWAY_STAGE_NAME} CLIENT_CERTIFICATE_ID pass
            fi
            MENU_ITEM=`expr $MENU_ITEM + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

######################################################################
#                                                                    #
#                           ASG MENU SECTION                         #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: asg_auto_scaling_groups_menu
# Purpose:  Used to display the asg auto scaling groups menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function asg_auto_scaling_groups_menu {
    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "ASG Auto Scalin Groups"
        
        for ASG_AUTO_SCALING_GROUP_NAME in "${ASG_AUTO_SCALING_GROUP_NAMES[@]}"
        do
            padding $MENU_ITEM"." 4 " " ${ASG_AUTO_SCALING_GROUP_NAME}
			MENU_ITEM=`expr $MENU_ITEM + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            [1-9]|[1-9][0-9]) if [ $OPTION -gt ${#ASG_AUTO_SCALING_GROUP_NAMES[@]} ]; then continue; else asg_auto_scaling_group_menu ${ASG_AUTO_SCALING_GROUP_NAMES[$OPTION-1]}; fi ;;
            
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

######################################################################
#                                                                    #
#                       CLOUDFRONT MENU SECTION                      #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: cloudfront_distributions_menu
# Purpose:  Used to display the cloudfront distributions menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function cloudfront_distributions_menu {
    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "CloudFront Distributions"
        
        for CLOUDFRONT_DISTRIBUTION_ID in "${CLOUDFRONT_DISTRIBUTION_IDS[@]}"
        do
            padding $MENU_ITEM"." 4 " " ${CLOUDFRONT_DISTRIBUTION_ID}
			MENU_ITEM=`expr $MENU_ITEM + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            [1-9]|[1-9][0-9]) if [ $OPTION -gt ${#CLOUDFRONT_DISTRIBUTION_IDS[@]} ]; then continue; else cloudfront_distribution_menu ${CLOUDFRONT_DISTRIBUTION_IDS[$OPTION-1]}; fi ;;
            
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

######################################################################
#                                                                    #
#                        DYNAMODB MENU SECTION                       #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: dynamodb_tables_menu
# Purpose:  Used to display the dynamodb tables menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function dynamodb_tables_menu {
    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "DynamoDB Tables"
        
        for DYNAMODB_TABLE_NAME in "${DYNAMODB_TABLE_NAMES[@]}"
        do
            padding $MENU_ITEM"." 4 " " ${DYNAMODB_TABLE_NAME}
			MENU_ITEM=`expr $MENU_ITEM + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            [1-9]|[1-9][0-9]) if [ $OPTION -gt ${#DYNAMODB_TABLE_NAMES[@]} ]; then continue; else dynamodb_table_menu ${DYNAMODB_TABLE_NAMES[$OPTION-1]}; fi ;;
            
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

######################################################################
#                                                                    #
#                      ELASTICACHE MENU SECTION                      #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: elasticache_cache_clusters_menu
# Purpose:  Used to display the elasticache clusters menu.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function elasticache_cache_clusters_menu {
    while true ; do

        MENU_ITEM=1

        clear
        print_menu_header "ElastiCache Cache Clusters"
        
        for ELASTICACHE_CACHE_CLUSTER_ID in "${ELASTICACHE_CACHE_CLUSTER_IDS[@]}"
        do
            padding $MENU_ITEM"." 4 " " ${ELASTICACHE_CACHE_CLUSTER_ID}
			MENU_ITEM=`expr $MENU_ITEM + 1`
        done

        ### Print footer
        print_menu_footer

        read OPTION

        case $OPTION in

            [1-9]|[1-9][0-9]) if [ $OPTION -gt ${#ELASTICACHE_CACHE_CLUSTER_IDS[@]} ]; then continue; else elasticache_cache_cluster_menu ${ELASTICACHE_CACHE_CLUSTER_IDS[$OPTION-1]}; fi ;;
            
            ''|[Bb]|[Bb]ack) break ;;
	
            [Mm]|[Mm]ain) clr ; main_menu ;;

            [EeQq]|[Ee]xit) echo "\n" ; exit ;;

            *)  clr ; wr_err "Invalid option! ==> $OPTION" ;;

        esac
    done
}

######################################################################
#                                                                    #
#                           COMMAND SECTION                          #
#                                                                    #
######################################################################

### Function to run command
function run_command
{
    eval "${1}${SUFFIX}"
    if [ $? -ne 0 ]; then
        print_error ${2} ${1}
    fi
}

######################################################################
#                                                                    #
#                           OUTPUT SECTION                           #
#                                                                    #
######################################################################
#----------------------------------------------------------------------
# Function: print_menu_header
# Purpose:  Used to print menu header.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function print_menu_header
{
    MENU_TITLE=$1

    if [[ "$MENU_TITLE" == "" ]]; then
        MENU_TITLE="Initializing"
    fi

    echo -e "${CYAN}
        OS: ${OS_FULL_NAME} ${OS_VERSION}                         AWS Compliance Script (v${AWS_COMPLIANCE_VERSION})
                  - ${RESET_FORMATTING}${WHITE}${MENU_TITLE}${RESET_FORMATTING}${CYAN}
        Profile: [${AWS_PROFILE}]    Region: [${AWS_REGION}]    Account: [${STS_ACCOUNT}]
        -------------------------------------------------------------------------------${RESET_FORMATTING}
        "
}

#----------------------------------------------------------------------
# Function: print_menu_footer
# Purpose:  Used to print menu footer.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function print_menu_footer {
    echo "     

            
               
			
        B. Back to previous menu         E. Exit         M. Main Menu

        ${MAGENTA}Please enter option [B] :  ${RESET_FORMATTING}\c"
}

#----------------------------------------------------------------------
# Function: print_compliance_line
# Purpose:  Used to display compliances and to show their states.
# Args:     compliance_no, compliance name, compliance value and compliance state.
# Returns:  null 
#----------------------------------------------------------------------
function print_compliance_line {
    COMPLIANCE_NO=$1
    COMPLIANCE_NAME=$2
    COMPLIANCE_VALUE=$3
    COMPLIANCE_STATE=$4

    COMPLIANCE_NO_LENGTH=${#COMPLIANCE_NO}
    COMPLIANCE_NAME_LENGTH=${#COMPLIANCE_NAME}

    DOTS=""
	COUNT=0
	MAX=60
	DEFLENGTH=44
	let LOOPS=$DEFLENGTH-$COMPLIANCE_NO_LENGTH-$COMPLIANCE_NAME_LENGTH
        
        while [  $COUNT -lt "$LOOPS" ]; do
		DOTS=$DOTS"."
		let COUNT=COUNT+1
	done

    if [ "$COMPLIANCE_STATE" == "fail" ]; then
        print "${COMPLIANCE_NO}. ${COMPLIANCE_NAME} $DOTS...... ${RED}Fail!${RESET_FORMATTING}\n"
    else
        print "${COMPLIANCE_NO}. ${COMPLIANCE_NAME} $DOTS...... ${GREEN}Pass!${RESET_FORMATTING}\n"
    fi
}

#----------------------------------------------------------------------
# Function: clr
# Purpose:  Used to clear screen.
# Args:     none.
# Returns:  null 
#----------------------------------------------------------------------
function clr { clear; echo; }

#----------------------------------------------------------------------
# Function: to_lower
# Purpose:  Used to make text lower case.
# Args:     string containing text to convert.
# Returns:  an echo of text in lower case
#----------------------------------------------------------------------
function to_lower() {
  echo $1 | tr "[:upper:]" "[:lower:]" 
} 

#----------------------------------------------------------------------
# Function: to_upper
# Purpose:  Used to make text upper case.
# Args:     string containing text to convert.
# Returns:  an echo of text in upper case
#----------------------------------------------------------------------
function to_upper() {
  echo $1 | tr "[:lower:]" "[:upper:]" 
} 

#----------------------------------------------------------------------
# Function: wr_err
# Purpose:  Used to write either an error message or to ask user to press enter.
# Args:     string containing text to display.
# Returns:  an echo of text that needs to be removed by pressing Enter.
#----------------------------------------------------------------------
function wr_err {
    [ "$1" ] && echo "\n"
    for ERR in "$@"
    do
        echo "        ${RED}$ERR${RESET_FORMATTING}\n"
    done
    if [ "$1" ]
    then echo "\a        ${CYAN}Press Enter to continue... ${RESET_FORMATTING}\c"
    else echo "\n        ${CYAN}Press Enter to continue... ${RESET_FORMATTING}\c"
    fi
    read RESP
    echo
}

#----------------------------------------------------------------------
# Function: prompt
# Purpose:  Used to ask a yes/no question and evaluating the response.
# Args:     string containing text to display, and the default choice.
# Returns:  an echo displaying text and waiting for input by user.
#----------------------------------------------------------------------
function prompt {
    # parameters passed are 'screen message' 'variable' ['default']
    if [ "$3" ]
    then echo "\n        $1 [$3] :  \c"
    else echo "\n        $1 :  \c"
    fi
    read ANSWER
    case $ANSWER in
    '') [ "$3" ] && eval $2=\"\$3\" ;;
    *)  eval $2=\"\$ANSWER\" ;;
    esac
}

#----------------------------------------------------------------------
# Function: print
# Purpose:  Used to write formated text to screen.
# Args:     string containing text to display.
# Returns:  an echo of the formated text.
#----------------------------------------------------------------------
function print {
	echo "\n        $1\c"
}

#----------------------------------------------------------------------
# Function: confirm
# Purpose:  Used to ask user to press Enter to continue.
# Args:     null.
# Returns:  an echo asking user to press Enter. 
#----------------------------------------------------------------------
function confirm {
	print "Press Enter to continue..." ; read ; echo
}

#----------------------------------------------------------------------
# Function: is_number
# Purpose:  Used to verify that argument is a number.
# Args:     value to be verified as number.
# Returns:  1 on true and 0 on false.
#----------------------------------------------------------------------
function is_number {
	NUM=$1
	
	expr $NUM + 1 2> /dev/null
	if [ $? = 0 ]
	then
		return 1
	else
		return 0
	fi
}

#----------------------------------------------------------------------
# Function: is_selected
# Purpose:  Used to output brackets around a selected item and spaces 
#           around otherwise.
# Args:     value to be selected, value to be compared too
# Returns:  "[$1]"" if true otherwise " $1 "
#----------------------------------------------------------------------
function is_selected {
    if [[ "$1" == "$2" ]]; then
        echo "["${1}"]"
    else
        echo " "${1}" "
    fi
}

#----------------------------------------------------------------------
# Function: padding
# Purpose:  Used to add X chars of padding between two entities.
# Args:     $BEGINNING, $LENGTH, $PADDING_CHAR, $END.
# Returns:  $STRING 
#----------------------------------------------------------------------
function padding {

	BEGINNING=$1
	LENGTH=$2
	PADDING_CHAR=$3
	END=$4
	
	BEGINNING_LENGTH=${#BEGINNING}
	
	PADDING=$(loop_padding ${LENGTH} ${BEGINNING_LENGTH} ${PADDING_CHAR})
	
	echo "		${BEGINNING}${PADDING}${END}"
}

#----------------------------------------------------------------------
# Function: number_padding
# Purpose:  Used to add X spaces of padding after a number.
# Args:     Number to be padded.
# Returns:  $STRING 
#----------------------------------------------------------------------
function number_padding {
    if [ $1 -gt 99 ]; then
        echo " "
    elif [ $1 -gt 9 ]; then
        echo "  "
    else
        echo "   "
    fi
}

#----------------------------------------------------------------------
# Function: loop_padding
# Purpose:  Used to add X chars of padding.
# Args:     Number to be padded.
# Returns:  $STRING 
#----------------------------------------------------------------------
function loop_padding {
    COUNT=0
    LOOP_PADDING=""
    let LOOPS=$1-$2
    while [  $COUNT -lt "$LOOPS" ]; do
		LOOP_PADDING=${LOOP_PADDING}${3}
		let COUNT=COUNT+1 
	done
    echo "${LOOP_PADDING}"
}

#----------------------------------------------------------------------
# Function: start_daemon
# Purpose:  Used to background process.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function start_daemon
{
    ### Start the loading animation in background and grab the pid
    if [ "${VERBOSE}" == "false" ]; then
        show_loading "${YELLOW}${1}" &
        PID=$!
    else
        print_line "${YELLOW}${1}...${RESET_FORMATTING}" 0 1
    fi
}

#----------------------------------------------------------------------
# Function: end_daemon
# Purpose:  Used to foreground process.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function end_daemon
{
    if [ "${VERBOSE}" == "false" ]; then
        ### Kill the spinner
        kill ${PID}
        wait ${PID} 2>/dev/null

        ### Fix ending dots
        end_loading "${YELLOW}${1}"
    fi
}

#----------------------------------------------------------------------
# Function: show_loading
# Purpose:  Used to start loading animation.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function show_loading
{
    echo -ne "${1}\r"

    while [ 1 ]
    do
        echo -ne "${1}.\r"
        sleep 0.5
        echo -ne "${1}..\r"
        sleep 0.5
        echo -ne "${1}...\r"
        sleep 0.5
        echo -ne "\r\033[K"
        echo -ne "${1}\r"
        sleep 0.5
    done
}

#----------------------------------------------------------------------
# Function: end_loading
# Purpose:  Used to end loading animation.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function end_loading
{
    echo -ne "${1}\r${RESET_FORMATTING}"
}

#----------------------------------------------------------------------
# Function: print_line
# Purpose:  Used to print line with tabs.
# Args:     null
# Returns:  null 
#----------------------------------------------------------------------
function print_line
{
    ### Add tab level
    if [ -z ${2} ]; then
        SPACES=0
    else
        SPACES=${2}
    fi

    ### Add newline if needed
    if [[ -z ${3} || "$3" -eq 0 ]]; then
        NEWLINE=""
    else
        NEWLINE="\n"
    fi

    let TABS=${SPACES}*4
    LINE=$(printf  "%*s%s" ${TABS} '' "${1}")
    
    echo -e "${NEWLINE}${LINE}"
}

### Function to print error and line number for error
function print_error
{
    echo -e "${RED}Error - [${CURRENT_SCRIPT}:${1}] ${2}${RESET_FORMATTING}"
    #exit 1
}

### Function to print script usage
function print_usage
{
    ### We have future usage already set here too
    clear
    echo -e "\nUsage: ./${CURRENT_SCRIPT} [-p|--profile] [-r|--region] [-e|--email]"
    echo -e "\n    arguments:"
    echo -e "        -p|--profile [profile]       name of prifile (not required)"
    echo -e "        -r|--region [region]         name of region (not required)"
    echo -e "        -e|--email [email]           e-mail to use (not required)"
    echo -e "        -h|--help                    print this menu"

    exit 1
}

######################################################################
#                                                                    #
#                         SCRIPT ENTRY POINT                         #
#                                                                    #
######################################################################

while [ $# -gt 0 ]
do
    case "$1" in
        -p|--profile)
            shift
            AWS_PROFILE=$1
            shift
            ;;
        -r|--region)
            shift
            AWS_REGION=$1
            shift
            ;;
        -e|--email)
            shift
            EMAIL=$1
            shift
            ;;
        -d|--debug)
            shift
            DEBUG="true"
            ;;
        -s|--skip-resources)
            shift
            SKIP="true"
            ;;
    esac
done

### Announce DEBUG mode
if [[ "$DEBUG" == "true" ]]; then
    echo "DEBUG Mode Enabled!!!"
    sleep 2
fi
### Call main function
main

### Exit with good code
exit 0


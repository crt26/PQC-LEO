#!/bin/bash

# Copyright (c) 2023-2025 Callum Turino
# SPDX-License-Identifier: MIT

# This script automates the setup process for the PQC-evaluation-tools benchmarking suite. It provides options to build and configure
# the required libraries (Liboqs, OQS-Provider, and OpenSSL) and their dependencies. The script handles directory
# creation, dependency installation, library downloads, and builds. It also allows customisation of build options,
# such as enabling additional algorithms or modifying OpenSSL configurations. The script ensures compatibility
# with the system environment and provides user-friendly prompts for setup decisions.

#-------------------------------------------------------------------------------------------------------------------------------
# Declare the global main directory path variables
root_dir=$(pwd)
libs_dir="$root_dir/lib"
tmp_dir="$root_dir/tmp"
test_data_dir="$root_dir/test_data"
alg_lists_dir="$test_data_dir/alg_lists"
util_scripts="$root_dir/scripts/utility_scripts"

# Declare the global dependency library version variables
openssl_version="3.5.0"

# Declare the global library download URL variables
liboqs_download_url="https://github.com/open-quantum-safe/liboqs.git"
oqs_provider_download_url="https://github.com/open-quantum-safe/oqs-provider.git"
openssl_download_url="https://github.com/openssl/openssl/releases/download/openssl-3.5.0/openssl-3.5.0.tar.gz"

# Declare the global last tested version SHA variables
liboqs_tested_sha="b75bfb8c56d23a92227b04c096f0264b992de874"
oqs_provider_tested_sha="9a22bfb5e5c14a831419c1b10fbab08af5361a70"

# Declare the global library directory path variables
openssl_path="$libs_dir/openssl_$openssl_version"
liboqs_path="$libs_dir/liboqs"
oqs_provider_path="$libs_dir/oqs_provider"

# Declare the global source-code directory path variables
liboqs_source="$tmp_dir/liboqs_source"
oqs_provider_source="$tmp_dir/oqs_provider_source"
openssl_source="$tmp_dir/openssl_$openssl_version"

# Set the global flag variables
install_type=0 # 0=Liboqs-only, 1=Liboqs+OQS-Provider, 2=OQS-Provider-only
use_latest_version=0
user_defined_speed_flag=0
enable_hqc=0 # temp flag for hqc bug fix

#-------------------------------------------------------------------------------------------------------------------------------
function get_user_yes_no() {
    # Helper function for getting a yes or no response from the user for a given question regarding the setup process. The function
    # will return 0 for yes and 1 for no which can be checked by the calling function.

    # Set the local user prompt variable to what was passed to the function
    local user_prompt="$1"

    # Get the user input for the yes or no question
    while true; do

        # Output the question to the user and get their response
        read -p "$user_prompt (y/n): " user_input

        # Check the user input is valid and set the user response variable
        case $user_input in

            [Yy]* )
                user_y_n_response=1
                return 0
                ;;

            [Nn]* )
                user_y_n_response=0
                return 1
                ;;

            * )
                echo -e "Please answer y or n\n"
                ;;

        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function confirm_enable_hqc_algs() {
    # Temporary helper function for warning the user about the disabled HQC KEM algorithms as discussed in issue 
    # (https://github.com/crt26/pqc-evaluation-tools/issues/46). The function will display a security warning and provide 
    # background information about why HQC KEM algorithms are disabled by default in Liboqs. It then prompts the user to 
    # decide whether to proceed with enabling HQC for benchmarking purposes. This function will be removed in the future 
    # when Liboqs version 0.14.0 is released and the HQC KEM algorithms are re-enabled by default.

    # Output the current task and the warning message to the terminal
    echo -e "\nEnable HQC KEM Algorithms Flag Detected:\n"

    echo -e "[WARNING] - The Liboqs library disables HQC KEM algorithms by default due to a recently disclosed"
    echo -e "security vulnerability that compromises their IND-CCA2 security guarantees. Since this project's primary"
    echo -e "focus is benchmarking (not production deployment), HQC can be still be enabled for performance testing purposes.\n"

    echo -e "For more details, see:"
    echo -e "- Liboqs issue: https://github.com/open-quantum-safe/liboqs/issues/2118"
    echo -e "- pqc-evaluation-tools issue: https://github.com/crt26/pqc-evaluation-tools/issues/46\n"

    echo -e "Please note: Enabling HQC is done at your own risk. This project assumes no responsibility for"
    echo -e "any consequences that may result from using these algorithms.\n"

    # Determine if the user wishes to continue with enabling the HQC KEM algorithms
    get_user_yes_no "Would you like continue with enabling the HQC KEM algorithms in the Liboqs library?"

    # Check the user response and set the enable_hqc flag accordingly
    if [ "$user_y_n_response" -eq 1 ]; then
        echo -e "\n[NOTICE] - HQC KEM algorithms will be enabled in the Liboqs library build process\n"
        enable_hqc=1
    else
        echo -e "\n[NOTICE] - HQC KEM algorithms will not be enabled in the Liboqs library build process\n"
        enable_hqc=0
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function output_help_message() {
    # Helper function for outputting the help message to the user when the --help flag is present or when incorrect arguments are passed.

    # Output the supported options and their usage to the user
    echo "Usage: setup.sh [options]"
    echo "Options:"
    echo "  --latest-dependency-versions   Use the latest available versions of the OQS libraries (may cause compatibility issues)."
    echo "  --set-speed-new-value=[int]    Set a new value for MAX_KEM_NUM and MAX_SIG_NUM in OpenSSL's speed.c file."
    echo "  --enable-hqc-algs              Enable HQC KEM algorithms in liboqs (default: disabled due to security concerns)."
    echo "  --help                         Display this help message."

}

#-------------------------------------------------------------------------------------------------------------------------------
function parse_args() {
    # Function for parsing the command line arguments passed to the script. Based on the detected arguments, the function will 
    # set the relevant global flags that are used throughout the setup process.

    # Check if the help flag is passed at any position in the command line arguments
    if [[ "$*" =~ --help ]]; then
        output_help_message
        exit 0
    fi

    # Loop through the passed command line arguments and check for the supported options
    while [[ $# -gt 0 ]]; do

        # Check if the argument is a valid option, then shift to the next argument
        case "$1" in

            --latest-dependency-versions)

                # Output the warning message to the user and set the use_tested_version flag
                echo -e "\n[NOTICE] Using the latest version of the OQS libraries. This may lead to compatibility issues with this project."
                echo "If the latest upstream changes cause problems, please report them to this projects issue page."
                echo -e "You can re-run the setup script without this flag to use the last tested version of the libraries if issues occur.\n"

                # Determine if the user wishes to proceed with using the latest version
                get_user_yes_no "Would you like to continue with using the latest version of the OQS libraries?"

                # Check the user response and to determine the next steps
                if [ "$user_y_n_response" -eq 1 ]; then
                    echo -e "\n[NOTICE] - Using the latest version of the OQS libraries...\n"
                    use_latest_version=1
                else
                    echo -e "\n[NOTICE] - Using the last tested versions of the OQS libraries...\n"
                    use_latest_version=0
                fi

                shift
                ;;

            --set-speed-new-value=*)

                # Set the user-defined speed flag and value
                user_defined_speed_flag=1
                user_defined_speed_value="${1#*=}"

                # Ensure that the user-defined value is a valid integer if the user-defined speed flag is set
                if [ "$user_defined_speed_flag" -eq 1 ] && ! [[ "$user_defined_speed_value" =~ ^[0-9]+$ ]]; then
                    echo -e "[ERROR] - The user-defined speed value must be a valid integer, please verify the value and rerun the setup script\n"
                    output_help_message
                    exit 1
                fi

                shift
                ;;
            
            --enable-hqc-algs)
            
                # Call the helper function to confirm enabling the HQC algorithms
                confirm_enable_hqc_algs
                shift
                ;;

            *)

                # Output an error message if an unknown option is passed
                echo "[ERROR] - Unknown option: $1"
                output_help_message
                exit 1
                ;;

        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function configure_dirs() {
    # Function for creating the required directory structure for the automated tools alongside setting the root directory path tmp file.

    # Declare required directories array used in the directory check and creation
    required_dirs=("$libs_dir" "$oqs_provider_source" "$tmp_dir" "$test_data_dir" "$alg_lists_dir")

    # Set the default value for the previous install flag
    previous_install=0

    # Check if the dependency libraries have already been installed based on install type selected
    case $install_type in

        0)
            if [ -d "$liboqs_path" ]; then
                previous_install=1
            fi
            ;;

        1)
            if [ -d "$liboqs_path" ] || [ -d "$oqs_provider_path" ]; then
                previous_install=1
            fi
            ;;

        2)
            if [ -d "$oqs_provider_path" ]; then
                previous_install=1
            fi
            ;;

    esac

    # If a previous install is detected, get the user choice for reinstalling the dependency libraries
    if [ "$previous_install" -eq 1 ]; then

        # Output the warning message and get the user choice for reinstalling the libraries
        echo -e "\n[WARNING] - Previous Install Detected!!"
        get_user_yes_no "Would you like to reinstall the libraries?"

        # Continue with the setup or exit based on the user choice
        if [ "$user_y_n_response" -eq 1 ]; then
            echo -e "Deleting old files and reinstalling...\n"
        else
            echo "Will not reinstall, exiting setup script..."
            exit 0
        fi

    fi

    # Remove old directories depending on the install type selected
    for dir in "${required_dirs[@]}"; do
        
        # Check if directory exists and remove it for a clean install
        if [ -d "$dir" ]; then
            
            # If install type is 2, remove the old OQS-Provider install directory and not any existing Liboqs install directory
            if [ "$dir" == "$libs_dir" ] && [ "$install_type" -eq 2 ]; then
                rm -rf "$oqs_provider_path" && mkdir -p "$oqs_provider_path"

            elif [ "$dir" == "$tmp_dir" ] && [ "$install_type" -eq 2 ]; then 
                rm -rf "$oqs_provider_path"

            else
                rm -rf "$dir" && mkdir -p "$dir"
                
            fi

        else
            rm -rf "$dir" && mkdir -p "$dir"

        fi

    done

    # Create the hidden pqc_eval_dir_marker.tmp file that is used by the test scripts to determine the root directory path
    touch "$root_dir/.pqc_eval_dir_marker.tmp"

}

#-------------------------------------------------------------------------------------------------------------------------------
function configure_oqs_provider_build() {
    # Function for configuring the OQS-Provider build process based on if the user wishes to set optional build options. The 
    # function will then set the relevant build flags based on the user response.

    # Declare the default optional OQS-Provider build flag values
    oqs_enable_algs="false"
    oqs_enable_encoders="false"

    # Output the current task to the terminal
    echo -e "\nConfiguring Optional OQS-Provider Build Options:\n"

    # Determine if the user wishes to enable all disabled signature algorithms in the OQS-Provider library
    get_user_yes_no "Would you like to enable all the digital signature algorithms in the OQS-Provider library that are disabled by default?"

    # Set the enable_algs flag based on the user response to later be checked the OQS-Provider build function
    if [ "$user_y_n_response" -eq 1 ]; then
        oqs_enable_algs="true"
    else
        oqs_enable_algs="false"
    fi

    # Determine if the users wishes to enable the KEM encoders option in the OQS-Provider build
    get_user_yes_no "Would you like to enable the KEM encoders option in the OQS-Provider build?"

    # Set the OQS-Provider build flags based on the user response
    if [ "$oqs_enable_algs" == "true" ]; then
        encoder_flag="ON"
    else
        encoder_flag="OFF"
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function download_libraries() {
    # Function for Downloading the required dependency libraries (OpenSSL, Liboqs, OQS-Provider). Uses the latest or last-tested 
    # versions of the libraries based on if the --safe-setup command line argument has been passed to the setup script.

    # Output the current task to the terminal
    echo -e "\n##############################"
    echo "Downloading Required Libraries"
    echo -e "##############################\n"

    # Download OpenSSL 3.4.1 and extract it into the tmp directory
    wget -O "$tmp_dir/openssl_$openssl_version.tar.gz" "$openssl_download_url"
    tar -xf "$tmp_dir/openssl_$openssl_version.tar.gz" -C $tmp_dir
    rm "$tmp_dir/openssl_$openssl_version.tar.gz"

    # Ensure that the OpenSSL source directory is present before continuing
    if [ ! -d "$openssl_source" ]; then
        echo -e "\n[ERROR] - The OpenSSL source directory could not be found after downloading, please verify the installation and rerun the setup script"
        exit 1
    fi

    # Download the required version of the Liboqs library
    if [ "$user_opt" == "1" ] || [ "$user_opt" == "2" ]; then

        # Clone the Liboqs library repository based on the version needed
        if [ "$use_latest_version" -eq 0 ]; then

            # Clone Liboqs and checkout to the last tested version
            git clone "$liboqs_download_url" $liboqs_source
            cd "$liboqs_source" && git checkout "$liboqs_tested_sha"
            cd "$root_dir"

        elif [ "$use_latest_version" -eq 1 ]; then

            # Clone the latest version of the Liboqs library
            git clone https://github.com/open-quantum-safe/liboqs.git $liboqs_source

        else

            # Output an error message as the use_latest_version flag variable is not set correctly
            echo "[ERROR] - The use_latest_version flag variable is not set correctly, please verify the code in the setup.sh script"
            exit 1
        
        fi

        # Ensure that the Liboqs source directory is present before continuing
        if [ ! -d "$liboqs_source" ]; then
            echo -e "\n[ERROR] - The Liboqs source directory could not be found after downloading, please verify the installation and rerun the setup script"
            exit 1
        fi

    fi

    # Download the required version of the OQS-Provider library
    if [ "$user_opt" == "2" ] || [ "$user_opt" == "3" ]; then
        
        # Clone the OQS-Provider library repository based on the version needed
        if [ "$use_latest_version" -eq 0 ]; then

            # Clone OQS-Provider and checkout to the last tested version
            git clone "$oqs_provider_download_url" $oqs_provider_source >> /dev/null
            cd $oqs_provider_source && git checkout "$oqs_provider_tested_sha"
            cd $root_dir

        elif [ "$use_latest_version" -eq 1 ]; then

            # Clone the latest OQS-Provider version
            git clone https://github.com/open-quantum-safe/oqs-provider.git $oqs_provider_source >> /dev/null

        else

            # Output an error message as the use_tested_version flag variable is not set correctly
            echo "[ERROR] - The use_tested_version flag variable is not set correctly, please verify the code in the setup.sh script"
            exit 1
        
        fi

        # Ensure that the OQS-Provider source-code directory is present before continuing
        if [ ! -d "$oqs_provider_source" ]; then
            echo -e "\n[ERROR] - The OQS-Provider source directory could not be found after downloading, please verify the installation and rerun the setup script"
            exit 1
        fi

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function dependency_install() {
    # Function for checking and installing the required system dependencies needed for the projects functionality. The function will 
    # check for missing system packages and Python pip packages and install them if they are not present. Finally, the function will
    # call the download_libraries function used to get  the required dependency libraries (OpenSSL, Liboqs, OQS-Provider).

    # Output the current task to the terminal
    echo -e "\n############################"
    echo "Performing Dependency Checks"
    echo -e "############################\n"

    # Check for any missing dependency system packages
    echo "Checking System Packages Dependencies..."
    packages=(
        "git" "astyle" "cmake" "gcc" "ninja-build" "libssl-dev" "python3-pytest" "python3-pytest-xdist" 
        "unzip" "xsltproc" "doxygen" "graphviz" "python3"-yaml "valgrind" "libtool" "make" "net-tools" "python3-pip" "netcat-openbsd"
    )
    not_installed=()

    for package in "${packages[@]}"; do
        if ! dpkg -s "$package" >/dev/null 2>&1; then
            not_installed+=("$package")
        fi
    done

    # Install any of the missing dependency system packages
    if [[ ${#not_installed[@]} -ne 0 ]]; then
        sudo apt-get update && sudo apt-get upgrade -y
        sudo apt-get install -y "${not_installed[@]}"
    fi

    # Determine which Python pip packages are needing to be installed
    echo "Checking Python Dependencies..."
    required_pip_packages=("pandas" "jinja2" "tabulate")
    missing_pip_packages=()

    for package in "${required_pip_packages[@]}"; do
        if ! python3 -c "import $package" 2>/dev/null; then
            missing_pip_packages+=("$package")
        fi
    done

    # Check if any pip packages are missing before checking pip install functionality
    if [[ ${#missing_pip_packages[@]} -ne 0 ]]; then

        # Capture the output of the pip install for error checking
        pip_output=$(pip install 2>&1)
        exit_status=$?

        # Check if pip is functioning correctly and if the --break-system-packages flag is needed
        if [ "$exit_status" -ne 0 ]; then

            # Determine the cause of the pip failure
            if echo "$pip_output" | grep -q "error: externally-managed-environment"; then

                # Output the cause to the user and determine if they wish to use the --break-system-packages flag
                echo -e "\nNOTICE: This version of pip requires that either virtual environments be used or the packages be installed system-wide"
                echo -e "This project does not currently support automatic setup of virtual environments.\n"
                
                # Get the user choice for using the --break-system-packages flag or not
                while true; do

                    # Output the options for proceeding to the user
                    echo "Please select one of the following options to handle missing pip packages:"
                    echo "1. Use the --break-system-packages flag to install packages system-wide."
                    echo "2. Exit the setup script and manually install the required packages before retrying."

                    # Read in the user's response
                    read -p "Please Select from the above options (1/2): " user_input

                    # Determine the next action based on the user's response
                    case $user_input in

                        1 )

                            # Output the message to the user and set the PIP_BREAK_SYSTEM_PACKAGES flag
                            echo "Proceeding with system-wide installation using --break-system-packages..."
                            export PIP_BREAK_SYSTEM_PACKAGES=1
                            break
                            ;;

                        2 )

                            # Output the message to the user and exit the setup script
                            echo -e "\nExiting setup script, please handle the install of the following pip packages manually:"
                            echo "${missing_pip_packages[@]}"
                            exit 1
                            ;;

                        * )

                            # Output a warning message if the user input is invalid
                            echo -e "Invalid selection. Please enter 1 or 2.\n"
                            ;;

                    esac

                done

            elif echo "$pip_output" | grep -q 'ERROR: You must give at least one requirement to install (see "pip help install")'; then
                # No need to do anything as pip is functioning correctly, as it supports the installing to the local user installation
                # This check just makes sure that this expected error from the pip install is ignored and does get caught by the else statement
                :

            else

                # Output the error message to the user indicating that the error captured is not an expected error
                echo -e "\n[ERROR] - pip is not functioning correctly, please verify the installation and rerun the setup script"
                exit 1
            
            fi
        
        fi
        
        # Install the missing Python pip packages
        for package in "${missing_pip_packages[@]}"; do
            pip install "$package"
        done
    
    else
        echo "All required Python packages are installed and are accessible in the current environment"

    fi

    # Determine location of the system's Python binary
    if [ -x "$(command -v python3)" ]; then
        python_bin="python3" 
    else
        python_bin="python"
    fi

    echo "Dependency checks complete"

    # Downloading the required dependency libraries (OpenSSL, Liboqs, OQS-Provider)
    download_libraries

}

#-------------------------------------------------------------------------------------------------------------------------------
function set_new_speed_values() {
    # Helper function for setting the new values for the hardcoded MAX_KEM_NUM/MAX_SIG_NUM variables in the OpenSSL speed.c file

    # Set the passed function arguments to local variables
    local passed_filepath="$1"
    local passed_value="$2"

    # Modify the speed.c source code file to increase the MAX_KEM_NUM/MAX_SIG_NUM values
    sed -i "s/#define MAX_SIG_NUM [0-9]\+/#define MAX_SIG_NUM $new_value/g" "$passed_filepath"
    sed -i "s/#define MAX_KEM_NUM [0-9]\+/#define MAX_KEM_NUM $new_value/g" "$passed_filepath"

    # Ensure that the MAX_KEM_NUM/MAX_SIG_NUM values were successfully modified before continuing
    if ! grep -q "#define MAX_SIG_NUM $new_value" "$passed_filepath" || ! grep -q "#define MAX_KEM_NUM $new_value" "$passed_filepath"; then
        echo -e "\n[ERROR] - Modifying the MAX_KEM_NUM/MAX_SIG_NUM values in the speed.c file failed, please verify the setup and run a clean install"
        exit 1
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function modify_openssl_src() {
    # Function for modifying the source code of the OpenSSL s_speed tool (speed.c) to adjust the hardcoded MAX_KEM_NUM and MAX_SIG_NUM 
    # variables if the OQS-Provider library is being built with the enable all disabled algorithms flag.

    # Output the current task to the terminal
    echo -e "[NOTICE] - Enable all disabled OQS-Provider algorithms flag is set, modifying the OpenSSL speed.c file to adjust the MAX_KEM_NUM/MAX_SIG_NUM values...\n"

    # Set the speed.c filepath
    speed_c_filepath="$openssl_source/apps/speed.c"

    # Set the empty variable used for storing the fail output message used in the initial file checks
    fail_output=""

    # Check if the speed.c file is present and if the MAX_KEM_NUM/MAX_SIG_NUM values are present in the file
    if [ ! -f "$speed_c_filepath" ]; then
        fail_output="1"

    elif ! grep -q "#define MAX_SIG_NUM" "$speed_c_filepath" || ! grep -q "#define MAX_KEM_NUM" "$speed_c_filepath"; then
        fail_output="2"

    fi

    # If a fail output message is present, output the related options for proceeding based on the fail type
    if [ -n "$fail_output" ]; then

        # Output the relevant warning message and info to the the user
        if [ "$fail_output" == "1" ]; then

            # Output the file can not be found warning message to the user
            echo "[WARNING] - The setup script cannot find the speed.c file in the OpenSSL source code."
            echo -e "The setup process can continue, but the TLS speed tests may not work correctly.\n"

        elif [ "$fail_output" == "2" ]; then

            # Output the MAX_KEM_NUM/MAX_SIG_NUM values not found warning message to the user
            echo "[WARNING] - The OpenSSL speed.c file does not contain the MAX_KEM_NUM/MAX_SIG_NUM values and could not be modified."
            echo "The setup script can continue, but as the enable all disabled algs flag is set, the TLS speed tests may not work correctly."
            echo -e "However, the TLS handshake tests will still work as expected.\n"

        fi

        # Output the options for proceeding to the user
        get_user_yes_no "Would you like to continue with the setup process?"

        # Determine which option the user has selected and continue with the setup process or exit
        if [ "$user_y_n_response" -eq 1 ]; then
            echo "Continuing setup process..."
            return 0
        else
            echo "Exiting setup script..."
            exit 1
        fi

    fi

    # Extract the default values assigned to the MAX_KEM_NUM/MAX_SIG_NUM variables in the speed.c file
    default_max_kem_num=$(grep -oP '(?<=#define MAX_KEM_NUM )\d+' "$speed_c_filepath")
    default_max_sig_num=$(grep -oP '(?<=#define MAX_SIG_NUM )\d+' "$speed_c_filepath")

    # If the user-defined speed flag is set, use the user-defined value
    if [ "$user_defined_speed_flag" -eq 1 ]; then
        new_value=$user_defined_speed_value
    fi

    # Set the default fallback value and emergency padding value for the MAX_KEM_NUM/MAX_SIG_NUM values in case of automatic detection failure
    fallback_value=200
    emergency_padding=100

    # Determine highest value between the default MAX_KEM_NUM and MAX_SIG_NUM values (they should be the same but just in case)
    highest_default_value=$(($default_max_kem_num > $default_max_sig_num ? $default_max_kem_num : $default_max_sig_num))

    # Ensure that the fallback value is greater than the default MAX_KEM_NUM/MAX_SIG_NUM values
    if [ "$highest_default_value" -gt "$fallback_value" ]; then

        # Set the emergency fallback value and emergency value
        fallback_value=$((highest_default_value + emergency_padding))

        # Warn the user this has happened before continuing the setup process
        echo "[WARNING] - The default fallback value for the MAX_KEM_NUM/MAX_SIG_NUM values is less than the default values in the speed.c file."
        echo -e "The new fallback value with an emergency padding of $emergency_padding is $fallback_value.\n"
        sleep 5

    fi

    # If the user defined value is set, check that the supplied value is not lower than the current default values in the speed.c file
    if [ "$user_defined_speed_flag" -eq 1 ] && [ "$new_value" -lt "$highest_default_value" ]; then

        # Output the warning message to the user and get their choice for continuing with the setup process
        echo -e "\n[WARNING] - The user-defined new value for the MAX_KEM_NUM/MAX_SIG_NUM variables are less than the default values in the speed.c file."
        echo "The current values in the speed.c file is MAX_KEM_NUM: $default_max_kem_num and MAX_SIG_NUM: $default_max_sig_num."
        echo -e "In this situation, the setup process can use the fallback value of $fallback_value instead of the user defined value of $new_value\n"
        get_user_yes_no "Would you like to continue with the setup process using the default new value of $fallback_value instead?"

        # If fallback should be used, modify the speed.c file to use the fallback value instead, otherwise exit the setup script
        if [ "$user_y_n_response" -eq 1 ]; then
            new_value=$fallback_value
        else
            echo "Exiting setup script..."
            exit 1
        fi

    fi

    # Perform automatic adjustment or user defined adjustment of the MAX_KEM_NUM/MAX_SIG_NUM variables in the speed.c file
    if [ "$user_defined_speed_flag" -eq 0 ]; then

        # Determine how much the hardcoded MAX_KEM_NUM/MAX_SIG_NUM variables need increased by
        cd "$util_scripts"
        util_output=$($python_bin "get_algorithms.py" "4" 2>&1)
        py_exit_status=$?
        cd "$root_dir"

        # Check if there were any errors with executing the Python utility script
        if [ "$py_exit_status" -eq 0 ]; then

            # Extract the number of algorithms in the OQS-Provider ALGORITHMS.md file from the Python script output
            alg_count=$(echo "$util_output" | grep -oP '(?<=Total number of Algorithms: )\d+')

            # Check if the captured algorithm count is a valid number
            if ! [[ "$alg_count" =~ ^[0-9]+$ ]]; then
                echo "[ERROR] - Failed to extract a valid number of algorithms from the Python script output."
                exit 1
            fi

            # Determine the new value by adding the default value to the number of algorithms found
            new_value=$((highest_default_value + alg_count))

        else

            # Determine what the cause of the error was and output the appropriate message and options to the user
            if echo "$util_output" | grep -q "File not found:.*"; then

                # Output the error message to the user
                echo "[ERROR] - The Python script that extracts the number of algorithms from the OQS-Provider library could not find the required files."
                echo "Please verify the installation of the OQS-Provider library and rerun the setup script."
                exit 1
            
            elif echo "$util_output" | grep -q "Failed to parse processing file structure:.*"; then

                # Output the warning message to the user
                echo "[WARNING] - There was an issue with the Python script that extracts the number of algorithms from the OQS-Provider library."
                echo "The script returned the following error message: $util_output"

                # Present the options to the user and determine the next steps
                echo -e "It is possible to continue with the setup process using the fallback high values for the MAX_KEM_NUM and MAX_SIG_NUM values.\n"
                get_user_yes_no "Would you like to continue with the setup process using the fallback values ($fallback_value algorithms)?"

                if [ "$user_y_n_response" -eq 1 ]; then
                    echo "Continuing setup process with fallback values..."
                    new_value=$fallback_value
                else
                    echo "Exiting setup script..."
                    exit 1
                fi

            else

                # Output the error message to the user
                echo "[ERROR] - A wider error occurred within the Python get_algorithms utility script. This will cause larger errors in the setup process."
                echo "Please verify the setup environment and rerun the setup script."
                echo "The script returned the following error message: $util_output"
                exit 1

            fi
            
        fi
        
        # Set the new values using the new_value variable
        set_new_speed_values "$speed_c_filepath" "$new_value"
    
    elif [ "$user_defined_speed_flag" -eq 1 ]; then

        # Set the new values using the user-defined value
        set_new_speed_values "$speed_c_filepath" "$new_value"

    else

        # Output an error message as the user_defined_speed_flag flag variable is not set correctly
        echo "[ERROR] - The user_defined_speed_flag flag variable is not set correctly, please verify the code in the setup.sh script"
        exit 1

    fi

    # Output modification success message to the terminal
    echo "[NOTICE] - The MAX_KEM_NUM/MAX_SIG_NUM values in the OpenSSL speed.c file have been successfully modified to $new_value"

}

#-------------------------------------------------------------------------------------------------------------------------------
function openssl_build() {
    # Function for handling the build of the OpenSSL library (version 3.5.0). The function will check if the library is already built
    # and if not, it will build the library using the specified configuration options. The function will call the modify_openssl_src function
    # to modify the speed.c source code file if the OQS-Provider library is being built with the enable all disabled algorithms flag.

    # Output the current task to the terminal
    echo -e "\n######################"
    echo "Building OpenSSL-$openssl_version"
    echo -e "######################\n"

    # Output warning message this make take a while to the user
    echo -e "Starting OpenSSL $openssl_version build process. This may take a while, and no progress bar will be shown...\n"
    sleep 2

    # Setting CPU thread count for the build process
    threads=$(nproc)

    # Define the path to the OQS-Provider library and the openssl.cnf file changes
    oqsprovider_path="$oqs_provider_path/lib/oqsprovider.so"

    # Check if a previous OpenSSL build is present and build if not
    if [ ! -d "$openssl_path" ]; then

        # Modify the s_speed tool's source code if the OQS-Provider library is being built with the enable all disabled algorithms flag
        if [ "$oqs_enable_algs" == "true" ]; then
            modify_openssl_src
        fi

        # Build the required version of OpenSSL in project's directory structure only, not system wide
        echo "Building OpenSSL Library"
        cd $openssl_source
        ./config --prefix="$openssl_path" --openssldir="$openssl_path" shared >/dev/null
        make -j $threads >/dev/null
        make -j $threads install >/dev/null
        cd $root_dir
        echo -e "OpenSSL build complete"

        # Check the OpenSSL library directory name before exporting temp path 
        if [[ -d "$openssl_path/lib64" ]]; then
            openssl_lib_path="$openssl_path/lib64"
        else
            openssl_lib_path="$openssl_path/lib"
        fi

        # Exporting the OpenSSL library filepath for install success check
        export LD_LIBRARY_PATH="$openssl_lib_path:$LD_LIBRARY_PATH"

        # Testing if the OpenSSL has been correctly installed
        test_output=$("$openssl_path/bin/openssl" version)

        if [[ "$test_output" != "OpenSSL 3.5.0 8 Apr 2025 (Library: OpenSSL 3.5.0 8 Apr 2025)" ]]; then
            echo -e "\n\n[ERROR] - Installing required OpenSSL version failed, please verify install process"
            exit 1
        fi

        # Patch the OpenSSL configuration file to include directives for the OQS-Provider library
        if ! "$util_scripts/configure-openssl-cnf.sh" 0; then
            echo "[ERROR] - Failed to modify OpenSSL configuration file."
            exit 1
        fi

    else
        echo "openssl build present, skipping build"

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function enable_arm_pmu() {
    # Function for enabling the ARM PMU and allowing it to be used in user space. The function will also check if the system is a Raspberry-Pi
    # and install the Pi kernel headers if they are not already installed. The function will then enable the PMU and set the enabled_pmu flag.

    # Checking if the system is a Raspberry-Pi and install the Pi kernel headers
    if ! dpkg -s "raspberrypi-kernel-headers" >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install raspberrypi-kernel-headers
    fi

    # Output the current task to the terminal
    echo -e "\nEnabling User Space Access to the ARM PMU\n"

    # Move into the libs directory and clone the pqax repository
    cd "$libs_dir"
    git clone --branch main https://github.com/mupq/pqax.git
    cd "$libs_dir/pqax/enable_ccr"

    # Enable user space access to the ARM PMU
    make
    make_status=$?
    make install
    make_install_status=$?
    cd $root_dir

    # Check if the make and make install commands were successful
    if [ "$make_status" -ne 0 ] || [ "$make_install_status" -ne 0 ]; then
        echo -e "\nPMU build failed, please check the system and try again\n"
        exit 1
    fi

    # Ensure that the system has user access to the ARM PMU
    if lsmod | grep -q 'enable_ccr'; then
        enabled_pmu=1
    else
        echo "[ERROR] - The enable_ccr module is not loaded, please verify the installation and rerun the setup script"
        enabled_pmu=0
        exit 1
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function liboqs_build() {
    # Function for building the OQS Liboqs dependency library. The function will determine the system architecture and 
    # build the library accordingly. The function will also call the enable_arm_pmu function if the system is a ARM device. 

    # Building Liboqs if install type selected is 0 or 1
    if [ "$install_type" -eq 0 ] || [ "$install_type" -eq 1 ]; then

        # Output the current task to the terminal
        echo -e "\n#################"
        echo "Installing Liboqs"
        echo -e "#################\n"

        # Ensuring that the build filepath is clean before proceeding
        if [ -d "$liboqs_path" ]; then 
            sudo rm -r "$liboqs_path"
        fi
        mkdir -p $liboqs_path

        # Set the build options based on the detected system architecture
        if [ "$(uname -m)" = "x86_64" ] && [ "$(uname -s)" = "Linux" ]; then

            # Setting x86 Liboqs build options
            build_options="no-shared linux-x86_64"
            build_flags=""
            threads=$(nproc)

        elif [[ "$(uname -m)" = arm* || "$(uname -m)" == aarch* ]]; then

            # Set the default value for the enabled_pmu flag
            enabled_pmu=0

            # Enable user space access to the ARM PMU if needed
            if lsmod | grep -q 'enable_ccr'; then
                echo "The enable_ccr module is already enabled, skipping build."
            else
                enable_arm_pmu
            fi

            # Setting ARM arrch64 build options for pi
            if [ $enabled_pmu -eq 1 ];then
                build_flags="-DOQS_SPEED_USE_ARM_PMU=ON"
                #build_flags="-DOQS_SPEED_USE_ARM_PMU=ON -DOQS_ENABLE_KEM_HQC=ON"
            else
                build_flags=""
            fi
            threads=$(nproc)
            
        else
            # Output the unsupported system error message to the user
            echo -e "[ERROR] - Unsupported System Detected - Manual Build Required!\n"
            exit 1

        fi

        # Replacing the default Liboqs test_mem source-code files with the modded versions
        cp "$root_dir/modded_lib_files/test_sig_mem.c" "$liboqs_source/tests/test_sig_mem.c"
        cp "$root_dir/modded_lib_files/test_kem_mem.c" "$liboqs_source/tests/test_kem_mem.c"

        # Set the HQC enabled cmake flag is the user has selected to enable HQC
        if [ "$enable_hqc" -eq 1 ]; then
            hqc_flag="-DOQS_ENABLE_KEM_HQC=ON"
            touch "$tmp_dir/.hqc_enabled.flag"
        else
            hqc_flag=""
            rm -f "$tmp_dir/.hqc_enabled.flag"
        fi

        # Set up the build directory and build Liboqs
        cmake -GNinja \
            -S "$liboqs_source/" \
            -B "$liboqs_path/build" \
            -DCMAKE_INSTALL_PREFIX="$liboqs_path" \
            -DOQS_USE_OPENSSL=ON \
            -DOPENSSL_ROOT_DIR="$openssl_path" \
            $build_flags \
            $hqc_flag\

        cmake --build "$liboqs_path/build" -- -j $threads
        cmake --build "$liboqs_path/build" --target install -- -j $threads

        # Create the test-data storage directories
        mkdir -p "$liboqs_path/mem_results/kem_mem_metrics/" && mkdir -p "$liboqs_path/mem_results/sig_mem_metrics/" && mkdir "$liboqs_path/speed_results"

        # Output the install success message to the terminal
        echo -e "\nLiboqs Install Complete"

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function oqs_provider_build() {
    # Function for building OQS-Provider dependency library. The function will determine the system architecture and 
    # build the library accordingly. The function will also determine if the user has selected the enable all disabled algorithms flag and 
    # take the appropriate steps to do this using the specified steps listed by the OQS-Provider repository instructions.

    # Output the current task to the terminal
    echo -e "\n#######################"
    echo "Installing OQS-Provider"
    echo -e "#######################\n"

    # Set the generate.yml filepaths
    backup_generate_file="$root_dir/modded_lib_files/generate.yml"
    oqs_provider_generate_file="$oqs_provider_source/oqs-template/generate.yml"

    # Enable all the disabled signature algorithms in the OQS-Provider library if the user has specified to do so
    if [ "$oqs_enable_algs" == "true" ]; then

        # Ensure that the generate.yml file is present and determine action based on its presence
        if [ ! -f  "$oqs_provider_generate_file" ]; then

            # Output the error message to the user and getting their choice for proceeding
            echo -e "\n[WARNING] - The generate.yml file is missing from the OQS-Provider library, it is possible that the library no longer supports this feature"
            get_user_yes_no "Would you like to continue with the setup process anyway?"

            # Determine the next action based on the user's response
            if [ "$user_y_n_response" -eq 0 ]; then
                echo -e "Exiting setup script..."
                exit 1
            else
                echo "Continuing setup process..."
                return 0
            fi

        fi

        # Ensure that the generate.yml file still follows the enable: true/enable: false format before proceeding
        if ! grep -q "enable: true" "$oqs_provider_generate_file" || ! grep -q "enable: false" "$oqs_provider_generate_file"; then

            # Output the error message to the user and getting their choice for proceeding
            echo -e "\n[WARNING] - The generate.yml file in the OQS-Provider library does not follow the expected format"
            echo -e "this setup script cannot automatically enable all disabled signature algorithms\n"
            get_user_yes_no "Would you like to continue with the setup process anyway?"

            # Determine the next action based on the user's response
            if [ "$user_y_n_response" -eq 0 ]; then
                echo -e "Exiting setup script..."
                exit 1
            else
                echo "Continuing setup process..."
                return 0
            fi

        fi

        # Modify the generate.yml file to enable all the disabled signature algorithms
        sed -i 's/enable: false/enable: true/g' "$oqs_provider_generate_file"

        # Check if the generate.yml file was successfully modified
        if ! grep -q "enable: true" "$oqs_provider_generate_file"; then
            echo -e "\n[ERROR] - Enabling all disabled signature algorithms in the OQS-Provider library failed, please verify the setup and run a clean install"
            exit 1
        fi

        # Run the generate.py script to enable all disabled signature algorithms in the OQS-Provider library
        export LIBOQS_SRC_DIR="$liboqs_source"
        cd $oqs_provider_source
        $python_bin $oqs_provider_source/oqs-template/generate.py
        cd $root_dir

    fi

    # Build the OQS-Provider dependency library
    cmake -S $oqs_provider_source \
        -B "$oqs_provider_path" \
        -DCMAKE_INSTALL_PREFIX="$oqs_provider_path" \
        -DOPENSSL_ROOT_DIR="$openssl_path" \
        -Dliboqs_DIR="$liboqs_path/lib/cmake/liboqs" \
        -DOQS_KEM_ENCODERS="$encoder_flag"

    cmake --build "$oqs_provider_path" -- -j $(nproc)
    cmake --install "$oqs_provider_path"

    # Output the install complete message to the terminal
    echo "OQS-Provider Install Complete"

}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Main function for controlling the automated setup process for the PQC-Evaluation-Tools project.

    # Output the welcome message to the terminal
    echo "#################################"
    echo "PQC-Evaluation-Tools Setup Script"
    echo -e "#################################\n"

    # Parse the command line arguments passed to the script if any
    if [ "$#" -gt 0 ]; then
        parse_args "$@"
    fi

    # Output current task to the terminal
    echo "######################"
    echo "Install Type Selection"
    echo -e "######################\n"
    
    # Get the install type selection from the user
    while true; do

        # Output the install type options to the user
        echo "Please Select one of the following build options"
        echo "1 - Build Liboqs Library Only"
        echo "2 - Build OQS-Provider and Liboqs Library"
        echo "3 - Build OQS-Provider Library with previous Liboqs Install"
        echo "4 - Exit Setup"

        # Prompt the user for their selection
        read -p "Enter your choice (1-4): " user_opt

        # Determine the setup actions needed based on the user response
        case "$user_opt" in 

            1)
                # Output the selection choice to the terminal
                echo -e "\n############################"
                echo "Liboqs Only Install Selected"
                echo -e "############################\n"

                # Configure the setup environment and install the required dependencies
                install_type=0
                configure_dirs
                dependency_install

                # Build the required dependency libraries and clean up
                openssl_build
                liboqs_build
                # rm -rf $tmp_dir/* # original clean up
                rm -rf $tmp_dir/liboqs_source $tmp_dir/openssl_$openssl_version # temp removal for hqc bug fix

                # Create the required alg-list files for the automated testing
                cd "$util_scripts"
                $python_bin "get_algorithms.py" "1"
                py_exit_status=$?
                cd $root_dir

                break
                ;;
            
            2)
                # Output the selection choice to the terminal
                echo -e "\n########################################"
                echo "Liboqs and OQS-Provider Install Selected"
                echo -e "########################################\n"

                # Configure the setup environment and install the required dependencies
                install_type=1
                configure_dirs
                configure_oqs_provider_build
                dependency_install

                # Build the required dependency libraries and clean up
                openssl_build
                liboqs_build
                oqs_provider_build
                #rm -rf $tmp_dir/* # original clean up
                rm -rf $tmp_dir/liboqs_source $tmp_dir/openssl_$openssl_version $tmp_dir/oqs_provider_source # temp removal for hqc bug fix
                #touch "$tmp_dir/test.flag"

                # Create the required alg-list files for the automated testing
                cd "$util_scripts"
                $python_bin "get_algorithms.py" "2"
                py_exit_status=$?
                cd $root_dir

                break
                ;;

            3)
                # Output the selection choice to the terminal
                echo -e "\n##################################"
                echo "OQS-Provider Only Install Selected"
                echo -e "##################################\n"

                # Configure the setup environment and install the required dependencies
                install_type=2
                configure_dirs
                configure_oqs_provider_build
                dependency_install

                # Build OpenSSL 3.5.0
                openssl_build

                # Check if a Liboqs install is already present and install if not
                if [ ! -d "$liboqs_path" ]; then
                    echo -e "\n[ERROR] - The Liboqs Install source could not be found."
                    echo -e "Please select option 2 instead to install both Liboqs and OQS-Provider libraries\n"
                    echo "Exiting Script..."
                    exit 1
                fi

                # Build the OQS-Provider library
                oqs_provider_build
                #rm -rf $tmp_dir/* # original clean up
                rm -rf $tmp_dir/liboqs_source $tmp_dir/openssl_$openssl_version $tmp_dir/oqs_provider_source # temp removal for hqc bug fix

                # Check if the Liboqs alg-list files are present before deciding which alg-list files need generated
                if [ -f "$alg_lists_dir/kem-algs.txt" ] && [ -f "$alg_lists_dir/sig-algs.txt" ]; then
                    alg_list_flag="3"
                else
                    alg_list_flag="2"
                fi

                # Create the required alg-list files for the automated testing
                cd "$util_scripts"
                $python_bin "get_algorithms.py" "$alg_list_flag"
                py_exit_status=$?
                cd $root_dir

                break
                ;;

            4)

                # Output the selection choice to the terminal
                echo "Exiting Setup!"
                exit 1
                ;;

            *)

                # Output the invalid option message to the user
                echo "Invalid option, please select valid option value (1-4)"
                ;;

        esac
    
    done

    # Configure the flag file for the KEM encoders option in the OQS-Provider build for use by the testing scripts
    if [ "$encoder_flag" == "ON" ]; then
        touch "$tmp_dir/kem_encoders_enabled.flag"
    
    elif [ "$encoder_flag" == "OFF" ]; then

        # Remove flag file if present in the tmp directory as the KEM encoders are disabled
        if [ -f "$tmp_dir/kem_encoders_enabled.flag" ]; then
            rm "$tmp_dir/kem_encoders_enabled.flag"
        fi

    fi

    # Output that there was an issue with the python utility script that creates the alg-list files
    if [ "$py_exit_status" -ne 0 ]; then
        echo -e "\n[ERROR] - creating algorithm list files failed, please verify both setup and python scripts and rerun setup!!!"
        echo -e "If the issue persists, you may want to consider re-cloning the repo and rerunning the setup script\n"
    
    elif [ -z "$py_exit_status" ]; then
        echo -e "\nThe Python get_algorithms script did not return an exit status, please verify the script and rerun setup\n"
    fi

    # Output the setup complete message to the terminal
    echo -e "\n\nSetup complete, completed builds can be found in the builds directory"

}
main "$@"
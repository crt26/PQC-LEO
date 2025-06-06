#!/bin/bash

# Copyright (c) 2023-2025 Callum Turino
# SPDX-License-Identifier: MIT

# This script automates the setup process for the PQC-evaluation-tools benchmarking suite. It provides options to build and configure
# the required cryptographic libraries (Liboqs, OQS-Provider, and OpenSSL) and their dependencies. The script handles directory
# creation, dependency installation, library downloads, and compilation. It also allows customisation of build options,
# such as enabling additional algorithms or modifying OpenSSL configurations. The script ensures compatibility
# with the system environment and provides user-friendly prompts for setup decisions.

#-------------------------------------------------------------------------------------------------------------------------------
function setup_base_env() {
    # Function for initializing global variables and directory paths required for the setup process.
    # Sets paths for libraries, temporary files, test data, and utility scripts. Also defines default
    # values for flags and configuration options, ensuring a consistent environment for the setup script.

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
    liboqs_tested_sha="9aa76bc1309a9bc10061ec3aa07d727c030c9a86"
    oqs_provider_tested_sha="2cc8dd3d3ef8764fa432f87a0ae15431d86bfa90"

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_$openssl_version"
    liboqs_path="$libs_dir/liboqs"
    oqs_provider_path="$libs_dir/oqs_provider"

    # Declare the global source-code directory path variables
    liboqs_source="$tmp_dir/liboqs_source"
    oqs_provider_source="$tmp_dir/oqs_provider_source"
    openssl_source="$tmp_dir/openssl_$openssl_version"

    # Set the global flag variables
    install_type=0  # 0=Computational only, 1=Computational+TLS, 2=TLS only
    use_latest_version=0
    user_defined_speed_flag=0
    user_defined_speed_value=0
    enable_liboqs_hqc=0 # temp flag for hqc bug fix
    enable_oqs_hqc=0 # temp flag for hqc bug fix
    warning_given=0 # temp flag to indicate if the user has accepted the warning about HQC KEM algorithms
    allow_hqc=0 # temp flag to indicate if the user has accepted the warning about HQC KEM algorithms

    # Declare the global flags for enabling OQS-Provider build options
    oqs_enable_algs=0
    encoder_flag="OFF" # string as needed for insetting value into OQS-Provider cmake command

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_user_yes_no() {
    # Helper function to prompt the user for a yes or no response. The function loops until
    # a valid response ('y' or 'n') is provided and sets the global variable `user_y_n_response`
    # to 1 for 'yes' and 0 for 'no'.

    # Set the local user prompt variable to what was passed to the function
    local user_prompt="$1"

    # Get the user input for the yes or no question
    while true; do

        # Output the question to the user and get their response
        read -p "$user_prompt (y/n): " user_input

        # Validate the input and set the response
        case $user_input in

            [Yy]* )
                user_y_n_response=1
                break
                ;;

            [Nn]* )
                user_y_n_response=0
                break
                ;;

            * )
                echo -e "Please answer y or n\n"
                ;;

        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function output_help_message() {
    # Helper function for outputting the help message to the user when the --help flag is present or
    # when incorrect arguments are passed.

    # Output the supported options and their usage to the user
    echo "Usage: setup.sh [options]"
    echo "Options:"
    echo "  --latest-dependency-versions     Use the latest available versions of the OQS libraries (may cause compatibility issues)."
    echo "  --set-speed-new-value=[int]      Set a new value for MAX_KEM_NUM and MAX_SIG_NUM in OpenSSL's speed.c file."
    echo "  --enable-liboqs-hqc-algs         Enable HQC KEM algorithms in liboqs (disabled by default due to spec non-conformance)."
    echo "  --enable-oqs-hqc-algs            Enable HQC KEM algorithms in OQS-Provider (requires HQC to also be enabled in liboqs)."
    echo "  --enable-all-hqc-algs            Enable all HQC KEM algorithms in both liboqs and OQS-Provider (overrides individual HQC flags)."
    echo "  --help                           Display this help message."
    
}

#-------------------------------------------------------------------------------------------------------------------------------
function confirm_enable_hqc_algs() {
    # Temporary helper function for warning the user about the disabled HQC KEM algorithms as discussed in issue
    # (https://github.com/crt26/pqc-evaluation-tools/issues/46). The function will display a security warning and provide
    # background information about why HQC KEM algorithms are disabled by default in Liboqs and OQS-Provider. It then 
    # prompts the user to decide whether to proceed with enabling HQC for benchmarking purposes. This function will be 
    # removed in the future when Liboqs version 0.14.0 is released and the HQC KEM algorithms are re-enabled by default.

    # Displays a clear warning about HQC vulnerabilities and disclaims all responsibility for its use.
    echo -e "\nEnable HQC KEM Algorithms Flag Detected:\n"

    echo -e "[WARNING] - The current implementation of the HQC KEM algorithm in the OQS libraries (liboqs and oqs-provider)"
    echo -e "does not conform to the latest reference specification, which includes fixes for a previously identified security flaw.\n"

    echo -e "Because of this, HQC is disabled by default in the OQS libraries.\n"

    echo -e "This project provides the option to re-enable HQC solely for benchmarking purposes. Whether or not to enable it is"
    echo -e "entirely up to the user. If HQC is enabled for performance testing within this project, the risks must"
    echo -e "be fully understood and accepted.\n"

    echo -e "This project and its maintainers make no guarantees about the correctness, security, or compliance of HQC"
    echo -e "as currently implemented in the OQS libraries. Enabling HQC is done entirely at your own risk, and this project"
    echo -e "accepts no responsibility for any issues that may arise from its use.\n"
    
    echo -e "For more information, see:"
    echo -e "- https://github.com/open-quantum-safe/liboqs/issues/2118"
    echo -e "- https://github.com/crt26/pqc-evaluation-tools/issues/46"
    echo -e "- https://github.com/crt26/pqc-evaluation-tools/issues/60\n"

    # Prompt the user to acknowledge the risks and decide whether to proceed with enabling HQC KEM algorithms
    get_user_yes_no "Do you acknowledge the risks and wish to proceed with enabling HQC KEM algorithms?"

    # Set the allow_hqc flag based on the user response
    if [ $user_y_n_response -eq 1 ]; then
        echo -e "\n[NOTICE] - HQC KEM algorithms will be enabled where applicable\n"
        allow_hqc=1
    else
        echo -e "\n[NOTICE] - HQC KEM algorithms will remain disabled\n"
        allow_hqc=0
    fi

    # Set the warning_given flag to indicate that the user has been warned about the HQC KEM algorithms
    warning_given=1

}

#-------------------------------------------------------------------------------------------------------------------------------
function parse_args() {
    # Function for parsing command-line arguments and sets global flags based on detected options.
    # Flags control various aspects of the setup process, such as library versions, speed values, and HQC algorithm settings.

    # Check for the --help flag and display the help message
    if [[ "$*" =~ --help ]]; then
        output_help_message
        exit 0
    fi

    # Set the default flag set values for HQC flags (temp for hqc bug fix)
    local all_hqc_flag_set=0
    local liboqs_hqc_flag_set=0
    local oqs_hqc_flag_set=0

    # Check if the user has passed the enable all hqc algorithms flag
    if [[ "$*" =~ --enable-all-hqc-algs ]]; then
        all_hqc_flag_set=1
    fi

    # Loop through the passed command line arguments and check for the supported options
    while [[ $# -gt 0 ]]; do

        # Check if the argument is a valid option, then shift to the next argument
        case "$1" in

            --latest-dependency-versions)

                # Output the warning message to the user
                echo -e "\n[NOTICE] Using the latest version of the OQS libraries. This may lead to compatibility issues with this project."
                echo "If the latest upstream changes cause problems, please report them to this projects issue page."
                echo -e "You can re-run the setup script without this flag to use the last tested version of the libraries if issues occur.\n"

                # Determine if the user wishes to proceed with using the latest version
                get_user_yes_no "Would you like to continue with using the latest version of the OQS libraries?"

                # Prompt the user to confirm using the latest versions
                if [ $user_y_n_response -eq 1 ]; then
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

                # Validate the speed value (must be an integer)
                if ! [[ "$user_defined_speed_value" =~ ^[0-9]+$ ]]; then
                    echo -e "[ERROR] - Speed value must be a valid integer. Verify and re-run the script.\n"
                    output_help_message
                    exit 1
                fi

                shift
                ;;

            --enable-liboqs-hqc-algs)

                # Set the Liboqs HQC flag to indicate the flag has been passed
                liboqs_hqc_flag_set=1

                # Only handle the checks and enabling if the all_hqc_flag_set is not set
                if [ $all_hqc_flag_set -eq 0 ]; then

                    # Give the user a warning about the HQC KEM algorithms if not already given
                    if [ $warning_given -ne 1 ]; then
                        confirm_enable_hqc_algs
                    fi

                    # Enable the Liboqs HQC KEM algorithm if warning has been accepted
                    if [ $allow_hqc -eq 1 ]; then
                        enable_liboqs_hqc=1
                    else
                        enable_liboqs_hqc=0
                    fi

                fi

                shift
                ;;

            --enable-oqs-hqc-algs)

                # Set the OQS-Provider HQC flag to indicate the flag has been passed
                oqs_hqc_flag_set=1

                # Only handle the checks and enabling if the all_hqc_flag_set is not set
                if [ $all_hqc_flag_set -eq 0 ]; then

                    # Give the user a warning about the HQC KEM algorithms if not already given
                    if [ $warning_given -ne 1 ]; then
                        confirm_enable_hqc_algs
                    fi

                    # Enable the OQS-Provider HQC KEM algorithm if warning has been accepted
                    if [ $allow_hqc -eq 1 ]; then
                        enable_oqs_hqc=1
                        oqs_hqc_flag_set=1
                    else
                        enable_oqs_hqc=0
                    fi
                
                fi
                
                shift
                ;;

            --enable-all-hqc-algs)

                # Give the user a warning about the HQC KEM algorithms if not already given
                if [ $warning_given -ne 1 ]; then
                    confirm_enable_hqc_algs
                fi

                # Enable both Liboqs and OQS-Provider HQC KEM algorithms if warning has been accepted
                if [ $allow_hqc -eq 1 ]; then
                    enable_liboqs_hqc=1
                    enable_oqs_hqc=1
                else
                    enable_liboqs_hqc=0
                    enable_oqs_hqc=0
                fi

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

    # Output the message that all HQC algs will be enabled regardless of other flags if the enabled all_hqc_flag_set flag is set
    if [ $all_hqc_flag_set -eq 1 ] && { [ $liboqs_hqc_flag_set -eq 1 ] || [ $oqs_hqc_flag_set -eq 1 ]; }; then
        echo -e "[NOTICE] - The --enable-all-hqc-algs has been set, enabling all HQC KEMs in Liboqs and OQS-Provider and overriding other HQC flags\n"

    fi

    # If enabling OQS-Provider HQC KEM algorithms, ensure that Liboqs HQC KEM algorithms are also enabled
    if [ $enable_oqs_hqc -eq 1 ] && [ $enable_liboqs_hqc -eq 0 ]; then

        # Output the warning message to the user and prompt to enable Liboqs HQC KEM algorithms as well
        echo -e "[WARNING] - Enabling OQS-Provider HQC KEM algorithms requires Liboqs HQC KEM algorithms to be enabled as well."
        get_user_yes_no "Would you like to enable Liboqs HQC KEM algorithms as well?"

        # Determine any flag changes based on the user response
        if [ $user_y_n_response -eq 1 ]; then
            echo -e "\n[NOTICE] - Liboqs HQC KEM algorithms will be enabled in the Liboqs library build process\n"
            enable_liboqs_hqc=1
        else
            echo -e "\n[NOTICE] - OQS-Provider HQC KEM algorithms will not be enabled in the OQS-Provider library build process"
            sleep 3
            enable_oqs_hqc=0
        fi

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function configure_dirs() {
    # Function for creating the required directory structure for the setup process and handling previous installations.
    # Detects existing installations based on the selected install type, prompts the user for reinstallation, and ensures
    # a clean setup by removing old directories. Also creates a marker file for identifying the root directory path.

    # Declare required directories array used in the directory check and creation
    required_dirs=("$libs_dir" "$oqs_provider_source" "$tmp_dir" "$test_data_dir" "$alg_lists_dir")

    # Set the default value for the previous install flag
    previous_install=0

    # Check if the dependency libraries have already been installed based on install type selected
    case $install_type in
        0) [ -d "$liboqs_path" ] && previous_install=1 ;;
        1) [ -d "$liboqs_path" ] || [ -d "$oqs_provider_path" ] && previous_install=1 ;;
        2) [ -d "$oqs_provider_path" ] && previous_install=1 ;;
    esac

    # If a previous install is detected, get the user choice for reinstalling the dependency libraries
    if [ "$previous_install" -eq 1 ]; then

        # Output the warning message and get the user choice for reinstalling the libraries
        echo -e "\n[WARNING] - Previous Install Detected!!"
        get_user_yes_no "Would you like to reinstall the libraries?"

        # Continue with the setup or exit based on the user choice
        if [ $user_y_n_response -eq 1 ]; then
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

    # If HQC is to be enabled, create the hqc_algorithms marker file in the temp directory
    if [ $enable_liboqs_hqc -eq 1 ] || [ $enable_oqs_hqc -eq 1 ]; then
        touch "$tmp_dir/.hqc_enabled.flag"
    else
        rm -f "$tmp_dir/.hqc_enabled.flag"
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function configure_oqs_provider_build() {
    # Function for configuring the OQS-Provider build process by setting optional build flags based on user input.

    # Output the current task to the terminal
    echo -e "\nConfiguring Optional OQS-Provider Build Options:\n"

    # Determine if the user wishes to enable all disabled signature algorithms in the OQS-Provider library
    get_user_yes_no "Would you like to enable all the digital signature algorithms in the OQS-Provider library that are disabled by default?"

    # Set the oqs_enable_algs build flag option based on the user response
    if [ $user_y_n_response -eq 1 ]; then
        oqs_enable_algs=1
    else
        oqs_enable_algs=0
    fi

    # Determine if the users wishes to enable the KEM encoders option in the OQS-Provider build
    get_user_yes_no "Would you like to enable the KEM encoders option in the OQS-Provider build?"

    # Set the OQS-Provider build flags based on the user response
    if [ $user_y_n_response -eq 1 ]; then
        encoder_flag="ON"
    else
        encoder_flag="OFF"
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function download_libraries() {
    # Function for downloading the required cryptographic libraries (OpenSSL, Liboqs, OQS-Provider). For the OQS libraries, it will
    # default to using the last tested versions of the libraries, unless the --latest-dependency-versions command line argument has
    # been passed to the setup script. The OpenSSL library version will always remain the same.

    # Output the current task to the terminal
    echo -e "\n############################################"
    echo "Downloading Required Cryptographic Libraries"
    echo -e "############################################\n"

    # Download OpenSSL 3.5.0 and extract it into the tmp directory
    wget -O "$tmp_dir/openssl_$openssl_version.tar.gz" "$openssl_download_url"
    tar -xf "$tmp_dir/openssl_$openssl_version.tar.gz" -C $tmp_dir
    mv "$tmp_dir/openssl-$openssl_version" "$openssl_source"
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
            echo -e "\n[ERROR] - The use_latest_version flag variable is not set correctly, please verify the code in the setup.sh script"
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

    # Check for missing system packages
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

    # Install missing packages
    if [[ ${#not_installed[@]} -ne 0 ]]; then
        sudo apt-get update
        sudo apt-get install -y "${not_installed[@]}"
    fi

    # Check for missing Python pip packages
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

    # Output the system dependency check completion message
    echo "Dependency checks complete"

    # Downloading the required cryptographic libraries (OpenSSL, Liboqs, OQS-Provider)
    download_libraries

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

    # Set the number of CPU threads to use for the build process
    threads=$(nproc)

    # Define the path to the OQS-Provider library
    oqsprovider_path="$oqs_provider_path/lib/oqsprovider.so"

    # Check if a previous OpenSSL build is present and build if not
    if [ ! -d "$openssl_path" ]; then

        # Modify the s_speed tool's source code if the OQS-Provider library is being built with the enable all disabled algorithms flag
        if [ $oqs_enable_algs -eq 1 ]; then

            # Call the source code modifier utility script and capture the exit status
            "$util_scripts/source_code_modifier.sh" "modify_openssl_src" \
                "--user-defined-flag=$user_defined_speed_flag" \
                "--user-defined-speed-value=$user_defined_speed_value"
            exit_status=$?

            # Ensure that the source code modifier script ran successfully
            if [ $exit_status -ne 0 ]; then
                echo -e "\n[ERROR] - The source code modifier script failed to run successfully, please verify the installation and rerun the setup script"
                exit 1
            fi

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
        if ! "$util_scripts/configure_openssl_cnf.sh" 0; then
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
        echo -e "\n[ERROR] - PMU build failed, please check the system and try again\n"
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
    # Function to build the Liboqs dependency library. Detects system architecture and configures the build process accordingly.
    # On ARM devices, enables user space access to the ARM PMU if needed. Handles optional enabling of HQC algorithms and 
    # replaces default test_mem files with project-specific versions for benchmarking.

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

        # Set the number of CPU threads to use for the build process
        threads=$(nproc)

        # Set the build options based on the detected system architecture
        if [ "$(uname -m)" = "x86_64" ] && [ "$(uname -s)" = "Linux" ]; then

            # Setting x86 Liboqs build options
            build_options="no-shared linux-x86_64"
            build_flags=""

        elif [[ "$(uname -m)" = arm* || "$(uname -m)" == aarch* ]]; then

            # Set the default value for the enabled_pmu flag
            enabled_pmu=0

            # Enable user space access to the ARM PMU if needed
            if lsmod | grep -q 'enable_ccr'; then
                echo "The enable_ccr module is already enabled, skipping build."
            else
                enable_arm_pmu
            fi

            # Set ARM-specific build flags if PMU is enabled otherwise use default build flags
            if [ $enabled_pmu -eq 1 ];then
                build_flags="-DOQS_SPEED_USE_ARM_PMU=ON"
            else
                build_flags=""
            fi

        else

            # Output the unsupported system error message to the user
            echo -e "[ERROR] - Unsupported System Detected - Manual Build Required!\n"
            exit 1

        fi

        # Replace the default Liboqs test_mem source-code files with the modded versions
        cp "$root_dir/modded_lib_files/test_sig_mem.c" "$liboqs_source/tests/test_sig_mem.c"
        cp "$root_dir/modded_lib_files/test_kem_mem.c" "$liboqs_source/tests/test_kem_mem.c"

        # Set the HQC enabled cmake flag if the user has selected to enable HQC
        if [ $enable_liboqs_hqc -eq 1 ]; then
            hqc_flag="-DOQS_ENABLE_KEM_HQC=ON"
        else
            hqc_flag=""
        fi

        # Build Liboqs using CMake
        cmake -GNinja \
            -S "$liboqs_source/" \
            -B "$liboqs_path/build" \
            -DCMAKE_INSTALL_PREFIX="$liboqs_path" \
            -DOQS_USE_OPENSSL=ON \
            -DOPENSSL_ROOT_DIR="$openssl_path" \
            $build_flags \
            $hqc_flag

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
    # Function for Building the OQS-Provider dependency library. Configures the build process, enables disabled signature algorithms 
    # if requested, patches the generate.yml file, and runs the code generator. Ensures correct paths for OpenSSL and Liboqs, 
    # applies the KEM encoder option, and handles errors for missing or malformed configuration files.

    # Output the current task to the terminal
    echo -e "\n#######################"
    echo "Installing OQS-Provider"
    echo -e "#######################\n"

    # Define paths for the generate.yml file
    backup_generate_file="$root_dir/modded_lib_files/generate.yml"
    oqs_provider_generate_file="$oqs_provider_source/oqs-template/generate.yml"

    # Enable disabled signature algorithms if user has specified
    if [ $oqs_enable_algs -eq 1 ] || [ $enable_oqs_hqc -eq 1 ]; then

        # Call the source code modifier utlity script and capture the exit status
        "$util_scripts/source_code_modifier.sh" "oqs_enable_algs" \
            "--enable-hqc-algs=$enable_oqs_hqc" \
            "--enable-disabled-algs=$oqs_enable_algs"
        exit_status=$?

        # Ensure that the source code modifier script ran successfully
        if [ $exit_status -ne 0 ]; then
            echo -e "\n[ERROR] - The source code modifier script failed to run successfully, please verify the installation and rerun the setup script"
            exit 1
        fi

    fi

    # Build the OQS-Provider library
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
function setup_controller() {
    # Function for controlling the setup process based on the user's selected install type. Provides options for computational 
    # performance testing, TLS PQC performance testing, or both. Handles environment configuration, dependency installation, 
    # library builds, and cleanup tasks. Prompts the user for decisions and ensures the setup process is tailored to their selection.

    # Output current task to the terminal
    echo "######################"
    echo "Install Type Selection"
    echo -e "######################\n"

    # Get the install type selection from the user
    while true; do

        # Output the install type options to the user
        echo "Please Select one of the following build options"
        echo "1 - Computational Performance Testing Only"
        echo "2 - Both Computational and TLS PQC Performance Testing"
        echo "3 - TLS PQC Performance Testing Only (requires existing computational setup)"
        echo "4 - Exit Setup"

        # Prompt the user for their selection
        read -p "Enter your choice (1-4): " user_opt

        # Determine the setup actions needed based on the user response
        case "$user_opt" in

            1)
                # Output the selection choice to the terminal
                echo -e "\n###############################################"
                echo "Computational Performance Only Install Selected"
                echo -e "###############################################\n"

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
                echo -e "\n##################################################"
                echo "Computational and TLS Performance Install Selected"
                echo -e "###############################################\n"

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
                echo -e "\n#####################################"
                echo "TLS Performance Only Install Selected"
                echo -e "#####################################\n"

                # Configure the setup environment and install the required dependencies
                install_type=2
                configure_dirs
                configure_oqs_provider_build
                dependency_install

                # Build OpenSSL 3.5.0
                openssl_build

                # Check if a Liboqs install is already present and install if not
                if [ ! -d "$liboqs_path" ]; then
                    echo -e "\n[ERROR] - Existing computational performance setup not found."
                    echo -e "Please select option 2 instead to install both Liboqs and OQS-Provider libraries\n"
                    echo "Exiting Script..."
                    exit 1
                fi

                # Build the OQS-Provider library
                oqs_provider_build
                #rm -rf $tmp_dir/* # original clean up
                rm -rf $tmp_dir/liboqs_source $tmp_dir/openssl_$openssl_version $tmp_dir/oqs_provider_source # temp removal for hqc bug fix

                # Check if the Liboqs alg-list files are present before deciding which alg-list files need generated
                if [ -f "$alg_lists_dir/kem_algs.txt" ] && [ -f "$alg_lists_dir/sig_algs.txt" ]; then
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

}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Entry point for the PQC-Evaluation-Tools setup script. Initializes the environment, parses command-line arguments,
    # and delegates the setup process to the setup_controller function.

    # Output the welcome message to the terminal
    echo "#################################"
    echo "PQC-Evaluation-Tools Setup Script"
    echo -e "#################################\n"

    # Setup the base environment global variables and directories paths
    setup_base_env

    # Parse the command line arguments passed to the script if any
    if [ "$#" -gt 0 ]; then
        parse_args "$@"
    fi

    # Call the setup controller function to handle the setup process
    setup_controller

    # Output the setup complete message to the terminal
    echo -e "\n\nSetup complete, completed builds can be found in the builds directory"

}
main "$@"
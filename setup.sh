#!/bin/bash

# Copyright (c) 2023-2026 Callum Turino
# SPDX-License-Identifier: MIT

# This script automates the setup process for the PQC-LEO benchmarking framework. It provides options to build and configure
# the required cryptographic libraries (Liboqs, OQS-Provider, and OpenSSL) and their dependencies. The script handles directory
# creation, dependency installation, library downloads, and compilation. It also allows customisation of build options,
# such as enabling additional algorithms or modifying OpenSSL configurations. The script ensures compatibility
# with the system environment and provides user-friendly prompts for setup decisions. It also includes optional
# energy-collection setup support for the energy collector, computational energy tester, and related workflow flags.

#-------------------------------------------------------------------------------------------------------------------------------
function setup_base_env() {
    # Function for initialising global variables and directory paths required for the setup process. Sets paths for libraries, 
    # temporary files, test data, and utility scripts. Also defines default values for flags and configuration options, ensuring 
    # a consistent environment for the setup script.

    # Declare the global main directory path variables
    root_dir=$(pwd)
    libs_dir="$root_dir/lib"
    tmp_dir="$root_dir/tmp"
    test_data_dir="$root_dir/test_data"
    alg_lists_dir="$test_data_dir/alg_lists"
    util_scripts="$root_dir/scripts/utility_scripts"
    tools_dir="$root_dir/tools"
    test_scripts="$root_dir/scripts/test_scripts"

    # Declare the global dependency library version variables
    openssl_version="3.6.1"

    # Declare the global library download URL variables
    liboqs_download_url="https://github.com/open-quantum-safe/liboqs.git"
    oqs_provider_download_url="https://github.com/open-quantum-safe/oqs-provider.git"
    openssl_download_url="https://github.com/openssl/openssl/releases/download/openssl-3.6.1/openssl-3.6.1.tar.gz"

    # Declare the global last tested version SHA variables
    liboqs_tested_sha="5a1a854b0dc9f2141bdc771c555ee60c37950183"
    oqs_provider_tested_sha="1670a8a91bbca997d33e6b6851309d6241cc224c"

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_$openssl_version"
    liboqs_path="$libs_dir/liboqs"
    oqs_provider_path="$libs_dir/oqs_provider"
    comp_energy_tester_path="$libs_dir/comp_energy_tester"
    energy_collector_path="$libs_dir/energy_collector"

    # Declare the global source-code directory path variables
    liboqs_source="$tmp_dir/liboqs_source"
    oqs_provider_source="$tmp_dir/oqs_provider_source"
    openssl_source="$tmp_dir/openssl_$openssl_version"
    energy_collector_source="$tools_dir/energy_collector_source"
    comp_energy_tester_source="$tools_dir/comp_energy_tester"
    energy_collector_source="$tools_dir/energy_collector_source"

    # Set the global flag variables
    install_type=0  # 0=Computational only, 1=Computational+TLS, 2=TLS only, 3=energy collector only
    use_latest_version=0
    user_defined_speed_flag=0
    user_defined_speed_value=0
    special_cmake_handling=0
    use_energy_tools=0
    eng_openssl_download=0
    liboqs_alg_memory_optimisation=0

    # Declare the global flags for enabling OQS-Provider build options
    oqs_enable_algs=0
    encoder_flag="OFF" # string as needed for inserting value into OQS-Provider cmake command

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_user_yes_no() {
    # Helper function to prompt the user for a yes or no response. The function loops until a valid response ('y' or 'n') is 
    # provided and sets the global variable 'user_y_n_response' to 1 for 'yes' and 0 for 'no'.

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
function build_status_checker() {
    # Helper function for checking the exit status of build commands. The function takes the exit status and an string with 
    # the build step name as arguments, and checks if the exit status is non-zero.

    # Define local variables to store the passed function arguments
    local return_status="$1"
    local build_step="$2"
    
    # Check if the passed return status is failed exit code
    if [ "$return_status" -ne 0 ]; then
        echo -e "\n[ERROR] - $build_step failed, please verify the installation and rerun the setup script"
        exit 1
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function output_help() {
    # Helper function for outputting the help message to the user when the --help flag is present or when incorrect arguments 
    # are passed.

    # Output the supported options and their usage to the user
    echo "Usage: setup.sh [options]"
    echo "Options:"
    echo "--latest-dependency-versions     Use the latest available versions of the OQS libraries (may cause compatibility issues)."
    echo "--set-speed-new-value=[int]      Set a new value for MAX_KEM_NUM and MAX_SIG_NUM in OpenSSL's speed.c file."
    echo "--liboqs-memory-optimisation     Enable liboqs algorithm memory optimisation feature for supported algorithms (disabled by default)."
    echo "--help                           Display this help message."
    
}

#-------------------------------------------------------------------------------------------------------------------------------
function parse_args() {
    # Function for parsing command-line arguments and setting global flags based on detected options. Flags control various 
    # aspects of the setup process, such as library versions, speed values, and optional Liboqs build settings.

    # Check for the --help flag and display the help message
    if [[ "$*" =~ --help ]]; then
        output_help
        exit 0
    fi

    # Loop through the passed command line arguments and check for the supported options
    while [[ $# -gt 0 ]]; do

        # Check if the argument is a valid option, then shift to the next argument
        case "$1" in

            --latest-dependency-versions)

                # Output the warning message to the user
                echo -e "\n[NOTICE] Using the latest version of the OQS libraries. This may lead to compatibility issues with this project."
                echo "If the latest upstream changes cause problems, please report them to this project's issue page."
                echo -e "You can re-run the setup script without this flag to use the last tested version of the libraries if issues occur.\n"

                # Determine if the user wishes to proceed with using the latest version
                get_user_yes_no "Would you like to continue using the latest version of the OQS libraries?"

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
                    output_help
                    exit 1
                fi

                shift
                ;;

            --liboqs-memory-optimisation)

                # Set the Liboqs memory optimisation flag to indicate the flag has been passed
                liboqs_alg_memory_optimisation=1

                shift
                ;;

            *)

                # Output an error message if an unknown option is passed
                echo "[ERROR] - Unknown option: $1"
                output_help
                exit 1
                ;;

        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function configure_dirs() {
    # Function for creating the required directory structure for the setup process and handling previous installations.
    # Detects existing installations based on the selected install type, prompts the user for reinstallation, and ensures
    # a clean setup by removing old directories. Also creates a marker file for identifying the root directory path.

    # Declare the required directories array used in the directory check and creation
    required_dirs=("$libs_dir" "$oqs_provider_source" "$tmp_dir" "$test_data_dir" "$alg_lists_dir")

    # Set the default value for the previous install flag
    previous_install=0

    # Track whether a previous energy-tools build is present in the project lib directory
    previous_energy_tools_install=0
    if [ $install_type -ne 3 ] && ([ -d "$comp_energy_tester_path" ] || [ -d "$energy_collector_path" ]); then
        previous_install=1
    elif [ $install_type -eq 3 ] && [ -d "$energy_collector_path" ]; then
        previous_install=1
    fi

    # Check if the dependency libraries have already been installed based on the install type selected
    case $install_type in
        0) [ -d "$liboqs_path" ] || [ "$previous_energy_tools_install" -eq 1 ] && previous_install=1 ;;
        1) [ -d "$liboqs_path" ] || [ -d "$oqs_provider_path" ] || [ "$previous_energy_tools_install" -eq 1 ] && previous_install=1 ;;
        2) [ -d "$oqs_provider_path" ] && previous_install=1 ;;
        3) [ "$previous_energy_tools_install" -eq 1 ] && previous_install=1 ;;
    esac

    # If a previous install is detected, get the user's choice for reinstalling the dependency libraries
    if [ "$previous_install" -eq 1 ]; then

        # Output the warning message and get the user's choice for reinstalling the libraries
        echo -e "\n[WARNING] - Previous Install Detected!!"
        get_user_yes_no "Would you like to reinstall the libraries?"

        # Continue with the setup or exit based on the user's choice
        if [ $user_y_n_response -eq 1 ]; then
            echo -e "Deleting old files and reinstalling...\n"
        else
            echo "Will not reinstall, exiting setup script..."
            exit 0
        fi

    fi

    # Remove old directories depending on the install type selected
    for dir in "${required_dirs[@]}"; do

        # Check if the directory exists and remove it for a clean install
        if [ -d "$dir" ]; then

            # If install type is 2, remove the old OQS-Provider install directory and any existing Liboqs install directory
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

    # Create the hidden pqc_leo_dir_marker.tmp file that is used by the test scripts to determine the root directory path
    touch "$root_dir/.pqc_leo_dir_marker.tmp"

}

#-------------------------------------------------------------------------------------------------------------------------------
function configure_oqs_provider_build() {
    # Function for configuring the OQS-Provider build process by setting optional build flags based on user input.

    # Output the current task to the terminal
    echo -e "\nConfiguring Optional OQS-Provider Build Options:\n"

    # Determine if the user wishes to enable all supported algorithms disabled by default in the OQS-Provider library
    get_user_yes_no "Would you like to enable all algorithms supported by PQC-LEO in the OQS-Provider library that are disabled by default?"

    # Set the oqs_enable_algs build flag option based on the user's response
    if [ $user_y_n_response -eq 1 ]; then
        oqs_enable_algs=1
    else
        oqs_enable_algs=0
    fi

    # Determine if energy measurement tools are set to be used, if so force enabling of the KEM encoders
    if [ $use_energy_tools -eq 0 ]; then

        # If energy measurement tools are not set to be used, determine if the user wishes to enable the KEM encoders option in the OQS-Provider build
        get_user_yes_no "Would you like to enable the KEM encoders option in the OQS-Provider build?"

        # Set the encoder_flag build flag option based on the user's response
        if [ $user_y_n_response -eq 1 ]; then
            encoder_flag="ON"
        else
            encoder_flag="OFF"
        fi

    else
        # Force set the enable encoder flag
        encoder_flag="ON"

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function download_libraries() {
    # Function for downloading the required cryptographic libraries (OpenSSL, Liboqs, OQS-Provider). For the OQS libraries, 
    # it will default to using the last tested versions of the libraries, unless the --latest-dependency-versions command line 
    # argument has been passed to the setup script. The OpenSSL library version will always remain the same.

    # Output the current task to the terminal
    echo -e "\n############################################"
    echo "Downloading Required Cryptographic Libraries"
    echo -e "############################################\n"

    # Check if the install mode requires downloading the OpenSSL library
    if [ $install_type -ne 3 ] || [ $eng_openssl_download -eq 1 ]; then

        # Download OpenSSL 3.6.1 and extract it into the tmp directory
        wget -O "$tmp_dir/openssl_$openssl_version.tar.gz" "$openssl_download_url"
        tar -xf "$tmp_dir/openssl_$openssl_version.tar.gz" -C $tmp_dir
        mv "$tmp_dir/openssl-$openssl_version" "$openssl_source"
        rm "$tmp_dir/openssl_$openssl_version.tar.gz"

        # Ensure that the OpenSSL source directory is present before continuing
        if [ ! -d "$openssl_source" ]; then
            echo -e "\n[ERROR] - The OpenSSL source directory could not be found after downloading, please verify the installation and rerun the setup script"
            exit 1
        fi

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
    # Function for checking and installing the required system dependencies needed for the project's functionality. The function 
    # will check for missing system packages and Python pip packages and install them if they are not present. Finally, the 
    # function will call the download_libraries function used to get the required dependency libraries 
    # (OpenSSL, Liboqs, OQS-Provider).

    # Output the current task to the terminal
    echo -e "\n############################"
    echo "Performing Dependency Checks"
    echo -e "############################\n"

    # Check for missing system packages
    echo "Checking System Packages Dependencies..."
    packages=(
        "git" "astyle" "cmake" "gcc" "ninja-build" "libssl-dev" "python3-pytest" "python3-pytest-xdist" "libserialport-dev"
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

    # Determine the location of the system's Python binary before checking Python dependencies
    if [ -x "$(command -v python3)" ]; then
        python_bin="python3"
    else
        python_bin="python"
    fi

    # Output the current task to the terminal for checking Python dependencies
    echo "Checking Python Dependencies..."

    # Define the required pip packages and their corresponding import names
    required_pip_packages=("pandas" "jinja2" "tabulate" "pyserial")
    required_pip_imports=("pandas" "jinja2" "tabulate" "serial")
    missing_pip_packages=()

    # Loop through the required pip packages to check if any are missing
    for package_index in "${!required_pip_packages[@]}"; do

        # Get the package name and module name for the current index
        package_name="${required_pip_packages[$package_index]}"
        module_name="${required_pip_imports[$package_index]}"

        # Check if the module can be imported using the Python binary, and if not, add it to the missing packages list
        if ! "$python_bin" -c "import $module_name" 2>/dev/null; then
            missing_pip_packages+=("$package_name")
        fi
        
    done

    # Check if any pip packages are missing before checking pip install functionality
    if [[ ${#missing_pip_packages[@]} -ne 0 ]]; then

        # Capture the output of the pip install for error checking
        pip_output=$("$python_bin" -m pip install 2>&1)
        exit_status=$?

        # Check if pip is functioning correctly and if the --break-system-packages flag is needed
        if [ "$exit_status" -ne 0 ]; then

            # Determine the cause of the pip failure
            if echo "$pip_output" | grep -q "error: externally-managed-environment"; then

                # Output the cause to the user and determine if they wish to use the --break-system-packages flag
                echo -e "\nNOTICE: This version of pip requires that either virtual environments be used or the packages be installed system-wide"
                echo -e "This project does not currently support automatic setup of virtual environments.\n"

                # Get the user's choice for using the --break-system-packages flag or not
                while true; do

                    # Output the options for proceeding to the user
                    echo "Please select one of the following options to handle missing pip packages:"
                    echo "1) Use the --break-system-packages flag to install packages system-wide."
                    echo "2) Exit the setup script and manually install the required packages before retrying."

                    # Read in the user's response
                    read -p "Please select from the above options (1/2): " user_input

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
                # No need to do anything as pip is functioning correctly, as it supports installing to the local user installation
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
            "$python_bin" -m pip install "$package"
        done

    else
        echo "All required Python packages are installed and are accessible in the current environment"

    fi

    # Get the version of CMake that is installed on the system
    cmake_version=$(cmake --version | head -n 1 | awk '{print $3}')
    exit_status=$?
    
    if [ "$exit_status" -ne 0 ] || [ -z "$cmake_version" ] || ! [[ "$cmake_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then

        # Output the warning message to the user about the failure to determine the CMake version
        local terminal_width=$(tput cols)
        warning_text="[WARNING] - Failed to determine the version of CMake installed on the system. This will limit the setup script's ability to handle older versions of CMake. "
        warning_text+="This will only cause issues if using a CMake version older than 3.23.0."
        printf "\n%s\n" "$warning_text" | fold -s -w "$terminal_width"

        # Ask the user if they would like to continue with the setup process and determine the next steps based on their response
        get_user_yes_no "Would you like to continue with the setup process anyway?"

        if [ "$user_y_n_response" -eq 1 ]; then
            echo -e "\nContinuing with the setup process...\n"
            special_cmake_handling=0
        else
            echo -e "\nExiting setup process, please update CMake to version 3.23.0 or later and re-run the setup script...\n"
            exit 0
        fi

    else

        # Enable special handling if the installed CMake version is older than 3.23.0
        if [ "$cmake_version" != "3.23.0" ] && printf '%s\n%s\n' "$cmake_version" "3.23.0" | sort -V -C; then
            echo "[NOTICE] - Detected CMake version is older than 3.23.0, enabling special handling for older CMake versions in the setup process"
            sleep 1
            special_cmake_handling=1
        else
            special_cmake_handling=0
        fi

    fi

    # Output the system dependency check completion message
    echo "Dependency checks complete"

    # Downloading the required cryptographic libraries (OpenSSL, Liboqs, OQS-Provider)
    download_libraries

}

#-------------------------------------------------------------------------------------------------------------------------------
function energy_tools_checker() {
    # Helper function for prompting to user on whether they would like to enable the usage of energy measurement tools 
    # in the benchmarking process. A flag is then set on whether to use energy measurement tools or not based on the user's
    # response.

    # Prompt the user for their choice on whether to use energy measurement tools or not
    get_user_yes_no "Would you like to enable the usage of energy measurement tools in the benchmarking process?"

    # Determine the next steps based on the user's response
    if [ $user_y_n_response -eq 1 ]; then
        echo -e "\nEnergy measurement tools will be enabled in the benchmarking process."
        use_energy_tools=1
    else
        echo -e "\nEnergy measurement tools will not be enabled in the benchmarking process."
        use_energy_tools=0
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function openssl_build() {
    # Function for handling the build of the OpenSSL library (version 3.6.1). The function will check if the library is already
    # built and if not, it will build the library using the specified configuration options. The function will call the 
    # modify_openssl_src function to modify the speed.c source code file if the OQS-Provider library is being built with the 
    # enable all disabled algorithms flag.

    # Output the current task to the terminal
    echo -e "\n######################"
    echo "Building OpenSSL-$openssl_version"
    echo -e "######################\n"

    # Output warning message, this may take a while to the user
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

        # Output the current task to the terminal and move into the OpenSSL source directory
        echo "Building OpenSSL Library"
        cd $openssl_source

        # Configure the OpenSSL build to be used by PQC-LEO
        ./config --prefix="$openssl_path" --openssldir="$openssl_path" shared >/dev/null
        exit_status=$?
        build_status_checker "$exit_status" "OpenSSL configuration"

        # Build the OpenSSL library
        make -j $threads >/dev/null
        exit_status=$?
        build_status_checker "$exit_status" "OpenSSL build"

        # Install the OpenSSL library to the PQC-LEO lib directory
        make -j $threads install >/dev/null
        exit_status=$?
        build_status_checker "$exit_status" "OpenSSL installation"

        # Return to the project root directory and output the build completion message to the user
        cd $root_dir
        echo -e "OpenSSL build complete"

        # Check the OpenSSL library directory name before exporting the temp path
        if [[ -d "$openssl_path/lib64" ]]; then
            openssl_lib_path="$openssl_path/lib64"
        else
            openssl_lib_path="$openssl_path/lib"
        fi

        # Exporting the OpenSSL library filepath for the install success check
        export LD_LIBRARY_PATH="$openssl_lib_path:$LD_LIBRARY_PATH"

        # Testing if OpenSSL has been correctly installed
        test_output=$("$openssl_path/bin/openssl" version)

        if [[ "$test_output" != "OpenSSL 3.6.1 27 Jan 2026 (Library: OpenSSL 3.6.1 27 Jan 2026)" ]]; then
            echo -e "\n\n[ERROR] - Installing required OpenSSL version failed, please verify the installation process"
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
    # Function for enabling the ARM PMU and allowing it to be used in user space. The function will also check if the system is 
    # a Raspberry Pi and install the Pi kernel headers if they are not already installed. The function will then enable the PMU 
    # and set the enabled_pmu flag.

    # Checking if the system is a Raspberry Pi and install the Pi kernel headers
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

    # Build the enable_ccr module to allow user space access to the ARM PMU
    make
    exit_status=$?
    build_status_checker "$exit_status" "ARM PMU enable - build"

    # Install the enable_ccr module and return to the root directory
    make install
    exit_status=$?
    build_status_checker "$exit_status" "ARM PMU enable - install"
    cd $root_dir

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
    # On ARM devices, enables user space access to the ARM PMU if needed and replaces default test_mem files with
    # project-specific versions for benchmarking.

    # Set the default value for the custom build flags
    build_flags=""

    # Building Liboqs if the install type selected is 0 or 1
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

            # Set ARM-specific build flags if PMU is enabled, otherwise use default build flags
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

        # Check if the memory optimisation flag should be passed to the Liboqs build process
        if [ $liboqs_alg_memory_optimisation -eq 1 ]; then
            build_flags="${build_flags:-} -DOQS_MEMOPT_BUILD=ON"
        fi

        # Determine if the CMake command requires a custom lib suffix
        if [ $special_cmake_handling -eq 1 ]; then
            if [ "$build_flags" == "" ]; then
                build_flags="-DCMAKE_FIND_LIBRARY_CUSTOM_LIB_SUFFIX=64"
            else
                build_flags="$build_flags -DCMAKE_FIND_LIBRARY_CUSTOM_LIB_SUFFIX=64"
            fi
        fi

        # Configure the Liboqs build with CMake using the specified build options and flags
        cmake -GNinja \
            -S "$liboqs_source/" \
            -B "$liboqs_path/build" \
            -DCMAKE_INSTALL_PREFIX="$liboqs_path" \
            -DOQS_USE_OPENSSL=ON \
            -DOPENSSL_ROOT_DIR="$openssl_path" \
            $build_flags
        exit_status=$?
        build_status_checker "$exit_status" "Liboqs configuration"

        # Build the Liboqs library
        cmake --build "$liboqs_path/build" -- -j $threads
        exit_status=$?
        build_status_checker "$exit_status" "Liboqs build"

        # Install the Liboqs library to the specified install path
        cmake --build "$liboqs_path/build" --target install -- -j $threads
        exit_status=$?
        build_status_checker "$exit_status" "Liboqs installation"

        # Output the install success message to the terminal
        echo -e "\nLiboqs Install Complete"

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function oqs_provider_build() {
    # Function for building the OQS-Provider dependency library. Configures the build process, enables disabled signature 
    # algorithms if requested, patches the generate.yml file, and runs the code generator. Ensures correct paths for OpenSSL 
    # and Liboqs, applies the KEM encoder option, and handles errors for missing or malformed configuration files.

    # Set the default value for the custom build flags
    build_flags=""

    # Output the current task to the terminal
    echo -e "\n#######################"
    echo "Installing OQS-Provider"
    echo -e "#######################\n"

    # Define paths for the generate.yml file
    backup_generate_file="$root_dir/modded_lib_files/generate.yml"
    oqs_provider_generate_file="$oqs_provider_source/oqs-template/generate.yml"

    # Enable disabled algorithms if the user has specified
    if [ $oqs_enable_algs -eq 1 ]; then

        # Call the source code modifier utility script and capture the exit status
        "$util_scripts/source_code_modifier.sh" "oqs_enable_algs"
        exit_status=$?

        # Ensure that the source code modifier script ran successfully
        if [ $exit_status -ne 0 ]; then
            echo -e "\n[ERROR] - The source code modifier script failed to run successfully, please verify the installation and rerun the setup script"
            exit 1
        fi

        # Create a flag file for utilities that need to know the disabled algorithms were enabled
        touch "$tmp_dir/.oqs_prov_algs_enabled.flag"

    else

        # Ensure a flag from an earlier setup does not report disabled algorithms as enabled
        rm -f "$tmp_dir/.oqs_prov_algs_enabled.flag"

    fi

    # Determine if the CMake command requires a custom lib suffix
    if [ $special_cmake_handling -eq 1 ]; then
        if [ "$build_flags" == "" ]; then
            build_flags="-DCMAKE_FIND_LIBRARY_CUSTOM_LIB_SUFFIX=64"
        else
            build_flags="$build_flags -DCMAKE_FIND_LIBRARY_CUSTOM_LIB_SUFFIX=64"
        fi
    fi

    # Configure the OQS-Provider build with CMake using the specified build options and flags
    cmake -S $oqs_provider_source \
        -B "$oqs_provider_path" \
        -DCMAKE_INSTALL_PREFIX="$oqs_provider_path" \
        -DOPENSSL_ROOT_DIR="$openssl_path" \
        -Dliboqs_DIR="$liboqs_path/lib/cmake/liboqs" \
        -DOQS_KEM_ENCODERS="$encoder_flag" \
        $build_flags
    exit_status=$?
    build_status_checker "$exit_status" "OQS-Provider configuration"

    # Build the OQS-Provider library
    cmake --build "$oqs_provider_path" -- -j $(nproc)
    exit_status=$?
    build_status_checker "$exit_status" "OQS-Provider build"

    # Install the OQS-Provider library to the specified install path
    cmake --install "$oqs_provider_path"
    exit_status=$?
    build_status_checker "$exit_status" "OQS-Provider installation"

    # Output the install complete message to the terminal
    echo "OQS-Provider Install Complete"

}

#-------------------------------------------------------------------------------------------------------------------------------
function energy_tools_build() {
    # Function for handling the build of the energy measurement tools used in the benchmarking process. The function will 
    # check if the tools are already built, and if not, it will build the tools using the specified configuration options. 
    
    # Output the current task to the terminal
    echo -e "\n#################################"
    echo "Building Energy Measurement Tools"
    echo -e "#################################\n"

    # Ensure that the build filepath is clean before proceeding
    if [ -d "$comp_energy_tester_path" ] || [ -d "$energy_collector_path" ]; then
        sudo rm -r "$comp_energy_tester_path" "$energy_collector_path"
    fi

    # Determine which lib directories need made for the energy tools based on install type
    if [ $install_type -eq 3 ]; then
        mkdir -p $energy_collector_path
    else
        mkdir -p $comp_energy_tester_path $energy_collector_path
    fi

    # Set the number of CPU threads to use for the build process
    threads=$(nproc)

    # Prepare OpenSSL path for build (if available)
    openssl_build_flag=""
    if [ -d "$openssl_path" ]; then
        openssl_build_flag="OPENSSL_PATH=$openssl_path"
    fi

    # Determine which type of energy tools install needs to be performed
    if [ $install_type -ne 3 ]; then

        # Ensure that Liboqs is present before building the energy measurement tools as comp_energy_collector depends on the library
        if [ ! -d "$liboqs_path" ]; then
            echo -e "\n[ERROR] - Liboqs library not found, the energy measurement tools cannot be built. Please verify and re-run the setup script"
            exit 1
        fi
        
        # Move into the tools directory and build the tools with custom OpenSSL path (if available)
        cd "$tools_dir"
        make -j $threads $openssl_build_flag
        exit_status=$?
        build_status_checker "$exit_status" "tools build"

        # Copy over the compiled binaries and libs to the project lib directory
        cp -r "$tools_dir/comp_energy_tester/build" "$comp_energy_tester_path/"
        cp -r "$tools_dir/energy_collector/build" "$energy_collector_path/"

        # Clean the tools directory to remove the build files
        make clean

    else 

        # Move into the energy_collector directory
        cd "$tools_dir/energy_collector"

        # Build only the energy collector tools with custom OpenSSL path (if available)
        make -j $threads $openssl_build_flag
        exit_status=$?
        build_status_checker "$exit_status" "energy_collector build"

        # Copy over the the compiled energy collector binaries
        cp -r "$tools_dir/energy_collector/build" "$energy_collector_path/"

        # Clean the energy_collector directory to remove the build files
        make clean
    
    fi

    # Return to the project root directory and output the build completion message to the user
    cd $root_dir
    echo -e "Energy measurement tools build complete"

}

#-------------------------------------------------------------------------------------------------------------------------------
function setup_controller() {
    # Function for controlling the setup process based on the user's selected install type. Provides options for computational 
    # performance testing, TLS PQC performance testing, or both. Handles environment configuration, dependency installation, 
    # library builds, and cleanup tasks. Prompts the user for decisions and ensures the setup process is tailored to their 
    # selection.

    # Output current task to the terminal
    echo "######################"
    echo "Install Type Selection"
    echo -e "######################\n"

    # Set the default value of the py_exit_status variable
    py_exit_status=0

    # Get the install type selection from the user
    while true; do

        # Output the install type options to the user
        echo "Please select one of the following build options"
        echo "1 - Computational Performance Testing Only"
        echo "2 - Both Computational and TLS PQC Performance Testing"
        echo "3 - TLS PQC Performance Testing Only (requires existing computational setup)"
        echo "4 - Energy Collector Machine Setup (Only compile energy collector)"
        echo "5 - Exit Setup"

        # Prompt the user for their selection
        read -p "Enter your choice (1-5): " user_opt

        # Determine the setup actions needed based on the user's response
        case "$user_opt" in

            1)
                # Output the selection choice to the terminal
                echo -e "\n###############################################"
                echo "Computational Performance Only Install Selected"
                echo -e "###############################################\n"

                # Determine if user wishes to enable energy measurement tools in the benchmarking process
                energy_tools_checker

                # Configure the setup environment and install the required dependencies
                install_type=0
                configure_dirs
                dependency_install

                # Build the required dependency libraries and clean up
                openssl_build
                liboqs_build

                # Check if the energy tools need to be built and configured
                if [ $use_energy_tools -eq 1 ]; then
                    energy_tools_build
                fi

                # Clean up the tmp directory
                rm -rf $tmp_dir/*

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

                # Determine if user wishes to enable energy measurement tools in the benchmarking process
                energy_tools_checker

                # Configure the setup environment and install the required dependencies
                install_type=1
                configure_dirs
                configure_oqs_provider_build
                dependency_install

                # Build the required dependency libraries and clean up
                openssl_build
                liboqs_build
                oqs_provider_build

                # Check if the energy tools need to be built and configured
                if [ $use_energy_tools -eq 1 ]; then
                    energy_tools_build
                fi

                # Clean up the tmp directory
                rm -rf $tmp_dir/*

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

                # Determine if user wishes to enable energy measurement tools in the benchmarking process
                energy_tools_checker

                # Configure the setup environment and install the required dependencies
                install_type=2
                configure_dirs
                configure_oqs_provider_build
                dependency_install

                # Build OpenSSL 3.6.1
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

                # Handle energy tools usage for TLS-only setup. Reuse existing tools when present, otherwise build the tools
                if [ $use_energy_tools -eq 1 ]; then

                    # Check if a previous computational install already provides both tools
                    if [ -d "$comp_energy_tester_path" ] && [ -d "$energy_collector_path" ]; then
                        echo -e "\n[NOTICE] - Existing energy measurement tools detected, skipping energy tools build."
                    else
                        echo -e "\n[NOTICE] - Energy tools requested but not found from a previous computational setup."
                        echo -e "Attempting to build energy measurement tools now...\n"
                        energy_tools_build
                    fi

                fi

                # Clean up the tmp directory
                rm -rf $tmp_dir/*

                # Check if the Liboqs alg-list files are present before deciding which alg-list files need generating
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
                echo -e "\n#######################################"
                echo "Energy Collector Machine Setup Selected"
                echo -e "#######################################\n"

                # Configure the setup environment and install the required dependencies
                install_type=3
                configure_dirs
                dependency_install

                # Check if a previous install of OpenSSL is available
                if [ ! -d "$openssl_path" ]; then

                    # Ask the user if they wish to build OpenSSL 3.6.1 or use the system install for the energy collector
                    echo "[NOTICE] - The PQC-LEO install of OpenSSL 3.6.1 is not currently present."

                    # Prompt the user for their selection until a valid choice is made
                    while true; do

                        # Output the options to the user
                        echo "The following options are available:"
                        echo "1) - Download and build OpenSSL 3.6.1 for the energy collector"
                        echo "2) - Use the system OpenSSL install for the energy collector"
                        read -p "Enter selected option (1/2): " eng_openssl_user_choice

                        # Check and validate the selected option
                        if [ "$eng_openssl_user_choice" -eq 1 ]; then
                            eng_openssl_download=1
                            echo -e "\nProceeding with OpenSSL 3.6.1 build for the energy collector..."
                            download_libraries
                            openssl_build
                            break

                        elif [ "$eng_openssl_user_choice" -eq 2 ]; then
                            echo -e "\nProceeding with system OpenSSL install for the energy collector..."
                            break

                        else
                            echo -e "\n[WARNING] - Invalid option selected, please select either option 1 or option 2\n"
                        fi
                    
                    done

                fi

                # Build the energy measurement tools
                energy_tools_build

                break
                ;;

            5)

                # Output the selection choice to the terminal
                echo "Exiting Setup!"
                exit 1
                ;;

            *)

                # Output the invalid option message to the user
                echo "Invalid option, please select a valid option value (1-4)"
                ;;

        esac

    done

    # Configure the flag file for the KEM encoders option in the OQS-Provider build for use by the testing scripts
    if [ "$encoder_flag" == "ON" ]; then
        touch "$tmp_dir/kem_encoders_enabled.flag"

    elif [ "$encoder_flag" == "OFF" ]; then

        # Remove the flag file if present in the tmp directory, as the KEM encoders are disabled
        if [ -f "$tmp_dir/kem_encoders_enabled.flag" ]; then
            rm "$tmp_dir/kem_encoders_enabled.flag"
        fi

    fi

    # Configure the flag file for the energy tools option in the benchmarking process for use by the testing scripts
    if [ $use_energy_tools -eq 1 ]; then
        touch "$tmp_dir/energy_tools_enabled.flag"
    else
    
        # Remove the flag file if present in the tmp directory, as the energy measurement tools are not enabled
        if [ -f "$tmp_dir/energy_tools_enabled.flag" ]; then
            rm "$tmp_dir/energy_tools_enabled.flag"
        fi

    fi

    # Output that there was an issue with the Python utility script that creates the alg-list files
    if [ "$py_exit_status" -ne 0 ]; then
        echo -e "\n[ERROR] - creating algorithm list files failed, please verify both setup and python scripts and rerun setup!!!"
        echo -e "If the issue persists, you may want to consider re-cloning the repo and rerunning the setup script\n"

    elif [ -z "$py_exit_status" ]; then
        echo -e "\nThe Python get_algorithms script did not return an exit status, please verify the script and rerun setup\n"
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Entry point for the PQC-LEO setup script. Initialises the environment, parses command-line arguments, and delegates the
    # setup process to the setup_controller function.

    # Output the welcome message to the terminal
    echo "####################"
    echo "PQC-LEO Setup Script"
    echo -e "####################\n"

    # Setup the base environment, global variables, and directory paths
    setup_base_env

    # Parse the command line arguments passed to the script, if any
    if [ "$#" -gt 0 ]; then
        parse_args "$@"
    fi

    # Call the setup controller function to handle the setup process
    setup_controller

    # Output the setup complete message to the terminal
    echo -e "\n\nSetup complete, completed builds can be found in the builds directory"

}
main "$@"

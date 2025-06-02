#!/bin/bash

# Copyright (c) 2023-2025 Callum Turino
# SPDX-License-Identifier: MIT

# Utility script for toggling the OpenSSL configuration settings in the openssl.cnf file to enable or 
# disable post-quantum cryptographic key generation. It comments or uncomments default group directives
# required for compatibility with scheme groups supported by the OQS-Provider when integrated with OpenSSL 3.5.0.

#-------------------------------------------------------------------------------------------------------------------------------
function output_help_message() {
    # Helper function for outputting the help message to the user when the --help flag is present or when incorrect arguments are passed

    # Output the supported options and their usage to the user
    echo "Usage: configure-openssl-cnf.sh [options]"
    echo "Options:"
    echo "  0                     Modify default OpenSSL Configuration file to include OQS-Provider directives (for setup only)"
    echo "  1                     Configure OpenSSL Configuration for Key Generation mode"
    echo "  2                     Configure OpenSSL for TLS testing mode"
    echo "  --help                Display this help message and exit"

}

#-------------------------------------------------------------------------------------------------------------------------------
function parse_args() {
    # Function for parsing the command line arguments passed to the script. Based on the detected arguments, the function will 
    # set the relevant global flags and parameter variables that are used throughout the test control process.

    # Check if the help flag is passed at any position in the command line arguments
    if [[ "$*" =~ --help ]]; then
        output_help_message
        exit 0
    fi

    # Set the default option selected flag 
    mode_selected="False"

    # Loop through the passed command line arguments and check for the supported options
    while [[ $# -gt 0 ]]; do

        # Check if the argument is a valid option, then shift to the next argument
        case "$1" in

            0)

                # Set the configure mode if no mode has been yet
                if [ "$mode_selected" == "False" ]; then
                    configure_mode=0
                    mode_selected="True"

                else
                    echo "[ERROR] - Only one mode can be selected at a time"
                    exit 1
                fi

                shift
                ;;

            1)

                # Set the configure mode if no mode has been yet
                if [ "$mode_selected" == "False" ]; then
                    configure_mode=1
                    mode_selected="True"

                else
                    echo "[ERROR] - Only one mode can be selected at a time"
                    exit 1
                fi

                shift
                ;;

            2)
                # Set the configure mode if no mode has been yet
                if [ "$mode_selected" == "False" ]; then
                    configure_mode=2
                    mode_selected="True"

                else
                    echo "[ERROR] - Only one mode can be selected at a time"
                    exit 1
                fi

                shift
                ;;

            *)

                # Output the error message for unknown options and display the help message
                echo -e "[ERROR] - Invalid argument passed to configure-openssl-cnf.sh"
                output_help_message
                exit 1
                ;;

        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function setup_base_env() {
    # Function for setting up the global environment variables for the test suite. This includes determining the root directory 
    # by tracing the script's location, and configuring paths for libraries, test data, and temporary files.

    # Determine the directory that the script is being executed from
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    # Try and find the .dir_marker.tmp file to determine the project's root directory
    current_dir="$script_dir"

    # Continue moving up the directory tree until the .pqc_eval_dir_marker.tmp file is found
    while true; do

        # Check if the .pqc_eval_dir_marker.tmp file is present
        if [ -f "$current_dir/.pqc_eval_dir_marker.tmp" ]; then
            root_dir="$current_dir"  # Set root_dir to the directory, not including the file name
            break
        fi

        # Move up a directory and store the new path
        current_dir=$(dirname "$current_dir")

        # If the system's root directory is reached and the file is not found, exit the script
        if [ "$current_dir" == "/" ]; then
            echo -e "Root directory path file not present, please ensure the path is correct and try again."
            exit 1
        fi

    done

    # Declare the main directory path variables based on the project's root dir
    libs_dir="$root_dir/lib"
    tmp_dir="$root_dir/tmp"
    test_data_dir="$root_dir/test_data"
    test_scripts_path="$root_dir/scripts/test_scripts"

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_3.5.0"
    liboqs_path="$libs_dir/liboqs"
    oqs_provider_path="$libs_dir/oqs_provider"

    # Ensure that the OpenSSL library is present before proceeding
    if [ ! -d "$openssl_path" ]; then
        echo "[ERROR] - OpenSSL library not found in $libs_dir"
        exit 1
    fi

    # Check the OpenSSL library directory path
    if [[ -d "$openssl_path/lib64" ]]; then
        openssl_lib_path="$openssl_path/lib64"
    else
        openssl_lib_path="$openssl_path/lib"
    fi

    # Export the OpenSSL library filepath
    export LD_LIBRARY_PATH="$openssl_lib_path:$LD_LIBRARY_PATH"

}

#-------------------------------------------------------------------------------------------------------------------------------
function configure_conf_statements() {
    # Function to modify the OpenSSL configuration (openssl.cnf) between standard and PQC testing modes. 
    # Standard mode comments out custom group settings, while PQC mode enables them for post-quantum 
    # key generation with the OQS-Provider.

    # Declare the required local variables
    local openssl_conf_path="$openssl_path/openssl.cnf"

    # Set the configurations based on the configuration mode passed
    if [ "$configure_mode" -eq 0 ]; then

        # Set the OpenSSL configuration array to append onto the end of the file
        conf_changes=(
            "[ssl_sect]"
            "system_default = system_default_sect"
            "[system_default_sect]"
            "Groups = \$ENV::DEFAULT_GROUPS"
        )

        # Patch the OpenSSL configuration file to have the correct provider settings
        sed -i '/^\[openssl_init\]/,/^\[/{ 
            s/^providers *=.*/providers  = provider_sect/
            /ssl_conf[[:space:]]*=/d
            /providers  = provider_sect/a\
ssl_conf   = ssl_sect
        }' "$openssl_conf_path"


        for conf_change in "${conf_changes[@]}"; do
            echo $conf_change >> "$openssl_conf_path"
        done


    elif [ "$configure_mode" -eq 1 ]; then

        # Comment out PQC-related configuration lines for standard mode
        sed -i 's/^ssl_conf   = ssl_sect$/#ssl_conf   = ssl_sect/' "$openssl_conf_path"
        sed -i 's/^\[ssl_sect\]$/#[ssl_sect]/' "$openssl_conf_path"
        sed -i 's/^system_default = system_default_sect$/#system_default = system_default_sect/' "$openssl_conf_path"
        sed -i 's/^\[system_default_sect\]$/#[system_default_sect]/' "$openssl_conf_path"
        sed -i 's/Groups = \$ENV::DEFAULT_GROUPS/#Groups = \$ENV::DEFAULT_GROUPS/' $openssl_conf_path

    elif [ "$configure_mode" -eq 2 ]; then

        # Uncomment PQC-related configuration lines for PQC testing mode
        sed -i 's/^#ssl_conf   = ssl_sect$/ssl_conf   = ssl_sect/' "$openssl_conf_path"
        sed -i 's/^#\[ssl_sect\]$/[ssl_sect]/' "$openssl_conf_path"
        sed -i 's/^#system_default = system_default_sect$/system_default = system_default_sect/' "$openssl_conf_path"
        sed -i 's/^#\[system_default_sect\]$/[system_default_sect]/' "$openssl_conf_path"
        sed -i 's/^#Groups = \$ENV::DEFAULT_GROUPS/Groups = \$ENV::DEFAULT_GROUPS/' $openssl_conf_path

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Main function for controlling the utility script

    # Declare the global configuration mode flag
    configure_mode=""

    # Ensure that arguments have been passed to the script and parse them
    if [[ $# -gt 0 ]]; then
        parse_args "$@"

    else
        echo "[ERROR] - No arguments passed to configure-openssl-cnf.sh"
        output_help_message
        exit 1

    fi

    # Setup the base environment for the utility script
    setup_base_env

    # Configure the OpenSSL configuration file based on the selected mode
    configure_conf_statements

}
main "$@"
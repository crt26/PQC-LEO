#!/bin/bash

# Copyright (c) 2023-2025 Callum Turino
# SPDX-License-Identifier: MIT

# This utility script provides internal source code modification utilities used exclusively by the main setup script 
# in the PQC-evaluation-tools benchmarking suite. It is not intended to be executed manually. Instead, it is automatically
# invoked during the setup process to modify source files in the OQS-Provider and OpenSSL libraries as required for
# benchmarking configuration.

# The first argument passed to this script must always specify the modification tool to use (e.g., `oqs_enable_algs`
# or `modify_openssl_src`). Subsequent arguments must include the required flags and values specific to the selected
# tool. These include options such as enabling specific algorithms, adjusting OpenSSL internal constants, or applying
# user-defined values.

# The script includes validation checks, fallback logic, and interactive prompts to handle edge cases or unexpected
# source states, ensuring a safe and guided modification process.

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
    # when incorrect arguments are passed. It will determine which modification tool is being used
    # and output the relevant help message for that tool.

    # Determine which modification tool is being used and set the help message accordingly
    if [ "$modification_tool" == "oqs_enable_algs" ]; then

            # Output the help message for the oqs_enable_algs modification tool
            echo "Usage: source_code_modifier.sh oqs_enable_algs [options]"
            echo "Required Flags:"
            echo "  --enable-hqc-algs=[0|1]        Set to 1 to enable the HQC KEM algorithms in the OQS-Provider library."
            echo "  --enable-disabled-algs=[0|1]   Set to 1 to enable all disabled signature algorithms in the OQS-Provider library."
            echo "  --help                         Display this help message."
            
    elif [ "$modification_tool" == "modify_openssl_src" ]; then

        # Output the help message for the modify_openssl_src modification tool
        echo "Usage: source_code_modifier.sh modify_openssl_src [options]"
        echo "Required Flags:"
        echo "  --user-defined-flag=[0|1]           Set to 1 to use a user-defined value for MAX_KEM_NUM and MAX_SIG_NUM in OpenSSL's speed.c file."
        echo "  --user-defined-speed-value=[int]    Set a new value for MAX_KEM_NUM and MAX_SIG_NUM in OpenSSL's speed.c file. Can be 0 if --user-defined-flag is 0."
        echo "  --help                              Display this help message."

    else

        # Output an error message if the modification tool is unknown
        echo "[ERROR] - Unknown modification tool passed as first argument: $modification_tool"
        exit 1

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function parse_args() {
    # Function for parsing command-line arguments and setting global flags based on detected options.
    # Supports arguments for both oqs_enable_algs and modify_openssl_src tools, with validation for required flags.

    # Check for the --help flag and display the help message
    if [[ "$*" =~ --help ]]; then
        output_help_message
        exit 0
    fi

    # Determine which set of arguments need to be parsed based on the supplied modification tool
    if [ "$modification_tool" == "oqs_enable_algs" ]; then

        # Loop through the passed command line arguments and check for the supported options
        while [[ $# -gt 0 ]]; do

            # Check if the argument is a valid option, then shift to the next argument
            case "$1" in

                --enable-hqc-algs=*)

                    # Set the enable_hqc flag based on the value passed
                    enable_hqc=$(echo "$1" | cut -d '=' -f 2)

                    # Ensure that value attached to the flag is either 0 or 1
                    if [[ "$enable_hqc" != "0" && "$enable_hqc" != "1" ]]; then
                        echo "[ERROR] - Invalid value for --enable-hqc-algs, must be 0 or 1"
                        output_help_message
                        exit 1
                    fi
                    
                    shift
                    ;;

                --enable-disabled-algs=*)

                    # Set the enable_disabled_algs flag based on the value passed
                    enable_disabled_algs=$(echo "$1" | cut -d '=' -f 2)

                    # Ensure that value attached to the flag is either 0 or 1
                    if [[ "$enable_disabled_algs" != "0" && "$enable_disabled_algs" != "1" ]]; then
                        echo "[ERROR] - Invalid value for --enable-disabled-algs, must be 0 or 1"
                        output_help_message
                        exit 1
                    fi
                    
                    shift
                    ;;
                    
                *)

                    # Output an error message if an unknown option is passed
                    echo "[ERROR] - Unknown option passed to the utility script: $1"
                    output_help_message
                    exit 1
                    ;;

            esac

        done

        # Ensure that all the required flags have been set before continuing
        if [ -z "$enable_hqc" ] || [ -z "$enable_disabled_algs" ]; then
            echo "[ERROR] - Missing required command line arguments for the oqs_enable_algs function in the utility script"
            output_help_message
            exit 1
        fi

    elif [ "$modification_tool" == "modify_openssl_src" ]; then

        # Loop through the passed command line arguments and check for the supported options
        while [[ $# -gt 0 ]]; do

            # Check if the argument is a valid option, then shift to the next argument
            case "$1" in

                --user-defined-flag=*)

                    # Extract the value from the argument and ensure it is either 0 or 1
                    user_defined_speed_flag=$(echo "$1" | cut -d '=' -f 2)

                    # Ensure that value attached to the flag is either 0 or 1
                    if [[ "$user_defined_speed_flag" != "0" && "$user_defined_speed_flag" != "1" ]]; then
                        echo "[ERROR] - Invalid value for --user-defined-flag, must be 0 or 1"
                        output_help_message
                        exit 1
                    fi

                    shift
                    ;;
            

                --user-defined-speed-value=*)

                    # Set the user defined speed value based on the value passed
                    user_defined_speed_value=$(echo "$1" | cut -d '=' -f 2)

                    # Check if it's a valid positive integer
                    if ! [[ "$user_defined_speed_value" =~ ^[0-9]+$ ]]; then
                        echo "[ERROR] - Invalid value for --user-defined-speed-value, must be a positive integer"
                        output_help_message
                        exit 1
                    fi

                    shift
                    ;;

                *)

                    # Output an error message if an unknown option is passed
                    echo "[ERROR] - Unknown option passed to the utility script: $1"
                    output_help_message
                    exit 1
                    ;;

            esac

        done

        # Ensure that if the user_defined_speed_flag is set, both user_defined_speed_flag and user_defined_speed_value are set
        if [ -z "$user_defined_speed_flag" ] || [ -z "$user_defined_speed_value" ]; then
            echo "[ERROR] - Missing required command line arguments for the modify_openssl_src function in the utility script"
            output_help_message
            exit 1
        fi

        # Ensure that if the user_defined_speed_flag is set that user defined speed value is not 0
        if [ "$user_defined_speed_flag" -eq 1 ] && [ "$user_defined_speed_value" -eq 0 ]; then
            echo "[ERROR] - The new speed value for the MAX_KEM_NUM/MAX_SIG_NUM variables can not be 0"
            exit 1
        fi

    else
        echo "[ERROR] - Unknown modification tool passed as first argument: $modification_tool"
        exit 1

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function setup_base_env() {
    # Function for setting up the foundational global variables required for the test suite. This includes determining the project's root directory,
    # establishing paths for libraries, scripts, and test data, and validating the presence of required libraries. Additionally, it sets up environment
    # variables for control ports and sleep timers, ensuring proper configuration for the test suite's execution.

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
    util_scripts="$root_dir/scripts/utility_scripts"

    # Declare the global dependency library version variables
    openssl_version="3.5.0"

    # Declare the global source-code directory path variables
    liboqs_source="$tmp_dir/liboqs_source"
    oqs_provider_source="$tmp_dir/oqs_provider_source"
    openssl_source="$tmp_dir/openssl_$openssl_version"

}

#-------------------------------------------------------------------------------------------------------------------------------
function set_new_speed_values() {
    # Helper function for setting the new hardcoded MAX_KEM_NUM/MAX_SIG_NUM variable values in the OpenSSL speed.c file
    # This function is used by the modify_openssl_src modification tool to set the new values for those variables.

    # Set the passed function arguments to local variables
    local passed_filepath="$1"
    local passed_value="$2"

    # Update the MAX_KEM_NUM and MAX_SIG_NUM values in the speed.c file
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
    # Function for modifying OpenSSL's speed.c file to adjust MAX_KEM_NUM and MAX_SIG_NUM values.
    # Handles errors, fallback values, and user-defined adjustments. It requires that the 
    # user_defined_speed_flag and user_defined_speed_value flags have been passed to the script.

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
        if [ $user_y_n_response -eq 1 ]; then
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
        if [ $user_y_n_response -eq 1 ]; then
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
        util_output=$(python3 "get_algorithms.py" "4" 2>&1)
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

                if [ $user_y_n_response -eq 1 ]; then
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
    echo -e "[NOTICE] - The MAX_KEM_NUM/MAX_SIG_NUM values in the OpenSSL speed.c file have been successfully modified to $new_value\n"

}

#-------------------------------------------------------------------------------------------------------------------------------
function enable_oqs_algs() {
    # Function for enabling disabled algorithms in the OQS-Provider library.
    # Modifies generate.yml to enable selected KEMs/signatures and runs generate.py to apply changes.
    # It requires that the enable_disabled_algs and enable_hqc flags have been passed to the script.

    # Define paths for the generate.yml file
    backup_generate_file="$root_dir/modded_lib_files/generate.yml"
    oqs_provider_generate_file="$oqs_provider_source/oqs-template/generate.yml"

    # Ensure that the generate.yml file is present and determine action based on its presence
    if [ ! -f  "$oqs_provider_generate_file" ]; then

        # Output the error message to the user and prompt for their choice on proceeding
        echo -e "\n[WARNING] - The generate.yml file is missing from the OQS-Provider library, it is possible that the library no longer supports this feature"
        get_user_yes_no "Would you like to continue with the setup process anyway?"

        # Determine the next action based on the user's response
        if [ $user_y_n_response -eq 0 ]; then
            echo -e "Exiting setup script..."
            exit 1
        else
            echo "Continuing setup process..."
            return 0
        
        fi

    fi

    # Determine if the disabled signature algorithms should be enabled
    if [ $enable_disabled_algs -eq 1 ]; then

        # Ensure that the generate.yml file still follows the enable: true/enable: false format before proceeding
        if ! grep -q "enable: true" "$oqs_provider_generate_file" || ! grep -q "enable: false" "$oqs_provider_generate_file"; then

            # Output the error message to the user and prompt for their choice on proceeding
            echo -e "\n[WARNING] - The generate.yml file in the OQS-Provider library does not follow the expected format"
            echo -e "this setup script cannot automatically enable all disabled signature algorithms\n"
            get_user_yes_no "Would you like to continue with the setup process anyway?"

            # Determine the next action based on the user's response
            if [ $user_y_n_response -eq 0 ]; then
                echo -e "Exiting setup script..."
                exit 1
            else
                echo "Continuing setup process..."
                return 0
            fi

        fi

        # Modify the generate.yml file to enable all the disabled signature algorithms
        sed -i 's/enable: false/enable: true/g' "$oqs_provider_generate_file"
        #sed -i 's/enable_kem: false/enable_kem: true/g' "$oqs_provider_generate_file"

        # Check if the generate.yml file was successfully modified
        if ! grep -q "enable: true" "$oqs_provider_generate_file"; then
            echo -e "\n[ERROR] - Enabling all disabled signature algorithms in the OQS-Provider library failed, please verify the setup and run a clean install"
            exit 1
        fi

    fi

    # Determine if the HQC KEM algorithms should be enabled
    if [ $enable_hqc -eq 1 ]; then

    tmp_file=$(mktemp)
awk '
  BEGIN { hqc_block = 0 }
  /family: .HQC./ { hqc_block = 1 }
  /family:/ && $0 !~ /HQC/ { hqc_block = 0 }
  hqc_block && /enable_kem: false/ { sub(/enable_kem: false/, "enable_kem: true") }
  { print }
' "$oqs_provider_generate_file" > "$tmp_file" && mv "$tmp_file" "$oqs_provider_generate_file"

    fi

    # Check if the genreate.py script needs executed
    if [ $enable_disabled_algs -eq 1 ] || [ $enable_hqc -eq 1 ]; then

        # Run the generate.py script to enable all disabled signature algorithms in the OQS-Provider library
        export LIBOQS_SRC_DIR="$liboqs_source"
        cd $oqs_provider_source
        python3 $oqs_provider_source/oqs-template/generate.py
        cd $root_dir

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function modifier_entrypoint() {
    # Entrypoint function for the script. Determines the selected modification tool,
    # parses relevant arguments, and calls the appropriate handler function.

    # Setup the base environment and parse the command line arguments
    setup_base_env

    # Ensure that arguments are passed to the script and store the first argument as the modification tool
    if [ $# -gt 0 ]; then
        modification_tool="$1"
        shift
    else
        echo -e "[ERROR] - No arguments have been passed to the script"
        exit 1
    fi

    # Check if the modification tool is a valid option and call the appropriate functions
    case "$modification_tool" in

        # Enable all disabled OQS-Provider algorithms
        oqs_enable_algs)

            # parse the command line arguments for the enable_oqs_algs function
            parse_args "$@"

            # Call the function to enable all disabled OQS-Provider algorithms
            enable_oqs_algs

            ;;

        # Modify OpenSSL's speed.c file to adjust MAX_KEM_NUM/MAX_SIG_NUM values
        modify_openssl_src)

            # Parse the command line arguments for the modify_openssl_src function
            parse_args "$@"

            # Call the function to modify OpenSSL's speed.c file
            modify_openssl_src
            ;;

        *)

            # Output an error message if an unknown modification tool is passed
            echo "[ERROR] - Unknown modification tool passed as first argument: $modification_tool"
            echo "The required modification tool must be the first argument passed to the script."
            exit 1
            ;;

    esac

}
modifier_entrypoint "$@"
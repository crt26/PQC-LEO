#!/bin/bash

# Copyright (c) 2023-2026 Callum Turino
# SPDX-License-Identifier: MIT

# Script for controlling the automated PQC computational performance energy benchmarking. It accepts test parameters
# from the user and executes the comp_energy_tester binary after configuring the required environment and system state.
# The script accepts command line arguments to indicate that the user wishes to make use of the customisation options 
# that are available within the energy testing components of the PQC-LEO framework. If these flags are set, the script
# will call the relevant sub-scripts with the required flags to enable the customisation options.

# Declare global script variables
sys_state_configure_flag="--set-default" # options (--set-default (default method) | --set-custom)
sys_state_set_ok=0
trap_cleanup_done=0

#-------------------------------------------------------------------------------------------------------------------------------
function output_help() {
    # Helper function for outputting the help message to the user when the --help flag is present or when incorrect arguments 
    # are passed.

    # Output the supported options and their usage to the user
    echo "Usage: pqc_performance_energy_test.sh [options]"
    echo "Options:"
    echo "--use-custom-sys-state            Used to indicate that custom system state values should be set for the test instead of the default values"
    echo "--use-custom-eng-control-ports    Enable the use of custom network control ports for energy testing control signalling"
    echo "--help                            Display the help message"
    
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
function parse_args() {
    # Function for parsing the command line arguments passed to the script. Based on the detected arguments, the function will 
    # set the relevant global flags that are used throughout the setup process.

    # Check if the help flag is passed at any position in the command line arguments
    if [[ "$*" =~ --help ]]; then
        output_help
        exit 0
    fi

    # Loop through the passed command line arguments and check for the supported options
    while [[ $# -gt 0 ]]; do

        # Check if the argument is a valid option, then shift to the next argument
        case "$1" in

            --use-custom-sys-state)
                sys_state_configure_flag="--set-custom"
                shift
                ;;

            --use-custom-eng-control-ports)
                use_custom_eng_control_ports=1
                shift
                ;;

            --help)
                output_help
                exit 0
                ;;

            *)
                echo -e "Invalid argument: $1\n"
                output_help
                exit 1
                ;;

        esac
    
    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function setup_env() {
    # Function for setting up the basic global variables for the script. This includes setting the root directory, the global 
    # library paths for the test suite, and creating the algorithm arrays. The function establishes the root path by determining 
    # the path of the script and using this, determines the root directory of the project.
        
    # Determine the directory that the script is being run from
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    # Try and find the .pqc_leo_dir_marker.tmp file to determine the project's root directory
    current_dir="$script_dir"

    # Continue moving up the directory tree until the .pqc_leo_dir_marker.tmp file is found
    while true; do

        # Check if the .pqc_leo_dir_marker.tmp file is present
        if [ -f "$current_dir/.pqc_leo_dir_marker.tmp" ]; then
            root_dir="$current_dir"
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
    util_scripts="$root_dir/scripts/utility_scripts"

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_4.0.3"
    provider_path="$libs_dir/oqs_provider/lib"
    provider_flags="-provider default -provider oqsprovider -provider-path $provider_path"

    # If the use PQC-LEO OpenSSL build with energy testing flag is present, set the OpenSSL path to the PQC-LEO OpenSSL build
    if [ -f "$tmp_dir/energy_tools_pqc_leo_openssl.flag" ]; then

        # Check if the PQC-LEO OpenSSL build is present before proceeding, if not output an error message and exit the script
        if [ ! -d "$openssl_path" ]; then
            echo -e "[ERROR] - PQC-LEO OpenSSL build not found, please ensure the build is present and try again."
            exit 1
        fi

        # Use the same lib64-then-lib selection order as the energy-tool makefiles
        if [[ -f "$openssl_path/lib64/libcrypto.so" ]]; then
            openssl_lib_path="$openssl_path/lib64"

        elif [[ -f "$openssl_path/lib/libcrypto.so" ]]; then
            openssl_lib_path="$openssl_path/lib"

        else
            echo "[ERROR] - Selected OpenSSL installation does not contain libcrypto.so: $openssl_path"
            exit 1

        fi

        # Export the LD_LIBRARY_PATH to include the OpenSSL lib directory for the collector binary
        export LD_LIBRARY_PATH="$openssl_lib_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    fi

    # Define the temp cert/key storage directory path
    temp_test_storage="$tmp_dir/energy_test_certs"

    # Ensure that the temp cert/key storage directory is present and empty
    if [[ -d "$temp_test_storage" ]]; then
        rm -rf "$temp_test_storage"
    fi
    mkdir -p "$temp_test_storage"

    # Define path to energy testing util scripts
    energy_collector_path="$libs_dir/energy_collector"
    comp_tester_path="$libs_dir/comp_energy_tester"
    comp_tester_bin="$comp_tester_path/build/bin/comp_energy_tester"

    # Ensure that the energy tools are built
    if [ ! -d "$energy_collector_path" ]; then
        echo -e "[ERROR] - Energy collector tools not built, please build the tools before running the energy tests."
        exit 1
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function sys_state_configure() {
    # Function for configuring the system state for the performance energy test. The function will call the system state configurer 
    # utility script with the relevant flags based on the stage of the test (start or end) and the global configuration flag for the 
    # system state. Depending on whether the user has chosen to use the default state or custom state, the utility script will be called 
    # with the relevant flags. A trap is set to call this function with the "test_end" argument to restore the system state back to 
    # its original configuration.

    # Store the passed argument in a local variable
    local config_stage="$1"
    local restore_status=0
    local state_file="/tmp/.orig_cpu_governor"
    local state_out=""
    local exit_status=0

    # Determine which configuration actions to take based on the passed argument
    if [[ "$config_stage" == "test_start" ]]; then

        # Set the system state for the test and capture the target CPU core for the test from the util script's output
        state_out="$("$util_scripts/system_state_configurer.sh" "$sys_state_configure_flag" 2>&1)"
        exit_status=$?

        # Check that there was no errors with setting the system state
        if [ $exit_status -ne 0 ]; then

            # Output the warning to the user
            echo "$state_out" >&2
            echo -e "[ERROR] - Failed to set system state for the test, please check the error message below and try again."

            # Ask the user if they wish to continue with the test despite the failure to set the system state
            get_user_yes_no "Do you wish to continue with the test despite the failure to set the system state?"

            # Determine whether to continue or exit based on the user's response
            if [ "$user_y_n_response" -eq 1 ]; then

                # Output the warning and force the CPU core to be 0
                echo -e "Continuing with the test, but results may be inaccurate due to incorrect system state configuration.\n"
                TARGET_CPU_CORE=0
                sys_state_set_ok=0
                return 0

            else

                # Output the message to the user and exit the script
                echo -e "Exiting the test, please resolve the system state configuration issue and try again."
                exit 1

            fi
            
        fi

        # Extract the TARGET_CPU_CORE value from the output
        TARGET_CPU_CORE=$(echo "$state_out" | awk -F'=' '/^TARGET_CPU_CORE=/{print $2; exit}')

        # Ensure that the TARGET_CPU_CORE value is a valid integer before exporting it as an environment variable
        if ! [[ "$TARGET_CPU_CORE" =~ ^[0-9]+$ ]]; then
            echo "[ERROR] - Failed to parse TARGET_CPU_CORE from system_state_configurer output." >&2
            echo "[DEBUG] - Raw output: $state_out" >&2
            exit 1
        fi

        # Set the sys_state_set_ok flag to indicate that the system state has been set successfully
        sys_state_set_ok=1
    
    elif [[ "$config_stage" == "test_end" ]]; then

        # Skip restore if system state was not set successfully and the user continued anyway
        if [ "$sys_state_set_ok" -eq 0 ]; then
            echo -e "\n"
            return 0
        fi

        # Restore the CPU frequency scaling governor to the original setting
        "$util_scripts/system_state_configurer.sh" --restore
        restore_status=$?

        # Check if the restore was successful, if not output an error message and return a non-zero exit status
        if [ $restore_status -ne 0 ]; then
            echo "[ERROR] - Failed to restore system state." >&2
            return 1
        fi

        # Reset the sys_state_set_ok flag to indicate that the system state has been restored
        sys_state_set_ok=0
        
    else
        echo -e "[ERROR] - Invalid argument passed to sys_state_configure function, please check the code and try again."
        exit 1
        
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function trap_handler() {
    # Function for handling the traps set for EXIT, INT, and TERM signals. The function takes a single argument which indicates 
    # the type of trap that was triggered (exit or interrupt). The function ensures that the system state is restored to its default 
    # configuration when the script exits, whether this is due to normal completion or an interrupt signal.

    # Preserve the script's exit status so trap cleanup does not hide command failures
    local prior_exit_status=$?

    # Store the passed trap handler flag
    local trap_handler_flag="$1"
    local cleanup_status=0

    # Prevent duplicate cleanup when INT/TERM is followed by EXIT
    if [ "$trap_cleanup_done" -eq 1 ]; then
        if [ "$trap_handler_flag" == "interrupt" ]; then
            exit 130
        fi
        return 0
    fi
    trap_cleanup_done=1

    # Disable traps during cleanup to avoid recursive trap execution
    trap - EXIT INT TERM

    # Restore the system state to its default setting
    sys_state_configure "test_end"
    cleanup_status=$?

    # If the handler flag is an INT or TERM, force exit of the script is needed
    if [ "$trap_handler_flag" == "interrupt" ]; then
        exit 130
    fi

    if [ "$prior_exit_status" -eq 0 ] && [ "$cleanup_status" -ne 0 ]; then
        return "$cleanup_status"
    fi

    return "$prior_exit_status"
    
}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Main function for controlling the automated PQC computational performance energy testing process.

    # Display the welcome message to the terminal
    echo "###############################"
    echo "PQC Computational Energy Tester"
    echo -e "###############################"

    # Define the global variables for the script with their default values
    use_custom_eng_control_ports=0

    # Check if any arguments have been passed to the script and parse them if so
    if [[ "$#" -gt 0 ]]; then
        parse_args "$@"
    fi
    
    # Setup the environment for the script and get testing options
    setup_env

    # Set traps before state changes so cleanup runs even if configuration exits early
    trap 'trap_handler "exit"' EXIT
    trap 'trap_handler "interrupt"' INT TERM

    # Configure the system state
    sys_state_configure "test_start"

    # Ensure that the comp energy tester binary is present before attempting to run the test
    if [ ! -f "$comp_tester_bin" ]; then
        echo -e "[ERROR] - Comp energy tester binary not found, please verify environment setup"
        exit 1
    fi

    # Run the computational performance energy testing binary based on whether the user has chosen to use custom control ports or not
    if [ "$use_custom_eng_control_ports" -eq 0 ]; then
        taskset -c "$TARGET_CPU_CORE" "$comp_tester_bin" -s
    else
        taskset -c "$TARGET_CPU_CORE" "$comp_tester_bin" -c -s
    fi
    
}
main "$@"

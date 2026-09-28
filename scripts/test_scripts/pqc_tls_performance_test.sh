#!/bin/bash

# Copyright (c) 2023-2026 Callum Turino
# SPDX-License-Identifier: MIT

# Script for controlling the TLS benchmarking suite using OpenSSL 4.0.1. Supports both OpenSSL native PQC algorithms and those
# provided via OQS-Provider. It handles the configuration of test parameters, machine role assignment, port and environment
# validation, and result directory setup. The script also supports optional energy testing mode, including energy collector
# control signalling configuration and custom system state options for client-side energy test execution. Based on the selected
# machine role, the script calls the relevant client or server benchmarking script to perform handshake and speed tests across
# post-quantum, Hybrid-PQC, and classical algorithm modes, storing results in machine-specific directories for later analysis.

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
function output_help() {
    # Helper function for outputting the help message to the user when the --help flag is present or when incorrect arguments 
    # are passed.

    # Output the supported options and their usage to the user
    echo "Usage: pqc_tls_performance_test.sh [options]"
    echo "Options:"
    echo "--server-control-port=<PORT>       Set the server control port             (1024-65535)"
    echo "--client-control-port=<PORT>       Set the client control port             (1024-65535)"
    echo "--s-server-port=<PORT>             Set the OpenSSL S_Server port           (1024-65535)"
    echo "--control-sleep-time=<TIME>        Set the control sleep time in seconds   (integer or float)"
    echo "--disable-control-sleep            Disable the control signal sleep time"
    echo "--disable-result-parsing           Disable the result parsing for the test suite."
    echo "--enable-energy-testing            Enable energy testing, ensure the power measurement device is connected and configured correctly"
    echo "--use-custom-eng-control-ports     Enable the use of custom network control ports for energy testing control signalling (requires --enable-energy-testing to be enabled)"
    echo "--use-custom-sys-state             If performing energy testing, use custom system state values for the test instead of the default values."
    echo "--help                             Display the help message"

}

#-------------------------------------------------------------------------------------------------------------------------------
function is_valid_port() {
    # Helper function to check if the passed network port number is a valid and falls within the range of 1024-65535.
    # The function will return 0 if the port number is valid and 1 if it is not.

    # Store passed value and check if it is a valid port number
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1024 && port <= 65535 )); then
        return 0
    else
        return 1
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function parse_args {
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

            --server-control-port=*)

                # Store the custom server control port number
                server_control_port="${1#*=}"

                # Check if the port number is valid
                if ! is_valid_port "$server_control_port"; then
                    echo "[ERROR] - Invalid server control port number: $server_control_port"
                    exit 1
                fi

                shift
                ;;

            --client-control-port=*)

                # Store the custom client control port number
                client_control_port="${1#*=}"

                # Check if the port number is valid
                if ! is_valid_port "$client_control_port"; then
                    echo "[ERROR] - Invalid client control port number: $client_control_port"
                    exit 1
                fi

                shift
                ;;

            --s-server-port=*)

                # Store the custom OpenSSL s_server port number
                s_server_port="${1#*=}"

                # Check if the port number is valid
                if ! is_valid_port "$s_server_port"; then
                    echo "[ERROR] - Invalid s_server port number: $s_server_port"
                    exit 1
                fi

                shift
                ;;

            --control-sleep-time=*)

                # Check if the disable control sleep flag has been set
                if [ "$disable_control_sleep" == "True" ]; then
                    echo "[ERROR] - Cannot use the --control-sleep-time flag when the --disable-control-sleep flag has been set"
                    exit 1
                fi

                # Store the custom control sleep time and set the custom control time flag
                control_sleep_time="${1#*=}"
                custom_control_time_flag="True"

                # Check if the sleep timer is a valid integer or float
                if [[ ! $control_sleep_time =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                    echo "[ERROR] - Invalid control sleep time: $control_sleep_time"
                    exit 1
                fi

                shift
                ;;

            --disable-control-sleep)

                # Check if the custom sleep time flag has been
                if [ "$custom_control_time_flag" == "True" ]; then
                    echo "[ERROR] - Cannot use the --disable-control-sleep flag when the --control-sleep-time flag has been set"
                    exit 1
                fi

                # Set the disable control sleep flag and shift
                echo -e "[NOTICE] - Control Signal Sleep Timer Disabled\n"
                disable_control_sleep="True"

                shift
                ;;

            --disable-result-parsing)

                # Output the warning message to the user
                echo -e "\n[WARNING] - Result parsing disabled, results will need to be parsed manually\n"

                # Confirm with the user if they wish to proceed with the parsing disabled
                get_user_yes_no "Are you sure you want to continue with result parsing disabled?"

                # Determine the next action based on the user's response
                if [ $user_y_n_response -eq 0 ]; then
                    echo "[NOTICE] - Continuing with result parsing disabled"
                    parse_results=0
                else
                    echo "[NOTICE] - Continuing with result parsing enabled"
                    parse_results=1
                fi

                shift
                ;;

            --enable-energy-testing)

                # Output the energy testing enabled message to the user and set the energy testing flag to true
                echo -e "\n[NOTICE] - Energy testing enabled, ensure the power measurement device is connected and configured correctly\n"
                enable_energy_testing=1
                sleep 2

                shift
                ;;
            
            --use-custom-eng-control-ports)

                # Set the custom control ports flag to true
                use_custom_eng_control_ports=1

                shift
                ;;

            --use-custom-sys-state)

                # Set the system state configuration flag to use custom values
                custom_sys_state_arg_used="True"
                sys_state_configure_flag="--set-custom"

                shift
                ;;

            *)

                # Output the error message for unknown options and display the help message
                echo "[ERROR] - Unknown option: $1"
                output_help
                exit 1
                ;;

        esac

    done

    # Ensure that if the --custom-sys-state flag is used, energy testing is also enabled
    if [ "$custom_sys_state_arg_used" == "True" ] && [ "$enable_energy_testing" == 0 ]; then
        echo "[ERROR] - The --use-custom-sys-state flag requires energy testing to be enabled"
        output_help
        exit 1

    elif [ "$custom_sys_state_arg_used" == "True" ] && [ "$enable_energy_testing" -eq 1 ]; then
        echo "[NOTICE] - Custom system state values will be used for energy testing"

    fi

    # Ensure that none of the custom ports set are the same
    if [ "$server_control_port" == "$client_control_port" ] || [ "$server_control_port" == "$s_server_port" ] || [ "$client_control_port" == "$s_server_port" ]; then
        echo -e "[ERROR] - Custom TCP ports cannot be the same"
        exit 1
    fi

    # If the custom control sleep time flag has been set, perform additional checks
    if [ "$custom_control_time_flag" == "True" ]; then

        # Check if the set sleep time value falls into the given special cases
        if awk -v sleep_time="$control_sleep_time" 'BEGIN { exit !(sleep_time > 0 && sleep_time < 0.25) }'; then

            # Output the warning to the user
            echo "[WARNING] - Control sleep time is below the lowest tested value of 0.25 seconds"
            echo "In most instances, this should be fine, but some environments have shown testing to fail using lower values"

            # Ask the user if they wish to continue with the lower value
            get_user_yes_no "Do you wish to continue with the sleep timer set to $control_sleep_time seconds?"

            # Determine the next action based on the user's response
            if [ $user_y_n_response -eq 0 ]; then
                echo -e "\nExiting script..."
                exit 1
            fi

        elif awk -v sleep_time="$control_sleep_time" 'BEGIN { exit !(sleep_time == 0) }'; then

            # Output the option to disable the sleep timer to the user and get their response
            echo "[NOTICE] - You have set the control sleep time to 0 seconds"
            get_user_yes_no "Do you wish to disable the control signal sleep statement?"

            # Determine the next action based on the user's response
            if [ $user_y_n_response -eq 1 ]; then
                echo -e "[NOTICE] - Control Signal Sleep Timer Disabled\n"
                disable_control_sleep="True"
            else
                echo -e "\nExiting script..."
                exit 1
            fi

        fi
    
    fi

    # Ensure that if the custom energy network control ports flag is set, energy testing is also enabled
    if [ $use_custom_eng_control_ports -eq 1 ] && [ $enable_energy_testing -eq 0 ]; then
        echo "[ERROR] - The --use-custom-eng-control-ports flag requires energy testing to be enabled"
        output_help
        exit 1

    elif [ $use_custom_eng_control_ports -eq 1 ] && [ $enable_energy_testing -eq 1 ]; then
        echo "[NOTICE] - Custom network control ports will be used for energy testing control signalling"

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function is_port_in_use() {
    # Helper function to determine if a given port is in use. The function will attempt to use various system tools to check if 
    # the port is in use. Once the available system tool has been determined, the function checks if a process is using the port; 
    # it then stores the process name in `port_process` and the process ID in `port_pid` variables.

    # Store the port number and initialise the process name and PID variables
    local port="$1"
    port_process=""
    port_pid=""
    system_net_tool=""

    # Attempt to check if the port is in use and, if so, store the process name and PID
    if command -v ss &>/dev/null; then

        # Set the system network tool to ss
        system_net_tool="ss"

        # Grab the process ID and process name when supplying the port number
        port_pid=$(ss -tulnp | awk -v port=":$port" '$0 ~ port {gsub(".*pid=","",$NF); gsub(",.*","",$NF); print $NF}')
        port_process=$(ss -tulnp | awk -v port=":$port" '$0 ~ port {for (i=1; i<=NF; i++) if ($i ~ /users:\(\("/) {print $i; exit}}' | sed -E 's/users:\(\("//;s/",pid=.*//')

        # Determine if the port is in use based on whether a process ID is found
        if [[ -n "$port_pid" ]]; then
            return 0
        fi

    elif command -v netstat &>/dev/null; then

        # Set the system network tool to netstat
        system_net_tool="netstat"

        # Grab the process ID and process name when supplying the port number
        port_pid=$(netstat -tulnp 2>/dev/null | grep ":$port" | awk '{print $7}' | cut -d'/' -f1)
        port_process=$(netstat -tulnp 2>/dev/null | grep ":$port" | awk '{print $7}' | cut -d'/' -f2)

        # Determine if the port is in use based on whether a process ID is found
        if [[ -n "$port_pid" ]]; then
            return 0
        fi

    elif command -v lsof &>/dev/null; then

        # Set the system network tool to lsof
        system_net_tool="lsof"

        # Grab the process ID and process name when supplying the port number
        port_pid=$(lsof -Pi :"$port" -sTCP:LISTEN -t 2>/dev/null)

        # Determine if the port is in use based on whether a process ID is found
        if [[ -n "$port_pid" ]]; then
            port_process=$(ps -p "$port_pid" -o comm= 2>/dev/null | awk '{$1=$1};1')
            return 0
        fi

    else

        # Output a warning that no tool was found to check port usage, and get the user's response
        echo -e "[WARNING] - No tool found to check port usage (lsof, ss, netstat)\n"
        get_user_yes_no "Do you wish to continue without checking if the control ports are already in use?"

        # Determine the next action based on the user's response
        if [ $user_y_n_response -eq 1 ]; then
            skip_port_check="True"
            return 1
        else
            echo -e "\nExiting script..."
            exit 1
        fi

    fi

    # Return that no process is using the passed port
    return 1

}

#-------------------------------------------------------------------------------------------------------------------------------
function setup_base_env() {
    # Function for setting up the foundational global variables required for the test suite. This includes determining the 
    # project's root directory, establishing paths for libraries, scripts, and test data, and validating the presence of required 
    # libraries. Additionally, it sets up environment variables for control ports and sleep timers, ensuring proper configuration 
    # for the test suite's execution.

    # Determine the directory that the script is being run from
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    # Try and find the .dir_marker.tmp file to determine the project's root directory
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
    parsing_scripts="$root_dir/scripts/parsing_scripts"

    # Declare the project scripts path variables
    tls_handshake_server="$test_scripts_path/internal_scripts/tls_handshake_test_server.sh"
    tls_handshake_client="$test_scripts_path/internal_scripts/tls_handshake_test_client.sh"
    tls_speed="$test_scripts_path/internal_scripts/tls_speed_test.sh"
    result_parser_script="$parsing_scripts/parse_results.py"

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_4.0.1"
    oqs_provider_path="$libs_dir/oqs_provider"

    # Ensure that the OQS-Provider and OpenSSL libraries are present before proceeding
    if [ ! -d "$oqs_provider_path" ]; then
        echo "[ERROR] - OQS-Provider library not found in $libs_dir"
        exit 1
    
    elif [ ! -d "$openssl_path" ]; then
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

    # Declare the global test parameter variables
    machine_type=""
    MACHINE_NUM="1"

    # Export the testing suite TCP port variables
    export SERVER_CONTROL_PORT="$server_control_port"
    export CLIENT_CONTROL_PORT="$client_control_port"
    export S_SERVER_PORT="$s_server_port"

    # Export the energy testing flag variable
    export ENABLE_ENERGY_TESTING="$enable_energy_testing"

    # Determine what control signal parameters to export
    if [ "$disable_control_sleep" == "False" ] && [ "$custom_control_time_flag" == "False" ]; then
        export CONTROL_SLEEP_TIME="0.25"

    elif [ "$disable_control_sleep" == "False" ] && [ "$custom_control_time_flag" == "True" ]; then
        export CONTROL_SLEEP_TIME="$control_sleep_time"
    
    elif [ "$disable_control_sleep" == "True" ]; then
        export DISABLE_CONTROL_SLEEP="True"

    fi

    # Define the flag variables and arrays used for the port checking
    skip_port_check="False"
    ports_to_check=("$server_control_port" "$client_control_port" "$s_server_port")
    port_names=("Server control port" "Client control port" "OpenSSL S_Server port")

    # Ensure that control ports are not in use by other processes in the system
    for custom_port_index in "${!ports_to_check[@]}"; do

        # Check if the port is in use in the system, if the user has not chosen to skip the check due to missing tools
        if [ "$skip_port_check" != "True" ] && is_port_in_use "${ports_to_check[$custom_port_index]}"; then

            # Extract where the process pid is being run from for the port being checked
            process_cmdline=$(readlink -f /proc/$port_pid/cwd)

            # Check if the conflicting process is from this test suite
            if echo "$process_cmdline" | grep -q "$root_dir"; then

                # Determine if the process is from this testing suite
                if [ "$port_process" == "nc" ] && [ "$custom_port_index" -ne 2 ]; then
                    continue

                elif [ "$custom_port_index" -eq 2 ] && [ "$port_process" == "openssl" ]; then
                    echo -e "[WARNING] - ${port_names[$custom_port_index]} is active from a previous test, killing the process\n"
                    kill -9 "$port_pid"

                else
                    echo "[ERROR] - A service in the project is using the port: ${ports_to_check[$custom_port_index]}, this should not be the case"
                    echo "Please manually stop the service and try again"
                    exit 1

                fi

            else

                # Output the error message and exit the script
                echo -e "[ERROR] - ${port_names[$custom_port_index]} is already in use, Port: ${ports_to_check[$custom_port_index]}"
                echo "$port_process is using the port"
                exit 1

            fi

        fi

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function set_tls_paths() {
    # Function for setting the results paths based on the machine-ID assigned to the test results and exporting the paths 
    # to the environment for the server/client script.

    # Set the result directory paths based on the assigned machine-ID for results
    export MACHINE_RESULTS_PATH="$test_data_dir/up_results/tls_performance/machine_$MACHINE_NUM"
    export MACHINE_HANDSHAKE_RESULTS="$MACHINE_RESULTS_PATH/handshake_results"
    export MACHINE_SPEED_RESULTS="$MACHINE_RESULTS_PATH/speed_results"

    # Set the specific test types' result directory paths
    export PQC_HANDSHAKE="$MACHINE_HANDSHAKE_RESULTS/pqc"
    export CLASSIC_HANDSHAKE="$MACHINE_HANDSHAKE_RESULTS/classic"
    export HYBRID_HANDSHAKE="$MACHINE_HANDSHAKE_RESULTS/hybrid"
    export PQC_SPEED="$MACHINE_SPEED_RESULTS/pqc"
    export HYBRID_SPEED="$MACHINE_SPEED_RESULTS/hybrid"
    export CLASSIC_SPEED="$MACHINE_SPEED_RESULTS/classic"

    # Declare the results directory paths array based on if energy testing/store results is enabled or not
    if [ "$enable_energy_testing" -eq 0 ]; then
        result_dir_paths=("$PQC_HANDSHAKE" "$CLASSIC_HANDSHAKE" "$HYBRID_HANDSHAKE" "$PQC_SPEED" "$HYBRID_SPEED" "$CLASSIC_SPEED")

    elif [ "$enable_energy_testing" -eq 1 ] && [ "$STORE_TEST_RESULTS" -eq 1 ]; then
        result_dir_paths=("$PQC_HANDSHAKE" "$CLASSIC_HANDSHAKE" "$HYBRID_HANDSHAKE")
        
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function clean_environment() {
    # Function for cleaning the environment after the automated testing has completed

    # Clear the root results paths
    unset MACHINE_RESULTS_PATH
    unset MACHINE_HANDSHAKE_RESULTS
    unset MACHINE_SPEED_RESULTS

    # Clear the test parameter variables
    unset MACHINE_NUM
    unset MACHINE_TYPE
    unset NUM_RUN
    unset TIME_NUM
    unset CLIENT_IP
    unset SERVER_IP
    unset LD_LIBRARY_PATH
    unset SERVER_CONTROL_PORT
    unset CLIENT_CONTROL_PORT
    unset S_SERVER_PORT
    unset CONTROL_SLEEP_TIME
    unset ENABLE_ENERGY_TESTING
    unset STORE_TEST_RESULTS

    # Clear the TLS speed test env var if energy testing was not enabled as var was set
    if [ $enable_energy_testing -eq 0 ]; then
        unset SPEED_NUM
    fi

    # Clear the DISABLE_CONTROL_SLEEP variable if set
    if [ -z $DISABLE_CONTROL_SLEEP ]; then
        unset DISABLE_CONTROL_SLEEP
    fi

    # Clear the result types directory paths 
    for var in "${result_dir_paths[@]}"; do
        unset $var
    done

    # Clear the IP variable depending on the machine type
    if [ $machine_type == "Server" ]; then
        unset CLIENT_IP
    else
        unset SERVER_IP
    fi

    # Clear the energy testing flag variable and com flags variable if energy testing is enabled
    if [ "$enable_energy_testing" -eq 1 ]; then
        unset ENABLE_ENERGY_TESTING
        unset COM_FLAGS
        unset ENERGY_POLL_RATE
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_machine_num() {
    # Helper function for getting the machine-ID from the user to assign to the test results

    # Prompt the user for the machine-ID to be assigned to the results
    while true; do

        # Get the machine-ID from the user
        read -p "What Machine-ID would you like to assign to these results?: " user_response
        
        # Check that the input from the user is a valid integer and store it
        case "$user_response" in

            ''|*[!0-9]*)

                # Output to the user that the input is invalid
                echo -e "Invalid value, please enter a number.\n"
                continue
                ;;
            
            *)
                # Store the machine-ID from the user and break out of the loop
                MACHINE_NUM="$user_response"
                echo -e "\nMachine-ID set to $user_response\n"
                break
                ;;

        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function handle_machine_id_clash() {
    # Helper function for handling the clash of pre-existing results for the machine-ID being already present when assigning 
    # the machine-ID for the results. It prompts the user to either replace the old results or assign a new machine-ID.

    # Prompt the user for their choice until a valid response is given
    while true; do

        # Output the choices for handling the clash to the user
        echo -e "[WARNING] - There are already results stored for Machine-ID ($MACHINE_NUM), would you like to:"
        echo -e "1 - Replace old results and keep the same Machine-ID"
        echo -e "2 - Assign a different machine ID"

        # Read in the user's response
        read -p "Enter Option: " user_response

        # Determine the action based on the user's response
        case $user_response in

            1)

                # Remove old results and create new directories
                echo -e "\nReplacing old results\n"
                rm -rf $MACHINE_RESULTS_PATH

                for result_dir in "${result_dir_paths[@]}"; do
                    mkdir -p "$result_dir"
                done

                break
                ;;

            2)

                # Get a new machine-ID that will be assigned to the results instead
                echo -e "\nAssigning new Machine-ID for test results"
                get_machine_num

                # Set the results directory paths based on the newly assigned machine-ID
                set_tls_paths

                # Ensure the new machine-ID does not have results already present
                if [ ! -d "$MACHINE_RESULTS_PATH" ]; then
                    echo -e "No previous results present for Machine-ID ($MACHINE_NUM), continuing test setup"
                    break
                else
                    echo "There are previous results detected for the new Machine-ID value, please select a different value or replace the old results"
                fi
                ;;

            *)

                # Output to the user that the input is invalid
                echo "Invalid option, please select a valid option value (1-2)"
                ;;

        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function configure_results_dir() {
    # Function responsible for setting up and managing the results directories for the test suite. This includes handling 
    # potential clashes with existing results, creating new directories for unparsed and parsed results, and ensuring proper 
    # configuration for storing test outputs.

    # Set the results paths based on the machine-ID
    set_tls_paths

    # Create the unparsed result directories for the machine-ID and handle any clashes
    if [ -d "$test_data_dir/up_results" ]; then
    
        # Check if there are already results present for the assigned machine-ID and handle any clashes
        if [ -d "$MACHINE_RESULTS_PATH" ]; then
            handle_machine_id_clash
        
        else

            # Create the result directories for the new machine-ID
            for result_dir in "${result_dir_paths[@]}"; do
                mkdir -p "$result_dir"
            done

        fi

    else

        # Create the new results directories
        for result_dir in "${result_dir_paths[@]}"; do
            mkdir -p "$result_dir"
        done

    fi

    # Set the parsed results directory path based on the decided machine-ID
    parsed_results_path="$test_data_dir/results/tls_performance/machine_$MACHINE_NUM"

    # Check if Parsed results already exist for the Machine-ID
    if [ -d "$parsed_results_path" ]; then

        # Output to the user that the parsed results already exist
        echo -e "[WARNING] - Parsed results already exist for Machine-ID ($MACHINE_NUM)"
        get_user_yes_no "Would you like to replace the existing parsed results?"

        # Determine the next action based on the user's response
        if [ $user_y_n_response -eq 0 ]; then

            # Output to the user that the parsed results will not be replaced
            echo -e "[NOTICE] - Keeping existing parsed results, manual parsing is now required\n"
            sleep 2

            # Set the automatic result parsing flag to disabled
            parse_results=0

        elif [ $user_y_n_response -eq 1 ]; then

            # Output to the user that the parsed results will be replaced
            echo -e "[NOTICE] - Existing Parsed Results for Machine-ID ($MACHINE_NUM) will be replaced\n"
            sleep 2

            # Set the automatic result parsing flag to enabled
            replace_old_results=1
            
        fi

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_ip() {
    # Helper function to prompt the user for an IP address and validate the input to ensure it is in the correct format.

    # Store the passed ip types passed (local/remote)
    local ip_request_string="$1"

    # Define the ipv4 regex pattern for validating the user input
    ipv4_regex_check="^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$"

    # Prompt the user for the IP address of the other machine until a valid response is given
    while true; do

        # Prompt the user for their response and read it in
        read -p "Please enter the $ip_request_string device listening IP address: " usr_ip_input

        # Format the user IP input by removing trailing spaces
        ip_address=$(echo $usr_ip_input | tr -d ' ')

        # Check if the IP address entered is in the correct format
        if [[ $ip_address =~ $ipv4_regex_check ]]; then

            # Ensure that the IP address is not set to 0.0.0.0 or 255.255.255.255 before continuing
            if [[ "$ip_address" == "0.0.0.0" || "$ip_address" == "255.255.255.255" ]]; then
                echo "Invalid IP address: $ip_address. Please enter a valid IP address."
            else
                machine_ip="$ip_address"
                break
            fi

        else
            echo "Invalid IP format, please try again"

        fi
    
    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_net_port() {
    # Helper function to prompt the user for a network control port number and validate the input to ensure it is a valid port 
    # number. Used for the energy testing control signalling configuration if the user has chosen to use custom network control 
    # ports for energy testing.

    # Store the passed port type (local/remote)
    local port_type="$1"

    # Define an array of the TLS handshake testing communication ports to check against
    tls_handshake_com_ports=("$server_control_port" "$client_control_port" "$s_server_port")

    # Prompt the user for the network control port until a valid response is given
    while true; do

        # Prompt the user for their response and read it in
        read -p "Enter the $port_type network control port number to use for energy collector communication (1-65535): " user_port_input

        # Check if the port number is valid
        if is_valid_port "$user_port_input"; then

            # Check if the port number is already being used by the TLS handshake testing communication ports
            for tls_port in "${tls_handshake_com_ports[@]}"; do
                if [ "$user_port_input" -eq "$tls_port" ]; then
                    echo "[ERROR] - Port number ($user_port_input) is already in use by the TLS handshake testing communication. Please choose a different port number."
                    continue 2
                fi
            done

            # All checks have passed, allocate the port number to the relevant variable and break out of the loop
            echo "Using $port_type network control port: $user_port_input"
            port_num="$user_port_input"
            break

        else
            echo "[ERROR] - Invalid port number: $user_port_input"
        fi

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function configure_control_method() {
    # Function for configuring the control communication method for communicating with the energy collector based on user input. 
    # The function prompts the user to select the control communication method (serial or network) and then collects the relevant 
    # configuration information based on the selected method.

    # Output the current task to the terminal
    echo "Configure the control signaller"

    # Prompt the user to select the control communication method until a valid input is given
    while true; do

        # Output the available control communication methods to the user and prompt for selection
        echo "Available Control Communication Methods:"
        echo "1) Serial"
        echo "2) Network"
        read -p "Select the control communication method to use for communicating with the energy collector (1 or 2): " comm_method
        echo -e "\n"

        # Check which option has been selected and prompt for the relevant configuration settings
        case $comm_method in

            1)
                # Call the serial port selector utility script and capture only the selected port from stdout
                com_port_name="$(python3 "$util_scripts/serial_port_selector.py")"
                selector_exit_code=$?

                # Ensure that the serial port selection completed successfully
                if [ "$selector_exit_code" -ne 0 ] || [ -z "$com_port_name" ]; then
                    echo -e "[ERROR] - Failed to select a valid serial (com) port, please verify pyserial is installed and try again."
                    exit 1
                fi

                # Output the selected com port and set the communication flags
                echo -e "Using com port: $com_port_name\n"
                com_flags=(-Z serial -C "$com_port_name")
                export COM_FLAGS="${com_flags[*]}"

                break
                ;;

            2)
                # Define the machine_ip buffer variable
                machine_ip=""

                # Prompt the user for the local and remote IP addresses to use for the network communication
                get_ip "local"
                local_ip="$machine_ip"
                get_ip "remote"
                remote_ip="$machine_ip"

                # Check if custom network control ports should be used
                if [ $use_custom_eng_control_ports -eq 1 ]; then

                    # Define the port_num buffer variable
                    port_num=""

                    # Prompt the user for energy network control ports until valid and different port numbers are provided
                    while true; do 

                        # Prompt the user for the desired local and remote network control ports for control signalling
                        get_net_port "local"
                        local_port="$port_num"
                        get_net_port "remote"
                        remote_port="$port_num"

                        # Ensure that the local and remote ports are not the same
                        if [ "$local_port" -eq "$remote_port" ]; then
                            echo -e "[ERROR] - Local and remote network control ports cannot be the same, please enter different port numbers.\n"
                        else
                            break
                        fi

                    done

                fi

                # Set the com flags based on the user inputs and set communication parameters
                if [ $use_custom_eng_control_ports -eq 0 ]; then
                    com_flags=(-Z network -L "$local_ip" -Q "$remote_ip")
                else
                    com_flags=(-Z network -L "$local_ip" -Q "$remote_ip" -N "$local_port" -J "$remote_port")
                fi
                export COM_FLAGS="${com_flags[*]}"

                break
                ;;

            *)

                # Output to the user that the input is invalid and prompt again
                echo -e "\nInvalid value, please enter 1 or 2.\n"
                ;;

        esac

    done 

}

#-------------------------------------------------------------------------------------------------------------------------------
function configure_test_options {
    # Function for configuring the test parameters based on user input. This includes selecting the machine type (server or client),
    # specifying the number of test runs, and setting the TLS handshake and speed test durations.

    # Output the current task to the terminal
    echo -e "#########################"
    echo "Configure Test Parameters"
    echo -e "#########################\n"

    # Prompt the user for the test machine type selection until a valid response is given
    while true; do

        # Outputting the test machine options to the user
        echo "Please select one of the following test machine options to configure machine type:"
        echo "1-This machine will be the server"
        echo "2-This machine will be the client"
        echo "3-Exit"

        # Read in the user's response
        read -p "Enter your choice (1-3): " usr_mach_option

        # Determine the action based on the user's response
        case $usr_mach_option in

            1)

                # Set the machine type to server and which IP address to request
                echo -e "\nServer machine type selected\n"
                machine_type="Server"
                ip_request_string="Client"
                break
                ;;

            2)

                # Set the machine type to server and which IP address to request
                echo -e "\nClient machine type selected\n"
                machine_type="Client"
                ip_request_string="Server"
                break
                ;;

            3)

                # Output the exit message to the terminal and exit the script
                echo "Exiting test suite"
                exit 1
                break
                ;;

            *)

                # Output to the user that the input is invalid
                echo "Invalid option, please select a valid option value (1-3)"
                ;;

        esac

    done

    # Set the default value of the store test results flag to true
    STORE_TEST_RESULTS=1

    # If the machine type is client and the user wishes to performed energy testing, configure the control communication method and energy meter polling rate
    if [ $machine_type == "Client" ] && [ $enable_energy_testing -eq 1 ]; then

        # Output the current task to the terminal
        echo -e "\n=== Energy Testing Configuration ===\n"

        # Determine if the user wishes to still store the TLS handshake results or if energy testing only
        get_user_yes_no "Do you wish to still write the TLS handshake performance results to the client's disk, despite performing energy testing?"

        # Set the store test results flag based on the user's response
        if [ $user_y_n_response -eq 0 ]; then
            echo -e "\nTLS handshake performance results will not be stored to disk\n"
            STORE_TEST_RESULTS=0
        else
            echo -e "\nTLS handshake performance results will be stored to disk\n"
            STORE_TEST_RESULTS=1
        fi

        # Configure the control communication method and export the relevant parameters to the environment
        configure_control_method

        # Prompt the user for the energy meter polling rate until a valid response is given
        while true; do

            # Prompt the user for their response and read it in
            read -p "Enter the energy meter polling rate in milliseconds (0 for no delays between polls): " user_poll_rate

            # Check if the input is a valid value (int, 0, or positive float) and store it if valid
            if [[ "$user_poll_rate" =~ ^[0-9]+$|^[0-9]*\.[0-9]+$ ]]; then
                export ENERGY_POLL_RATE="$user_poll_rate"
                break
            else
                echo -e "Invalid input. Please enter a valid polling rate (0 or above) or decimal value.\n"

            fi
        
        done

        # Output a newline for spacing before the next task
        echo -e "\n"

    fi

    # If the test machine is a client, get the TLS handshake and speed test lengths from the user
    if [ $machine_type == "Client" ]; then

        # Output the test parameters message task to the user
        echo -e "=== Setting PQC TLS performance test parameters ===\n"

        # Export the STORE_TEST_RESULTS variable to the environment for use in the client script
        export STORE_TEST_RESULTS="$STORE_TEST_RESULTS"

        # Only prompt for machine-ID configuration if not performing energy testing or if the user has chosen to store the TLS handshake results to disk
        if [ "$enable_energy_testing" -eq 0 ] || [ "$STORE_TEST_RESULTS" -eq 1 ]; then

            # Ask the user if they wish to assign a machine-ID to the performance results
            echo -e "\n=== Setting test results Machine-ID ===\n"
            get_user_yes_no "Do you wish to assign a custom Machine-ID to the performance results?"

            # Determine whether to assign a custom machine-ID or not based on the user response
            if [ $user_y_n_response -eq 1 ]; then

                # Get the machine-ID from the user and configure the results directory
                get_machine_num
                configure_results_dir
                export MACHINE_NUM="$MACHINE_NUM"

            else

                # Set the machine-ID to the default value and configure the results directory
                echo -e "\nUsing default Machine-ID (1) for test results\n"
                configure_results_dir
                export MACHINE_NUM="1"

            fi

        fi

        # Set inf test length flags to their default value of false
        inf_warning_printed="False"
        enforce_safe_time_window="False"

        # Prompt the user for the TLS test length until a valid response is given
        while true; do

            # Prompt the user for their response and read it in
            read -p "Enter the desired length for each TLS Handshake test in seconds: " user_time_num

            # Check if the input is a valid integer before performing additional checks
            if [[ $user_time_num =~ ^[1-9][0-9]*$ ]]; then

                # Checks to handle instances of test length being in a range likely to cause inf values
                if [ "$enforce_safe_time_window" == "False" ] && [ $user_time_num -lt 5 ]; then

                    # Determine terminal width, create the warning message, and output the warning to the user
                    local terminal_width=$(tput cols)
                    warning_text="[WARNING] - TLS handshake test lengths less than 5 seconds may produce inf values for \"Connections Per User Second\" when testing certain signature/KEM combinations. "
                    warning_text+="If you proceed with a lower test length, experimentation will continue to function, but there is a possibility that not all testing runs can be used in average calculations due to the "
                    warning_text+="presence of inf in a given test run."
                    printf "\n%s\n" "$warning_text" | fold -s -w "$terminal_width"
                    echo -e "\nDetails on what this means, how it occurs, and how this impacts result average calculations are described in the following PQC-LEO documentation:\n"
                    echo -e "https://github.com/crt26/PQC-LEO/blob/main/docs/performance_results/tls_handshake_inf_result_handling.md\n"

                    # Set the warning printed flag to true
                    inf_warning_printed="True"

                    # Get the users response on how to proceed and determine next actions
                    get_user_yes_no "Do you wish to assign a new TLS handshake test length?"

                    if [ $user_y_n_response -eq 1 ]; then
                        enforce_safe_time_window="True"
                        echo -e "\n"
                        continue
                    else
                        export TIME_NUM="$user_time_num"
                        break
                    fi

                elif [ "$enforce_safe_time_window" == "True" ] && [ $user_time_num -lt 5 ]; then
                    echo "[WARNING] - Please enter a test length of 5 or more seconds to avoid possible inf value occurrences"
                    continue
                
                else
                    export TIME_NUM="$user_time_num"
                    break

                fi

            else
                echo -e "[WARNING] - Invalid input. Please enter a valid integer above 0.\n"

            fi
        
        done

        # Prompt for TLS speed test length configuration if not performing energy testing
        if [ "$enable_energy_testing" -eq 0 ]; then

            # Add spacing if the inf warning was printed out
            if [ "$inf_warning_printed" == "True" ]; then
                echo -e "\n"
            fi

            # Prompt the user for the TLS speed test length until a valid response is given
            while true; do

                # Prompt the user for their response and read it in
                read -p "Enter the test length in seconds for the TLS speed tests: " user_speed_num

                # Check if the input is a valid integer and export it to the environment if valid
                if [[ $user_speed_num =~ ^[1-9][0-9]*$ ]]; then
                    export SPEED_NUM="$user_speed_num"
                    break
                else
                    echo -e "Invalid input. Please enter a valid integer above 0.\n"
                fi
            
            done

        fi

    fi

    # Prompt the user for the number of test runs until a valid response is given
    while true; do

        # Output task to the terminal only if the machine is a server
        if [ $machine_type == "Server" ]; then
            echo -e "\n=== Setting Test Parameters ===\n"
        fi

        # Prompt the user for their response and read it in
        read -p "Enter the number of test runs required: " user_run_num

        # Check if the input is a valid integer and export it to the environment if valid
        if [[ $user_run_num =~ ^[1-9][0-9]*$ ]]; then
            export NUM_RUN="$user_run_num"
            break
        else
            echo -e "Invalid input. Please enter a valid integer above 0.\n"
        fi
    
    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function check_transferred_keys() {
    # Function to ensure the user has generated and transferred the necessary server certificates and private keys to the client 
    # machine before proceeding with the tests.

    # Check with the user if cert/keys have been transferred
    while true; do

        # Prompt the user for their response
        get_user_yes_no "Have you generated and transferred the testing keys to the client machine?"

        # Determine the next action based on the user's response
        if [ $user_y_n_response -eq 1 ]; then
            break

        else
            echo -e "\nPlease generate the certificates and keys needed for testing (e.g., via tls_generate_keys.sh) and transfer them to the client machine."
            echo -e "\nExiting test..."
            sleep 2
            exit 0

        fi
    
    done

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
                export TARGET_CPU_CORE
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

        # Export the TARGET_CPU_CORE value as an environment variable for use in the test scripts
        export TARGET_CPU_CORE

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
        if [ $restore_status -ne 0 ]; then
            echo "[ERROR] - Failed to restore system state." >&2
            return 1
        fi

        # Reset the sys_state_set_ok flag to indicate that the system state has been restored
        sys_state_set_ok=0

        # Unset the TARGET_CPU_CORE environment variable to clean up the environment
        unset TARGET_CPU_CORE

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

    # Restore the system state if needed
    sys_state_configure "test_end"
    cleanup_status=$?

    # If interrupted, exit with signal-style code
    if [ "$trap_handler_flag" == "interrupt" ]; then
        exit 130
    fi

    if [ "$prior_exit_status" -eq 0 ] && [ "$cleanup_status" -ne 0 ]; then
        return "$cleanup_status"
    fi

    return "$prior_exit_status"

}

#-------------------------------------------------------------------------------------------------------------------------------
function run_tests() {
    # Function responsible for executing TLS handshake and speed tests. It prompts the user to provide the IP address of the 
    # other machine, and validates the format of the provided IP address. Based on the machine type (server or client), it 
    # invokes the appropriate test scripts to perform the tests and handles any errors that may occur during execution.
    
    # If the machine is a client and energy testing is enabled, set the system state and the exit trap for energy testing
    if [ $machine_type == "Client" ] && [ $enable_energy_testing -eq 1 ]; then

        # Set traps before state changes so cleanup runs even if configuration exits early
        trap 'trap_handler "exit"' EXIT
        trap 'trap_handler "interrupt"' INT TERM

        # Configure the system state for the energy test and set the trap to restore the system state on exit or interruption
        sys_state_configure "test_start"

    fi

    # Set the regex variable for checking the IP address format entered by the user
    ipv4_regex_check="^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$"

    # Prompt the user for the IP address of the other machine until a valid response is given
    while true; do

        # Prompt the user for their response and read it in
        echo -e "\n=== Configure TLS Test IP Parameters ===\n"
        read -p "Please enter the $ip_request_string machine's IP address: " usr_ip_input

        # Format the user IP input by removing trailing spaces
        ip_address=$(echo $usr_ip_input | tr -d ' ')

        # Check if the IP address entered is in the correct format
        if [[ $ip_address =~ $ipv4_regex_check ]]; then

            # Ensure that the IP address is not set to 0.0.0.0 or 255.255.255.255 before continuing
            if [[ "$ip_address" == "0.0.0.0" || "$ip_address" == "255.255.255.255" ]]; then
                echo "Invalid IP address: $ip_address. Please enter a valid IP address."
            else
                echo "Other test machine set to - $ip_address"
                machine_ip=$ip_address
                break
            fi

        else
            echo "Invalid IP format, please try again"

        fi
    
    done

    # Output the reminder to move keys before starting the test (will automate in future)
    echo -e "\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo -e "Please ensure that you have generated and transferred keys before starting the test"
    echo -e "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"

    # Prompt the user to see if they have transferred the certs/keys, and clear the screen
    check_transferred_keys
    clear

    # Call the TLS handshake test script based on the machine type selected
    if [ $machine_type == "Server" ]; then

        # Export the client IP to the environment
        export CLIENT_IP="$machine_ip"

        # Call the server machine test script
        $tls_handshake_server
        exit_code=$?

        # Ensure that the server test script completed successfully
        if [ $exit_code -ne 0 ]; then
            echo "[ERROR] - TLS handshake test failed."
            exit 1
        fi

    else
    
        # Export the server IP to the environment
        export SERVER_IP="$machine_ip"
        
        # Call the server machine test script
        $tls_handshake_client
        exit_code=$?

        # Ensure that the client test script completed successfully
        if [ $exit_code -ne 0 ]; then
            echo "[ERROR] - TLS handshake test failed."
            exit 1
        fi

        # Run the TLS Speed testing if energy testing is not being performed
        if [ $enable_energy_testing -eq 0 ]; then

            # Call the TLS speed test script
            $tls_speed
            exit_code=$?

            # Ensure that the speed test script completed successfully
            if [ $exit_code -ne 0 ]; then
                echo "[ERROR] - TLS speed test failed."
                exit 1
            fi
        
        else
            echo "[NOTICE] - Skipping TLS speed testing as energy testing is enabled"

        fi

        # Set the parsing check flag based on the status of energy testing and store test results flags
        if [ $enable_energy_testing -eq 0 ]; then
            parsing_check_needed=1

        elif [ $enable_energy_testing -eq 1 ] && [ $STORE_TEST_RESULTS -eq 1 ]; then
            parsing_check_needed=1

        else
            parsing_check_needed=0
            
        fi

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function handle_result_parsing() {
    # Function for handling automatic result parsing based on user-defined flags. This function determines whether to parse 
    # results automatically, replace old results, or skip parsing based on the flags set during the test setup. It calls the 
    # parsing script with the appropriate arguments and verifies the success of the parsing process.

    # Parse the results if the flag is set to enabled
    if [ $parse_results -eq 1 ]; then

        # Determine which additional control flags need to be passed to the parsing script
        local additional_parse_flags=()

        if [ $replace_old_results -eq 1 ]; then
            additional_parse_flags+=("--replace-old-results")
        fi

        if [ $enable_energy_testing -eq 1 ] && [ $STORE_TEST_RESULTS -eq 1 ]; then
            additional_parse_flags+=("--skip-tls-speed")
        fi

        # Call the automatic parsing script with the relevant flags and arguments
        python3 "$result_parser_script" \
            --parse-mode="tls"  \
            --machine-id="$MACHINE_NUM" \
            --total-runs=$NUM_RUN \
            "${additional_parse_flags[@]}"
        exit_status=$?

        # Ensure that the parsing script completed successfully
        if [ $exit_status -ne 0 ]; then
            echo -e "\n[WARNING] - Result parsing failed, manual calling of parsing script is now required\n"
        fi

    elif [ $parse_results -eq 0 ]; then

        # Output the complete message with the test results path to the user
        echo -e "All performance testing complete, the unparsed results for Machine-ID ($MACHINE_NUM) can be found in:"
        echo "$MACHINE_RESULTS_PATH"
        
    else
        echo -e "\n[ERROR] - parse_results flag not set correctly, manual calling of parsing script is now required\n"
        exit 1
        
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Main function for controlling automated TLS performance testing using PQC algorithms supported by OpenSSL and OQS-Provider

    # Output the welcome message to the terminal
    echo "###############################################"
    echo "PQC-LEO - Automated PQC TLS Performance Testing"
    echo -e "###############################################\n"

    # Set the default global flag variables
    custom_control_time_flag="False"
    disable_control_sleep="False"
    parsing_check_needed=0
    parse_results=1
    replace_old_results=0
    enable_energy_testing=0
    use_custom_eng_control_ports=0
    sys_state_configure_flag="--set-default"
    custom_sys_state_arg_used="False"
    sys_state_set_ok=0
    trap_cleanup_done=0

    # Set the default TCP port values
    server_control_port="25000"
    client_control_port="25001"
    s_server_port="4433"

    # Parse the command line arguments passed to the script, if any
    if [[ $# -gt 0 ]]; then
        parse_args "$@"
    fi

    # Setup the base environment for the test suite
    setup_base_env

    # Get the test options and perform the PQC, Hybrid-PQC, and classical TLS tests
    configure_test_options
    run_tests

    # Handle automatic result parsing if the client machine
    if [ "$parsing_check_needed" -eq 1 ]; then
        handle_result_parsing
    fi

    # Clean the environment before exiting the script
    clean_environment

}
main "$@"
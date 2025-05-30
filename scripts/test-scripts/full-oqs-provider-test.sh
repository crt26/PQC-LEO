#!/bin/bash

# Copyright (c) 2023-2025 Callum Turino
# SPDX-License-Identifier: MIT

# Script for controlling the OQS-Provider TLS benchmarking suite using OpenSSL 3.5.0. It handles the configuration 
# of test parameters, machine role assignment, port and environment validation, and result directory setup. Based on 
# the selected machine role, the script calls the relevant client or server benchmarking script to perform handshake 
# and speed tests across post-quantum, classical, and hybrid-pqc algorithm modes, storing results in machine-specific 
# directories for later analysis.

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
function output_help_message() {
    # Helper function for outputting the help message to the user when the --help flag is present or when incorrect arguments are passed

    # Output the supported options and their usage to the user
    echo "Usage: full-oqs-provider-test.sh [options]"
    echo "Options:"
    echo "  --server-control-port=<PORT>       Set the server control port             (1024-65535)"
    echo "  --client-control-port=<PORT>       Set the client control port             (1024-65535)"
    echo "  --s-server-port=<PORT>             Set the OpenSSL S_Server port           (1024-65535)"
    echo "  --control-sleep-time=<TIME>        Set the control sleep time in seconds   (integer or float)"
    echo "  --disable-control-sleep            Disable the control signal sleep time"
    echo "  --disable-result-parsing           Disable the result parsing for the test suite."
    echo "  --help                             Display the help message"

}

#-------------------------------------------------------------------------------------------------------------------------------
function is_valid_port() {
    # Helper function to check if the passed TCP port number is a valid and falls within the range of 1024-65535.
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
    # set the relevant global flags and parameter variables that are used throughout the test control process.

    # Check if the help flag is passed at any position in the command line arguments
    if [[ "$*" =~ --help ]]; then
        output_help_message
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

                # Check if the sleep timer is valid integer or float
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
                disable_control_sleep="True"

                shift
                ;;

            --disable-result-parsing)

                # Output the warning message to the user
                echo -e "\n[WARNING] - Result parsing disabled, results will require to be parsed manually\n"

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

            *)

                # Output the error message for unknown options and display the help message
                echo "[ERROR] - Unknown option: $1"
                output_help_message
                exit 1
                ;;

        esac

    done

    # Ensure that none of the custom ports set are the same
    if [ "$server_control_port" == "$client_control_port" ] || [ "$server_control_port" == "$s_server_port" ] || [ "$client_control_port" == "$s_server_port" ]; then
        echo -e "[ERROR] - Custom TCP ports cannot be the same"
        exit 1
    fi

    # If the custom control sleep time flag has been set, perform additional checks
    if [ "$custom_control_time_flag" == "True" ]; then

        # Check if the set sleep time value falls into given special cases
        if (( $(echo "$control_sleep_time > 0 && $control_sleep_time < 0.25" | bc -l) )); then

            # Output the warning to the user
            echo "[WARNING] - Control sleep time is below the lowest tested value of 0.25 seconds"
            echo "In most instances this should be fine, but some environments have shown testing to fail using lower values"

            # Ask the user if they wish to continue with the lower value
            get_user_yes_no "Do you wish to continue with the sleep timer set to $control_sleep_time seconds?"

            # Determine if the script should based on the user response
            if [ $user_y_n_response -eq 0 ]; then
                echo -e "\nExiting script..."
                exit 1
            fi

        elif (( $(echo "$control_sleep_time == 0" | bc -l) )); then

            # Output the option to disable the sleep timer to the user and get their response
            echo "[NOTICE] - You have set the control sleep time to 0 seconds"
            get_user_yes_no "Do you wish to disable the control signal sleep statement?"

            # Determine the next action based on the user response
            if [ $user_y_n_response -eq 1 ]; then
                disable_control_sleep="True"
            else
                echo -e "\nExiting script..."
                exit 1
            fi

        fi
    
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function is_port_in_use() {
    # Helper function to determine if a given port is in use. The function will attempt to use various system tools to check if the port is in use.
    # Once the available system tool has been determine, the function checks if a process is using the port, it then stores the process name 
    # in `port_process` and the process ID in `port_pid` variables.

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

        # Determine if the port is in use based on if a process ID is found
        if [[ -n "$port_pid" ]]; then
            return 0
        fi

    elif command -v netstat &>/dev/null; then

        # Set the system network tool to netstat
        system_net_tool="netstat"

        # Grab the process ID and process name when supplying the port number
        port_pid=$(netstat -tulnp 2>/dev/null | grep ":$port" | awk '{print $7}' | cut -d'/' -f1)
        port_process=$(netstat -tulnp 2>/dev/null | grep ":$port" | awk '{print $7}' | cut -d'/' -f2)

        # Determine if the port is in use based on if a process ID is found
        if [[ -n "$port_pid" ]]; then
            return 0
        fi

    elif command -v lsof &>/dev/null; then

        # Set the system network tool to lsof
        system_net_tool="lsof"

        # Grab the process ID and process name when supplying the port number
        port_pid=$(lsof -Pi :"$port" -sTCP:LISTEN -t 2>/dev/null)

        # Determine if the port is in use based on if a process ID is found
        if [[ -n "$port_pid" ]]; then
            port_process=$(ps -p "$port_pid" -o comm= 2>/dev/null | awk '{$1=$1};1')
            return 0
        fi

    else

        # Output a warning that no tool was found to check port usage and get the user response
        echo -e "[WARNING] - No tool found to check port usage (lsof, ss, netstat)\n"
        get_user_yes_no "Do you wish to continue without checking if the control ports are already in use?"

        # Determine the next action based on the user response
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
    # Function for setting up the basic global variables for the test suite. This includes setting the root directory
    # and the global library paths for the test suite. The function establishes the root path by determining the path of the script and
    # using this, determines the root directory of the project.

    # Determine the directory that the script is being run from
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    # Try and find the .dir_marker.tmp file to determine the project's root directory
    current_dir="$script_dir"

    # Continue moving up the directory tree until the .pqc_eval_dir_marker.tmp file is found
    while true; do

        # Check if the .pqc_eval_dir_marker.tmp file is present
        if [ -f "$current_dir/.pqc_eval_dir_marker.tmp" ]; then
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
    test_data_dir="$root_dir/test-data"
    test_scripts_path="$root_dir/scripts/test-scripts"
    util_scripts="$root_dir/scripts/utility-scripts"
    parsing_scripts="$root_dir/scripts/parsing-scripts"

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_3.5.0"
    oqs_provider_path="$libs_dir/oqs-provider"

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

        # Check if the port is in use in the system if the user has not chosen to skip the check due to missing tools
        if [ "$skip_port_check" != "True" ] && is_port_in_use "${ports_to_check[$custom_port_index]}"; then

            # Extract where the process pid is being ran from for the port being checked
            process_cmdline=$(readlink -f /proc/$port_pid/cwd)

            # Check if the conflicting process is from this test suite
            if echo "$process_cmdline" | grep -q "$root_dir"; then

                # Determine if the process is from this testing suite
                if [ "$port_process" == "nc" ] && [ "$custom_port_index" -ne 2 ]; then
                    continue

                elif [ "$custom_port_index" -eq 2 ] && [ "$port_process" == "openssl" ]; then
                    echo "[WARNING] - ${port_names[$custom_port_index]} is active from a previous test, killing the process"
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

    # Set the result directory paths based on assigned machine-ID for results
    export MACHINE_RESULTS_PATH="$test_data_dir/up-results/oqs-provider/machine-$MACHINE_NUM"
    export MACHINE_HANDSHAKE_RESULTS="$MACHINE_RESULTS_PATH/handshake-results"
    export MACHINE_SPEED_RESULTS="$MACHINE_RESULTS_PATH/speed-results"

    # Set the specific test types result directory paths
    export PQC_HANDSHAKE="$MACHINE_HANDSHAKE_RESULTS/pqc"
    export CLASSIC_HANDSHAKE="$MACHINE_HANDSHAKE_RESULTS/classic"
    export HYBRID_HANDSHAKE="$MACHINE_HANDSHAKE_RESULTS/hybrid"
    export PQC_SPEED="$MACHINE_SPEED_RESULTS/pqc"
    export HYBRID_SPEED="$MACHINE_SPEED_RESULTS/hybrid"

    # Declare the results directory paths array
    result_dir_paths=("$PQC_HANDSHAKE" "$CLASSIC_HANDSHAKE" "$HYBRID_HANDSHAKE" "$PQC_SPEED" "$HYBRID_SPEED")

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
    unset SPEED_NUM
    unset CLIENT_IP
    unset SERVER_IP
    unset LD_LIBRARY_PATH
    unset SERVER_CONTROL_PORT
    unset CLIENT_CONTROL_PORT
    unset S_SERVER_PORT
    unset CONTROL_SLEEP_TIME

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

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_machine_num() {
    # Helper function for getting the machine-ID from the user to assign to the test results

    # Prompt the use for the machine number to be assigned to the results
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
                # Store the machine-ID  from the user and break out of the loop
                MACHINE_NUM="$user_response"
                echo -e "\nMachine-ID set to $user_response\n"
                break
                ;;

        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function handle_machine_id_clash() {
    # Helper function for handling the clash of pre-existing results for the machine-ID being already present when 
    # assigning the machine-ID for the results. It prompts the user to either replace the old results or assign a new machine-ID.

    # Prompt the user for their choice until a valid response is given
    while true; do

        # Output the choices for handling the clash to the user
        echo -e "[WARNING] - There are already results stored for Machine-ID ($MACHINE_NUM), would you like to:"
        echo -e "1 - Replace old results and keep same Machine-ID"
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

                # Get a new machine-ID that will assigned to the results instead
                echo -e "\nAssigning new Machine-ID for test results"
                get_machine_num

                # Set the results directory paths based on the newly assigned machine-ID
                set_tls_paths

                # Ensure the new machine-ID does not have results already present
                if [ ! -d "$MACHINE_RESULTS_PATH" ]; then
                    echo -e "No previous results present for Machine-ID ($MACHINE_NUM), continuing test setup"
                    break
                else
                    echo "There are previous results detected for new Machine-ID value, please select different value or replace old results"
                fi
                ;;

            *)

                # Output to the user that the input is invalid
                echo "Invalid option, please select valid option value (1-2)"
                ;;

        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function configure_results_dir() {
    # Function for configuring the results directories for the test results

    # Set the results paths based on the machine-ID
    set_tls_paths

    # Create the un-parsed result directories for the machine-ID and and handle any clashes
    if [ -d "$test_data_dir/up-results" ]; then
    
        # Check if there is already results present for assigned machine-ID and handle any clashes
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
    parsed_results_path="$test_data_dir/results/oqs-provider/machine-$MACHINE_NUM"

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
function configure_test_options {
    # Function for configuring the test parameters, including machine type, number of test runs, and TLS test lengths, based on user input

    # Output the current task to the terminal
    echo -e "#########################"
    echo "Configure Test Parameters"
    echo -e "#########################\n"

    # Prompt the user for the test machine selection until a valid response is given
    while true; do

        # Outputting the test machine options to the user
        echo "Please select on of the following test machine options to configure machine type:"
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
                echo "Invalid option, please select valid option value (1-3)"
                ;;

        esac

    done

    # If test machine is client, get the TLS handshake and speed test lengths from user
    if [ $machine_type == "Client" ]; then

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

        # Output the test parameters message to the user
        echo -e "=== Setting test parameters for the TLS Handshake and Speed tests ===\n"

        # Prompt the user for the TLS test length until a valid response is given
        while true; do

            # Prompt the user for their response and read it in
            read -p "Enter the desired length for each TLS Handshake test in seconds: " user_time_num

            # Check if the input is a valid integer and export it to the environment if valid
            if [[ $user_time_num =~ ^[1-9][0-9]*$ ]]; then
                export TIME_NUM="$user_time_num"
                break
            else
                echo -e "Invalid input. Please enter a valid integer above 0.\n"
            fi
        
        done

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

    # Prompt the user for the number of test runs until a valid response is given
    while true; do

        # Output task to terminal only if server
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
    # Function for checking with the user they have generated and transferred the server certificates and private-keys
    # to the client machine before starting tests

    # Check with the user if cert/keys have been transferred
    while true; do

        # Prompt the user for their response
        get_user_yes_no "Have you generated and transferred the testing keys to the client machine?"

        # Determine the next action based on the user response
        if [ $user_y_n_response -eq 1 ]; then
            break

        else
            echo -e "\nPlease generate the certs and keys needed for testing using oqsprovider-generate-keys.sh and transfer to client machine before testing"
            echo -e "\nExiting test..."
            sleep 2
            exit 0

        fi
    
    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function run_tests() {
    # Function for performing the TLS handshake and speed tests. It will get the IP address of the other machine from the user
    # and check that the IP address is in the correct format. The function will then call the relevant test scripts based on
    # the machine type selected.
   
    # Set the regex variable for checking the IP address format entered by user
    ipv4_regex_check="^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$"

    # Prompt the user for the IP address of the other machine until a valid response is given
    while true; do

        # Prompt the user for their response and read it in
        echo -e "\n=== Configure IP Parameters ===\n"
        read -p "Please enter the $ip_request_string machine's IP address: " usr_ip_input

        # Format the user ip input by removing trailing spaces
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

    # Output the reminder to move keys before starting test (will automate in future)
    echo -e "\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo -e "Please ensure that you have generated and transferred keys before starting test"
    echo -e "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"

    # Prompt the user to see if they have transferred the certs/keys and clearing the screen
    check_transferred_keys
    clear

    # Call the TLS handshake test script based on the machine type selected
    if [ $machine_type == "Server" ]; then

        # Export the client IP to the environment
        export CLIENT_IP="$machine_ip"

        # Call the server machine test script
        $test_scripts_path/oqsprovider-test-server.sh
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
        $test_scripts_path/oqsprovider-test-client.sh
        exit_code=$?

        # Ensure that the client test script completed successfully
        if [ $exit_code -ne 0 ]; then
            echo "[ERROR] - TLS handshake test failed."
            exit 1
        fi

        # Call the TLS speed test script
        $test_scripts_path/oqsprovider-test-speed.sh
        exit_code=$?

        # Ensure that the speed test script completed successfully
        if [ $exit_code -ne 0 ]; then
            echo "[ERROR] - TLS speed test failed."
            exit 1
        fi

        # Set the parsing checks needed as this is the client machine
        parsing_check_needed=1

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function handle_result_parsing() {
    # Function for handling automatic result parsing based on user-defined flags. Calls the parsing script with 
    # the correct arguments, including the replace flag if set, and verifies whether parsing completed successfully.

    # Parse the results if the flag is set to enabled
    if [ $parse_results -eq 1 ]; then

        # Call the automatic parsing script based on if old results need to be replaced
        if [ $replace_old_results -eq 0 ]; then

            # Call the result parsing script to parse the results with replace flag not set
            python3 "$parsing_scripts/parse_results.py" \
                --parse-mode="oqs-provider"  \
                --machine-id="$MACHINE_NUM" \
                --total-runs=$NUM_RUN
            exit_status=$?

        else

            # Call the result parsing script to parse the results with replace flag set
            python3 "$parsing_scripts/parse_results.py" \
                --parse-mode="oqs-provider"  \
                --machine-id="$MACHINE_NUM" \
                --total-runs=$NUM_RUN \
                --replace-old-results
            exit_status=$?

        fi

        # Ensure that the parsing script completed successfully
        if [ $exit_status -eq 0 ]; then
            echo -e "\nParsed results can be found in the following directory:"
            echo "$test_data_dir/results/oqs-provider/machine-$MACHINE_NUM"
        else
            echo -e "\n[WARNING] - Result parsing failed, manual calling of parsing script is now required\n"
        fi

    elif [ $parse_results -eq 0 ]; then

        # Output the complete message with the test results path to the user
        echo -e "All performance testing complete, the unparsed results for Machine-ID ($MACHINE_NUM) can be found in:"
        echo "Results Dir Path - $MACHINE_RESULTS_PATH"
        
    else
        echo -e "\n[ERROR] - parse_results flag not set correctly, manual calling of parsing script is now required\n"
        exit 1
        
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Main function for controlling the automated OQS-Provider PQC TLS performance testing

    # Output the welcome message to the terminal
    echo "#####################################################################"
    echo "PQC-Evaluation-Tools - Automated OQS-Provider TLS Performance Testing"
    echo -e "#####################################################################\n"

    # Set the default global flag variables
    custom_control_time_flag="False"
    disable_control_sleep="False"
    parsing_check_needed=0
    parse_results=1
    replace_old_results=0

    # Set the default TCP port values
    server_control_port="25000"
    client_control_port="25001"
    s_server_port="4433"

    # Parse the command line arguments passed to the script if any
    if [[ $# -gt 0 ]]; then
        parse_args "$@"
    fi

    # Setup the base environment for the test suite
    setup_base_env

    # Get the test options and perform the PQC TLS tests 
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
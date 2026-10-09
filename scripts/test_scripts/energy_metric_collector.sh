#!/bin/bash

# Copyright (c) 2023-2026 Callum Turino
# SPDX-License-Identifier: MIT

# Controller script for collecting energy consumption metrics from PQC-LEO testing suites. Provides an interactive
# configuration interface for collection parameters (test type, machine ID, test runs), manages result directories 
# and pre-existing result handling, and invokes the energy collector binary. Supports computational performance, TLS handshake,
# and TLS operations collection types, including their PQC, Hybrid-PQC, and classical coverage, plus custom workflows. The script
# can also call the central parser automatically to structure the collected results as CSV files.

#-------------------------------------------------------------------------------------------------------------------------------
function output_help() {
    # Helper function for outputting the help message to the user when the --help flag is present or
    # when incorrect arguments are passed.

    # Output the supported options and their usage to the user
    echo "Usage: energy_metric_collector.sh [options]"
    echo "Options:"
    echo "--disable-result-parsing       Disable the automatic result parsing for the test suite."
    echo "--help                         Display this help message."

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

            --disable-result-parsing)

                # Output the warning message to the user
                echo -e "\n[WARNING] - Automatic result parsing disabled, results will need to be parsed manually\n"

                # Confirm with the user if they wish to proceed with the parsing disabled
                get_user_yes_no "Are you sure you want to continue with automatic result parsing disabled?"

                # Determine the next action based on the user's response
                if [ $user_y_n_response -eq 1 ]; then
                    echo "[NOTICE] - Continuing with automatic result parsing disabled"
                    parse_results=0
                else
                    echo "[NOTICE] - Continuing with automatic result parsing enabled"
                    parse_results=1
                fi

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
function setup_base_env() {
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
    parsing_scripts="$root_dir/scripts/parsing_scripts"

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_4.0.3"
    provider_path="$libs_dir/oqs_provider/lib"
    provider_flags="-provider-path $provider_path -provider default -provider oqsprovider"

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

    # Declare the internal test script path variables
    result_parser_script="$parsing_scripts/parse_results.py"

    # Define the temp cert/key storage directory path
    temp_test_storage="$tmp_dir/energy_test_certs"

    # Ensure that the temp cert/key storage directory is present and empty
    if [[ -d "$temp_test_storage" ]]; then
        rm -rf "$temp_test_storage"
    fi
    mkdir -p "$temp_test_storage"

    # Define path to energy testing util scripts
    energy_collector_path="$libs_dir/energy_collector"
    collector_bin="$energy_collector_path/build/bin/collector"

    # Ensure that the energy tools are built
    if [ ! -d "$energy_collector_path" ]; then
        echo -e "[ERROR] - Energy collector tools not built, please build the tools before running the energy tests."
        exit 1
    fi

    # Ensure that the energy collector bin is present
    if [ ! -f "$collector_bin" ]; then
        echo -e "[ERROR] - Energy collector binary not found, please build the tools before running the energy tests."
        exit 1
    fi

    # Declare global collection parameter flags (collection_type: 1 - Computational, 2 - TLS Handshake, 3 - TLS Operations, 4 - Custom)
    collection_type=0
    machine_num=""
    result_dir_name=""
    number_of_runs=0

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_machine_num() {
    # Helper function for getting the machine-ID from the user to assign to the test results

    # Prompt the user for the machine number to be assigned to the results
    while true; do

        # Get the machine-ID from the user
        read -p "What machine-ID would you like to assign to these results? - " user_response
        
        # Check that the input from the user is a valid integer and store it
        if [[ "$user_response" =~ ^[0-9]+$ ]]; then
            machine_num="$user_response"
            echo -e "\nMachine-ID set to $user_response\n"
            break

        else
            echo -e "[WARNING] - Invalid value, please enter a number\n"

        fi

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function handle_machine_id_clash() {
    # Helper function for handling the clash of pre-existing results for the machine-ID being already present when assigning the 
    # machine-ID for the results. It prompts the user to either replace the old results or assign a new machine-ID.

    # Prompt the user for their choice until a valid response is given
    while true; do

        # Output the choices for handling the clash to the user
        echo -e "There are already results stored for Machine-ID ($machine_num), would you like to:"
        echo -e "1 - Replace old results and keep the same Machine-ID"
        echo -e "2 - Assign a different machine ID\n"

        # Read in the user's response
        read -p "Please select an option (1-2): " user_response

        # Determine the action based on the user's response
        case $user_response in

            1)
                # Remove old results and create new directories
                echo -e "\nReplacing old results\n"
                rm -rf $unparsed_results_path
                break;;

            2)
                # Get a new machine-ID that will be assigned to the results instead
                echo -e "Assigning new Machine-ID for test results"
                get_machine_num

                # Update both result paths for the newly assigned machine-ID
                unparsed_results_path="$unparsed_results_base_path/machine_$machine_num"
                parsed_results_path="$test_data_dir/results/energy_test_results/$result_dir_name/machine_$machine_num"

                # Ensure the new machine-ID does not have results already present
                if [ ! -d "$unparsed_results_path" ]; then
                    echo -e "No previous results present for Machine-ID ($machine_num), continuing test setup"
                    break
                else
                    echo "There are previous results detected for the new Machine-ID value, please select a different value or replace the old results"
                fi
                ;;
        
        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_collection_options() {
    # Function for getting the collection options from the user to configure the test suite setup. It prompts the user for the type 
    # of energy testing to be performed, the machine-ID to assign to the results, and the number of test runs to perform. The 
    # function validates the user input and sets the relevant global variables based on the responses.

    # Output the current task to the terminal
    echo -e "----------------------------"
    echo "Configure Collection Options"
    echo -e "----------------------------\n"

    # Ask the user which type of testing the energy metrics will be collected for until a valid response is given
    echo -e "Test type selection:\n"
    while true; do

        # Output the available options to the user and read in their response
        echo "Available options for test collection type:"
        echo "1) PQC Performance Energy Testing"
        echo "2) TLS Handshake Performance Energy Testing"
        echo "3) TLS Operations Energy Testing"
        echo "4) Custom Option"
        read -p "Please select collection type (1-4): " collection_response

        # Determine the testing type based on the users response
        case $collection_response in

            1)
                # Set the collection type variable to PQC performance testing
                collection_type=1
                result_dir_name="pqc_performance_energy_results"
                echo -e "\nCollection type set to PQC Performance Energy Testing\n"
                break;;

            2)
                # Set the collection type variable to TLS handshake testing
                collection_type=2
                result_dir_name="tls_handshake_energy_results"
                echo -e "\nCollection type set to TLS Handshake Performance Energy Testing\n"
                break;;

            3)
                # Set the collection type variable to TLS operations energy testing
                collection_type=3
                result_dir_name="tls_operations_energy_results"
                echo -e "\nCollection type set to TLS Operations Energy Testing\n"
                break;;

            4)  
                # Set the collection type variable to custom option and prompt the user to enter a custom name for the collection type
                collection_type=4
                read -p "Please enter a name for this collection type: " custom_collection_name
                echo -e "\nCollection type set to $custom_collection_name\n"
                result_dir_name="${custom_collection_name// /_}_energy_results" # Replace spaces with underscores for the result directory name
                break;;

            *)
                # Output to the user that their response is invalid and prompt again
                echo -e "\nInvalid response, please select a valid option (1-4)\n"
                ;;
        
        esac

    done

    # If a custom energy test has been selected, disable automatic parsing
    if [ $collection_type -eq 4 ]; then
        parse_results=0
        echo "[NOTICE] - As a custom collection type has been selected, automatic parsing is now disabled. Result data will need to be parsed manually"
    fi

    # Ask the user if they wish to assign a custom Machine-ID to the performance results
    while true; do

        # Prompt the user for their response and read it in
        read -p "Do you wish to assign a custom Machine-ID to the energy usage results? [y/n] - " machine_id_response

        # Determine what action to take based on the user's response
        case $machine_id_response in

            [Yy]* )

                # Get the machine-ID from the user to assign to the results
                get_machine_num
                break;;

            [Nn]* )

                # Output to the user that the default machine-ID will be used, and set it to 1
                echo -e "\nUsing default Machine-ID for saving results\n"
                machine_num="1"
                break;;

            * ) 
            
                # Output to the user that the input is invalid and prompt again
                echo -e "\nInvalid value, please answer (y/n)\n"
                ;;

        esac

    done

    # Ask the user for the number of test runs to perform
    while true; do

        # Prompt the user for their response and read it in
        read -p "Enter the number of test runs required: " user_run_num

        # Check if the input is a valid integer and store it if valid
        if [[ "$user_run_num" =~ ^[1-9][0-9]*$ ]]; then
            number_of_runs=$user_run_num
            break

        else
            echo -e "Invalid input. Please enter a valid integer above 0.\n"

        fi
    
    done

    # Output newline for formatting
    echo -e "\n"

}

#-------------------------------------------------------------------------------------------------------------------------------
function setup_collection_suite() {
    # Function for setting up the collection suite based on the user selections. This function defines the relevant directory 
    # paths for storing the results based on the machine-ID and collection type selected by the user, and checks for any pre-existing 
    # results, handling any clashes. 

    # Define the target up_results and results directory paths
    unparsed_results_base_path="$test_data_dir/up_results/energy_test_results/$result_dir_name"
    unparsed_results_path="$test_data_dir/up_results/energy_test_results/$result_dir_name/machine_$machine_num"
    parsed_results_path="$test_data_dir/results/energy_test_results/$result_dir_name/machine_$machine_num"

    # Ensure the parent path exists, but do not pre-create the machine-specific output directory
    if [ ! -d "$unparsed_results_base_path" ]; then
        mkdir -p "$unparsed_results_base_path"
    fi

    # If previous unparsed results exist for this machine-ID handle the clash
    if [ -d "$unparsed_results_path" ]; then
        handle_machine_id_clash
    fi

    # Check if Parsed results already exist for the Machine-ID
    if [ -d "$parsed_results_path" ]; then

        # Output to the user that the parsed results already exist
        echo -e "[WARNING] - Parsed results already exist for Machine-ID ($machine_num)"
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
            echo -e "[NOTICE] - Existing Parsed Results for Machine-ID ($machine_num) will be replaced\n"
            sleep 2

            # Set the flag to replace existing parsed results
            replace_old_results=1
            
        fi

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function handle_result_parsing() {
    # Function for handling automatic result parsing based on user-defined flags. This function determines whether to parse 
    # results automatically, replace old results, or skip parsing based on the flags set during the test setup. It calls the 
    # parsing script with the appropriate arguments and verifies the success of the parsing process.

    # Check if the automatic result parsing flag is set to enabled
    if [ $parse_results -eq 1 ]; then

        # Call the automatic parsing script based on whether old results need to be replaced
        if [ $replace_old_results -eq 0 ]; then

            # Call the result parsing script to parse the results with the replace flag not set
            python3 "$result_parser_script" \
                --parse-mode="energy"  \
                --energy-test-type=$collection_type \
                --machine-id="$machine_num" \
                --total-runs=$number_of_runs
            exit_status=$?

        else

            # Call the result parsing script to parse the results with the replace flag set
            python3 "$result_parser_script" \
                --parse-mode="energy"  \
                --energy-test-type=$collection_type \
                --machine-id="$machine_num" \
                --total-runs=$number_of_runs \
                --replace-old-results
            exit_status=$?

        fi

        # Ensure that the parsing script completed successfully
        if [ $exit_status -ne 0 ]; then
            echo -e "\n[WARNING] - Result parsing failed, manual calling of parsing script is now required\n"
        fi

    elif [ $parse_results -eq 0 ]; then

        # Output the complete message with the test results path to the user
        echo -e "All performance testing complete, the unparsed results for Machine-ID ($machine_num) can be found in:"
        echo "$unparsed_results_path"
        
    else
        echo -e "\n[ERROR] - parse_results flag not set correctly, manual calling of parsing script is now required\n"
        exit 1
            
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Main function for controlling the energy metric collection machine used to collect energy consumption metrics for 
    # the computational and TLS testing categories supported by PQC-LEO.

    # Output the welcome message to the terminal
    echo -e "###############################"
    echo "PQC-LEO Energy Metric Collector"
    echo -e "###############################\n"

    # Set the default automatic result parsing flags
    parse_results=1
    replace_old_results=0

    # Parse the command line arguments passed to the script, if any
    if [[ $# -gt 0 ]]; then
        parse_args "$@"
    fi

    # Setup the base environment, get collection options, and setup the collection suite based on the user selections
    setup_base_env
    get_collection_options
    setup_collection_suite

    # Call the collector binary with the relevant flags based on the user selections on collection environment
    "$collector_bin" -s -d "$unparsed_results_path"
    exit_status=$?

    # Ensure that the collector script executed successfully, if not output an error message to the user
    if [ $exit_status -ne 0 ]; then
        echo -e "[ERROR] - Energy collector script did not execute successfully, stored results may be incomplete or corrupted."
        exit 1
    fi

    # Handle the automatic result parsing based on the user input flags
    handle_result_parsing

}
main "$@"

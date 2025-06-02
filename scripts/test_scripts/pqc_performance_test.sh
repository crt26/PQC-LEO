#!/bin/bash

# Copyright (c) 2023-2025 Callum Turino
# SPDX-License-Identifier: MIT

# Script for controlling the Liboqs PQC computational performance benchmarking. It accepts test parameters 
# from the user and executes the relevant benchmarking binaries to perform speed and memory tests 
# on the post-quantum cryptographic algorithms included in the Liboqs library.
# The script also handles the organisation and storage of results, ensuring they are saved in the appropriate 
# directories based on the assigned machine number.

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
    # Helper function for outputting the help message to the user when the --help flag is present or when incorrect arguments are passed.

    # Output the supported options and their usage to the user
    echo "Usage: setup.sh [options]"
    echo "Options:"
    echo "  --disable-result-parsing       Disable the result parsing for the test suite."
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

                # Output an error message if an unknown option is passed
                echo "[ERROR] - Unknown option: $1"
                output_help_message
                exit 1
                ;;

        esac

    done

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

    # Clean the previous build files before cloning the repository
    if [ -d "$libs_dir/pqax" ]; then
        rm -rf "$libs_dir/pqax"
    fi

    # Move into the libs directory and clone the pqax repository if missing
    cd "$libs_dir"
    git clone --branch main https://github.com/mupq/pqax.git
    cd "$libs_dir/pqax/enable_ccr"

    # Ensure that the clone was successful
    if [ ! -d "$libs_dir/pqax" ]; then
        echo -e "\n[ERROR] - PQAX clone failed, to ensure a clean environment, it is best to re-run the main setup script\n"
        exit 1
    fi

    # Enable user space access to the ARM PMU
    make
    make_status=$?
    make install
    make_install_status=$?
    cd $root_dir

    echo "make status: $make_status"
    echo "make install status: $make_install_status"

    # Check if the make and make install commands were successful
    if [ "$make_status" -ne 0 ] || [ "$make_install_status" -ne 0 ]; then
        echo -e "\n[ERROR] - PMU build failed, please check the system and try again\n"
        exit 1
    fi

    # Ensure that the system has user access to the ARM PMU
    if ! lsmod | grep -q 'enable_ccr'; then

        # Output to the user that the PMU access was not enabled
        echo "[ERROR] - The enable_ccr module is not loaded, could not enable PMU access"
        echo "Please re-run the main setup script to ensure a clean environment"
        exit 1

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function resolve_arm_pmu_access() {

    # Check if a PQAX install is already present and if not call the function to enable it
    if [ -d "$libs_dir/pqax" ]; then

        # Output the current task to the terminal
        echo -e "\nPQAX already built, attempting to enable PMU access"

        # Attempt to reload the PQAX kernel module
        cd "$libs_dir/pqax/enable_ccr"
        sudo rmmod enable_ccr 2>/dev/null
        sudo insmod enable_ccr.ko 2>/dev/null
        cd "$root_dir"

        # Ensure that the system has user access to the ARM PMU
        if lsmod | grep -q 'enable_ccr'; then
            echo -e "\nPMU access enabled successfully\n"
        else
            echo -e "\n[WARNING] - ARM PMU access not enabled using current build, attempting to resolve the issue with a clean install..." && sleep 2
            enable_arm_pmu
        fi

    else

        # If PQAX is not present, call the function to enable it
        enable_arm_pmu

    fi
    
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
    parsing_scripts="$root_dir/scripts/parsing_scripts"

    # Check if the system is ARM based and if PMU checks are required
    if [[ "$(uname -m)" = arm* || "$(uname -m)" == aarch* ]]; then

        # Ensure that the system still has user access to the ARM PMU
        if ! lsmod | grep -q 'enable_ccr'; then
            echo -e "[WARNING] - ARM PMU access not enabled, attempting to resolve the issue..."
            sleep 2
            resolve_arm_pmu_access
        fi

    fi

    # Declare the global library directory path variables
    liboqs_path="$libs_dir/liboqs"

    # Ensure that the Liboqs library is present before proceeding
    if [ ! -d "$liboqs_path" ]; then
        echo "[ERROR] - Liboqs library not found in $libs_dir"
        exit 1
    fi

    # Declare the global test parameter variables
    machine_num=""
    number_of_runs=0

}

#-------------------------------------------------------------------------------------------------------------------------------
function set_result_paths() {
    # Helper function for setting the result storage paths based on the assigned machine-ID

    # Set the results directory paths based on assigned machine-ID for these results
    machine_results_path="$test_data_dir/up_results/liboqs/machine_$machine_num"
    parsed_results_path="$test_data_dir/results/liboqs/machine_$machine_num"
    machine_speed_results="$machine_results_path/raw_speed_results"
    machine_mem_results="$machine_results_path/mem_results"
    kem_mem_results="$machine_mem_results/kem_mem_metrics"
    sig_mem_results="$machine_mem_results/sig_mem_metrics"

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_machine_num() {
    # Helper function for getting the machine-ID from the user to assign to the test results

    # Prompt the use for the machine number to be assigned to the results
    while true; do

        # Get the machine-ID from the user
        read -p "What machine-ID would you like to assign to these results? - " user_response
        
        # Check that the input from the user is a valid integer and store it
        case "$user_response" in

            ''|*[!0-9]*)

                # Output to the user that the input is invalid
                echo -e "Invalid value, please enter a number.\n"
                continue
                ;;
            
            *)
                # Store the machine-ID  from the user and break out of the loop
                machine_num="$user_response"
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
        echo -e "There are already results stored for Machine-ID ($machine_num), would you like to:"
        echo -e "1 - Replace old results and keep same Machine-ID"
        echo -e "2 - Assign a different machine ID\n"

        # Read in the user's response
        read -p "Please select an option (1-2):" user_response

        # Determine the action based on the user's response
        case $user_response in

            1)

                # Remove old results and create new directories
                echo -e "\nReplacing old results\n"
                rm -rf $machine_results_path
                mkdir -p "$machine_speed_results"
                mkdir -p "$kem_mem_results" && mkdir -p "$sig_mem_results"
                break;;

            2)

                # Get a new machine-ID that will assigned to the results instead
                echo -e "Assigning new Machine-ID for test results"
                get_machine_num

                # Set the results directory paths based on the newly assigned machine-ID
                set_result_paths

                # Ensure the new machine-ID does not have results already present
                if [ ! -d "$machine_results_path" ]; then
                    echo -e "No previous results present for Machine-ID ($machine_num), continuing test setup"
                    break
                else
                    echo "There are previous results detected for new Machine-ID value, please select different value or replace old results"
                fi
                ;;
        
        esac

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_test_options() {
    # Function for getting the testing parameters from the user. This includes the machine-ID for the results,
    # the number of test runs, and whether the results will be compared against other machines.

    # Ask the user if they want to compare results with other machines
    while true; do

        # Prompt the user for their response and read it in
        read -p "Do you wish to assign a custom Machine-ID to the performance results? [y/n] - " response_1

        # Determine what action to take based on the user's response
        case $response_1 in

            [Yy]* )

                # Get the machine-ID from the user to assign to the results
                get_machine_num
                break;;

            [Nn]* ) 

                # Output to the user that the default machine-ID will be used and set it to 1
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
            echo -e "Number of test runs set to - $number_of_runs\n"
            break

        else
            echo -e "Invalid input. Please enter a valid integer above 0.\n"

        fi
    
    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function setup_test_suite() {
    # Function for setting up the Liboqs test suite. This includes creating the necessary directories for storing results,
    # checking for existing results, creating the algorithms arrays, and setting up the filepaths for the test binaries.

    # Output the current task to the terminal
    echo "#########################"
    echo "Configure Test Parameters"
    echo -e "#########################\n"

    # Get the test parameters from the user and set the result directory paths
    get_test_options
    set_result_paths

    # Create the un-parsed results directory for the machine-ID
    if [ -d "$test_data_dir/up_results" ]; then

        # Check if there is already results present for assigned machine-ID and handle any clashes
        if [ -d "$machine_results_path" ]; then
            handle_machine_id_clash
            
        else
            mkdir -p "$machine_speed_results"
            mkdir -p "$kem_mem_results" && mkdir -p "$sig_mem_results"

        fi

    else
        mkdir -p "$machine_speed_results"
        mkdir -p "$kem_mem_results" && mkdir -p "$sig_mem_results"

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

            # Set the automatic result parsing flag to enabled
            replace_old_results=1
            
        fi

    fi

    # Set the Liboqs test/bin directory path
    liboqs_test_path="$liboqs_path/build/tests"

    # Set the filepaths for the Liboqs speed test binaries
    kem_speed_bin="$liboqs_test_path/speed_kem"
    sig_speed_bin="$liboqs_test_path/speed_sig"

    # Set the filepaths for the Liboqs memory test binaries
    kem_mem_bin="$liboqs_test_path/test_kem_mem"
    sig_mem_bin="$liboqs_test_path/test_sig_mem"

    # Define the Liboqs test binaries to be checked
    test_bins=("$kem_speed_bin" "$sig_speed_bin" "$kem_mem_bin" "$sig_mem_bin")

    # Ensure the Liboqs binaries are present and executable
    for test_binary in "${test_bins[@]}"; do

        if [ ! -f "$test_binary" ]; then
            echo -e "\n[ERROR] - Liboqs test binaries - ($test_binary) not present, please verify build"
            exit 1
        elif [ ! -x "$test_binary" ]; then
            echo -e "\n[ERROR] - Liboqs test binaries - ($test_binary) not executable, please verify binary permissions"
            exit 1
        fi

    done

    # Set the alg-list txt filepaths
    kem_alg_file="$test_data_dir/alg_lists/kem_algs.txt"
    sig_alg_file="$test_data_dir/alg_lists/sig_algs.txt"

    # Create the PQC KEM and digital signature algorithm list arrays
    kem_algs=()
    while IFS= read -r line; do
        kem_algs+=("$line")
    done < $kem_alg_file

    sig_algs=()
    while IFS= read -r line; do
        sig_algs+=("$line")
    done < $sig_alg_file

    # Declare the PQC algorithm cryptographic operations arrays
    op_kem=("Keygen" "Encaps" "Decaps")
    op_sig=("Keygen" "Sign" "Verify")

    # Create the temp memory results directories for storing Valgrind operation files
    mem_tmp_dir="$tmp_dir/mem_test_tmp"
    rm -rf "$mem_tmp_dir/" && mkdir -p "$mem_tmp_dir"

}

#-------------------------------------------------------------------------------------------------------------------------------
function speed_tests() {
    # Function for performing the Liboqs CPU speed benchmarking tests. This includes running the KEM and digital signature speed tests
    # for the specified number of runs and storing the results in the appropriate results directories.

    # Output the current task to the terminal
    echo "#############################"
    echo "Performing Liboqs Speed Tests"
    echo -e "#############################\n"

    # Perform the Liboqs CPU performance testing for the specified number of runs
    for run_num in $(seq 1 $number_of_runs); do 

        # Execute KEM CPU performance benchmarking
        echo -e "Performing PQC KEM speed test run number - $run_num\n"
        "$kem_speed_bin" > "$machine_speed_results/test-kem-speed-$run_num.csv"

        # Execute digital signature CPU performance benchmarking
        echo -e "Performing PQC digital signature speed test run number - $run_num\n"
        "$sig_speed_bin" > "$machine_speed_results/test-sig-speed-$run_num.csv"

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function mem_tests() {
    # Function for performing the Liboqs memory performance benchmarking tests. This includes running the KEM and digital signature memory tests
    # for the specified number of runs and storing the results in the appropriate results directories.

    # Output the current task to the terminal
    echo -e "##############################"
    echo -e "Performing Liboqs Memory Tests"
    echo -e "*##############################\n"

    # Ensure the temp memory results directories are present
    if [ -d "$test_scripts_path/tmp/" ]; then
        rm -rf "$test_scripts_path/tmp/"
    fi

    # Perform the Liboqs memory performance testing for the specified number of runs
    for run_count in $(seq 1 $number_of_runs); do

        # Output the current test run number to the terminal
        echo -e "Memory Test Run - $run_count\n\n"
        
        # Output the current set of tests to the terminal
        echo -e "KEM Memory Tests\n"

        # Loop through the KEM algorithms and perform the memory tests
        for kem_alg in "${kem_algs[@]}"; do

            # Perform the memory metrics test for each cryptographic operation
            for operation in {0..2}; do

                # Get the current operation string and output to terminal
                op_kem_str=${op_kem[operation]}
                echo -e "$kem_alg - $op_kem_str Test\n"

                # Run the memory test with the Valgrind memory profiler and output the memory metrics
                filename="$kem_mem_results/$kem_alg-$operation-$run_count.txt"
                valgrind --tool=massif --stacks=yes --massif-out-file="$mem_tmp_dir/massif.out" "$kem_mem_bin" "$kem_alg" "$operation"
                ms_print "$mem_tmp_dir/massif.out" > $filename
                rm -f "$mem_tmp_dir/massif.out" && echo -e "\n"
  
            done

            # Clear the temp memory results directory before the next test
            rm -rf "$test_scripts_path/tmp/"

        done

        # Output the current set of tests to the terminal
        echo -e "\nDigital Signature Memory Tests\n"

        # Loop through the digital signature algorithms and the perform memory tests
        for sig_alg in "${sig_algs[@]}"; do

            # Perform the memory metrics test for each cryptographic operation
            for operation in {0..2}; do

                # Get the current operation string and output to terminal
                op_sig_str=${op_sig[operation]}
                echo -e "$sig_alg - $op_sig_str Test\n"

                # Run the memory test with the Valgrind memory profiler and output the memory metrics
                filename="$sig_mem_results/$sig_alg-$operation-$run_count.txt"
                valgrind --tool=massif --stacks=yes --massif-out-file="$mem_tmp_dir/massif.out" "$sig_mem_bin" "$sig_alg" "$operation"
                ms_print "$mem_tmp_dir/massif.out" > $filename
                rm -f "$mem_tmp_dir/massif.out" && echo -e "\n"

            done

            # Clear the temp memory results directory before the next test
            rm -rf "$test_scripts_path/tmp/"

        done

        # Clean up the temp memory results directory
        rm -rf $mem_tmp_dir && rm -rf "$test_scripts_path/tmp"
        mkdir -p "$mem_tmp_dir"

    done

    # Perform the final clean up of the Liboqs memory test temp dirs
    rm -rf $mem_tmp_dir
    rm -rf "$test_scripts_path/tmp"

}

#-------------------------------------------------------------------------------------------------------------------------------
function handle_result_parsing() {
    # Function for handling automatic result parsing based on user-defined flags. Calls the parsing script with 
    # the correct arguments, including the replace flag if set, and verifies whether parsing completed successfully.

    # Check if the automatic result parsing flag is set to enabled
    if [ $parse_results -eq 1 ]; then

        # Call the automatic parsing script based on if old results need to be replaced
        if [ $replace_old_results -eq 0 ]; then

            # Call the result parsing script to parse the results with replace flag not set
            python3 "$parsing_scripts/parse_results.py" \
                --parse-mode="liboqs"  \
                --machine-id="$machine_num" \
                --total-runs=$number_of_runs
            exit_status=$?

        else

            # Call the result parsing script to parse the results with replace flag set
            python3 "$parsing_scripts/parse_results.py" \
                --parse-mode="liboqs"  \
                --machine-id="$machine_num" \
                --total-runs=$number_of_runs \
                --replace-old-results
            exit_status=$?

        fi

        # Ensure that the parsing script completed successfully
        if [ $exit_status -eq 0 ]; then
            echo -e "\nParsed results can be found in the following directory:"
            echo "$test_data_dir/results/liboqs/machine-$machine_num"
        else
            echo -e "\n[WARNING] - Result parsing failed, manual calling of parsing script is now required\n"
        fi 

    elif [ $parse_results -eq 0 ]; then

        # Output the complete message with the test results path to the user
        echo -e "All performance testing complete, the unparsed results for Machine-ID ($machine_num) can be found in:"
        echo "Results Dir Path - $machine_results_path"
        
    else
        echo -e "\n[ERROR] - parse_results flag not set correctly, manual calling of parsing script is now required\n"
        exit 1
            
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Main function for controlling the automated Liboqs PQC computational performance testing

    # Output the welcome message to the terminal
    echo "###########################################################"
    echo "PQC-Evaluation-Tools - Automated Liboqs Performance Testing"
    echo -e "###########################################################\n"

    # Set the default automatic result parsing flags
    parse_results=1
    replace_old_results=0

    # Setup the base environment and testing suite setup
    setup_base_env
    setup_test_suite

    # Perform the Liboqs speed and memory performance tests
    speed_tests
    mem_tests

    # Output the testing complete message to the user
    echo -e "All performance testing complete"

    # Handle the automatic result parsing based on the user input flags
    handle_result_parsing

}
main
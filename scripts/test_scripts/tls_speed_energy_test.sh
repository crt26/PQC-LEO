#!/bin/bash

# Copyright (c) 2023-2026 Callum Turino
# SPDX-License-Identifier: MIT

# Script for controlling automated TLS operation energy benchmarking. It measures key generation, encapsulation, and
# decapsulation for PQC and Hybrid-PQC KEMs; key generation, signing, and verification for PQC, Hybrid-PQC, and classical
# signatures; and key generation and shared-secret derivation for classical key-exchange algorithms. The script configures 
# the required environment and system state, supports custom energy-collector control ports, and restores system state upon 
# completion or interruption.

# DEVELOPER NOTE: Some of the PQC and classic functions could definitely be combined to reduce code duplication at some point.
# It was just done this way to get it working really, this will be refactored in the future to make it more concise.

# Declare global script variables
sys_state_configure_flag="--set-default" # options (--set-default (default method) | --set-custom)
use_custom_control_ports=0 # flag for whether to use custom network control ports for energy collector communication (0 = no, 1 = yes)
sys_state_set_ok=0
trap_cleanup_done=0

#-------------------------------------------------------------------------------------------------------------------------------
function output_help() {
    # Helper function for outputting the help message to the user when the --help flag is present or when incorrect arguments 
    # are passed.

    # Output the supported options and their usage to the user
    echo "Usage: tls_speed_energy_testing.sh [options]"
    echo "Options:"
    echo "--use-custom-sys-state            Used to indicate that custom system state values should be set for the test instead of the default values"
    echo "--use-custom-net-control-ports    Use custom network control ports for energy collector communication"
    echo "--help                            Display the help message"
    
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

            --use-custom-net-control-ports)
                use_custom_control_ports=1
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
function get_ip() {
    # Helper function to prompt the user for an IP address and validate the input to ensure it is in the correct format.

    # Store the passed ip types passed (local/remote)
    local ip_request_string="$1"

    # Define the ipv4 regex pattern for validating the user input
    ipv4_regex_check="^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$"

    # Prompt the user for the IP address of the other machine until a valid response is given
    while true; do

        # Prompt the user for their response and read it in
        read -p "Please enter the $ip_request_string IP address: " usr_ip_input

        # Format the user IP input by removing trailing spaces
        ip_address=$(echo $usr_ip_input | tr -d ' ')

        # Check if the IP address entered is in the correct format
        if [[ $ip_address =~ $ipv4_regex_check ]]; then

            # Ensure that the IP address is not set to 0.0.0.0 or 255.255.255.255 before continuing
            if [[ "$ip_address" == "0.0.0.0" || "$ip_address" == "255.255.255.255" ]]; then
                echo "Invalid IP address: $ip_address. Please enter a valid IP address."
            else
                echo "Other test machine set to - $ip_address"
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

    # Prompt the user for the network control port until a valid response is given
    while true; do

        # Prompt the user for their response and read it in
        read -p "Enter the $port_type network control port number to use for energy collector communication (1-65535): " user_port_input

        # Ensure that the input is a valid integer within the acceptable port range
        if [[ "$user_port_input" =~ ^[0-9]+$ ]] && [ "$user_port_input" -ge 1 ] && [ "$user_port_input" -le 65535 ]; then
            port_num="$user_port_input"
            echo -e "$port_type network control port set to $port_num\n"
            break
        else
            echo -e "Invalid port number, please enter an integer between 1 and 65535.\n"
        fi

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function setup_env() {
    # Function for setting up the basic global variables for the script. This includes setting the root directory, the global 
    # library paths for the test suite, and creating the algorithm arrays. The function establishes the root path by determining 
    # the path of the script and using this, determines the root directory of the project.

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

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_4.0.1"
    provider_path="$libs_dir/oqs_provider/lib"
    provider_flags="-provider default -provider oqsprovider -provider-path $provider_path"

    # Define the temp cert/key storage directory path
    temp_test_storage="$tmp_dir/energy_test_certs"

    # Ensure that the temp cert/key storage directory is present and empty
    if [[ -d "$temp_test_storage" ]]; then
        rm -rf "$temp_test_storage"
    fi
    mkdir -p "$temp_test_storage"

    # Define path to energy testing util scripts
    energy_collector_path="$libs_dir/energy_collector"
    control_sender="$energy_collector_path/build/bin/control_sender"

    # Ensure that the energy tools are built
    if [ ! -d "$energy_collector_path" ]; then
        echo -e "[ERROR] - Energy collector tools not built, please build the tools before running the energy tests."
        exit 1
    fi

    # Declare global test flags
    test_type=0 #0=pqc, 1=hybrid, 2=classic

    # Check the OpenSSL library directory path
    if [[ -d "$openssl_path/lib64" ]]; then
        openssl_lib_path="$openssl_path/lib64"
    else
        openssl_lib_path="$openssl_path/lib"
    fi

    # Export the OpenSSL library filepath
    export LD_LIBRARY_PATH="$openssl_lib_path:$LD_LIBRARY_PATH"

    # Declare the current group var that will be passed to DEFAULT_GROUP env var when changing the test type
    current_group=""

    # Declare the OpenSSL binary path
    openssl_bin="$openssl_path/bin/openssl"

    # Set the alg-list txt filepaths
    kem_alg_file="$test_data_dir/alg_lists/tls_speed_kem_algs.txt"
    sig_alg_file="$test_data_dir/alg_lists/tls_speed_sig_algs.txt"
    hybrid_kem_alg_file="$test_data_dir/alg_lists/tls_speed_hybr_kem_algs.txt"
    hybrid_sig_alg_file="$test_data_dir/alg_lists/tls_speed_hybr_sig_algs.txt"
    classic_sig_alg_file="$test_data_dir/alg_lists/tls_classic_sig_algs.txt"
    classic_key_exchange_alg_file="$test_data_dir/alg_lists/tls_classic_key_exchange_groups.txt"

    # Create the PQC KEM and digital signature algorithm list arrays
    kem_algs=()
    while IFS= read -r line; do
        kem_algs+=("$line")
    done < $kem_alg_file

    sig_algs=()
    while IFS= read -r line; do
        sig_algs+=("$line")
    done < $sig_alg_file

    # Create the hybrid KEM and digital signature algorithm list arrays
    hybrid_kem_algs=()
    while IFS= read -r line; do
        hybrid_kem_algs+=("$line")
    done < $hybrid_kem_alg_file

    hybrid_sig_algs=()
    while IFS= read -r line; do
        hybrid_sig_algs+=("$line")
    done < $hybrid_sig_alg_file

    # Define the list of hybrid KEM algorithms to be excluded from testing due to known issues accessing their KEM encoder
    excluded_hybrid_kems=(
        "X25519MLKEM768"
        "X448MLKEM1024"
        "SecP256r1MLKEM768"
        "SecP384r1MLKEM1024"
        "curveSM2MLKEM768"
    )

    # Filter the hybrid KEM algorithm list to remove any excluded algorithms
    filtered_hybrid_kem_algs=()
    for alg in "${hybrid_kem_algs[@]}"; do

        # Check if the current algorithm is in the excluded list and set the exclude_alg flag accordingly
        exclude_alg=0
        for excluded in "${excluded_hybrid_kems[@]}"; do
            if [[ "$alg" == "$excluded" ]]; then
                exclude_alg=1
                break
            fi
        done

        # If the algorithm is not excluded, add it to the filtered list
        if [[ $exclude_alg -eq 0 ]]; then
            filtered_hybrid_kem_algs+=("$alg")
        fi

    done
    hybrid_kem_algs=("${filtered_hybrid_kem_algs[@]}")

    # Create the classic digital signature and key exchange algorithm list arrays used in result filenames
    classic_filename_sig_algs=()
    while IFS= read -r line; do
        classic_filename_sig_algs+=("$line")
    done < $classic_sig_alg_file

    classic_filename_key_exchange_algs=()
    while IFS= read -r line; do
        classic_filename_key_exchange_algs+=("$line")
    done < $classic_key_exchange_alg_file

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

    # Preserve the script's exit status so trap cleanup does not hide command failures.
    local prior_exit_status=$?

    # Store the passed trap handler flag
    local trap_handler_flag="$1"
    local cleanup_status=0

    # Prevent duplicate cleanup when INT/TERM is followed by EXIT.
    if [ "$trap_cleanup_done" -eq 1 ]; then
        if [ "$trap_handler_flag" == "interrupt" ]; then
            exit 130
        fi
        return 0
    fi
    trap_cleanup_done=1

    # Disable traps during cleanup to avoid recursive trap execution.
    trap - EXIT INT TERM

    # Restore the system state to its default setting
    sys_state_configure "test_end"
    cleanup_status=$?

    # Remove the temp cert/key storage directory
    if [[ -d "$temp_test_storage" ]]; then
        rm -rf "$temp_test_storage"
    fi

    # Clear OID env variables in the current shell.
    source "$util_scripts/oid_handler.sh" --clear-env-oids

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
function configure_control_method() {
    # Function for configuring the control communication method for communicating with the energy collector based on user input. 
    # The function prompts the user to select the control communication method (serial or network) and then collects the relevant 
    # configuration information based on the selected method.

    # Output the current task to the terminal
    echo "-------------------------------"
    echo "Configure the control signaller"
    echo -e "-------------------------------\n"

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
                if [ "$use_custom_control_ports" -eq 1 ]; then

                    # Define the port_num buffer variable
                    port_num=""

                    # Prompt the user for the desired local and remote network control ports for control signalling
                    get_net_port "local"
                    local_port="$port_num"
                    get_net_port "remote"
                    remote_port="$port_num"

                fi

                # Set the com flags based on the user inputs and set communication parameters
                if [ "$use_custom_control_ports" -eq 0 ]; then
                    com_flags=(-Z network -L "$local_ip" -Q "$remote_ip")
                else
                    com_flags=(-Z network -L "$local_ip" -Q "$remote_ip" -N "$local_port" -J "$remote_port")
                fi

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
function get_test_options() {
    # Function for collecting testing parameters from the user. The function prompts the user for the number of iterations to 
    # perform for each testing operation, the number of test runs to perform, and the polling rate for the energy collector 
    # during the test runs. The function validates the user input to ensure it is in the correct format and stores the values in 
    # global variables for use throughout the testing process.

    # Configure the control method for communicating with the energy collector based on user input
    configure_control_method

    # Output the current task to the terminal
    echo "-------------------------------"
    echo "Configure the test parameters"
    echo -e "-------------------------------\n"

    # Ask the user for how many iterations each operation should be run
    while true; do

        # Prompt the user for their response and read it in
        read -p "Enter the number of iterations each operation should be run per test (e.g., 1000): " user_iter_num

        # Check if the input is a valid integer and store it if valid
        if [[ "$user_iter_num" =~ ^[1-9][0-9]*$ ]]; then
            operation_iterations=$user_iter_num
            break
        else
            echo -e "Invalid input. Please enter a valid integer above 0.\n"

        fi

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

    # Ask the user for the polling rate for the energy collector during the test runs
    while true; do

        # Prompt the user for their response and read it in
        read -p "Enter the energy meter polling rate in milliseconds (0 for no delays between polls): " user_poll_rate

        # Check if the input is a valid value (int, 0, or positive float) and store it if valid
        if [[ "$user_poll_rate" =~ ^[0-9]+$|^[0-9]*\.[0-9]+$ ]]; then
            energy_poll_rate=$user_poll_rate
            break
        else
            echo -e "Invalid input. Please enter a valid polling rate (0 or above) or decimal value.\n"

        fi

    done

    # Output newline for formatting
    echo -e "\n"

}

#-------------------------------------------------------------------------------------------------------------------------------
function get_baseline() {
    # Function for getting the baseline energy consumption for the testing machine. The function sends communicates with the 
    # energy collector to signal the start and end of the baseline measurement, and includes a 10 second sleep period to allow for
    # the measurement to be taken.

    # Send the GETREADY message to the collector for baseline measurement
    "$control_sender" -s \
        -T "tls_speed_baseline" \
        -A "baseline" \
        -R "1" \
        -P "$energy_poll_rate" \
        "${com_flags[@]}"

    # Sleep for 10 seconds to allow baseline measurement
    sleep 10

    # Send test stop message to the collector
    "$control_sender" -t "${com_flags[@]}"

}

#-------------------------------------------------------------------------------------------------------------------------------
function create_common_files() {
    # Helper function for precomputing the common files required for TLS operation testing. The function takes in the algorithm type
    # (PQC KEM, PQC signature, classical signature, or classical key exchange) and the specific algorithm. It generates the
    # necessary keypairs, messages, ciphertexts, signatures, and peer shared-secret material for the measured operations. If 
    # the algorithm type is a classical signature or key exchange, the function also takes in the relevant OpenSSL command line 
    # arguments.

    # Store the passed arguments in local variables
    local alg_type="$1"
    local testing_alg="$2"
    local classic_keygen_args="$3"
    local classic_sign_args="$4"
    local -a classic_keygen_arg_array=()
    local -a classic_sign_arg_array=()

    # Ensure that if it is a classic test, that all the required arguments have been passed
    if [ "$alg_type" == "Classic-Sig" ]; then

        # Ensure that both the keygen and sign args have been passed
        if [ -z "$classic_keygen_args" ] || [ -z "$classic_sign_args" ]; then
            echo -e "[ERROR] - Classic Signature algorithm type passed to create_common_files function, but not all required args were provided."
            exit 1
        fi

        # Read in the passed classic keygen and sign args into arrays for use in the OpenSSL commands
        read -r -a classic_keygen_arg_array <<< "$classic_keygen_args"
        read -r -a classic_sign_arg_array <<< "$classic_sign_args"

    elif [ "$alg_type" == "Classic-KEX" ]; then

        # Ensure that the keygen args have been passed
        if [ -z "$classic_keygen_args" ]; then
            echo -e "[ERROR] - Classic Key Exchange algorithm type passed to create_common_files function, but not all required args were provided."
            exit 1
        fi

        # Read in the passed classic keygen args into an array for use in the OpenSSL commands
        read -r -a classic_keygen_arg_array <<< "$classic_keygen_args"

    fi

    # Create the common files based on the algorithm type
    if [ "$alg_type" == "PQC-KEM" ]; then

        # Define the path/filenames for the common testing files
        priv_key_path="$temp_test_storage/${testing_alg}_priv.pem"
        pub_key_path="$temp_test_storage/${testing_alg}_pub.pem"
        ct_path="$temp_test_storage/${testing_alg}_ct.bin"

        # Ensure these files do not already exist and remove if they do
        if [[ -f "$priv_key_path" || -f "$pub_key_path" || -f "$ct_path" ]]; then
            echo -e "[NOTICE] - Removing existing common files for $testing_alg"
            rm -f "$priv_key_path" "$pub_key_path" "$ct_path"
        fi

        # Setup the keypair for the KEM algorithm
        "$openssl_bin" genpkey $provider_flags -algorithm "$testing_alg" -out "$priv_key_path"
        "$openssl_bin" pkey $provider_flags -in "$priv_key_path" -pubout -out "$pub_key_path"

        # Precompute the ciphertext for the decapsulation testing
        "$openssl_bin" pkeyutl $provider_flags -encap -pubin -inkey "$pub_key_path" -out "$ct_path" -secret /dev/null

        # Ensure that all required files were created
        if [[ ! -f "$priv_key_path" || ! -f "$pub_key_path" || ! -f "$ct_path" ]]; then
            echo -e "Error generating keys or ciphertext for $testing_alg, please check the OpenSSL installation and try again."
            exit 1
        fi

    elif [ "$alg_type" == "PQC-Sig" ]; then

        # Define the path/filenames for the common testing files
        priv_key_path="$temp_test_storage/${testing_alg}_priv.pem"
        pub_key_path="$temp_test_storage/${testing_alg}_pub.pem"
        sig_path="$temp_test_storage/${testing_alg}_sig.bin"
        msg_path="$temp_test_storage/${testing_alg}_msg.bin"

        # Ensure that the common files for this alg do not already exist and remove if they do
        if [[ -f "$priv_key_path" || -f "$pub_key_path" || -f "$sig_path" || -f "$msg_path" ]]; then
            echo -e "[NOTICE] - Removing existing common files for $testing_alg"
            rm -f "$priv_key_path" "$pub_key_path" "$sig_path" "$msg_path"
        fi

        # Setup the keypair for the signature algorithm
        "$openssl_bin" genpkey $provider_flags -algorithm "$testing_alg" -out "$priv_key_path"
        "$openssl_bin" pkey $provider_flags -in "$priv_key_path" -pubout -out "$pub_key_path"

        # Create the fixed random message for signing/verification testing
        head -c 512 /dev/urandom > "$msg_path"

        # Precompute the signature for the verification testing
        "$openssl_bin" pkeyutl $provider_flags -sign -inkey "$priv_key_path" -in "$msg_path" -out "$sig_path"

        # Ensure that all required files were created
        if [[ ! -f "$priv_key_path" || ! -f "$pub_key_path" || ! -f "$sig_path" || ! -f "$msg_path" ]]; then
            echo -e "Error generating keys, message, or signature for $testing_alg, please check the OpenSSL installation and try again."
            exit 1
        fi

    elif [ "$alg_type" == "Classic-Sig" ]; then

        # Define the path/filenames for the common testing files
        priv_key_path="$temp_test_storage/${testing_alg}_priv.pem"
        pub_key_path="$temp_test_storage/${testing_alg}_pub.pem"
        sig_path="$temp_test_storage/${testing_alg}_sig.bin"
        msg_path="$temp_test_storage/${testing_alg}_msg.bin"

        # Ensure that the common files for this alg do not already exist and remove if they do
        if [[ -f "$priv_key_path" || -f "$pub_key_path" || -f "$sig_path" || -f "$msg_path" ]]; then
            echo -e "[NOTICE] - Removing existing common files for $testing_alg"
            rm -f "$priv_key_path" "$pub_key_path" "$sig_path" "$msg_path"
        fi

        # Setup the keypair for the classic signature algorithm
        "$openssl_bin" genpkey $provider_flags "${classic_keygen_arg_array[@]}" -out "$priv_key_path"
        "$openssl_bin" pkey $provider_flags -in "$priv_key_path" -pubout -out "$pub_key_path"

        # Create the fixed random message for signing/verification testing
        head -c 512 /dev/urandom > "$msg_path"

        # Precompute the signature for the verification testing
        "$openssl_bin" pkeyutl \
            $provider_flags \
            -sign \
            "${classic_sign_arg_array[@]}" \
            -inkey "$priv_key_path" \
            -in "$msg_path" \
            -out "$sig_path"

        # Ensure that all required files were created
        if [[ ! -f "$priv_key_path" || ! -f "$pub_key_path" || ! -f "$sig_path" || ! -f "$msg_path" ]]; then
            echo -e "Error generating keys, message, or signature for $testing_alg, please check the OpenSSL installation and try again."
            exit 1
        fi

    elif [ "$alg_type" == "Classic-KEX" ]; then

        # Define the path/filenames for the common testing files
        local_priv_key_path="$temp_test_storage/${testing_alg}_local_priv.pem"
        local_pub_key_path="$temp_test_storage/${testing_alg}_local_pub.pem"
        peer_priv_key_path="$temp_test_storage/${testing_alg}_peer_priv.pem"
        peer_pub_key_path="$temp_test_storage/${testing_alg}_peer_pub.pem"
        local_secret_path="$temp_test_storage/${testing_alg}_local_secret.bin"
        peer_secret_path="$temp_test_storage/${testing_alg}_peer_secret.bin"

        # Ensure that the common files for this alg do not already exist and remove if they do
        local file_vars=($local_priv_key_path $local_pub_key_path $peer_priv_key_path $peer_pub_key_path $local_secret_path $peer_secret_path)

        for file in "${file_vars[@]}"; do
            if [[ -f "$file" ]]; then
                echo -e "[NOTICE] - Removing existing common file: $file"
                rm -f "$file"
            fi
        done

        # Create the local and peer keypairs for the classic key exchange algorithm
        "$openssl_bin" genpkey $provider_flags "${classic_keygen_arg_array[@]}" -out "$local_priv_key_path"
        "$openssl_bin" pkey $provider_flags -in "$local_priv_key_path" -pubout -out "$local_pub_key_path"
        "$openssl_bin" genpkey $provider_flags "${classic_keygen_arg_array[@]}" -out "$peer_priv_key_path"
        "$openssl_bin" pkey $provider_flags -in "$peer_priv_key_path" -pubout -out "$peer_pub_key_path"

        # Test the local and peer derivation to ensure that both peers derive the same shared secret
        "$openssl_bin" pkeyutl $provider_flags -derive -inkey "$local_priv_key_path" -peerkey "$peer_pub_key_path" -out "$local_secret_path"
        "$openssl_bin" pkeyutl $provider_flags -derive -inkey "$peer_priv_key_path" -peerkey "$local_pub_key_path" -out "$peer_secret_path"

        # Confirm that both peers derived the same shared secret
        if ! cmp -s "$local_secret_path" "$peer_secret_path"; then
            echo "[ERROR] - Derived secrets do not match for $testing_alg"
            exit 1
        fi

        # Ensure that all required files were created
        for file in "${file_vars[@]}"; do
            if [[ ! -f "$file" ]]; then
                echo -e "Error generating keys or shared secrets for $testing_alg, please check the OpenSSL installation and try again."
                exit 1
            fi
        done

    else

        # Output an error message and exit if an invalid algorithm type is passed
        echo -e "[ERROR] - Invalid algorithm type passed to create_common_files function, please check the code and try again."
        exit 1

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function pqc_kem_testing()  {
    # Function for performing the KEM operation testing for both the KEM and hybrid KEM algorithms. The function loops through 
    # the algorithms in the defined lists and performs the keygen, encapsulation, and decapsulation operations for each algorithm 
    # for the defined number of iterations.

    # Concat the two types of kem algs
    local all_kems=( "${kem_algs[@]}" "${hybrid_kem_algs[@]}" )

    # Ensure that the temp storage directory is present and empty
    if [[ -d "$temp_test_storage" ]]; then
        rm -rf "$temp_test_storage"/*
    else
        echo "[NOTICE] - Temporary test storage directory does not exist, creating it now..."
        mkdir -p "$temp_test_storage"
    fi

    # Loop through the KEM algorithms and run the tests for each
    for kem_alg in "${all_kems[@]}"; do

        # Create the common files required for this KEM algorithm
        create_common_files "PQC-KEM" "$kem_alg"

        # Output current testing to the user
        echo "Testing KEM $kem_alg - Keygen"

        # Send the GETREADY message to the collector for keygen testing
        "$control_sender" -s \
            -T "tls_speed_kem_keygen" \
            -A "$kem_alg" \
            -R "$run_num" \
            -P "$energy_poll_rate" \
            "${com_flags[@]}"
        exit_code=$?

        # Ensure no issues with the command
        if [ $exit_code -ne 0 ]; then
            echo -e "[ERROR] - Error sending GETREADY message to energy collector, please check the connection and try again."
            exit 1
        fi

        # Perform the keygen test for the defined number of iterations
        for ((i=1; i<=operation_iterations; i++)); do
            
            # Perform the keygen operation
            taskset -c "$TARGET_CPU_CORE" "$openssl_bin" genpkey $provider_flags -algorithm "$kem_alg" -out /dev/null
            exit_code=$?

            # Check for errors during the operation
            if [ $exit_code -ne 0 ]; then
                echo -e "[ERROR] - Error during $kem_alg keygen operation"
                exit 1
            fi

        done

        # Send the testing complete message to the collector
        "$control_sender" -t "${com_flags[@]}"

        # Output current testing to the user
        echo "Testing KEM $kem_alg - Encaps"

        # Send the GETREADY message to the collector for encapsulation testing
        "$control_sender" -s \
            -T "tls_speed_kem_encaps" \
            -A "$kem_alg" \
            -R "$run_num" \
            -P "$energy_poll_rate" \
            "${com_flags[@]}"
        exit_code=$?

        # Ensure no issues with the command
        if [ $exit_code -ne 0 ]; then
            echo -e "[ERROR] - Error sending GETREADY message to energy collector, please check the connection and try again."
            exit 1
        fi

        # Perform the encapsulation test for the defined number of iterations
        for ((i=1; i<=operation_iterations; i++)); do

            # Perform the encapsulation operation
            taskset -c "$TARGET_CPU_CORE" "$openssl_bin" pkeyutl $provider_flags -encap -pubin -inkey "$pub_key_path" -out /dev/null -secret /dev/null
            exit_code=$?

            # Check for errors during the operation
            if [ $exit_code -ne 0 ]; then
                echo -e "[ERROR] - Error during $kem_alg encapsulation operation"
                exit 1
            fi
        
        done

        # Send the testing complete message to the collector
        "$control_sender" -t "${com_flags[@]}"

        # Output current testing to the user
        echo "Testing KEM $kem_alg - Decaps"

        # Send the GETREADY message to the collector for decapsulation testing
        "$control_sender" -s \
            -T "tls_speed_kem_decaps" \
            -A "$kem_alg" \
            -R "$run_num" \
            -P "$energy_poll_rate" \
            "${com_flags[@]}"
        exit_code=$?

        # Ensure no issues with the command
        if [ $exit_code -ne 0 ]; then
            echo -e "[ERROR] - Error sending GETREADY message to energy collector, please check the connection and try again."
            exit 1
        fi

        # Perform the decapsulation test for the defined number of iterations
        for ((i=1; i<=operation_iterations; i++)); do

            # Perform the decapsulation operation
            taskset -c "$TARGET_CPU_CORE" "$openssl_bin" pkeyutl $provider_flags -decap -inkey "$priv_key_path" -in "$ct_path" -secret /dev/null
            exit_code=$?

            # Check for errors during the operation
            if [ $exit_code -ne 0 ]; then
                echo -e "[ERROR] - Error during $kem_alg decapsulation operation"
                exit 1
            fi

        done

        # Send the testing complete message to the collector
        "$control_sender" -t "${com_flags[@]}"

    done

    # Clean up the temp storage directory
    if [[ -d "$temp_test_storage" ]]; then
        rm -rf "$temp_test_storage"/*
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function pqc_sig_testing() {
    # Function for performing the signature operation testing for both the signature and hybrid signature algorithms. The function 
    # loops through the algorithms in the defined lists and performs the keygen, signing, and verification operations for each 
    # algorithm for the defined number of iterations.

    # Concat the two types of signature algs
    local all_sigs=( "${sig_algs[@]}" "${hybrid_sig_algs[@]}" )

    # Ensure that the temp storage directory is present and empty
    if [[ -d "$temp_test_storage" ]]; then
        rm -rf "$temp_test_storage"/*
    else
        echo "[NOTICE] - Temporary test storage directory does not exist, creating it now..."
        mkdir -p "$temp_test_storage"
    fi

    # Loop through the signature algorithms and run the tests for each
    for sig_alg in "${all_sigs[@]}"; do

        # Create the common files required for this signature algorithm
        create_common_files "PQC-Sig" "$sig_alg"

        # Output the current testing to the user
        echo "Testing SIG $sig_alg - Keygen"

        # Send the GETREADY message to the collector for keygen testing
        "$control_sender" -s \
            -T "tls_speed_sig_keygen" \
            -A "$sig_alg" \
            -R "$run_num" \
            -P "$energy_poll_rate" \
            "${com_flags[@]}"
        exit_code=$?

        # Ensure no issues with the command
        if [ $exit_code -ne 0 ]; then
            echo -e "[ERROR] - Error sending GETREADY message to energy collector, please check the connection and try again."
            exit 1
        fi

        # Perform the keygen test for the defined number of iterations
        for ((i=1; i<=operation_iterations; i++)); do

            # Perform the keygen operation
            taskset -c "$TARGET_CPU_CORE" "$openssl_bin" genpkey $provider_flags -algorithm "$sig_alg" -out /dev/null
            exit_code=$?

            # Check for errors during the operation
            if [ $exit_code -ne 0 ]; then
                echo -e "[ERROR] - Error during $sig_alg keygen operation"
                exit 1
            fi

        done

        # Send the testing complete message to the collector
        "$control_sender" -t "${com_flags[@]}"

        # Output the current testing to the user
        echo "Testing SIG $sig_alg - Sign"

        # Send the GETREADY message to the collector for signing testing
        "$control_sender" -s \
            -T "tls_speed_sig_sign" \
            -A "$sig_alg" \
            -R "$run_num" \
            -P "$energy_poll_rate" \
            "${com_flags[@]}"
        exit_code=$?

        # Ensure no issues with the command
        if [ $exit_code -ne 0 ]; then
            echo -e "[ERROR] - Error sending GETREADY message to energy collector, please check the connection and try again."
            exit 1
        fi

        # Perform the signing test for the defined number of iterations
        for ((i=1; i<=operation_iterations; i++)); do

            # Perform the signing operation
            taskset -c "$TARGET_CPU_CORE" "$openssl_bin" pkeyutl $provider_flags -sign -inkey "$priv_key_path" -in "$msg_path" -out /dev/null
            exit_code=$?

            # Check for errors during the operation
            if [ $exit_code -ne 0 ]; then
                echo -e "[ERROR] - Error during $sig_alg signing operation"
                exit 1
            fi

        done

        # Send the testing complete message to the collector
        "$control_sender" -t "${com_flags[@]}"

        # Output the current testing to the user
        echo "Testing SIG $sig_alg - Verify"

        # Send the GETREADY message to the collector for verification testing
        "$control_sender" -s \
            -T "tls_speed_sig_verify" \
            -A "$sig_alg" \
            -R "$run_num" \
            -P "$energy_poll_rate" \
            "${com_flags[@]}"
        exit_code=$?

        # Ensure no issues with the command
        if [ $exit_code -ne 0 ]; then
            echo -e "[ERROR] - Error sending GETREADY message to energy collector, please check the connection and try again."
            exit 1
        fi

        # Perform the verification test for the defined number of iterations
        for ((i=1; i<=operation_iterations; i++)); do

            # Perform the verification operation
            taskset -c "$TARGET_CPU_CORE" "$openssl_bin" pkeyutl $provider_flags -verify -pubin -inkey "$pub_key_path" -in "$msg_path" -sigfile "$sig_path" > /dev/null
            exit_code=$?

            # Check for errors during the operation
            if [ $exit_code -ne 0 ]; then
                echo -e "[ERROR] - Error during $sig_alg verification operation"
                exit 1
            fi

        done

        # Send the testing complete message to the collector
        "$control_sender" -t "${com_flags[@]}"

    done

    # Clean up the temp storage directory
    if [[ -d "$temp_test_storage" ]]; then
        rm -rf "$temp_test_storage"/*
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function classic_sig_testing() {
    # Function for measuring key generation, signing, and verification energy usage for the configured classical signatures.
    # The function loops through the defined classical signature algorithms and performs the keygen, signing, and verification
    # operations for each algorithm for the defined number of iterations.

    # Ensure that the temp storage directory is present and empty
    if [[ -d "$temp_test_storage" ]]; then
        rm -rf "$temp_test_storage"/*
    else
        echo "[NOTICE] - Temporary test storage directory does not exist, creating it now..."
        mkdir -p "$temp_test_storage"
    fi

    # Define the OpenSSL key-generation arguments for the classical signature tests
    local classic_sig_openssl_args=(
        "-algorithm RSA -pkeyopt rsa_keygen_bits:2048"
        "-algorithm RSA -pkeyopt rsa_keygen_bits:3072"
        "-algorithm RSA -pkeyopt rsa_keygen_bits:4096"
        "-algorithm RSA-PSS -pkeyopt rsa_keygen_bits:2048"
        "-algorithm RSA-PSS -pkeyopt rsa_keygen_bits:3072"
        "-algorithm RSA-PSS -pkeyopt rsa_keygen_bits:4096"
        "-algorithm EC -pkeyopt ec_paramgen_curve:prime256v1"
        "-algorithm EC -pkeyopt ec_paramgen_curve:secp384r1"
        "-algorithm EC -pkeyopt ec_paramgen_curve:secp521r1"
        "-algorithm ED25519"
        "-algorithm ED448"
        "-algorithm EC -pkeyopt ec_paramgen_curve:brainpoolP256r1"
        "-algorithm EC -pkeyopt ec_paramgen_curve:brainpoolP384r1"
        "-algorithm EC -pkeyopt ec_paramgen_curve:brainpoolP512r1"
    )

    # Loop through the classic signature algorithms and perform the keygen, signing, and verification operations for each
    for alg_name_index in "${!classic_filename_sig_algs[@]}"; do

        # Set the current OpenSSL algorithm name and param for the signature testing
        sig_alg="${classic_filename_sig_algs[$alg_name_index]}"
        algorithm_arg_string="${classic_sig_openssl_args[$alg_name_index]}"

        # Define the arrays for storing the OpenSSL command arguments for the current signature algorithm
        keygen_args=()
        sign_args=()

        # Read in the keygen arguments from the algorithm name string and store them in the keygen_args array
        read -r -a keygen_args <<< "$algorithm_arg_string"

        # Based on the algorithm type, set the signing arguments accordingly
        case "$sig_alg" in

            RSA_2048|RSA_3072|RSA_4096)
                sign_args=(-rawin -digest sha256 -pkeyopt rsa_padding_mode:pss -pkeyopt rsa_pss_saltlen:digest)
                ;;

            RSA-PSS_2048|RSA-PSS_3072|RSA-PSS_4096)
                sign_args=(-rawin -digest sha256 -pkeyopt rsa_padding_mode:pss -pkeyopt rsa_pss_saltlen:digest)
                ;;

            prime256v1|brainpoolP256r1)
                sign_args=(-rawin -digest sha256)
                ;;

            secp384r1|brainpoolP384r1)
                sign_args=(-rawin -digest sha384)
                ;;

            secp521r1|brainpoolP512r1)
                sign_args=(-rawin -digest sha512)
                ;;

            ed25519|ed448)
                sign_args=(-rawin)
                ;;

            *)
                echo "[ERROR] - Unsupported classical signature algorithm: $sig_alg"
                exit 1
                ;;

        esac

        # Create the common files for the current signature algorithm
        create_common_files "Classic-Sig" "$sig_alg" "${keygen_args[*]}" "${sign_args[*]}"
        

        # Output the current test to the user
        echo "Testing Classic SIG $sig_alg - Keygen"

        # Send the GETREADY message to the collector for keygen testing
        "$control_sender" -s \
            -T "tls_speed_sig_keygen" \
            -A "$sig_alg" \
            -R "$run_num" \
            -P "$energy_poll_rate" \
            "${com_flags[@]}"
        exit_code=$?

        # Ensure no issues with the command
        if [ $exit_code -ne 0 ]; then
            echo -e "[ERROR] - Error sending GETREADY message to energy collector, please check the connection and try again."
            exit 1
        fi

        # Perform the keygen test for the defined number of iterations
        for ((i=1; i<=operation_iterations; i++)); do

            # Perform the keygen operation
            taskset -c "$TARGET_CPU_CORE" "$openssl_bin" genpkey $provider_flags "${keygen_args[@]}" -out /dev/null
            exit_code=$?

            # Check for errors during the operation
            if [ $exit_code -ne 0 ]; then
                echo -e "[ERROR] - Error during $sig_alg keygen operation"
                exit 1
            fi

        done

        # Send the testing complete message to the collector
        "$control_sender" -t "${com_flags[@]}"

        # Output the current test to the user
        echo "Testing Classic SIG $sig_alg - Sign"

        # Send the GETREADY message to the collector for signing testing
        "$control_sender" -s \
            -T "tls_speed_sig_sign" \
            -A "$sig_alg" \
            -R "$run_num" \
            -P "$energy_poll_rate" \
            "${com_flags[@]}"
        exit_code=$?

        # Ensure no issues with the command
        if [ $exit_code -ne 0 ]; then
            echo -e "[ERROR] - Error sending GETREADY message to energy collector, please check the connection and try again."
            exit 1
        fi

        # Perform the signing test for the defined number of iterations
        for ((i=1; i<=operation_iterations; i++)); do

            # Perform the signing operation
            taskset -c "$TARGET_CPU_CORE" \
                "$openssl_bin" pkeyutl \
                $provider_flags \
                -sign \
                "${sign_args[@]}" \
                -inkey "$priv_key_path" \
                -in "$msg_path" \
                -out /dev/null
            exit_code=$?

            # Check for errors during the operation
            if [ $exit_code -ne 0 ]; then
                echo -e "[ERROR] - Error during $sig_alg signing operation"
                exit 1
            fi

        done

        # Send the testing complete message to the collector
        "$control_sender" -t "${com_flags[@]}"

        # Output the current test to the user
        echo "Testing Classic SIG $sig_alg - Verify"

        # Send the GETREADY message to the collector for verification testing
        "$control_sender" -s \
            -T "tls_speed_sig_verify" \
            -A "$sig_alg" \
            -R "$run_num" \
            -P "$energy_poll_rate" \
            "${com_flags[@]}"
        exit_code=$?

        # Ensure no issues with the command
        if [ $exit_code -ne 0 ]; then
            echo -e "[ERROR] - Error sending GETREADY message to energy collector, please check the connection and try again."
            exit 1
        fi

        # Perform the verification test for the defined number of iterations
        for ((i=1; i<=operation_iterations; i++)); do

            # Perform the verification operation
            taskset -c "$TARGET_CPU_CORE" \
                "$openssl_bin" pkeyutl \
                $provider_flags \
                -verify \
                "${sign_args[@]}" \
                -pubin \
                -inkey "$pub_key_path" \
                -in "$msg_path" \
                -sigfile "$sig_path" \
                > /dev/null
            exit_code=$?

            # Check for errors during the operation
            if [ $exit_code -ne 0 ]; then
                echo -e "[ERROR] - Error during $sig_alg verification operation"
                exit 1
            fi

        done

        # Send the testing complete message to the collector
        "$control_sender" -t "${com_flags[@]}"

    done

    # Clean up the temp storage directory
    if [[ -d "$temp_test_storage" ]]; then
        rm -rf "$temp_test_storage"/*
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function classic_key_exchange_testing() {
    # Function for measuring key-generation and shared-secret-derivation energy usage for the configured classical
    # XDH, NIST-curve ECDH, and Brainpool ECDH key-exchange algorithms. The function loops through the defined classical key 
    # exchange algorithms and performs the keygen and derivation operations for each algorithm for the defined number of iterations.
    
    # Define the OpenSSL algorithm name and param array for the key-exchange testing
    local classic_kex_openssl_args=(
        "-algorithm X25519"
        "-algorithm X448"
        "-algorithm EC -pkeyopt ec_paramgen_curve:prime256v1"
        "-algorithm EC -pkeyopt ec_paramgen_curve:secp384r1"
        "-algorithm EC -pkeyopt ec_paramgen_curve:secp521r1"
        "-algorithm EC -pkeyopt ec_paramgen_curve:brainpoolP256r1"
        "-algorithm EC -pkeyopt ec_paramgen_curve:brainpoolP384r1"
        "-algorithm EC -pkeyopt ec_paramgen_curve:brainpoolP512r1"
    )

    # Loop through the classic key exchange algorithms and perform the keygen and derivation testing
    for alg_name_index in "${!classic_filename_key_exchange_algs[@]}"; do

        # Set the current OpenSSL algorithm name and param for the key exchange testing
        key_exchange_alg="${classic_filename_key_exchange_algs[$alg_name_index]}"
        algorithm_arg_string="${classic_kex_openssl_args[$alg_name_index]}"

        # Define the keygen OpenSSL arguments for the current key exchange algorithm
        keygen_args=()
        read -r -a keygen_args <<< "$algorithm_arg_string"

        # Create the common files for the current key exchange algorithm
        create_common_files "Classic-KEX" "$key_exchange_alg" "${keygen_args[*]}"

        # Output the current test to the user
        echo "Testing Classic Key Exchange $key_exchange_alg - Keygen"

        # Send the GETREADY message to the collector for keygen testing
        "$control_sender" -s \
            -T "tls_speed_key-exchange_keygen" \
            -A "$key_exchange_alg" \
            -R "$run_num" \
            -P "$energy_poll_rate" \
            "${com_flags[@]}"
        exit_code=$?

        # Ensure no issues with the command
        if [ $exit_code -ne 0 ]; then
            echo -e "[ERROR] - Error sending GETREADY message to energy collector, please check the connection and try again."
            exit 1
        fi

        # Perform the keygen test for the defined number of iterations
        for ((i=1; i<=operation_iterations; i++)); do

            # Perform the keygen operation
            taskset -c "$TARGET_CPU_CORE" "$openssl_bin" genpkey $provider_flags "${keygen_args[@]}" -out /dev/null
            exit_code=$?

            # Check for errors during the operation
            if [ $exit_code -ne 0 ]; then
                echo -e "[ERROR] - Error during $key_exchange_alg keygen operation"
                exit 1
            fi

        done

        # Send the keygen testing complete message to the collector
        "$control_sender" -t "${com_flags[@]}"

        # Output the current test to the user
        echo "Testing Classic Key Exchange $key_exchange_alg - Derive"

        # Send the GETREADY message to the collector for derivation testing
        "$control_sender" -s \
            -T "tls_speed_key-exchange_derive" \
            -A "$key_exchange_alg" \
            -R "$run_num" \
            -P "$energy_poll_rate" \
            "${com_flags[@]}"
        exit_code=$?

        # Ensure no issues with the command
        if [ $exit_code -ne 0 ]; then
            echo -e "[ERROR] - Error sending GETREADY message to energy collector, please check the connection and try again."
            exit 1
        fi

        # Perform the derivation test for the defined number of iterations
        for ((i=1; i<=operation_iterations; i++)); do

            # Perform the derivation operation
            taskset -c "$TARGET_CPU_CORE" \
                "$openssl_bin" pkeyutl \
                $provider_flags \
                -derive \
                -inkey "$local_priv_key_path" \
                -peerkey "$peer_pub_key_path" \
                -out /dev/null
            exit_code=$?

            # Check for errors during the operation
            if [ $exit_code -ne 0 ]; then
                echo -e "[ERROR] - Error during $key_exchange_alg derivation operation"
                exit 1
            fi

        done

        # Send the testing complete message to the collector
        "$control_sender" -t "${com_flags[@]}"

    done

    # Clean up the temp storage directory
    if [[ -d "$temp_test_storage" ]]; then
        rm -rf "$temp_test_storage"/*
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Main function for controlling the automated TLS operation energy testing suite.

    # Output the welcome message to the terminal
    echo "############################################"
    echo "PQC-LEO - TLS Operation Energy Testing Suite"
    echo -e "############################################\n"

    # Check if any arguments have been passed to the script and parse them if so
    if [[ "$#" -gt 0 ]]; then
        parse_args "$@"
    fi

    # Setup the environment for the script and get testing options
    setup_env

    # Set traps before state changes so cleanup runs even if configuration exits early
    trap 'trap_handler "exit"' EXIT
    trap 'trap_handler "interrupt"' INT TERM

    # Configure the system state and set script traps
    sys_state_configure "test_start"

    # Get the test options from the user 
    get_test_options

    # Output the current task to the terminal
    echo "-------------------------"
    echo "Performing Energy Testing"
    echo -e "-------------------------\n"

    # Gather the baseline energy measurement
    echo -e "Gathering baseline energy measurement...\n"
    get_baseline
    echo -e "Baseline energy measurement complete\n"

    # Set OID env variables for OQS-Provider KEM algorithms
    source "$util_scripts/oid_handler.sh" --set-env-oids

    # Loop through the number of test runs and perform the tests
    for run_num in $(seq 1 $number_of_runs); do

        # Output the current run number to the terminal
        echo -e "------------------------"
        echo "Starting test run $run_num of $number_of_runs"
        echo -e "------------------------\n"

        # Perform the various TLS operation tests for the current run
        pqc_kem_testing
        pqc_sig_testing
        classic_sig_testing
        classic_key_exchange_testing

    done

    # Send END testing message to the collector
    "$control_sender" --end-testing "${com_flags[@]}"

    # Output the test completion message to the terminal
    echo -e "\nAll testing runs completed"
    echo "Energy usage results will be stored in the test_data directory on the collector machine"

}
main "$@"

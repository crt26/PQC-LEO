#!/bin/bash

# Copyright (c) 2023-2025 Callum Turino
# SPDX-License-Identifier: MIT

# Server-side script for executing TLS handshake performance tests in coordination with a remote client. 
# It evaluates all supported combinations of classic, Post-Quantum Cryptography (PQC), and Hybrid-PQC signature
# and Key Encapsulation Mechanism (KEM) algorithms using OpenSSL 3.5.0, with support for both native PQC 
# implementations and those integrated via OQS-Provider. The script performs three main test suites: 
# PQC-only, Hybrid-PQC, and Classic handshake tests. It is called by the TLS benchmarking controller script 
# and uses globally defined test parameters, certificate and key files, and control signalling for synchronisation with the client. 

#-------------------------------------------------------------------------------------------------------------------------------
function setup_base_env() {
    # Function for setting up the basic global variables for the script. This includes setting the root directory, the global 
    # library paths for the test suite, and creating the algorithm arrays. The function establishes the root path by determining 
    # the path of the script and using this, determines the root directory of the project.

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
    test_data_dir="$root_dir/test_data"
    test_scripts_path="$root_dir/scripts/test_scripts"
    util_scripts="$root_dir/scripts/utility_scripts"

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_3.5.0"
    provider_path="$libs_dir/oqs_provider/lib"

    # Declare global key storage directory paths
    key_storage_path="$test_data_dir/keys"
    pqc_cert_dir="$key_storage_path/pqc"
    classic_cert_dir="$key_storage_path/classic"
    hybrid_cert_dir="$key_storage_path/hybrid"

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

    # Set the alg-list txt filepaths
    kem_alg_file="$test_data_dir/alg_lists/tls_kem_algs.txt"
    sig_alg_file="$test_data_dir/alg_lists/tls_sig_algs.txt"
    hybrid_kem_alg_file="$test_data_dir/alg_lists/tls_hybr_kem_algs.txt"
    hybrid_sig_alg_file="$test_data_dir/alg_lists/tls_hybr_sig_algs.txt"

    # Set the test classic algorithms and ciphers arrays
    classic_algs=("RSA_2048" "RSA_3072" "RSA_4096" "prime256v1" "secp384r1" "secp521r1")
    ciphers=("TLS_AES_256_GCM_SHA384" "TLS_CHACHA20_POLY1305_SHA256" "TLS_AES_128_GCM_SHA256")

    # Ensure that the control sleep time env variables have been passed if not disabled
    if [ -z "$CONTROL_SLEEP_TIME" ] && [ -z "$DISABLE_CONTROL_SLEEP" ]; then
        echo "[ERROR] - Control sleep time env variable not set. This likely indicates a broader issue with the TLS benchmarking controller script."
        exit 1
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function set_test_env() {
    # Function for setting the default group depending on what type of TLS test is being performed. The function is passed
    # the test type and the configure mode as arguments. The test type is used to determine which algorithms to use for the 
    # test, and the configure mode is used to determine whether to use the default or custom OpenSSL configuration.
    # The test type options are: (pqc, hybrid-pqc, classic) 0=pqc, 1=hybrid, 2=classic.

    # Declare the local variables for the arguments passed to the function
    local test_type="$1"
    local configure_mode="$2"

    # Clear the current_group array before setting the new group
    current_group=""

    # Determine the test parameters based on the test type passed to the function
    if [ "$test_type" -eq 0 ]; then

        # Set the PQC KEM algorithms array
        kem_algs=()
        while IFS= read -r line; do
            kem_algs+=("$line")
        done < $kem_alg_file

        # Set the PQC digital signature algorithms array
        sig_algs=()
        while IFS= read -r line; do
            sig_algs+=("$line")
        done < $sig_alg_file

        # Populate the current group array with PQC algorithms
        for kem_alg in "${kem_algs[@]}"; do
            current_group+=":$kem_alg"
        done

        # Remove the beginning : at index 0
        current_group="${current_group:1}"

        # Set the configurations in openssl.cnf file for PQC testing
        if ! "$util_scripts/configure_openssl_cnf.sh" $configure_mode; then
            echo "[ERROR] - Failed to modify OpenSSL configuration."
            exit 1
        fi

    elif [ "$test_type" -eq 1 ]; then

        # Set the Hybrid-PQC KEM algorithms array
        kem_algs=()
        while IFS= read -r line; do
            kem_algs+=("$line")
        done < $hybrid_kem_alg_file

        # Set the Hybrid-PQC digital signature algorithms array
        sig_algs=()
        while IFS= read -r line; do
            sig_algs+=("$line")
        done < $hybrid_sig_alg_file

        # Populate the current group array with PQC algorithms
        for hybr_kem_alg in "${kem_algs[@]}"; do
            current_group+=":$hybr_kem_alg"
        done
        
        # Remove the beginning : at index 0
        current_group="${current_group:1}"

        # Set the configurations in openssl.cnf file for Hybrid-PQC testing
        if ! "$util_scripts/configure_openssl_cnf.sh" $configure_mode; then
            echo "[ERROR] - Failed to modify OpenSSL configuration."
            exit 1
        fi

    elif [ "$test_type" -eq 2 ]; then

        # Set the configurations in openssl.cnf file for classic algorithm testing
        current_group="ffdhe2048:ffdhe3072:ffdhe4096:prime256v1:secp384r1:secp521r1"

        # Set the configurations in openssl.cnf file for classic algorithm testing
        if ! "$util_scripts/configure_openssl_cnf.sh" $configure_mode; then
            echo "[ERROR] - Failed to modify OpenSSL configuration."
            exit 1
        fi

    fi

    # Export the default group env var for openssl.cnf
    export DEFAULT_GROUPS=$current_group
    
}

#-------------------------------------------------------------------------------------------------------------------------------
function check_control_port() {
    # Helper function that waits until the client is listening on the control port 
    # before allowing the client to send a control signal. If enabled, it includes 
    # a short delay to ensure the client is ready to receive the connection.

    # Wait until the client is listening on the control port before sending the signal
    until nc -z "$CLIENT_IP" "$CLIENT_CONTROL_PORT" > /dev/null 2>&1; do
        :
    done

    # Perform a small delay before sending the signal to allow the target device to be ready
    if [ -v $DISABLE_CONTROL_SLEEP ]; then
        sleep $CONTROL_SLEEP_TIME
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function control_signal() {
    # Function for handling server-to-client control signalling during TLS handshake testing.
    # Supports: control_send, control_wait, and iteration_handshake modes for coordination.

    # Declare the local variables for arguments passed to the function
    local type="$1"
    local message="$2"

    # Kill any lingering netcat processes
    pkill -f "nc -l -p $SERVER_CONTROL_PORT"

    # Determine the type of control signal method to be used
    case "$type" in

        "control_send")

            # Check if the control port is open on the client before sending the signal
            check_control_port

            # Send the control signal to the client until successful
            until echo "$message" | nc -n -w 1 "$CLIENT_IP" "$CLIENT_CONTROL_PORT" > /dev/null 2>&1; do
                exit_status=$?
                if [ "$exit_status" -ne 0 ]; then
                    :
                else
                    break
                fi
            done
            ;;

        "control_wait")

            # Wait until the control signal has been received and return the message
            while true; do

                # Wait for a connection from the client and capture the request in a variable
                signal_message=$(nc -l -p "$SERVER_CONTROL_PORT")

                # Check if the received control signal message is valid
                if [[ "$signal_message" == "ready" || "$signal_message" == "skip" || "$signal_message" == "complete" ]]; then
                    break
                fi

            done
            ;;

        "iteration_handshake")

            # Wait for the client to send the handshake-ready signal
            while true; do
                signal_message=$(nc -l -p "$SERVER_CONTROL_PORT")
                if [[ "$signal_message" == "handshake_ready" ]]; then
                    break
                fi
            done

            # Check if the control port is open on the client before sending the signal
            check_control_port

            # Send the handshake ready signal to the client until successful
            until echo "handshake_ready" | nc -n -w 1 "$CLIENT_IP" "$CLIENT_CONTROL_PORT" > /dev/null 2>&1; do
                exit_status=$?
                if [ "$exit_status" -ne 0 ]; then
                    :
                else
                    break
                fi
            done
            ;;

        *)

            # Output error message if an unknown control signal type is passed
            echo "[ERROR] - Unknown control signal type: $type"
            exit 1
            ;;

    esac

}

#-------------------------------------------------------------------------------------------------------------------------------
function pqc_tests() {
    # Function for performing the PQC and Hybrid-PQC TLS handshake tests. Digital signature and KEM algorithms are 
    # loaded based on the selected test type (0=pqc, 1=hybrid) via set_test_env. Using the current sig/kem
    # algorithm combination, the function starts an OpenSSL s_server process that the client can connect to.

    # Loop through all PQC/Hybrid-PQC sig algorithms to be used for signing
    for sig in "${sig_algs[@]}"; do

        # Loop through all PQC/Hybrid-PQC KEM algorithms to be used for key exchange
        for kem in "${kem_algs[@]}"; do

            # Perform the current run sig/kem combination test until it passes
            while true; do

                # Check if an old OpenSSL process is still active
                pgrep_output=$(pgrep openssl)

                # Kill the old process if active
                if [[ ! -z $pgrep_output ]]; then
                    kill "$pgrep_output"
                fi

                # Output the current TLS test info
                echo -e "\n-------------------------------------------------------------------------"
                echo "[OUTPUT] - Run - $run_num, Signature - $sig, KEM - $kem"

                # Perform the iteration handshake
                control_signal "iteration_handshake"

                # Wait for the ready signal from the client machine
                control_signal "control_wait"

                # Set the cert and key files depending on the test type
                if [ "$test_type" -eq 0 ]; then
                    cert_file="$pqc_cert_dir/""${sig/:/_}""_srv.crt"
                    key_file="$pqc_cert_dir/""${sig/:/_}""_srv.key"

                elif [ "$test_type" -eq 1 ]; then
                    cert_file="$hybrid_cert_dir/""${sig/:/_}""_srv.crt"
                    key_file="$hybrid_cert_dir/""${sig/:/_}""_srv.key"
                fi

                # Start the OpenSSL s_server process
                "$openssl_path/bin/openssl" s_server \
                    -cert  "$cert_file" \
                    -key   "$key_file"  \
                    -provider default \
                    -provider oqsprovider \
                    -provider-path "$provider_path" \
                    -www \
                    -tls1_3 \
                    -groups "$kem" \
                    -accept "$S_SERVER_PORT" &
                server_pid=$!

                # Check if the server has started before sending the ready signal to the client
                until netstat -tuln | grep ":$S_SERVER_PORT" > /dev/null; do
                    :
                done

                # Send the ready signal to the client
                control_signal "control_send" "ready"

                # Wait for the test status signal from the client
                control_signal "control_wait"

                # Check if the test status signal received from the client is complete or failed
                if [ $signal_message == "complete" ]; then

                    # Successful completion of the test from the client
                    kill $server_pid
                    break

                elif [ $signal_message == "failed" ]; then

                    # Restart sig/kem combination if a failed signal is received from the client
                    echo "[ERROR] - 3000 failed attempts signal received from client, restarting sig/kem combination"
                    kill $server_pid
                    sleep 2
                
                fi

            done

        done
    
    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function classic_tests() {
    # Function for performing the Classic TLS handshake tests using predefined signature algorithms and ciphers.
    # The function will loop through all classic algorithms and ciphers, starting a new OpenSSL s_server process
    # for each combination so that the client can connect to.

    # Loop through all the classic ciphers to be used for testing
    for cipher in "${ciphers[@]}"; do

        # Loop through all the classic signature algorithms and perform tests with the current cipher
        for classic_alg in "${classic_algs[@]}"; do

            # Perform the current run cipher/sig combination test until it passes
            while true; do

                # Check if an old OpenSSL process is still active
                pgrep_output=$(pgrep openssl)

                # Kill the old process if active
                if [[ ! -z $pgrep_output ]]; then
                    kill "$pgrep_output"
                fi

                # Output the current TLS handshake test info
                echo -e "\n-------------------------------------------------------------------------"
                echo "[OUTPUT] - Classic Cipher Tests, Run - $run_num, Cipher - $cipher, Sig Alg - $classic_alg"

                # Perform the iteration handshake
                control_signal "iteration_handshake"

                # Wait for the ready signal from the client
                control_signal "control_wait"

                # Check if the current digital signature is RSA or ECC to determine what parameters s_server needs
                if [[ $classic_alg == "prime256v1" || $classic_alg == "secp384r1" || $classic_alg == "secp521r1" ]]; then

                    # Set the cert/key filenames for the current ECC algorithm
                    classic_cert_file="$classic_cert_dir/${classic_alg}_srv.crt"
                    classic_key_file="$classic_cert_dir/${classic_alg}_srv.key"

                    # Start the ECC test server processes
                    "$openssl_path/bin/openssl" s_server \
                        -cert $classic_cert_file \
                        -key $classic_key_file \
                        -www \
                        -tls1_3 \
                        -named_curve $classic_alg \
                        -ciphersuites "$cipher" \
                        -accept $S_SERVER_PORT &
                    server_pid=$!

                else

                    # Set the cert/key filenames for the current RSA algorithm
                    classic_cert_file="$classic_cert_dir/${classic_alg}_srv.crt"
                    classic_key_file="$classic_cert_dir/${classic_alg}_srv.key"

                    # Start the RSA test server processes
                    "$openssl_path/bin/openssl" s_server \
                        -cert $classic_cert_file \
                        -key $classic_key_file \
                        -www \
                        -tls1_3 \
                        -ciphersuites $cipher \
                        -accept $S_SERVER_PORT &
                    server_pid=$!  

                fi

                # Check if the s_server has started before sending the ready signal to the client
                until netstat -tuln | grep ":$S_SERVER_PORT" > /dev/null; do
                    :
                done

                # Send the ready signal to the client and wait for the test status signal
                control_signal "control_send" "ready"

                # Wait for the final test status signal from the client
                control_signal "control_wait"

                # Check if the test status signal received from the client is complete or failed
                if [ $signal_message == "complete" ]; then

                    # Successful completion of the test from the client
                    kill $server_pid
                    break

                elif [ $signal_message == "failed" ]; then

                    # Restart the sig/cipher combination if the failed signal is received from the client
                    echo "[ERROR] - 3000 failed attempts signal received from client, restarting cipher/sig combination"
                    kill $server_pid
                    sleep 2
                
                fi

            done

        done

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function tls_server_test_entrypoint() {
    # Main entry point for the server-side TLS handshake testing script.
    # Coordinates setup, connection to the server, and execution of PQC, Hybrid-PQC, and Classic handshake tests
    # over a specified number of runs. Ensures the test environment is configured and handles control signalling.

    # Setup the base environment for the test suite
    setup_base_env
    clear

    # Check if custom ports have been used and if so, outputting a warning message
    if [ "$SERVER_CONTROL_PORT" != "25000" ] || [ "$CLIENT_CONTROL_PORT" != "25001" ] || [ "$S_SERVER_PORT" != "4433" ]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Custom TCP ports detected - Server Control Port: $SERVER_CONTROL_PORT, Client Control Port: $CLIENT_CONTROL_PORT, S_Server Port: $S_SERVER_PORT"
        echo "Please ensure that the client is passed the flags for any custom TCP port values"
        echo -e "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
    fi

    # Output the waiting message and begin the initial handshake
    echo -e "Server Script Activated, waiting for connection from client..."
    control_signal "iteration_handshake"
    clear

    # Output the test start message
    echo -e "\n####################################"
    echo "Performing TLS Handshake Tests"
    echo "####################################"

    # Perform the TLS handshake tests for the specified number of runs
    for run_num in $(seq 1 $NUM_RUN); do

        # Output the current run number
        echo -e "\n************************************************"
        echo "Performing TLS Handshake Tests Run - $run_num"
        echo -e "************************************************\n"

        # Perform the current run of PQC TLS handshake tests
        echo "-----------------"
        echo "PQC run $run_num"
        echo -e "-----------------\n"
        control_signal "iteration_handshake"

        # Set the test type, environment, and call the PQC tests function
        test_type=0
        set_test_env $test_type 2
        pqc_tests
        echo -e "[OUTPUT] - Completed $run_num PQC TLS Handshake Tests"

        # Perform the current run of Hybrid-PQC TLS handshake tests
        echo "-----------------"
        echo "Hybrid-PQC run $run_num"
        echo -e "-----------------\n"
        control_signal "iteration_handshake"

        # Set the test type, environment, and call the Hybrid-PQC tests function
        test_type=1
        set_test_env $test_type 2
        pqc_tests
        echo "[OUTPUT] - Completed $run_num Hybrid-PQC TLS Handshake Tests"

        # Perform the current run of classic handshake tests
        echo "-----------------"
        echo "Classic run $run_num"
        echo -e "-----------------\n"
        control_signal "iteration_handshake"

        # Set the test type, environment, and call the classic tests function
        test_type=2
        set_test_env $test_type 2
        classic_tests
        echo "[OUTPUT] - Completed $run_num Classic TLS Handshake Tests"

        # Output that the current run is complete
        echo "[OUTPUT] - All $run_num Testing Completed"

    done
    
}
tls_server_test_entrypoint
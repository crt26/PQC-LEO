#!/bin/bash

# Copyright (c) 2023-2026 Callum Turino
# SPDX-License-Identifier: MIT

# Client-side script for executing TLS handshake performance tests in coordination with a remote server.
# It evaluates PQC and Hybrid-PQC signature/KEM pairs and every configured classical
# signature/key-exchange-group/ciphersuite combination using OpenSSL 4.0.2, with support for both native PQC
# implementations and those integrated via the OQS-Provider. The script performs three main test suites:
# PQC, Hybrid-PQC, and classical handshake tests. It is called by the TLS benchmarking controller script
# and uses globally defined test parameters, certificate files, and control signalling for synchronisation with the server.
# As the client-side script, it stores the output of the tests based on parameters passed to it from the main controller script,
# saving the results to the designated directories for later analysis. The script also provides support for energy consumption testing 
# by coordinating with an energy collector utility, sending control signals to indicate test boundaries. This must be enabled during the 
# call of the main TLS benchmarking controller script and requires additional parameters to be passed for configuration.

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

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_4.0.2"
    provider_path="$libs_dir/oqs_provider/lib"

    # Declare global key storage directory paths
    key_storage_path="$test_data_dir/keys"
    pqc_cert_dir="$key_storage_path/pqc"
    classic_cert_dir="$key_storage_path/classic"
    hybrid_cert_dir="$key_storage_path/hybrid"

    # Define path to energy testing util scripts and import the communication flags array
    energy_collector_path="$libs_dir/energy_collector"
    control_sender="$energy_collector_path/build/bin/control_sender"
    communication_flags=($COMMUNICATION_FLAGS)

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

    # Set the OpenSSL command based on whether standard testing or energy testing is being performed
    if [ "$ENABLE_ENERGY_TESTING" -eq 0 ]; then
        openssl_cmd="$openssl_path/bin/openssl"
    else
        openssl_cmd="taskset -c $TARGET_CPU_CORE $openssl_path/bin/openssl"
    fi

    # Declare the current group var that will be passed to DEFAULT_GROUP env var when changing the test type
    current_group=""

    # Set the alg-list txt filepaths
    kem_alg_file="$test_data_dir/alg_lists/tls_kem_algs.txt"
    sig_alg_file="$test_data_dir/alg_lists/tls_sig_algs.txt"
    hybrid_kem_alg_file="$test_data_dir/alg_lists/tls_hybr_kem_algs.txt"
    hybrid_sig_alg_file="$test_data_dir/alg_lists/tls_hybr_sig_algs.txt"
    classic_sig_alg_file="$test_data_dir/alg_lists/tls_classic_sig_algs.txt"
    classic_key_exchange_group_file="$test_data_dir/alg_lists/tls_classic_key_exchange_groups.txt"
    classic_ciphersuite_file="$test_data_dir/alg_lists/tls_classic_ciphersuites.txt"

    # Ensure that the control sleep time env variables has been passed if not disabled
    if [ -z "$CONTROL_SLEEP_TIME" ] && [ -z "$DISABLE_CONTROL_SLEEP" ]; then
        echo "[ERROR] - Control sleep time env variable not set. This likely indicates a broader issue with the TLS benchmarking controller script."
        exit 1
    fi
    
}

#-------------------------------------------------------------------------------------------------------------------------------
function get_baseline() {
    # Function for performing the baseline measurement for energy testing. It sends a control signal to the energy collector 
    # machine to indicate the start of the baseline measurement, then sleeps for a specified amount of time to allow the 
    # measurement of the systems idle power consumption to be taken.
    
    # Send the GETREADY message to the collector machine for baseline measurement
    "$control_sender" -s \
        -T "tls_handshake_baseline" \
        -A "baseline" \
        -R "1" \
        -P "$ENERGY_POLL_RATE" \
        "${communication_flags[@]}"

    # Sleep for 10 seconds to allow baseline measurement to be taken
    sleep 10

    # Send test stop message to the collector machine
    "$control_sender" -t "${communication_flags[@]}"
    
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

    # Clear the current_group string before setting the new group
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

        # Populate the current group string with PQC algorithms
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

        # Populate the current group string with PQC algorithms
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

        # Set the classic signature algorithms
        classic_sig_algs=()
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ -n "$line" ]]; then
                classic_sig_algs+=("$line")
            fi
        done < "$classic_sig_alg_file"

        # Set the classic TLS key exchange groups
        classic_key_exchange_groups=()
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ -n "$line" ]]; then
                classic_key_exchange_groups+=("$line")
            fi
        done < "$classic_key_exchange_group_file"

        # Set the classic TLS ciphersuites
        classic_ciphersuites=()
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ -n "$line" ]]; then
                classic_ciphersuites+=("$line")
            fi
        done < "$classic_ciphersuite_file"

        # Populate the current group string with the configured classic TLS key exchange groups
        for classic_group in "${classic_key_exchange_groups[@]}"; do
            current_group+=":$classic_group"
        done

        # Remove the leading colon from the group string
        current_group="${current_group:1}"

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
    # Helper function that waits until the server is listening on the control port 
    # before allowing the client to send a control signal. If enabled, it includes 
    # a short delay to ensure the server is ready to receive the connection.

    # Wait until the server is listening on the control port before sending the signal
    until nc -z "$SERVER_IP" "$SERVER_CONTROL_PORT" > /dev/null 2>&1; do
        :
    done

    # Perform a small delay before sending the signal to allow the target device to be ready
    if [ -v $DISABLE_CONTROL_SLEEP ]; then
        sleep $CONTROL_SLEEP_TIME
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function control_signal() {
    # Function for handling client-to-server control signalling during TLS handshake testing.
    # Supports: control_send, control_wait, and iteration_handshake modes for coordination.

    # Declare the local variables for arguments passed to the function
    local type="$1"
    local message="$2"

    # Kill any lingering netcat processes
    pkill -f "nc -l -p $CLIENT_CONTROL_PORT"

    # Determine the type of control signal method to be used
    case "$type" in

        "control_send")

            # Check if the control port is open on the server before sending the signal
            check_control_port

            # Send the control signal to the server until successful
            until echo "$message" | nc -n -w 1 "$SERVER_IP" "$SERVER_CONTROL_PORT" > /dev/null 2>&1; do
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

                # Wait for a connection from the server and capture the request in a variable
                signal_message=$(nc -l -p "$CLIENT_CONTROL_PORT")

                # Check if the received control signal message is valid
                if [[ "$signal_message" == "ready" || "$signal_message" == "skip" || "$signal_message" == "complete" ]]; then
                    break
                fi

            done
            ;;

        "iteration_handshake")

            # Check if the control port is open on the server before sending the signal
            check_control_port

            # Send the handshake ready signal to the server until successful
            until echo "handshake_ready" | nc -n -w 1 "$SERVER_IP" "$SERVER_CONTROL_PORT" > /dev/null 2>&1; do
                exit_status=$?
                if [ "$exit_status" -ne 0 ]; then
                    :
                else
                    break
                fi
            done

            # Wait for the server to send the handshake ready signal
            while true; do
                signal_message=$(nc -l -p "$CLIENT_CONTROL_PORT")
                if [[ "$signal_message" == "handshake_ready" ]]; then
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
function test_success_check() {
    # Helper function for checking the exit status of a test attempt and determining whether to retry or not. It uses a fail 
    # counter to track the number of consecutive failures for a test combination, and if the number of failures exceeds a 
    # specified limit, it reports a hard failure to the caller.
    # Return codes: 0=success, 1=retry, 2=failed after max retries.

    # Declare the local variables to store test check variables
    local test_exit_code="$1"
    local max_fail_count=3000

    # Exit code 0 means the attempt succeeded
    if [ "$test_exit_code" -eq 0 ]; then
        return 0
    fi

    # While below the retry limit, increment the failure counter and request a retry
    if [ "$fail_counter" -lt "$max_fail_count" ]; then
        ((fail_counter++))
        echo "[ERROR] - s_time process failed $fail_counter times, retrying"
        return 1
    fi

    # Retry limit reached: report hard failure to the caller
    return 2

}

#-------------------------------------------------------------------------------------------------------------------------------
function check_s_time_errors() {
    # Helper function for checking the s_time process exit code and stderr captured in a temporary file. A non-zero exit code
    # or the presence of "verify error" in stderr indicates a failure, which is reported to the terminal. The function returns
    # a non-zero status when an error is detected; otherwise, it returns 0.

    # Declare the local variables for the arguments passed to the function
    local s_time_exit_code="$1"
    local s_time_error_file="$2"

    # Report any detected errors to the terminal and return a non-zero exit code to the caller
    if [ "$s_time_exit_code" -ne 0 ] || grep -q "^verify error:" "$s_time_error_file"; then
        cat "$s_time_error_file" >&2
        rm -f -- "$s_time_error_file"
        return 1
    fi

    # Remove the temporary stderr output file
    rm -f -- "$s_time_error_file"
    return 0

}

#-------------------------------------------------------------------------------------------------------------------------------
function pqc_tests() {
    # Function for performing the PQC and Hybrid-PQC TLS handshake tests. Digital signature and KEM algorithms are loaded based 
    # on the selected test type (0=pqc, 1=hybrid) via set_test_env. Each sig/KEM pair is tested using OpenSSL's s_time.

    # Loop through all PQC/Hybrid-PQC sig algorithms to be used for signing
    for sig in "${sig_algs[@]}"; do

        # Loop through all PQC/Hybrid-PQC KEM algorithms to be used for key exchange
        for kem in "${kem_algs[@]}"; do

            # Set the fail flag to the default value of false
            fail_flag=0

            # Perform the current run sig/kem combination test until it passes
            while true; do

                # Output the current TLS test info to the terminal
                echo -e "\n-------------------------------------------------------------------------"
                echo "[OUTPUT] - Run Number - $run_num, Signature - $sig, KEM - $kem"
                
                # Perform the iteration handshake
                control_signal "iteration_handshake"

                # Send the client ready signal and wait for the server ready signal
                control_signal "control_send" "ready"
                control_signal "control_wait"

                # Perform the test or skip based on sig/kem combination
                if [ $signal_message == "ready" ]; then

                    # Set the cert variable based on the current sig
                    sig_name="${sig/:/_}"

                    # Set the cert and key files depending on the test type
                    if [ "$test_type" -eq 0 ]; then
                        cert_file="$pqc_cert_dir/""${sig_name}""_CA.crt"
                        handshake_dir=$PQC_HANDSHAKE

                    elif [ "$test_type" -eq 1 ]; then
                        cert_file="$hybrid_cert_dir/""${sig/:/_}""_CA.crt"
                        handshake_dir=$HYBRID_HANDSHAKE
                        
                    fi

                    # Set the output filename based on the current combination and run
                    output_name="tls_handshake_${run_num}_${sig_name}_${kem}.txt"

                    # Define the output file path based on various env flags and test type
                    if [ "$ENABLE_ENERGY_TESTING" -eq 0 ]; then
                        output_path="$handshake_dir/$output_name"

                    elif [ "$ENABLE_ENERGY_TESTING" -eq 1 ] && [ "$STORE_TEST_RESULTS" -eq 0 ]; then
                        output_path="/dev/null"
                    
                    elif [ "$ENABLE_ENERGY_TESTING" -eq 1 ] && [ "$STORE_TEST_RESULTS" -eq 1 ]; then
                        output_path="$handshake_dir/$output_name"
                    
                    fi

                    # Reset the fail counter
                    fail_counter=0

                    # Perform the testing until successful or the fail counter reaches its limit
                    while true; do

                        # Track if the current attempt failed (0=success, 1=failed)
                        attempt_exit_code=0

                        # Perform necessary steps to perform TLS handshake testing based on whether energy testing is enabled or not
                        if [ "$ENABLE_ENERGY_TESTING" -eq 0 ]; then

                            # Create a temporary file for the s_time error output
                            s_time_error_file=$(mktemp) || {
                                echo "[ERROR] - Failed to create a temporary file for the s_time error output."
                                exit 1
                            }

                            # Run the OpenSSL s_time process with the current test parameters and grab the exit code
                            $openssl_cmd s_time \
                                -connect "${SERVER_IP}:${S_SERVER_PORT}" \
                                -CAfile  "$cert_file" \
                                -time    "$TIME_NUM" \
                                -verify  1 \
                                -provider default \
                                -provider oqsprovider \
                                -provider-path "$provider_path" \
                                > "$output_path" 2>"$s_time_error_file"
                            attempt_exit_code=$?

                            # Check the process result and stderr output, then remove the temporary file
                            if ! check_s_time_errors "$attempt_exit_code" "$s_time_error_file"; then
                                attempt_exit_code=1
                            fi

                        elif [ "$ENABLE_ENERGY_TESTING" -eq 1 ]; then

                            # Define the session-ID test type flags
                            session_id_types=("new" "reuse")

                            # Perform both new and reuse session ID testing if energy testing is enabled
                            for session_id in "${session_id_types[@]}"; do

                                # Create a temporary file for the s_time error output
                                s_time_error_file=$(mktemp) || {
                                    echo "[ERROR] - Failed to create a temporary file for the s_time error output."
                                    exit 1
                                }

                                # Send control signal to energy collector to get ready for a new test
                                "$control_sender" -s \
                                    -T "tls_handshake_${session_id}" \
                                    -A "$sig_name@$kem" \
                                    -R "$run_num" \
                                    -P "$ENERGY_POLL_RATE" \
                                    "${communication_flags[@]}"

                                # Run the OpenSSL s_time process with the current test parameters and grab the exit code
                                $openssl_cmd s_time \
                                    -connect "${SERVER_IP}:${S_SERVER_PORT}" \
                                    -CAfile  "$cert_file" \
                                    -time    "$TIME_NUM" \
                                    -verify  1 \
                                    -provider default \
                                    -provider oqsprovider \
                                    -provider-path "$provider_path" \
                                    "-${session_id}" \
                                    >> "$output_path" 2>"$s_time_error_file"
                                session_exit_code=$?

                                # Check the process result and stderr output, then remove the temporary file
                                if ! check_s_time_errors "$session_exit_code" "$s_time_error_file"; then
                                    session_exit_code=1
                                fi

                                # Send energy test complete signal for the current session-ID test
                                "$control_sender" -t "${communication_flags[@]}"

                                # If any session-ID test fails, mark attempt failed and retry entire combination
                                if [ "$session_exit_code" -ne 0 ]; then
                                    attempt_exit_code=1
                                    break
                                fi

                            done

                        fi

                        # Check if the attempt was successful and capture the return code to determine whether to retry or not
                        test_success_check "$attempt_exit_code"
                        check_status=$?

                        # Based on the return code, determine whether to retry the current test combination or not
                        if [ "$check_status" -eq 0 ]; then
                            fail_flag=0
                            break

                        elif [ "$check_status" -eq 1 ]; then
                            continue

                        else
                            fail_flag=1
                            break

                        fi
                        
                    done

                    # Send the test complete or failed signal to the server, if failed, then restart the current run sig/kem combination
                    if [ $fail_flag -eq 0 ]; then
                        control_signal "control_send" "complete"
                        break

                    else
                        echo "[ERROR] - Failed to establish test connection, restarting current run sig/kem combination"
                        control_signal "control_send" "failed"
                        sleep 4
                    
                    fi

                elif [ $signal_message == "skip" ]; then

                    # Send the skip test acknowledgement to the server
                    echo "[OUTPUT] - Skipping test as both sig and kem are classic!!!"
                    control_signal "control_send" "complete"
                    break
                
                fi
            
            done

        done

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function classic_tests() {
    # Function for performing the Classic TLS handshake tests using the generated signature algorithm, key exchange group, and
    # ciphersuite lists. Each configured combination is tested using OpenSSL's s_time utility.

    # Loop through all configured classic signature algorithms
    for classic_sig in "${classic_sig_algs[@]}"; do

        # Loop through all configured classic TLS key exchange groups
        for key_exchange_group in "${classic_key_exchange_groups[@]}"; do

            # Restrict the s_time client to the current TLS key exchange group through the OpenSSL configuration
            export DEFAULT_GROUPS="$key_exchange_group"

            # Loop through all configured classic TLS ciphersuites
            for ciphersuite in "${classic_ciphersuites[@]}"; do

                # Set the fail flag to the default value of false
                fail_flag=0

                # Perform the current signature/group/ciphersuite combination test until it passes
                while true; do

                    # Output the current TLS handshake test info
                    echo -e "\n-------------------------------------------------------------------------"
                    echo "[OUTPUT] - Classic Tests, Run - $run_num, Signature - $classic_sig, Key Exchange Group - $key_exchange_group, Ciphersuite - $ciphersuite"

                    # Perform the iteration handshake
                    control_signal "iteration_handshake"

                    # Send the client ready signal and wait for the server ready signal
                    control_signal "control_send" "ready"
                    control_signal "control_wait"

                    # Set the output filename and CA certificate based on the current test combination
                    output_name="tls_handshake_classic_${run_num}_${classic_sig}_${key_exchange_group}_${ciphersuite}.txt"
                    classic_cert_file="$classic_cert_dir/${classic_sig}_CA.crt"

                    # Ensure that the CA certificate for the current signature algorithm is present
                    if [[ ! -f "$classic_cert_file" ]]; then
                        echo "[ERROR] - Missing classic CA certificate for signature algorithm: $classic_sig"
                        exit 1
                    fi

                    # Define the output file path based on various env flags and test type
                    if [ "$ENABLE_ENERGY_TESTING" -eq 0 ]; then
                        output_path="$CLASSIC_HANDSHAKE/$output_name"

                    elif [ "$ENABLE_ENERGY_TESTING" -eq 1 ] && [ "$STORE_TEST_RESULTS" -eq 0 ]; then
                        output_path="/dev/null"

                    elif [ "$ENABLE_ENERGY_TESTING" -eq 1 ] && [ "$STORE_TEST_RESULTS" -eq 1 ]; then
                        output_path="$CLASSIC_HANDSHAKE/$output_name"

                    fi

                    # Reset the fail counter
                    fail_counter=0

                    # Perform the testing until successful or the fail counter reaches its limit
                    while true; do

                        # Track if the current attempt failed (0=success, 1=failed)
                        attempt_exit_code=0

                        # Perform necessary steps to perform TLS handshake testing based on whether energy testing is enabled or not
                        if [ "$ENABLE_ENERGY_TESTING" -eq 0 ]; then

                            # Create a temporary file for the s_time error output
                            s_time_error_file=$(mktemp) || {
                                echo "[ERROR] - Failed to create a temporary file for the s_time error output."
                                exit 1
                            }

                            # Run the OpenSSL s_time process with the current test parameters and grab the exit code
                            $openssl_cmd s_time \
                                -connect "${SERVER_IP}:${S_SERVER_PORT}" \
                                -CAfile "$classic_cert_file" \
                                -time "$TIME_NUM" \
                                -verify 1 \
                                -ciphersuites "$ciphersuite" \
                                >> "$output_path" 2>"$s_time_error_file"
                            attempt_exit_code=$?

                            # Check the process result and stderr output, then remove the temporary file
                            if ! check_s_time_errors "$attempt_exit_code" "$s_time_error_file"; then
                                attempt_exit_code=1
                            fi

                        elif [ "$ENABLE_ENERGY_TESTING" -eq 1 ]; then

                            # Define the session-ID test type flags
                            session_id_types=("new" "reuse")

                            # Perform both new and reuse session ID testing if energy testing is enabled
                            for session_id in "${session_id_types[@]}"; do

                                # Create a temporary file for the s_time error output
                                s_time_error_file=$(mktemp) || {
                                    echo "[ERROR] - Failed to create a temporary file for the s_time error output."
                                    exit 1
                                }

                                # Send control signal to energy collector to get ready for a new test
                                "$control_sender" -s \
                                    -T "tls_handshake_${session_id}" \
                                    -A "$classic_sig@$key_exchange_group@$ciphersuite" \
                                    -R "$run_num" \
                                    -P "$ENERGY_POLL_RATE" \
                                    "${communication_flags[@]}"

                                # Run the OpenSSL s_time process with the current test parameters and grab the exit code
                                $openssl_cmd s_time \
                                    -connect "${SERVER_IP}:${S_SERVER_PORT}" \
                                    -CAfile "$classic_cert_file" \
                                    -time "$TIME_NUM" \
                                    -verify 1 \
                                    -ciphersuites "$ciphersuite" \
                                    "-${session_id}" \
                                    >> "$output_path" 2>"$s_time_error_file"
                                session_exit_code=$?

                                # Check the process result and stderr output, then remove the temporary file
                                if ! check_s_time_errors "$session_exit_code" "$s_time_error_file"; then
                                    session_exit_code=1
                                fi

                                # Send energy test complete signal for the current session-ID test
                                "$control_sender" -t "${communication_flags[@]}"

                                # If any session-ID test fails, mark attempt failed and retry entire combination
                                if [ "$session_exit_code" -ne 0 ]; then
                                    attempt_exit_code=1
                                    break
                                fi

                            done

                        fi

                        # Check if the attempt was successful and capture the return code to determine whether to retry or not
                        test_success_check "$attempt_exit_code"
                        check_status=$?

                        # Based on the return code, determine whether to retry the current test combination or not
                        if [ "$check_status" -eq 0 ]; then
                            fail_flag=0
                            break

                        elif [ "$check_status" -eq 1 ]; then
                            continue

                        else
                            fail_flag=1
                            break

                        fi

                    done

                    # Send the test complete or failed signal to the server
                    if [ "$fail_flag" -eq 0 ]; then

                        # Send the complete signal to the server
                        control_signal "control_send" "complete"
                        break

                    else

                        # Send the failed signal and restart the current signature/group/ciphersuite combination after 4 seconds
                        echo "[ERROR] - Failed to establish test connection, restarting current signature/group/ciphersuite combination"
                        control_signal "control_send" "failed"
                        sleep 4

                    fi

                done

            done

        done

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function tls_client_test_entrypoint() {
    # Main entry point for the client-side TLS handshake testing script. Coordinates setup, connection to the server, and 
    # execution of PQC, Hybrid-PQC, and Classic handshake tests over a specified number of runs. Ensures the test environment 
    # is configured and handles control signalling.

    # Setup the base environment for the test suite
    setup_base_env
    
    # Check if custom ports have been used and, if so, output a warning message
    if [ "$SERVER_CONTROL_PORT" != "25000" ] || [ "$CLIENT_CONTROL_PORT" != "25001" ] || [ "$S_SERVER_PORT" != "4433" ]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Custom TCP ports detected - Server Control Port: $SERVER_CONTROL_PORT, Client Control Port: $CLIENT_CONTROL_PORT, S_Server Port: $S_SERVER_PORT"
        echo "Please ensure that the server has been passed the same custom TCP port values, otherwise tests will fail"
        echo -e "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
    fi

    # Perform the baseline measurement if energy testing is enabled
    if [ "$ENABLE_ENERGY_TESTING" -eq 1 ]; then
        echo -e "Gathering baseline energy measurement...\n"
        get_baseline
        echo -e "Baseline energy measurement complete\n"
    fi

    # Output the waiting message and begin the initial handshake
    echo -e "Client Script Activated, connecting to server...\n"
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

    # Send test complete control signal if energy testing is enabled
    if [ "$ENABLE_ENERGY_TESTING" -eq 1 ]; then
        "$control_sender" --end-testing "${communication_flags[@]}"
    fi

}
tls_client_test_entrypoint

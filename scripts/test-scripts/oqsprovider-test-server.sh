#!/bin/bash

# Copyright (c) 2024 Callum Turino
# SPDX-License-Identifier: MIT

# Server script for the TLS handshake tests, this script will coordinate with the client machine to conduct the tests
# using all the combinations of PQC and classic sig/kem using the global test parameters provided. 
# This script consists of three main tests, the PQC TLS handshake tests, Hybrid-PQC TLS handshake tests, and the Classic TLS handshake tests. 

#-------------------------------------------------------------------------------------------------------------------------------
function setup_base_env() {
    # Function for setting up the basic global variables for the test suite. This includes setting the root directory
    # and the global library paths for the test suite. The function establishes the root path by determining the path of the script and 
    # using this, determines the root directory of the project.

    # Determine directory that the script is being run from
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    # Try and find the .dir_marker.tmp file to determine the root directory
    current_dir="$script_dir"

    while true; do

        # Check if the .pqc_eval_dir_marker.tmp file is present
        if [ -f "$current_dir/.pqc_eval_dir_marker.tmp" ]; then
            root_dir="$current_dir"  # Set root_dir to the directory, not including the file name
            break
        fi

        # Move up a directory and check again
        current_dir=$(dirname "$current_dir")

        # If the root directory is reached and the file is not found, exit the script
        if [ "$current_dir" == "/" ]; then
            echo -e "Root directory path file not present, please ensure the path is correct and try again."
            exit 1
        fi

    done

    # Declaring main dir path variables based on root dir
    libs_dir="$root_dir/lib"
    tmp_dir="$root_dir/tmp"
    test_data_dir="$root_dir/test-data"
    test_scripts_path="$root_dir/scripts/test-scripts"
    util_scripts="$root_dir/scripts/utility-scripts"

    # Declaring global library path files
    open_ssl_path="$libs_dir/openssl_3.2"
    liboqs_path="$libs_dir/liboqs"
    oqs_openssl_path="$libs_dir/oqs-openssl"
    provider_path="$libs_dir/oqs-openssl/lib"

    # Declaring key storage dir paths
    key_storage_path="$test_data_dir/keys"
    pqc_cert_dir="$key_storage_path/pqc"
    classic_cert_dir="$key_storage_path/classic"
    hybrid_cert_dir="$key_storage_path/hybrid"

    # Declaring global flags
    test_type=0 #0=pqc, 1=classic, 2=hybrid

    # Exporting openssl lib path
    if [[ -d "$open_ssl_path/lib64" ]]; then
        openssl_lib_path="$open_ssl_path/lib64"
    else
        openssl_lib_path="$open_ssl_path/lib"
    fi

    export LD_LIBRARY_PATH="$openssl_lib_path:$LD_LIBRARY_PATH"

    # Declaring current group var that will be passed to DEFAULT_GROUP env var when changing test type
    current_group=""

    # Declaring static algorithm arrays and alg-list filepaths
    kem_alg_file="$test_data_dir/alg-lists/ssl-kem-algs.txt"
    sig_alg_file="$test_data_dir/alg-lists/ssl-sig-algs.txt"
    hybrid_kem_alg_file="$test_data_dir/alg-lists/ssl-hybr-kem-algs.txt"
    hybrid_sig_alg_file="$test_data_dir/alg-lists/ssl-hybr-sig-algs.txt"

    classic_algs=("RSA_2048" "RSA_3072" "RSA_4096" "prime256v1" "secp384r1" "secp521r1")
    ciphers=("TLS_AES_256_GCM_SHA384" "TLS_CHACHA20_POLY1305_SHA256" "TLS_AES_128_GCM_SHA256")

}

#-------------------------------------------------------------------------------------------------------------------------------
function set_test_env() {
    # Function for setting the default group depending on what type of tls test is being performed 
    # Options are: (pqc,classic,hybrid) 0=pqc, 1=classic, 2=hybrid

    # Declare local variables for arguments passed to function
    local test_type="$1"
    local configure_mode="$2"

    # Clearing current_group array before setting new group
    current_group=""

    # Determine test parameters based on test type
    if [ "$test_type" -eq 0 ]; then

        # Set kem algorithms array
        kem_algs=()
        while IFS= read -r line; do
            kem_algs+=("$line")
        done < $kem_alg_file

        # Set digital signature algorithms array
        sig_algs=()
        while IFS= read -r line; do
            sig_algs+=("$line")
        done < $sig_alg_file

        # Populate current group array with PQC kem algs
        for kem_alg in "${kem_algs[@]}"; do
            current_group+=":$kem_alg"
        done

        # Remove beginning : at index 0
        current_group="${current_group:1}"

        # Set configurations in openssl.cnf file for PQC testing
        "$util_scripts/configure-openssl-cnf.sh" $configure_mode

    elif [ "$test_type" -eq 1 ]; then # probably not needed and can remove

        # Set configurations in openssl.cnf file for Classic testing
        "$util_scripts/configure-openssl-cnf.sh" $configure_mode

    elif [ "$test_type" -eq 2 ]; then

        # Hybrid kem algorithms array
        kem_algs=()
        while IFS= read -r line; do
            kem_algs+=("$line")
        done < $hybrid_kem_alg_file

        # Hybrid sig algorithms array
        sig_algs=()
        while IFS= read -r line; do
            sig_algs+=("$line")
        done < $hybrid_sig_alg_file

        # Populate current group array with PQC algs
        for hybr_kem_alg in "${kem_algs[@]}"; do
            current_group+=":$hybr_kem_alg"
        done
        
        # Remove beginning : at index 0
        current_group="${current_group:1}"

        # Set configurations in openssl.cnf file for PQC testing
        "$util_scripts/configure-openssl-cnf.sh" $configure_mode

    fi

    # Export default group env var for openssl.cnf
    export DEFAULT_GROUPS=$current_group

}

#-------------------------------------------------------------------------------------------------------------------------------
function control_signal() {
    # Function for sending control signals to the client that are not part of the control handshake

    # Declare signal type local variable
    local type="$1"

    # Determine signal type and send signal to client
    if [ $type == "normal" ]; then

        # Send control signal
        until nc -z -v -w 1 $CLIENT_IP 12346 > /dev/null 2>&1; do
            exit_status=$?
            if [ $exit_status -ne 0 ]; then
                :
            else
                break
            fi
        done

    elif [ $type == "ready" ]; then 

        # Send server ready signal
        until echo "ready" | nc -n -w 1 $CLIENT_IP 12346 > /dev/null 2>&1; do
            exit_status=$?
            if [ $exit_status -ne 0 ]; then
                :
            else
                break
            fi
        done

    elif [ $type == "skip" ]; then

        # Send test skip signal
        until echo "skip" | nc -n -w 1 $CLIENT_IP 12346 > /dev/null 2>&1; do
            exit_status=$?
            if [ $exit_status -ne 0 ]; then
                :
            else
                break
            fi

        done
    
    elif [ $type == "iteration_handshake" ]; then

        # Wait for ready connection from client
        while true; do

            # Wait for a connection from the client and capture the request in a variable
            signal_message=$(nc -l -p 12345)
            if [[ $signal_message == "ready" ]]; then
                break
            fi

        done

        # Sending ready message to client
        until echo "ready" | nc -n -w 1 $CLIENT_IP 12346 > /dev/null 2>&1; do
            exit_status=$?
            if [ $exit_status -ne 0 ]; then
                :
            else
                break
            fi
          
        done

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function classic_tests {
    # Function for performing the classic TLS handshake tests using the given test parameters

    # Running tests for ecdsa ciphers
    for cipher in "${ciphers[@]}"; do

        # Loop through all classic algs and perform tests with current cipher
        for classic_alg in "${classic_algs[@]}"; do

            # Performing current run cipher/curve combination test until passed successfully
            while true; do

                # Check if an old openssl process is still active and kill if so
                pgrep_output=$(pgrep openssl)

                if [[ ! -z $pgrep_output ]]; then
                    kill "$pgrep_output"
                fi

                # Outputting current classic TLS test info
                echo -e "\n-------------------------------------------------------------------------"
                echo "[OUTPUT] - Classic Cipher Tests, Run - $run_num, Cipher - $cipher, Sig Alg - $classic_alg"

                # Performing iteration handshake
                control_signal "iteration_handshake"

                # Wait for ready signal from client
                nc -l -p 12345 > /dev/null

                # Checking if RSA or ECC to determine what parameters s_server needs
                if [[ $classic_alg == "prime256v1" || $classic_alg == "secp384r1" || $classic_alg == "secp521r1" ]]; then

                    # Set cert/key filenames for current ECC algorithm
                    classic_cert_file="$classic_cert_dir/$classic_alg-srv.crt"
                    classic_key_file="$classic_cert_dir/$classic_alg-srv.key"

                    # Start ECC test server processes
                    "$open_ssl_path/bin/openssl" s_server -cert $classic_cert_file -key $classic_key_file -www -tls1_3 \
                        -curves $classic_alg -ciphersuites "$cipher" -accept 4433 &
                    server_pid=$!

                else

                    # Set cert/key filenames for current RSA algorithm
                    classic_cert_file="$classic_cert_dir/$classic_alg-srv.crt"
                    classic_key_file="$classic_cert_dir/$classic_alg-srv.key"

                    # Start RSA test server processes
                    "$open_ssl_path/bin/openssl" s_server -cert $classic_cert_file -key $classic_key_file -www -tls1_3 -ciphersuites $cipher -accept 4433 &
                    server_pid=$!

                fi

                # Check if s_server has started before sending ready signal to client
                until netstat -tuln | grep ':4433' > /dev/null; do
                    :
                done

                # Send ready signal to client and wait for test status signal
                control_signal "normal"

                # Wait for final test status signal from client
                signal_message=$(nc -l -p 12345)

                # Check if test status signal received from client is complete or failed
                if [ $signal_message == "complete" ]; then

                    # Successful completion of test from client
                    kill $server_pid
                    break

                elif [ $signal_message == "failed" ]; then

                    # Restart sig/kem combination if failed signal from client
                    echo "[ERROR] - 3000 failed attempts signal received from client, restarting sig/kem combination"
                    kill $server_pid
                    sleep 2
                
                fi

            done

        done

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function pqc_tests() {
    # Function for performing the PQC TLS handshake and Hybrid-PQC TLS handshake tests 
    # using the given test parameters. The variables used by the function are set in set_test_env
    # function where whether to use PQC or Hybrid-PQC values are determined based on test-type

    # Looping through all PQC/Hybrid-PQC sig algs to be used for signing
    for sig in "${sig_algs[@]}"; do

        # Looping through all PQC/Hybrid-PQC KEM algs to be used for key exchange
        for kem in "${kem_algs[@]}"; do

            # Performing current run sig/kem combination test until passed
            while true; do

                # Check if an old openssl process is still active
                pgrep_output=$(pgrep openssl)

                # Kill old process if active
                if [[ ! -z $pgrep_output ]]; then
                    kill "$pgrep_output"
                fi

                # Outputting current TLS handshake test info
                echo -e "\n-------------------------------------------------------------------------"
                echo "[OUTPUT] - Run - $run_num, Signature - $sig, KEM - $kem"

                # Performing iteration handshake
                control_signal "iteration_handshake"

                # Wait for ready from client signal
                nc -l -p 12345 > /dev/null

                # Setting cert and key files depending on test type
                if [ "$test_type" -eq 0 ]; then
                    cert_file="$pqc_cert_dir/""${sig/:/_}""-srv.crt"
                    key_file="$pqc_cert_dir/""${sig/:/_}""-srv.key"

                elif [ "$test_type" -eq 2 ]; then
                    cert_file="$hybrid_cert_dir/""${sig/:/_}""-srv.crt"
                    key_file="$hybrid_cert_dir/""${sig/:/_}""-srv.key"
                fi

                # Starting server process
                "$open_ssl_path/bin/openssl" s_server -cert $cert_file -key $key_file -www -tls1_3 -groups $kem \
                    -provider oqsprovider -provider-path $provider_path -accept 4433 &
                server_pid=$!

                # Check if server has started before sending ready signal
                until netstat -tuln | grep ':4433' > /dev/null; do
                    :
                done

                # Send ready signal to client
                control_signal "ready"

                # Check test status signal from client
                signal_message=$(nc -l -p 12345)

                # Check if test status signal received from client is complete or failed
                if [ $signal_message == "complete" ]; then

                    # Successful completion of test from client
                    kill $server_pid
                    break

                elif [ $signal_message == "failed" ]; then

                    # Restart sig/kem combination if failed signal from client
                    echo "[ERROR] - 3000 failed attempts signal received from client, restarting sig/kem combination"
                    kill $server_pid
                    sleep 2
                
                fi

            done

        done
    
    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Main function which controls the server-side functionality of the TLS performance testing scripts
    # The global variables for the algorithm arrays and file path conventions are set using the specified
    # test type value: 0=pqc, 1=classic, 2=hybrid

    # Setting up the base environment for the test suite
    setup_base_env

    # Import algorithms and clear terminal
    get_algs
    clear

    # Performing initial handshake with client
    echo -e "Server Script Activated, waiting for connection from client..."
    control_signal "iteration_handshake"

    # Performing TLS handshake tests for the given number of runs
    for run_num in $(seq 1 $NUM_RUN); do

        # Performing output test start message
        echo -e "\n************************************************"
        echo "Performing TLS Handshake Tests Run - $run_num"
        echo -e "************************************************\n"

        # Performing run PQC test
        echo "-----------------"
        echo "PQC run $run_num"
        echo -e "-----------------\n"
        control_signal "iteration_handshake"

        # Calling PQC Tests
        test_type=0
        set_test_env $test_type 1
        pqc_tests
        echo -e "[OUTPUT] - Completed $run_num PQC Tests"

        # Performing run handshake
        echo "-----------------"
        echo "Classic run $run_num"
        echo -e "-----------------\n"
        control_signal "iteration_handshake"

        # Performing current run classic Tests
        test_type=1
        set_test_env $test_type 1
        classic_tests
        echo "[OUTPUT] - Completed $run_num Classic TLS Handshake Tests"

        # Performing run handshake
        echo "-----------------"
        echo "Hybrid-PQC run $run_num"
        echo -e "-----------------\n"
        control_signal "iteration_handshake"

        # Performing current run Hybrid-PQC Tests
        test_type=2
        set_test_env $test_type 1
        pqc_tests
        echo "[OUTPUT] - Completed $run_num Classic TLS Handshake Tests"

        # Outputting that the current run is complete
        echo "[OUTPUT] - All $run_num Testing Completed"

    done
    
}
main
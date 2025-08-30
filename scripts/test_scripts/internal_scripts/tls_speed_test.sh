#!/bin/bash

# Copyright (c) 2023-2025 Callum Turino
# SPDX-License-Identifier: MIT

# Client-side script for benchmarking the performance of cryptographic algorithms used in TLS, including 
# Post-Quantum Cryptography (PQC), and Hybrid-PQC signature and Key Encapsulation Mechanism (KEM) algorithms.
# This benchmarking is performed using OpenSSL 3.5.0's s_speed utility, which measures the execution time of 
# cryptographic operations for each algorithm. The script evaluates both native PQC implementations available in 
# OpenSSL and those integrated via OQS-Provider. The results are stored in machine-specific directories according 
# to the selected test type (PQC, Hybrid-PQC, or Classic). Test parameters are passed from the main OQS-Provider 
# benchmarking control script, which coordinates the execution and ensures synchronisation of the tests.

#-------------------------------------------------------------------------------------------------------------------------------
function setup_test_env() {
    # Function for setting up the basic global variables for the script. This includes setting the root directory, the global 
    # library paths for the test suite, and creating the algorithm arrays. The function establishes the root path by determining 
    # the path of the script and using this, determines the root directory of the project.

    # Determine the directory that the script is being executed from
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    # Try and find the .dir_marker.tmp file to determine the project's root directory
    current_dir="$script_dir"

    # Continue moving up the directory tree until the .pqc_leo_dir_marker.tmp file is found
    while true; do

        # Check if the .pqc_leo_dir_marker.tmp file is present
        if [ -f "$current_dir/.pqc_leo_dir_marker.tmp" ]; then
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
    test_scripts_path="$root_dir/scripts/test_scripts"
    util_scripts="$root_dir/scripts/utility_scripts"

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_3.5.0"
    oqs_provider_path="$libs_dir/oqs_provider"
    provider_path="$oqs_provider_path/lib"

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

    # Set the alg-list txt filepaths
    kem_alg_file="$test_data_dir/alg_lists/tls_speed_kem_algs.txt"
    sig_alg_file="$test_data_dir/alg_lists/tls_speed_sig_algs.txt"
    hybrid_kem_alg_file="$test_data_dir/alg_lists/tls_speed_hybr_kem_algs.txt"
    hybrid_sig_alg_file="$test_data_dir/alg_lists/tls_speed_hybr_sig_algs.txt"

    # Create the PQC KEM and digital signature algorithm list arrays
    kem_algs=()
    while IFS= read -r line; do
        kem_algs+=("$line")
    done < $kem_alg_file

    sig_algs=()
    while IFS= read -r line; do
        sig_algs+=("$line")
    done < $sig_alg_file

    # Create the Hybrid-PQC KEM and digital signature algorithm list arrays
    hybrid_kem_algs=()
    while IFS= read -r line; do
        hybrid_kem_algs+=("$line")
    done < $hybrid_kem_alg_file

    hybrid_sig_algs=()
    while IFS= read -r line; do
        hybrid_sig_algs+=("$line")
    done < $hybrid_sig_alg_file

    # Create the result output directories and remove old ones if needed
    if [ -d $PQC_SPEED ]; then
        rm -rf $PQC_SPEED
    fi
    mkdir -p $PQC_SPEED

    if [ -d $HYBRID_SPEED ]; then
        rm -rf $HYBRID_SPEED
    fi
    mkdir -p $HYBRID_SPEED

}

#-------------------------------------------------------------------------------------------------------------------------------
function tls_speed_test() {
    # Function for running TLS speed tests on various algorithm types, measuring cryptographic performance using OpenSSL 
    # 3.5.0's `s_speed` utility. The utility benchmarks signature and key exchange algorithms, supporting both native 
    # PQC algorithms and those provided via the OQS-Provider.

    # Set the test parameter arrays
    test_types=("PQC-KEMs" "PQC-Digital Signatures" "Hybrid-PQC KEMs" "Hybrid-PQC-Digital-Signatures")
    alg_lists=("${kem_algs[*]}" "${sig_algs[*]}" "${hybrid_kem_algs[*]}" "${hybrid_sig_algs[*]}")
    output_files=(
        "$PQC_SPEED/tls_speed_kem" 
        "$PQC_SPEED/tls_speed_sig" 
        "$HYBRID_SPEED/tls_speed_hybrid_kem"
        "$HYBRID_SPEED/tls_speed_hybrid_sig"
    )

    # Perform the TLS speed tests for the specified number of runs
    for run_num in $(seq 1 $NUM_RUN); do

        # Output the current run number to the terminal
        echo -e "\n----------------------------------"
        echo -e "Performing TLS speed test run $run_num:\n"

        # Loop through each test type and run the OpenSSL speed command
        for test_index in "${!test_types[@]}"; do

            # Set the temp error log file path for the current test type
            error_log_file="$tmp_dir/tls_speed_test_${run_num}_${test_types[$test_index]}.log"

            # Output the current task to the terminal
            echo "Performing TLS speed tests for ${test_types[$test_index]}..."

            # Set the algorithm list and output file for the current test type
            algs_string="${alg_lists[$test_index]}"
            output_file="${output_files[$test_index]}_$run_num.txt"

            # Perform the OpenSSL speed test with the current test parameters
            "$openssl_path/bin/openssl" speed \
                -seconds "$TIME_NUM" \
                -provider default \
                -provider oqsprovider \
                -provider-path "$provider_path" \
                $algs_string > "$output_file" 2> "$error_log_file"
            exit_status=$?

            # Check if the test completed without critical errors and remove the error log file if successful
            if [ $exit_status -ne 0 ]; then
                echo "[ERROR] - OpenSSL speed test failed for ${test_types[$test_index]}."
                echo "Check the error log file at $error_log_file for more details."
                exit 1
            else
                rm -rf "$error_log_file"
            fi

        done

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function tls_speed_test_entrypoint() {
    # Main function for managing the execution of TLS speed performance tests. 
    # It sets up the environment, runs the tests for various algorithm types, and handles OpenSSL configuration modifications.

    # Setup the base environment for the test suite
    setup_test_env

    # Output the test start message
    echo -e "\n##########################"
    echo "Performing TLS Speed Tests"
    echo -e "##########################"

    # Modify the OpenSSL conf file to temporarily remove the default groups configuration
    if ! "$util_scripts/configure_openssl_cnf.sh" 1; then
        echo "[ERROR] - Failed to modify OpenSSL configuration."
        exit 1
    fi

    # Run the TLS speed tests for the various algorithm types
    tls_speed_test

    # Restore the OpenSSL conf file to have the configuration needed for the testing scripts
    if ! "$util_scripts/configure_openssl_cnf.sh" 2; then
        echo "[ERROR] - Failed to modify OpenSSL configuration."
        exit 1
    fi

}
tls_speed_test_entrypoint
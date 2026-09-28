#!/bin/bash

# Copyright (c) 2023-2026 Callum Turino
# SPDX-License-Identifier: MIT

# Script for generating CA, server, and client certificates and keys used by TLS handshake performance,
# handshake energy, and transmission-cost testing. Generates classical, PQC, and Hybrid-PQC certificates using 
# OpenSSL 4.0.2, using PQC implementations natively available in OpenSSL and those integrated via OQS-Provider.
# The generated key material must be copied to the client machine unless both client and server run on the same system.

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
    util_scripts="$root_dir/scripts/utility_scripts"

    # Declare the global library directory path variables
    openssl_path="$libs_dir/openssl_4.0.2"
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

    # Declare global key storage directory paths
    keys_dir="$test_data_dir/keys"
    pqc_cert_dir="$keys_dir/pqc"
    classic_cert_dir="$keys_dir/classic"
    hybrid_cert_dir="$keys_dir/hybrid"

    # Set the alg-list txt filepaths
    sig_alg_file="$test_data_dir/alg_lists/tls_sig_algs.txt"
    hybrid_sig_alg_file="$test_data_dir/alg_lists/tls_hybr_sig_algs.txt"
    classic_sig_alg_file="$test_data_dir/alg_lists/tls_classic_sig_algs.txt"

    # Create the PQC and Hybrid-PQC digital signature algorithm list arrays
    sig_algs=()
    while IFS= read -r line; do
        sig_algs+=("$line")
    done < $sig_alg_file

    hybrid_sig_algs=()
    while IFS= read -r line; do
        hybrid_sig_algs+=("$line")
    done < $hybrid_sig_alg_file

    # Create the classical digital signature algorithm list array
    classic_sigs=()
    while IFS= read -r line; do
        classic_sigs+=("$line")
    done < $classic_sig_alg_file

    # Define the certificate types
    cert_types=("server" "client")

}

#-------------------------------------------------------------------------------------------------------------------------------
function set_openssl_conf() {
    # Helper function for switching the OpenSSL configuration between key-generation and TLS testing modes. This function 
    # validates the passed configuration command, calls the OpenSSL configuration utility script, and updates the restoration 
    # tracker flag.

    # Store the passed configure command
    local configure_command="$1"

    # Ensure that passed command is a valid integer (1 or 2)
    if [[ ! "$configure_command" =~ ^[1-2]$ ]]; then
        echo "[ERROR] - Invalid OpenSSL configuration command: $configure_command"
        exit 1
    fi

    # Set the restore flag before entering key-generation mode in case the configuration command partially fails
    if [ "$configure_command" -eq 1 ]; then
        openssl_conf_needs_restored=1
    fi

    # Call the OpenSSL conf modification utility script using the passed configure command
    if ! "$util_scripts/configure_openssl_cnf.sh" "$configure_command"; then
        echo "[ERROR] - Failed to modify OpenSSL configuration, the configuration may now be corrupted and require project re-install"
        exit 1
    fi

    # Clear the restore flag once the TLS testing configuration has been successfully restored
    if [ "$configure_command" -eq 2 ]; then
        openssl_conf_needs_restored=0
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function exit_handler() {
    # Helper function for restoring the OpenSSL configuration when the script exits unexpectedly. This function checks whether 
    # the configuration still needs to be restored and preserves the script's original exit status after completing the 
    # restoration.

    # Capture the scripts exit status so that it can be used in the exit command
    local exit_status=$?

    # Disable the exit trap while restoring the configuration to prevent the handler from running recursively
    trap - EXIT

    # Restore the OpenSSL configuration if the script exits while it is still in key-generation mode
    if [ "$openssl_conf_needs_restored" -eq 1 ]; then
        echo "[NOTICE] - Restoring the OpenSSL configuration file to default state"
        set_openssl_conf 2
    fi

    exit "$exit_status"

}

#-------------------------------------------------------------------------------------------------------------------------------
function pqc_keygen() {
    # Function for generating server certificates and private keys required for PQC TLS handshake benchmarking tests.
    # This includes creating CA certificates, server certificate signing requests, and signed server certificates using PQC
    # digital signature algorithms supported both natively in OpenSSL and integrated into OpenSSL via the OQS-Provider.

    # Define the local variable for storing command exit status
    local exit_status

    # Loop through the PQC digital signature to generate the CA/server certs and private-key files
    for sig in "${sig_algs[@]}"; do

        # Generate the CA certificate and private key for the current PQC signature algorithm
        "$openssl_path/bin/openssl" req \
            -x509 \
            -new \
            -newkey "$sig" \
            -keyout "$pqc_cert_dir/${sig}_CA.key" \
            -out "$pqc_cert_dir/${sig}_CA.crt" \
            -nodes \
            -subj "/CN=oqstest $sig CA" \
            -days 365 \
            -config "$openssl_path/openssl.cnf" \
            -provider default \
            -provider oqsprovider \
            -provider-path "$provider_path"
        exit_status=$?

        # Ensure that the PQC CA certificate and private key were generated successfully
        if [ $exit_status -ne 0 ] || [ ! -f "$pqc_cert_dir/${sig}_CA.key" ] || [ ! -f "$pqc_cert_dir/${sig}_CA.crt" ]; then
            echo "[ERROR] - Failed to generate the $sig CA certificate and private key."
            return 1
        fi

        # Loop through each certificate type, and perform the generation and signing operations
        for cert_type in "${cert_types[@]}"; do

            # Generate the certificate signing request for the current PQC signature algorithm
            "$openssl_path/bin/openssl" req \
                -new \
                -newkey "$sig" \
                -keyout "$pqc_cert_dir/${sig}_${cert_type}.key" \
                -out "$pqc_cert_dir/${sig}_${cert_type}.csr" \
                -nodes \
                -subj "/CN=oqstest $sig $cert_type" \
                -config "$openssl_path/openssl.cnf" \
                -provider default \
                -provider oqsprovider \
                -provider-path "$provider_path"
            exit_status=$?

            # Ensure that the PQC certificate signing request and private key were generated successfully
            if [ $exit_status -ne 0 ] || [ ! -f "$pqc_cert_dir/${sig}_${cert_type}.key" ] || [ ! -f "$pqc_cert_dir/${sig}_${cert_type}.csr" ]; then
                echo "[ERROR] - Failed to generate the $sig $cert_type certificate signing request and private key."
                return 1
            fi

            # Sign the CSR using the PQC CA certificate and key
            "$openssl_path/bin/openssl" x509 \
                -req \
                -in "$pqc_cert_dir/${sig}_${cert_type}.csr" \
                -out "$pqc_cert_dir/${sig}_${cert_type}.crt" \
                -CA "$pqc_cert_dir/${sig}_CA.crt" \
                -CAkey "$pqc_cert_dir/${sig}_CA.key" \
                -CAcreateserial \
                -days 365 \
                -provider default \
                -provider oqsprovider \
                -provider-path "$provider_path"
            exit_status=$?

            # Ensure that the PQC certificate was generated successfully
            if [ $exit_status -ne 0 ] || [ ! -f "$pqc_cert_dir/${sig}_${cert_type}.crt" ]; then
                echo "[ERROR] - Failed to generate the $sig $cert_type certificate."
                return 1
            fi

            # Remove the CSR file after signing
            rm -f "$pqc_cert_dir/${sig}_${cert_type}.csr"

        done

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function hybrid_pqc_keygen() {
    # Function for generating server certificates and private keys required for Hybrid-PQC TLS handshake benchmarking tests.
    # This includes creating CA certificates, server certificate signing requests, and signed server certificates using Hybrid-PQC
    # digital signature algorithms supported both natively in OpenSSL and integrated into OpenSSL via the OQS-Provider.

    # Define the local variable for storing command exit status
    local exit_status

    # Loop through the Hybrid-PQC digital signature to generate the CA/server certs and private-key files
    for sig in "${hybrid_sig_algs[@]}"; do

        # Generate the CA certificate and private key for the current Hybrid-PQC signature algorithm
        "$openssl_path/bin/openssl" req \
            -x509 \
            -new \
            -newkey "$sig" \
            -keyout "$hybrid_cert_dir/${sig}_CA.key" \
            -out "$hybrid_cert_dir/${sig}_CA.crt" \
            -nodes \
            -subj "/CN=oqstest $sig CA" \
            -days 365 \
            -config "$openssl_path/openssl.cnf" \
            -provider default \
            -provider oqsprovider \
            -provider-path "$provider_path"
        exit_status=$?

        # Ensure that the Hybrid-PQC CA certificate and private key were generated successfully
        if [ $exit_status -ne 0 ] || [ ! -f "$hybrid_cert_dir/${sig}_CA.key" ] || [ ! -f "$hybrid_cert_dir/${sig}_CA.crt" ]; then
            echo "[ERROR] - Failed to generate the $sig CA certificate and private key."
            return 1
        fi

        # Loop through each certificate type, and perform the generation and signing operations
        for cert_type in "${cert_types[@]}"; do

            # Generate the certificate signing request for the current Hybrid-PQC signature algorithm
            "$openssl_path/bin/openssl" req \
                -new \
                -newkey "$sig" \
                -keyout "$hybrid_cert_dir/${sig}_${cert_type}.key" \
                -out "$hybrid_cert_dir/${sig}_${cert_type}.csr" \
                -nodes \
                -subj "/CN=oqstest $sig $cert_type" \
                -config "$openssl_path/openssl.cnf" \
                -provider default \
                -provider oqsprovider \
                -provider-path "$provider_path"
            exit_status=$?

            # Ensure that the Hybrid-PQC certificate signing request and private key were generated successfully
            if [ $exit_status -ne 0 ] || [ ! -f "$hybrid_cert_dir/${sig}_${cert_type}.key" ] || [ ! -f "$hybrid_cert_dir/${sig}_${cert_type}.csr" ]; then
                echo "[ERROR] - Failed to generate the $sig $cert_type certificate signing request and private key."
                return 1
            fi

            # Sign the CSR using the Hybrid-PQC CA certificate and key
            "$openssl_path/bin/openssl" x509 \
                -req \
                -in "$hybrid_cert_dir/${sig}_${cert_type}.csr" \
                -out "$hybrid_cert_dir/${sig}_${cert_type}.crt" \
                -CA "$hybrid_cert_dir/${sig}_CA.crt" \
                -CAkey "$hybrid_cert_dir/${sig}_CA.key" \
                -CAcreateserial \
                -days 365 \
                -provider default \
                -provider oqsprovider \
                -provider-path "$provider_path"
            exit_status=$?

            # Ensure that the Hybrid-PQC certificate was generated successfully
            if [ $exit_status -ne 0 ] || [ ! -f "$hybrid_cert_dir/${sig}_${cert_type}.crt" ]; then
                echo "[ERROR] - Failed to generate the $sig $cert_type certificate."
                return 1
            fi

            # Remove the CSR file after signing
            rm -f "$hybrid_cert_dir/${sig}_${cert_type}.csr"

        done

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function create_classic_keyfile() {
    # Function for generating a classic private key file based on the passed signature algorithm name and certificate type. 
    # The function will determine the correct OpenSSL genpkey arguments based on the signature algorithm name and generate the 
    # private key file in the appropriate directory based on the certificate type (CA, server, or client).

    # Store the passed signature alg name and certificate type
    local sig_name="$1"
    local cert_type="$2"
    local key_file
    local key_bits
    local exit_status
    local -a keygen_args

    # Ensure that a signature algorithm name and certificate type are provided
    if [[ -z "$sig_name" || -z "$cert_type" ]]; then
        echo "[ERROR] - Signature algorithm name and certificate type not provided to create_classic_keyfile function."
        return 1
    fi

    # Ensure that passed certificate type is a valid option (CA, server, or client)
    if [[ ! "$cert_type" =~ ^(CA|server|client)$ ]]; then
        echo "[ERROR] - Invalid certificate type: $cert_type"
        return 1
    fi

    # Define the key filename and path based on the signature algorithm and certificate type
    key_file="$classic_cert_dir/${sig_name}_${cert_type}.key"

    # Determine which type of classic signature algorithm is being used and set the appropriate OpenSSL genpkey arguments
    case "$sig_name" in

        RSA_*)

            # Set the number of bits for the RSA key based on the signature algorithm name
            key_bits="${sig_name#RSA_}"

            # Validate that the extracted key size is a valid integer
            if [[ ! "$key_bits" =~ ^[0-9]+$ ]]; then
                echo "[ERROR] - Invalid RSA key size in algorithm name: $sig_name"
                return 1
            fi

            # Define the OpenSSL genpkey arguments for generating an RSA key with the specified modulus size
            keygen_args=(-algorithm RSA -pkeyopt "rsa_keygen_bits:$key_bits")
            ;;

        RSA-PSS_*)

            # Set the number of bits for the RSA-PSS key based on the signature algorithm name
            key_bits="${sig_name#RSA-PSS_}"

            # Validate that the extracted key size is a valid integer
            if [[ ! "$key_bits" =~ ^[0-9]+$ ]]; then
                echo "[ERROR] - Invalid RSA-PSS key size in algorithm name: $sig_name"
                return 1
            fi

            # Define the OpenSSL genpkey arguments for generating an RSA-PSS key with the specified modulus size
            keygen_args=(-algorithm RSA-PSS -pkeyopt "rsa_keygen_bits:$key_bits")
            ;;


        prime256v1|secp384r1|secp521r1|brainpoolP256r1|brainpoolP384r1|brainpoolP512r1)

            # Define the OpenSSL genpkey arguments for generating an ECC key using the specified curve
            keygen_args=(-algorithm EC -pkeyopt "ec_paramgen_curve:$sig_name")
            ;;

        ed25519)

            # Define the OpenSSL genpkey arguments for generating an Ed25519 key
            keygen_args=(-algorithm ED25519)
            ;;

        ed448)

            # Define the OpenSSL genpkey arguments for generating an Ed448 key
            keygen_args=(-algorithm ED448)
            ;;

        *)

            # Output an error message and exit if the signature algorithm is not supported
            echo "[ERROR] - Unsupported classic signature algorithm: $sig_name"
            return 1
            ;;

    esac

    # Generate the key file for the current classic signature algorithm and certificate type
    "$openssl_path/bin/openssl" genpkey \
        "${keygen_args[@]}" \
        -out "$key_file" \
        -provider-path "$provider_path" \
        -provider default \
        -provider oqsprovider
    exit_status=$?

    # Ensure that the key generation was successful, otherwise output an error and exit
    if [ $exit_status -ne 0 ] || [ ! -f "$key_file" ]; then
        echo "[ERROR] - Failed to generate the $sig_name $cert_type private key."
        return 1
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function classic_keygen() {
    # Function for generating CA, server, and client certificates and private keys required for classical TLS tests.
    # This covers generic RSA, RSA-PSS-restricted, ECDSA, EdDSA, and Brainpool signing keys supported by OpenSSL.

    # Define the local variable for storing command exit status
    local exit_status

    # Loop through the classic digital signature to generate the CA/server certs and private-key files
    for sig in "${classic_sigs[@]}"; do

        # Define the CA certificate and key filenames based on the signature algorithm
        ca_cert_file="$classic_cert_dir/${sig}_CA.crt"
        ca_key_file="$classic_cert_dir/${sig}_CA.key"

        # Generate the CA private key for the current classic signature algorithm
        if ! create_classic_keyfile "$sig" "CA"; then
            echo "[ERROR] - Failed to generate the $sig CA private key."
            return 1
        fi

        # Generate the CA certificate for the current classic signature algorithm
        "$openssl_path/bin/openssl" req \
            -x509 \
            -new \
            -key "$ca_key_file" \
            -out "$ca_cert_file" \
            -nodes \
            -subj "/CN=oqstest CA" \
            -days 365 \
            -config "$openssl_path/openssl.cnf" \
            -provider default \
            -provider oqsprovider \
            -provider-path "$provider_path"
        exit_status=$?

        # Ensure that the CA certificate was generated successfully
        if [ $exit_status -ne 0 ] || [ ! -f "$ca_cert_file" ]; then
            echo "[ERROR] - Failed to generate the $sig CA certificate."
            return 1
        fi

        # Generate the server and client certificates for the current classic signature algorithm
        for cert_type in "${cert_types[@]}"; do

            # Define the certificate and key filenames based on the signature algorithm and certificate type
            cert_file="$classic_cert_dir/${sig}_${cert_type}.crt"
            key_file="$classic_cert_dir/${sig}_${cert_type}.key"

            # Generate the private key for the current classic signature algorithm and certificate type
            if ! create_classic_keyfile "$sig" "$cert_type"; then
                echo "[ERROR] - Failed to generate the $sig $cert_type private key."
                return 1
            fi

            # Generate the certificate signing request for the current classic signature algorithm and certificate type
            "$openssl_path/bin/openssl" req \
                -new \
                -key "$key_file" \
                -out "$classic_cert_dir/${sig}_${cert_type}.csr" \
                -nodes \
                -subj "/CN=oqstest ${cert_type}" \
                -config "$openssl_path/openssl.cnf" \
                -provider default \
                -provider oqsprovider \
                -provider-path "$provider_path"
            exit_status=$?

            # Ensure that the certificate signing request was generated successfully
            if [ $exit_status -ne 0 ] || [ ! -f "$classic_cert_dir/${sig}_${cert_type}.csr" ]; then
                echo "[ERROR] - Failed to generate the $sig $cert_type certificate signing request."
                return 1
            fi

            # Sign the CSR using the CA certificate and key for the current classic signature algorithm
            "$openssl_path/bin/openssl" x509 \
                -req \
                -in "$classic_cert_dir/${sig}_${cert_type}.csr" \
                -out "$cert_file" \
                -CA "$ca_cert_file" \
                -CAkey "$ca_key_file" \
                -CAcreateserial \
                -days 365 \
                -provider default \
                -provider oqsprovider \
                -provider-path "$provider_path"
            exit_status=$?

            # Ensure that the certificate file was generated successfully
            if [ $exit_status -ne 0 ] || [ ! -f "$cert_file" ]; then
                echo "[ERROR] - Failed to generate the $sig $cert_type certificate."
                return 1
            fi

            # Remove the CSR file after signing
            rm -f "$classic_cert_dir/${sig}_${cert_type}.csr"

        done

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function main() {
    # Main function coordinating certificate and private-key generation for TLS handshake performance, energy, and
    # transmission-cost tests. This includes classical, PQC, and Hybrid-PQC digital signature algorithms.

    # Output the welcome message to the terminal
    echo "#########################################################"
    echo "PQC-LEO - TLS Certificate & Key Generator"
    echo "PQC | Hybrid-PQC | Classic (OpenSSL 4.0.2 + OQS-Provider)"
    echo -e "#########################################################\n"

    # Setup the base environment for the script
    setup_base_env

    # Define the tracker flag variable for whether the OpenSSL conf file has been modified
    openssl_conf_needs_restored=0

    # Restore the OpenSSL configuration if the script exits before the normal restoration step
    trap exit_handler EXIT

    # Modify the OpenSSL conf file to temporarily remove the default groups configuration
    set_openssl_conf 1

    # Remove the old keys directory if present
    if [ -d "$keys_dir" ]; then
        if ! rm -rf "$keys_dir"; then
            echo "[ERROR] - Failed to remove the existing certificate and key directories"
            exit 1
        fi
    fi

    # Create the new cert directories, ensuring that the command passes successfully
    if ! mkdir -p "$pqc_cert_dir" "$classic_cert_dir" "$hybrid_cert_dir"; then
        echo "[ERROR] - Failed to create the certificate and key directories"
        exit 1
    fi

    # Output the current task to the terminal
    echo -e "\nGenerating certs and keys for PQC tests:"

    # Generate the certs and keys for the PQC tests
    if ! pqc_keygen; then
        echo "[ERROR] - Could not complete PQC cert and key generation, restoring OpenSSL configuration"
        set_openssl_conf 2
        exit 1
    fi

    # Output the current task to the terminal
    echo -e "\nGenerating certs and keys for Hybrid-PQC tests:"

    # Generate the certs and keys for the Hybrid-PQC tests
    if ! hybrid_pqc_keygen; then
        echo "[ERROR] - Could not complete Hybrid-PQC cert and key generation, restoring OpenSSL configuration"
        set_openssl_conf 2
        exit 1
    fi

    # Output the current task to the terminal
    echo -e "\nGenerating certs and keys for classic ciphersuite tests:"
 
    # Generate the certificates and keys for the classical TLS tests
    if ! classic_keygen; then
        echo "[ERROR] - Could not complete classic cert and key generation, restoring OpenSSL configuration"
        set_openssl_conf 2
        exit 1
    fi

    # Restore the OpenSSL conf file to have the configuration needed for testing scripts
    set_openssl_conf 2

}
main

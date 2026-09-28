#/bin/bash

# Copyright (c) 2023-2026 Callum Turino
# SPDX-License-Identifier: MIT

# This utility script manages custom OID environment variable mappings used only during TLS speed energy testing in
# the PQC-LEO benchmarking suite. It is an internal helper invoked by the TLS speed energy test workflow and is not
# intended to be called manually. It supports setting or clearing OID mappings so OpenSSL and OQS-Provider can
# reference consistent private enterprise OIDs during controlled interoperability and performance test runs.
#
# The script accepts one command line argument which is used to indicate whether the OID environment variables 
# should be set or cleared. This flag is mandatory for the script to function correctly. 
# The supported options are:
# `--set-env-oids` to set the OID environment variables for all supported algorithms
# `--clear-env-oids` to clear those environment variables after testing is complete. 
#
# The algorithms that are included within this script are based on the algorithms listed by OQS-Provider
# in their ALGORITHMS.md file (OQS-Provider version 0.11.0). Currently, the script is hard-coded to include 
# the algorithms mentioned in that file. This will be updated in the future to be more dynamic.
# The version of the ALGORITHMS.md file used to dictate the algorithms included in this script can be found here:
# https://github.com/open-quantum-safe/oqs-provider/blob/a635e341d6a4624d9bba36d158804762f316fe5e/ALGORITHMS.md

#-------------------------------------------------------------------------------------------------------------------------------
function output_help() {
    # Helper function for outputting the help message to the user when the --help flag is present or when incorrect arguments 
    # are passed.

    # Output the help message for the oqs_enable_algs modification tool
    echo "Usage: oid_handler.sh [options]"
    echo "Options:"
    echo "--set-env-oids        Set OID environment variables for quantum-safe algorithms"
    echo "--clear-env-oids      Clear OID environment variables for quantum-safe algorithms"
    echo "--help                Display the help message"

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

    # Set the default option selected flag
    configure_mode=0
    local set_flag_seen=0
    local clear_flag_seen=0

    # Loop through the passed command line arguments and check for the supported options
    while [[ $# -gt 0 ]]; do

        case "$1" in

            --set-env-oids)

                # Check if either flag has already been seen, as only one of the two options can be passed
                if [[ $set_flag_seen -eq 1 || $clear_flag_seen -eq 1 ]]; then
                    echo "[ERROR] - Only one of --set-env-oids or --clear-env-oids can be passed."
                    output_help
                    exit 1
                fi

                # Set the flag for setting OID environment variables and update the configure mode
                set_flag_seen=1
                configure_mode=1
                shift
                ;;

            --clear-env-oids)

                # Check if either flag has already been seen, as only one of the two options can be passed
                if [[ $clear_flag_seen -eq 1 || $set_flag_seen -eq 1 ]]; then
                    echo "[ERROR] - Only one of --set-env-oids or --clear-env-oids can be passed."
                    output_help
                    exit 1
                fi

                # Set the flag for clearing OID environment variables and update the configure mode
                clear_flag_seen=1
                configure_mode=2
                shift
                ;;

            *)

                # Output an error message for invalid options and display the help message
                echo "[ERROR] - Invalid option: $1"
                output_help
                exit 1
                ;;

        esac

    done

    # Ensure that at least one of the required options has been provided to the script
    if [[ $configure_mode -eq 0 ]]; then
        echo "[ERROR] - One option is required: --set-env-oids or --clear-env-oids"
        output_help
        exit 1
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function OID_handler() {
    # Function to manage OID (Object Identifier) environment variables for TLS speed energy testing. Due to the algorithms 
    # present in OQS-Provider not being fully standardised, custom OID's must be assigned to the algorithms included within 
    # OQS-Provider in order to use them within manual cryptographic operations in OpenSSL. To do this, algorithms are provided 
    # with a base OID from a private enterprise OID space (1.3.6.1.4.1.555555.9000) and then assigned an OID variable in the 
    # environment. Based on the argument passed to the script, this function will either set or clear these environment variables.

    # Store the passed configure mode and define the base OID prefix for the custom OIDs
    local set_type=$1
    base_oid=1.3.6.1.4.1.555555.9000

    if [ $set_type -eq 1 ]; then

        # ML-DSA signature algorithms
        # export OQS_OID_MLDSA44=$base_oid.1
        export OQS_OID_P256_MLDSA44=$base_oid.2
        export OQS_OID_RSA3072_MLDSA44=$base_oid.3
        # export OQS_OID_MLDSA65=$base_oid.4
        export OQS_OID_P384_MLDSA65=$base_oid.5
        # export OQS_OID_MLDSA87=$base_oid.6
        export OQS_OID_P521_MLDSA87=$base_oid.7

        # Falcon signature algorithms
        export OQS_OID_FALCON512=$base_oid.8
        export OQS_OID_P256_FALCON512=$base_oid.9
        export OQS_OID_RSA3072_FALCON512=$base_oid.10
        export OQS_OID_FALCONPADDED512=$base_oid.11
        export OQS_OID_P256_FALCONPADDED512=$base_oid.12
        export OQS_OID_RSA3072_FALCONPADDED512=$base_oid.13
        export OQS_OID_FALCON1024=$base_oid.14
        export OQS_OID_P521_FALCON1024=$base_oid.15
        export OQS_OID_FALCONPADDED1024=$base_oid.16
        export OQS_OID_P521_FALCONPADDED1024=$base_oid.17

        # SPHINCS signature algorithms
        export OQS_OID_SPHINCSSHA2128FSIMPLE=$base_oid.18
        export OQS_OID_P256_SPHINCSSHA2128FSIMPLE=$base_oid.19
        export OQS_OID_RSA3072_SPHINCSSHA2128FSIMPLE=$base_oid.20
        export OQS_OID_SPHINCSSHA2128SSIMPLE=$base_oid.21
        export OQS_OID_P256_SPHINCSSHA2128SSIMPLE=$base_oid.22
        export OQS_OID_RSA3072_SPHINCSSHA2128SSIMPLE=$base_oid.23
        export OQS_OID_SPHINCSSHA2192FSIMPLE=$base_oid.24
        export OQS_OID_P384_SPHINCSSHA2192FSIMPLE=$base_oid.25
        export OQS_OID_SPHINCSSHAKE128FSIMPLE=$base_oid.26
        export OQS_OID_P256_SPHINCSSHAKE128FSIMPLE=$base_oid.27
        export OQS_OID_RSA3072_SPHINCSSHAKE128FSIMPLE=$base_oid.28

        # MAYO signature algorithms
        export OQS_OID_MAYO1=$base_oid.29
        export OQS_OID_P256_MAYO1=$base_oid.30
        export OQS_OID_MAYO2=$base_oid.31
        export OQS_OID_P256_MAYO2=$base_oid.32
        export OQS_OID_MAYO3=$base_oid.33
        export OQS_OID_P384_MAYO3=$base_oid.34
        export OQS_OID_MAYO5=$base_oid.35
        export OQS_OID_P521_MAYO5=$base_oid.36

        # CROSS signature algorithms
        export OQS_OID_CROSSRSDP128BALANCED=$base_oid.37

        # OV signature algorithms
        export OQS_OID_OV_IS_PKC=$base_oid.38
        export OQS_OID_P256_OV_IS_PKC=$base_oid.39
        export OQS_OID_OV_IP_PKC=$base_oid.40
        export OQS_OID_P256_OV_IP_PKC=$base_oid.41
        export OQS_OID_OV_IS_PKC_SKC=$base_oid.42
        export OQS_OID_P256_OV_IS_PKC_SKC=$base_oid.43
        export OQS_OID_OV_IP_PKC_SKC=$base_oid.44
        export OQS_OID_P256_OV_IP_PKC_SKC=$base_oid.45

        # SNOVA signature algorithms
        export OQS_OID_SNOVA2454=$base_oid.46
        export OQS_OID_P256_SNOVA2454=$base_oid.47
        export OQS_OID_SNOVA2454ESK=$base_oid.48
        export OQS_OID_P256_SNOVA2454ESK=$base_oid.49
        export OQS_OID_SNOVA37172=$base_oid.50
        export OQS_OID_P256_SNOVA37172=$base_oid.51
        export OQS_OID_SNOVA2455=$base_oid.52
        export OQS_OID_P384_SNOVA2455=$base_oid.53
        export OQS_OID_SNOVA2965=$base_oid.54
        export OQS_OID_P521_SNOVA2965=$base_oid.55

        # Frodo KEM algorithms
        export OQS_OID_FRODO640AES=$base_oid.56
        export OQS_OID_FRODO640AES=$base_oid.57
        export OQS_OID_P256_FRODO640AES=$base_oid.58
        export OQS_OID_X25519_FRODO640AES=$base_oid.59
        export OQS_OID_FRODO640SHAKE=$base_oid.60
        export OQS_OID_P256_FRODO640SHAKE=$base_oid.61
        export OQS_OID_X25519_FRODO640SHAKE=$base_oid.62
        export OQS_OID_FRODO976AES=$base_oid.63
        export OQS_OID_P384_FRODO976AES=$base_oid.64
        export OQS_OID_X448_FRODO976AES=$base_oid.65
        export OQS_OID_FRODO976SHAKE=$base_oid.66
        export OQS_OID_P384_FRODO976SHAKE=$base_oid.67
        export OQS_OID_X448_FRODO976SHAKE=$base_oid.68
        export OQS_OID_FRODO1344AES=$base_oid.69
        export OQS_OID_P521_FRODO1344AES=$base_oid.70
        export OQS_OID_FRODO1344SHAKE=$base_oid.71
        export OQS_OID_P521_FRODO1344SHAKE=$base_oid.72

        # ML-KEM algorithms
        export OQS_OID_MLKEM512=$base_oid.73
        export OQS_OID_P256_MLKEM512=$base_oid.74
        export OQS_OID_X25519_MLKEM512=$base_oid.75
        export OQS_OID_BP256_MLKEM512=$base_oid.76
        export OQS_OID_MLKEM768=$base_oid.77
        export OQS_OID_P384_MLKEM768=$base_oid.78
        export OQS_OID_X448_MLKEM768=$base_oid.79
        export OQS_OID_BP384_MLKEM768=$base_oid.80
        export OQS_OID_X25519MLKEM768=$base_oid.81
        export OQS_OID_SECP256R1MLKEM768=$base_oid.82
        export OQS_OID_MLKEM1024=$base_oid.83
        export OQS_OID_P521_MLKEM1024=$base_oid.84
        export OQS_OID_SECP384R1MLKEM1024=$base_oid.85
        export OQS_OID_BP512_MLKEM1024=$base_oid.86

        # BIKE KEM algorithms
        export OQS_OID_BIKEL1=$base_oid.87
        export OQS_OID_P256_BIKEL1=$base_oid.88
        export OQS_OID_X25519_BIKEL1=$base_oid.89
        export OQS_OID_BIKEL3=$base_oid.90
        export OQS_OID_P384_BIKEL3=$base_oid.91
        export OQS_OID_X448_BIKEL3=$base_oid.92
        export OQS_OID_BIKEL5=$base_oid.93
        export OQS_OID_P521_BIKEL5=$base_oid.94

        # HQC KEM algorithms
        export OQS_OID_HQC_128=$base_oid.95
        export OQS_OID_HQC_192=$base_oid.96
        export OQS_OID_HQC_256=$base_oid.97


    elif [ $set_type -eq 2 ]; then

        # Unset ML-DSA signature algorithms
        unset OQS_OID_MLDSA44
        unset OQS_OID_P256_MLDSA44
        unset OQS_OID_RSA3072_MLDSA44
        unset OQS_OID_MLDSA65
        unset OQS_OID_P384_MLDSA65
        unset OQS_OID_MLDSA87
        unset OQS_OID_P521_MLDSA87

        # Unset Falcon signature algorithms
        unset OQS_OID_FALCON512
        unset OQS_OID_P256_FALCON512
        unset OQS_OID_RSA3072_FALCON512
        unset OQS_OID_FALCONPADDED512
        unset OQS_OID_P256_FALCONPADDED512
        unset OQS_OID_RSA3072_FALCONPADDED512
        unset OQS_OID_FALCON1024
        unset OQS_OID_P521_FALCON1024
        unset OQS_OID_FALCONPADDED1024
        unset OQS_OID_P521_FALCONPADDED1024

        # Unset SPHINCS signature algorithms
        unset OQS_OID_SPHINCSSHA2128FSIMPLE
        unset OQS_OID_P256_SPHINCSSHA2128FSIMPLE
        unset OQS_OID_RSA3072_SPHINCSSHA2128FSIMPLE
        unset OQS_OID_SPHINCSSHA2128SSIMPLE
        unset OQS_OID_P256_SPHINCSSHA2128SSIMPLE
        unset OQS_OID_RSA3072_SPHINCSSHA2128SSIMPLE
        unset OQS_OID_SPHINCSSHA2192FSIMPLE
        unset OQS_OID_P384_SPHINCSSHA2192FSIMPLE
        unset OQS_OID_SPHINCSSHAKE128FSIMPLE
        unset OQS_OID_P256_SPHINCSSHAKE128FSIMPLE
        unset OQS_OID_RSA3072_SPHINCSSHAKE128FSIMPLE

        # Unset MAYO signature algorithms
        unset OQS_OID_MAYO1
        unset OQS_OID_P256_MAYO1
        unset OQS_OID_MAYO2
        unset OQS_OID_P256_MAYO2
        unset OQS_OID_MAYO3
        unset OQS_OID_P384_MAYO3
        unset OQS_OID_MAYO5
        unset OQS_OID_P521_MAYO5

        # Unset CROSS signature algorithms
        unset OQS_OID_CROSSRSDP128BALANCED

        # Unset OV signature algorithms
        unset OQS_OID_OV_IS_PKC
        unset OQS_OID_P256_OV_IS_PKC
        unset OQS_OID_OV_IP_PKC
        unset OQS_OID_P256_OV_IP_PKC
        unset OQS_OID_OV_IS_PKC_SKC
        unset OQS_OID_P256_OV_IS_PKC_SKC
        unset OQS_OID_OV_IP_PKC_SKC
        unset OQS_OID_P256_OV_IP_PKC_SKC

        # Unset SNOVA signature algorithms
        unset OQS_OID_SNOVA2454
        unset OQS_OID_P256_SNOVA2454
        unset OQS_OID_SNOVA2454ESK
        unset OQS_OID_P256_SNOVA2454ESK
        unset OQS_OID_SNOVA37172
        unset OQS_OID_P256_SNOVA37172
        unset OQS_OID_SNOVA2455
        unset OQS_OID_P384_SNOVA2455
        unset OQS_OID_SNOVA2965
        unset OQS_OID_P521_SNOVA2965

        # Unset Frodo KEM algorithms
        unset OQS_OID_FRODO640AES
        unset OQS_OID_P256_FRODO640AES
        unset OQS_OID_X25519_FRODO640AES
        unset OQS_OID_FRODO640SHAKE
        unset OQS_OID_P256_FRODO640SHAKE
        unset OQS_OID_X25519_FRODO640SHAKE
        unset OQS_OID_FRODO976AES
        unset OQS_OID_P384_FRODO976AES
        unset OQS_OID_X448_FRODO976AES
        unset OQS_OID_FRODO976SHAKE
        unset OQS_OID_P384_FRODO976SHAKE
        unset OQS_OID_X448_FRODO976SHAKE
        unset OQS_OID_FRODO1344AES
        unset OQS_OID_P521_FRODO1344AES
        unset OQS_OID_FRODO1344SHAKE
        unset OQS_OID_P521_FRODO1344SHAKE

        # Unset ML-KEM algorithms
        unset OQS_OID_P256_MLKEM512
        unset OQS_OID_X25519_MLKEM512
        unset OQS_OID_BP256_MLKEM512
        unset OQS_OID_BP384_MLKEM768
        unset OQS_OID_MLKEM1024
        unset OQS_OID_P521_MLKEM1024
        unset OQS_OID_BP512_MLKEM1024

        # Unset BIKE KEM algorithms
        unset OQS_OID_BIKEL1
        unset OQS_OID_P256_BIKEL1
        unset OQS_OID_X25519_BIKEL1
        unset OQS_OID_BIKEL3
        unset OQS_OID_P384_BIKEL3
        unset OQS_OID_X448_BIKEL3
        unset OQS_OID_BIKEL5
        unset OQS_OID_P521_BIKEL5

        # Unset HQC KEM algorithms
        unset OQS_OID_HQC_128
        unset OQS_OID_HQC_192
        unset OQS_OID_HQC_256

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function oid_handler_entrypoint() {
    # Main entry point for the OID handler script. This function is responsible for orchestrating the execution of the script 
    # by first parsing the command line arguments and then calling the OID handler function with the relevant configuration 
    # mode based on the detected arguments.

    # Ensure that arugments have been passed to the script
    if [[ $# -gt 0 ]]; then
        parse_args "$@"
        OID_handler $configure_mode
    else
        echo "[ERROR] - No arguments provided. One of --set-env-oids or --clear-env-oids is required."
        output_help
        exit 1
    fi

}
oid_handler_entrypoint "$@"
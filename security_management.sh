#!/usr/bin/env bash
# ==============================================================================
# Description	: 	Lib of functions for security handling
# Dependencies:     openssl;
# Bash_version:	    tested on GNU bash, version 4.4.20(1)-release
# Author:           aurel_cuvin@yahoo.com
# ===============================================================================
#set -euo pipefail
#set -x

# ============================================================================= #
# ==============================  SSL HELPERS  ============================ #
# ============================================================================= #

# -------------------------------------------------------- #
# -------------  SSL CERTIFICATES MANAGEMENT  ------------ #
# -------------------------------------------------------- #

# ----------------------------------------------------- #
# Create self signed certificates
# ----------------------------------------------------- #

function selfsigned_cert_do() {

    # Certificate details to be set if needed. Currently only CN is set to the server hostname and 1 year validity
    # "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"
    
    # Output directory for the certificates
    OUTPUT_DIR=$(mktemp -d)

    # Generate a private key
    openssl genpkey -algorithm RSA -out "$OUTPUT_DIR/private_key.pem" -pkeyopt rsa_keygen_bits:4096

    # Generate a self-signed certificate in PEM format
    openssl req -new -key "$OUTPUT_DIR/private_key.pem" -x509 -out "$OUTPUT_DIR/certificate.pem" -days 365 -subj "/CN=${HOSTNAME}"

    # Generate the same certificate in DER format
    openssl x509 -outform der -in "$OUTPUT_DIR/certificate.pem" -out "$OUTPUT_DIR/certificate.der"

    # Generate a PKCS#12 (PFX) file that includes both the private key and certificate
    openssl pkcs12 -export -out "$OUTPUT_DIR/certificate.pfx" -inkey "$OUTPUT_DIR/private_key.pem" -in "$OUTPUT_DIR/certificate.pem" -passout pass:

    echo "Certificates generated in $OUTPUT_DIR directory:"
    ls -l "$OUTPUT_DIR"

}

selfsigned_cert_do
#!/usr/bin/env bash
# Self-signed CA + Server Certificate Generator
# Ubuntu 24.04 compatible
# Read-only except for generated artifacts

set -euo pipefail

############################
# CONFIGURATION
############################
CERT_DIR="traefik-certs"
DAYS_VALID=365

# Certificate identity
C="USA"
ST="California"
L="San Francisco"
O="Tradespecter"
CN="local.domain"

# Subject Alternative Names
DNS_NAMES=("local.domain" "*.local.domain")
IP_NAMES=("127.0.0.1")

############################
# SETUP
############################
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "Using output directory: $(pwd)"

############################
# CREATE CA
############################
echo "Generating CA private key..."
openssl genrsa -out ca.key 2048

echo "Generating self-signed CA certificate..."
openssl req -x509 -new -nodes \
  -key ca.key \
  -sha256 \
  -days "$DAYS_VALID" \
  -out ca.crt \
  -subj "/C=$C/ST=$ST/L=$L/O=$O/CN=$CN-CA"

############################
# SERVER KEY
############################
echo "Generating server private key..."
openssl genrsa -out server.key 2048

############################
# CSR CONFIG
############################
echo "Creating CSR configuration..."

cat > csr.conf <<EOF
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = v3_req

[ dn ]
C  = $C
ST = $ST
L  = $L
O  = $O
CN = $CN

[ v3_req ]
keyUsage         = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName   = @alt_names

[ alt_names ]
EOF

i=1
for dns in "${DNS_NAMES[@]}"; do
  echo "DNS.$i = $dns" >> csr.conf
  ((i++))
done

i=1
for ip in "${IP_NAMES[@]}"; do
  echo "IP.$i = $ip" >> csr.conf
  ((i++))
done

############################
# GENERATE CSR
############################
echo "Generating Certificate Signing Request (CSR)..."
openssl req -new \
  -key server.key \
  -out server.csr \
  -config csr.conf

############################
# SIGN SERVER CERT
############################
echo "Signing server certificate with CA..."
openssl x509 -req \
  -in server.csr \
  -CA ca.crt \
  -CAkey ca.key \
  -CAcreateserial \
  -out server.crt \
  -days "$DAYS_VALID" \
  -sha256 \
  -extensions v3_req \
  -extfile csr.conf

############################
# ADDITIONAL FORMATS
############################
echo "Generating DER format certificate..."
openssl x509 -outform der \
  -in server.crt \
  -out server.der

echo "Generating PKCS#12 (PFX) bundle..."
openssl pkcs12 -export \
  -out server.pfx \
  -inkey server.key \
  -in server.crt \
  -certfile ca.crt \
  -passout pass:

############################
# SUMMARY
############################
echo
echo "Certificate generation complete:"
ls -lh

echo
echo "Files:"
echo "  CA:"
echo "    ca.key        (CA private key)"
echo "    ca.crt        (CA certificate)"
echo "  Server:"
echo "    server.key    (server private key)"
echo "    server.crt    (server certificate, PEM)"
echo "    server.der    (server certificate, DER)"
echo "    server.pfx    (server cert + key bundle)"


# Self Signed Certs
# These are the steps to generate a certificate for www.example.com. Replace this value with the actual server name in the steps below.
# 1. Generate key:

# "openssl genpkey -algorithm RSA -out key.pem -pkeyopt rsa_keygen_bits: 2048"
# 2048 is considered secure for the next 4 years.
# 2. Generate csr

# "openssl req -new -key key.pem -days 1096 -extensions v3_ca -batch -out example.csr - utf8 -subj '/CN=www.example.com'
# Make a new Certificate Signing Request (CSR) that will be valid for 3 years.
# 3. Write extensions file (make a new file with name openssl.ss.cnf with the following contents)

# basicConstraints = CA:FALSE
# subjectAltName =DNS:www.example.com
# extendedKeyUsage =serverAuth
# 4. Self-sign csr (using SHA256) and append the extensions described in the file

# "openssl x509 -req -sha256 -days 3650 -in example.csr -signkey key.pem -set-serial $ANY_INTEGER -extfile openssl.ss.cnf -out example.pem"
# You can now use example.pem as your certfile
###############################   https://wiki.mozilla.org/SecurityEngineering/x509Certs#Self_Signed_Certs ##############################
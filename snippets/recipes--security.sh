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

# interactive
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365
# non-interactive and 10 years expiration
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 3650 -nodes -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"
#!/usr/bin/env bash


# ================================================== #
# ----------  PASSING ARRAY as argument  ----------- #
# ================================================== #

# ---------------------------------------
# Passing an ARRAY as a LIST of ARGUMENTS
# ---------------------------------------
function process_array_as_multiple_arguments {
    local array=("$@")
    for element in "${array[@]}"; do
        echo "Element: $element"
    done
}

my_array=("apple" "banana" "cherry")
# Call the function and pass the array
process_array "${my_array[@]}"

# ---------------------------------------
# Passing an ARRAY as a LIST of ARGUMENTS
# ---------------------------------------
function process_array_by_its_name() {
    local array_name="$1[@]"
    local array_ref=("${!array_name}")

    for element in "${array_ref[@]}" ; do
        echo "$element"
    done
}

my_array=("one two" "LAST")
# Call the function and pass the array name as string
process_array_by_its_name "my_array"

# ================================================== #
# ----------  RETURNING MULTIPLE VALUES  ----------- #
# ================================================== #

# -----------------
# Returns BY ARRAY
# -----------------
function get_values() {
    local result=()
    result[0]="Value1"
    result[1]="Value2"
    result[2]="Value3"
    echo "${result[@]}"
}

# Call the function and capture the values in an array
values=($(get_values))

# Access the values
val1="${values[0]}"
val2="${values[1]}"
val3="${values[2]}"


# ----------------------------
# Returns BY GLOBAL VARIABLES
# ----------------------------
value1=""
value2=""
value3=""
function set_values() {
    value1="Value1"
    value2="Value2"
    value3="Value3"
}

# Call the function to set the values
set_values

# Access the values
echo "value1: $value1"
echo "value2: $value2"
echo "value3: $value3"





















#----------------------------------------------------------------#
# GENERAL SCRIPTING - OPTIONS / ARGUMENTS HANDLING
#----------------------------------------------------------------#


##################################################################
# GENERAL SCRIPTING - WORKING DIRECTORY POSITIONING AT STARTUP
##################################################################
# detect the script location folder
#!/bin/bash
script="$0"
basename="$(dirname $script)"
 
echo "Script name $script resides in $basename directory."


# detect the current working folder


##################################################################
# GENERAL SCRIPTING - SCRIPT LOGGER
##################################################################

#----------------------------------------------------------------#
# GENERAL SCRIPTING - COMMAND OUPUT & EXIT STATUS USAGE
#----------------------------------------------------------------#

#### save output to a variable:
variable_name=$(command)
OR
variable_name=`command`

#----------------------------------------------------------------#
# FILE MANAGEMENT - CREATE FOLDER STRUCTURE
#----------------------------------------------------------------#

echo "Create folder structure 1"
mkdir -p mydir/{colors/{basic,blended},shape,animals/{mammals,reptiles}}

echo "Create folder structure 2 with files inside"
arr=( mydir1/{colors/{basic/{red,blue,green},blended/{yellow,orange,pink}},shape/{circle,square,cube},animals/{mammals/{platipus,bat,dog},reptiles/{snakes,crocodile,lizard}}} )
for i in "${arr[@]}"; do  mkdir -p "${i%/*}" && touch "$i"; done

# demo
# echo "Created folder structure 1"
# tree mydir
# rm -fr mydir
# echo "Created folder structure 2"
# tree mydir1
# rm -fr mydir1

#----------------------------------------------------------------#
# FILE MANAGEMENT - WALK FOLDER STRUCTURE
#----------------------------------------------------------------#


#----------------------------------------------------------------#
# FILE MANAGEMENT - FIND COMMAND SOLUTIONS
#----------------------------------------------------------------#


#----------------------------------------------------------------#
# SECURITY - CREATE SELF SIGNED CERTIFICATE
#----------------------------------------------------------------#

sudo mkdir -p /etc/pki/tls/certs
sudo chmod 755 /etc/pki/tls/certs
sudo apt-get install libssl1.0.0 -y

cd /etc/pki/tls/certs
export FQDN=`hostname -f`
echo -------------------
echo FQDN is $FQDN
echo -------------------

sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
-keyout $FQDN.key -out $FQDN.crt \
-subj "/C=RO/ST=TM/L=TMS/O=ATOSS/CN=$FQDN"

sudo cat $FQDN.crt $FQDN.key | sudo tee -a $FQDN.pem
openssl x509 -noout -subject -in /etc/pki/tls/certs/$FQDN.crt

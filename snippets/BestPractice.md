## **VARIABLES**
- Prefer local variables within functions over global variables
- Variables should always be referred in curly braces and quoted: "${var}"
- Capitalization:
  - Environment (exported) variables: ${ALL_CAPS}
  - Local variables: ${lower_case}
   
- Positional parameters of the script should be checked, those of functions should not

## **COMMENTS**
<ins>**Script Antet**</ins>
```
# ==============================================================================
# Description:   	  [Enter a short description of the script purpose]
# Dependencies:     [Enter any special package needed by the script. Ex: jq]
# bash_version:	    [Enter the minimal known bash version tested with the script]
# Author email:     aurel_cuvin@yahoo.com
# ===============================================================================
```
<ins>**Header_1 Level**</ins>
```
# ================================================== #
# ===================  HEADER_1  =================== #
# ================================================== #
```
<ins>**Header_2 Level**</ins>
```
# -------------------------------------------------- #
# -------------------  HEADER_2  ------------------- #
# -------------------------------------------------- #
```

<ins>**Header_3 Level**</ins>
```
# ----------------------------------------------
# Header_3
# ----------------------------------------------
```

## **SUBSTITUTION**
- Always use $(cmd) for command substitution (as opposed to backquotes)
- Prepend a command with \ to override alias/builtin lookup.

## **OUTPUT AND REDIRECTION**
- printf is preferable to echo (more control, more portable and its behaviour is defined better)
- when redirection is needed use: 1>&2
- Strong quoted heredoc = Single-quote of the leading tag (prevent expansion within message)

## **FUNCTIONS**
- Apply the Single Responsibility Principle: a function does one thing.
- Don’t mix levels of abstraction
- Describe the usage of each function: number of arguments, return value, output
- Declare local variables with a meaningful name for positional parameters of functions
- Create functions with a meaningful name for complex tests
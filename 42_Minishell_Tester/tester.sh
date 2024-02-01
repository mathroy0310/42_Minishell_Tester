#!/bin/bash

# Global variables
MINISHELL_PATH="../minishell"
PROMPT=$(echo -e "\nexit\n" | $MINISHELL_PATH | head -n 1 | sed "s/\x1B\[[0-9;]\{1,\}[A-Za-z]//g" )
REMOVE_COLORS="sed s/\x1B\[[0-9;]\{1,\}[A-Za-z]//g"
REMOVE_EXIT="grep -v ^exit$"

# Colors
BOLD="\e[1m"
YELLOW="\033[0;33m"
GREY="\033[38;5;244m"
GREEN="\033[0;32m"
PURPLE="\033[0;35m"
BLUE="\033[0;36m"
RED="\e[0;31m"
END="\033[0m"

TESTFILES_LIST=(
    "./test_cmds/syntax.txt"
    "./test_cmds/builtins.txt"
    "./test_cmds/pipes.txt"
    "./test_cmds/redirects.txt"
    "./test_cmds/extras.txt"
)
usage() {
    echo "Usage: $0 [-h|--help]"
    echo "Options:"
    echo "  -h, --help    Display this help message"
    exit
}

# Parse command-line options
while (( "$#" )); do
    case "$1" in
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
    shift
done

# Create output directories
setup() {
    chmod 000 ./test_files/no_rights.txt
    mkdir -p ./outfiles ./minishell_outfiles ./bash_outfiles
}

# Clean up
cleanup() {
    chmod 666 ./test_files/no_rights.txt
    rm -rf ./outfiles ./minishell_outfiles ./bash_outfiles
}

# Run tests
run_tests() {
    local ok=0
	local total=0

    for testfile in ${TESTFILES_LIST[*]}; do

        printf $RED
        echo "———————————— $testfile"

    	local i=0
        while read teste; do
            ((i++))
			((total++))

            rm -rf ./outfiles/*
            rm -rf ./minishell_outfiles/*
            MINISHELL_OUTPUT=$(echo -e "$teste" | $MINISHELL_PATH 2> /dev/null | $REMOVE_COLORS | grep -vF "$PROMPT" | $REMOVE_EXIT )
            MINISHELL_OUTFILES=$(cp ./outfiles/* ./minishell_outfiles &>/dev/null)
            MINISHELL_EXIT_CODE=$(echo -e "$MINISHELL_PATH\n$teste\necho \$?\nexit\n" | bash 2> /dev/null | $REMOVE_COLORS | grep -vF "$PROMPT" | $REMOVE_EXIT | tail -n 1)
            MINISHELL_ERROR_MSG=$(trap "" PIPE && echo "$teste" | $MINISHELL_PATH 2>&1 > /dev/null |  $REMOVE_COLORS | grep -o '[^:]*$' )

            rm -rf ./outfiles/*
            rm -rf ./bash_outfiles/*
            BASH_OUTPUT=$(echo -e "$teste" | bash 2> /dev/null)
            BASH_EXIT_CODE=$(echo $?)
            BASH_OUTFILES=$(cp ./outfiles/* ./bash_outfiles &>/dev/null)
            BASH_ERROR_MSG=$(trap "" PIPE && echo "$teste" | bash 2>&1 > /dev/null | grep -o '[^:]*$' | head -n1)

            OUTFILES_DIFF=$(diff --brief ./minishell_outfiles ./bash_outfiles)

            printf $BLUE
            printf "Test %3s: " $i
			printf  "$END Command : $GREY $teste $END"
			if [[ "$MINISHELL_OUTPUT" == "$BASH_OUTPUT" && "$MINISHELL_EXIT_CODE" == "$BASH_EXIT_CODE" && -z "$OUTFILES_DIFF" ]]; then
				printf "✅ OK\n"
				((ok++))
			else
				printf "❌ KO\n"
				printf $RED
				if [ "$OUTFILES_DIFF" ]; then
					echo -e " Outfiles Difference:"
					echo "$OUTFILES_DIFF"
					echo -e " Minishell Outfiles:"
					cat ./minishell_outfiles/*
					echo -e " Bash Outfiles:"
					cat ./bash_outfiles/*
				fi

				if [ "$MINISHELL_OUTPUT" != "$BASH_OUTPUT" ]; then
					echo -e  "Minishell Output: ($MINISHELL_OUTPUT)"
					echo -e " Bash Output: ($BASH_OUTPUT)"
				fi

				if [ "$MINISHELL_EXIT_CODE" != "$BASH_EXIT_CODE" ]; then
					echo -e " Minishell Exit Code: $MINISHELL_EXIT_CODE"
					echo -e " Bash Exit Code: $BASH_EXIT_CODE"
				fi

				if [ "$MINISHELL_ERROR_MSG" != "$BASH_ERROR_MSG" ]; then
					echo -e " Minishell Error Message:($MINISHELL_ERROR_MSG)"
					echo -e " Bash Error Message: ($BASH_ERROR_MSG)"
				fi
				printf $END
				printf "\n"
			fi
        done < $testfile
    done
    printf "${BLUE}${BOLD}Summary:${END} Passed $ok out of $total tests\n"

    if [[ "$ok" == "$total" ]]; then
        printf "${GREEN}All tests passed! Great job!${END}\n"
    else
        printf "${RED}Some tests failed. Keep trying!${END}\n"
    fi
}

# Main function
main() {
    setup
    run_tests
    cleanup
}

# Run the script
main

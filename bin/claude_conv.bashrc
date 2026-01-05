# Claude Conversation Converter
# Add this to your ~/.bashrc or ~/.bash_profile
#
# Dependencies:
#   pip install reportlab  (only needed for PDF output)
#
# Usage:
#   claude-conv input.txt                     # -> input_conversation.pdf
#   claude-conv input.txt output.pdf          # explicit output
#   claude-conv input.txt output.md           # markdown output
#   claude-conv input.txt -f md               # markdown, auto filename
#   claude-conv input.txt -f pdf -t "Title"   # PDF with title

# Set this to where you put the Python script
CLAUDE_CONV_SCRIPT="${HOME}/bin/claude_conv_to_pdf.py"

claude-conv() {
    if [[ ! -f "${CLAUDE_CONV_SCRIPT}" ]]; then
        echo "Error: Claude converter script not found at ${CLAUDE_CONV_SCRIPT}"
        echo "Update CLAUDE_CONV_SCRIPT in your bashrc to point to the script location."
        return 1
    fi

    if [[ $# -eq 0 ]]; then
        echo "Usage: claude-conv <input.txt> [output.pdf|output.md] [-f pdf|md] [-t title]"
        echo ""
        echo "Convert Claude conversation exports to PDF or Markdown."
        echo ""
        echo "Options:"
        echo "  -f, --format    Output format: pdf or md (overrides extension)"
        echo "  -t, --title     Document title"
        echo ""
        echo "Examples:"
        echo "  claude-conv chat.txt                    # -> chat_conversation.pdf"
        echo "  claude-conv chat.txt notes.md           # -> notes.md (markdown)"
        echo "  claude-conv chat.txt -f md              # -> chat_conversation.md"
        echo "  claude-conv chat.txt -t 'Project Chat'  # PDF with custom title"
        return 0
    fi

    python3 "${CLAUDE_CONV_SCRIPT}" "$@"
}

# Optional: tab completion for the function
_claude_conv_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "${prev}" in
        -f|--format)
            COMPREPLY=($(compgen -W "pdf md markdown" -- "${cur}"))
            return 0
            ;;
        -t|--title)
            # No completion for title
            return 0
            ;;
    esac

    if [[ "${cur}" == -* ]]; then
        COMPREPLY=($(compgen -W "-f --format -t --title -h --help" -- "${cur}"))
    else
        # Complete filenames
        COMPREPLY=($(compgen -f -- "${cur}"))
    fi
}

complete -F _claude_conv_completions claude-conv

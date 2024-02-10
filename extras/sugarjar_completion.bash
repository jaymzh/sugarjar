# bash completion for sugarjar

SJCONFIG="$HOME/.config/sugarjar/config.yaml"

_sugarjar_completions()
{
    if [ "${#COMP_WORDS[@]}" -eq 2 ]; then
        return
    fi

    local -a suggestions

    # grap the feature_prefix if we have one so that we
    # can let the user ignore that part. If we have `yq`
    # we'll use it as that's going to be always 100%
    # reliable, but if we don't, do our best with shell
    # utils
    local prefix=''
    if [ -e "$SJCONFIG" ]; then
        if type yq &>/dev/null; then
            prefix=$(yq .feature_prefix $SJCONFIG)
        else
            # the xargs removes extra spaces
            prefix=$(grep feature_prefix $SJCONFIG | cut -f2 -d: | xargs)
        fi
    fi

    case "${COMP_WORDS[1]}" in
        co|checkout|bclean)
            local branches=$(git branch | sed -e 's/* //g' | xargs)
            if [ -n "$prefix" ]; then
                local branches=$(echo $branches | sed -e "s!$prefix!!g")
            fi
            suggestions=($(compgen -W "$branches" -- "${COMP_WORDS[2]}"))
            COMPREPLY=("${suggestions[@]}")
            ;;
        *)
            return
    esac
}

complete -F _sugarjar_completions sj

# bash completion for sugarjar

SJCONFIG="$HOME/.config/sugarjar/config.yaml"

_sugarjar_completions()
{
    if [ "${#COMP_WORDS[@]}" -eq 2 ]; then
        return
    fi

    local -a suggestions

    # grap any and all feature_prefixes so that we can let the user ignore that
    # part. If we have `yq` we'll use it as that's going to be always 100%
    # reliable, but if we don't, do our best with shell utils
    local prefixes=''
    if [ -e "$SJCONFIG" ]; then
        if type yq &>/dev/null; then
            # We don't use the '// empty' syntax here as thats only in
            # very new yq, so use the more standard '| select(. != null)'
            yq_search='[.host_configs[].feature_prefix | select(. != null)] | unique[]'
            prefixes=$(yq -r "$yq_search" $SJCONFIG | xargs)
        else
            prefixes=$(
                grep feature_prefix $SJCONFIG | cut -f2 -d: | sort -u | xargs
            )
        fi
    fi

    case "${COMP_WORDS[1]}" in
        co|checkout|bclean)
            local branches=$(git branch | sed -e 's/* //g' | xargs)
            if [ -n "$prefixes" ]; then
                regex=$(printf '%s\n' $prefixes | paste -sd'|')
                local branches=$(echo $branches | sed -E "s!($regex)!!g")
            fi
            suggestions=($(compgen -W "$branches" -- "${COMP_WORDS[2]}"))
            COMPREPLY=("${suggestions[@]}")
            ;;
        *)
            return
    esac
}

complete -F _sugarjar_completions sj

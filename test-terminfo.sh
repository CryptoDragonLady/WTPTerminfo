#!/usr/bin/env bash
# Visual and interactive checks for the profiles in wt-advanced.tl.
set -euo pipefail
export LC_ALL=C

usage() {
    cat <<'EOF'
Usage: TERM=wt-advanced ./test-terminfo.sh [--keys]
       TERM=wt-direct   ./test-terminfo.sh [--keys]

Shows text styles, indexed colors, RGB colors (wt-direct), hyperlinks,
synchronized redraws, and snake.six. --keys also compares
keypresses with the installed terminfo key sequences; press q to finish.
Requires Bash and ncurses tput. Run directly in Windows Terminal Preview.
EOF
}

test_keys=0
case ${1:-} in
    '') ;;
    --keys) test_keys=1 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac
if (( $# > 1 )); then usage >&2; exit 2; fi
if [[ ! -t 1 ]]; then
    printf 'Run this demo in a terminal; stdout must not be redirected.\n' >&2
    exit 1
fi
if (( test_keys )) && [[ ! -t 0 ]]; then
    printf 'The key test requires terminal input.\n' >&2
    exit 1
fi
case ${TERM:-} in
    wt-advanced|wt-direct) ;;
    *) printf 'Set TERM=wt-advanced or TERM=wt-direct after installing wt-advanced.tl.\n' >&2; exit 1 ;;
esac
if ! command -v tput >/dev/null; then
    printf 'Install ncurses tput before running the demo.\n' >&2
    exit 1
fi
demo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ ! -r $demo_dir/snake.six ]]; then
    printf 'Cannot read the SIXEL asset: %s/snake.six\n' "$demo_dir" >&2
    exit 1
fi

# Check lookups before emitting any escape sequences.
required=(sgr0 bold sitm smul rev Smol Rmol Smul2 Smulc Smuld Smule
          Smulx Rmulx Sync civis cnorm cr el setaf setab)
if (( test_keys )); then required+=(smkx rmkx); fi
if [[ $TERM == wt-direct ]]; then required+=(setfrgb setbrgb); fi
for capability in "${required[@]}"; do
    if ! tput "$capability" >/dev/null 2>&1; then
        printf 'Missing %s in %s. Reinstall with tic -x -o "$HOME/.terminfo" wt-advanced.tl\n' \
            "$capability" "$TERM" >&2
        exit 1
    fi
done

reset=$(tput sgr0)
link_start=$(tput Smulx)
link_end=$(tput Rmulx)
if [[ $link_start != $'\033]8;;%p1%s\033\\' || $link_end != $'\033]8;;\033\\' ]]; then
    printf 'The installed %s hyperlink definition is outdated or incompatible.\n' "$TERM" >&2
    printf 'Recompile the updated source: tic -x -o "$HOME/.terminfo" wt-advanced.tl\n' >&2
    exit 1
fi
sync_on=$(tput Sync 1)
sync_off=$(tput Sync 0)
cursor_hide=$(tput civis)
cursor_show=$(tput cnorm)
carriage_return=$(tput cr)
erase_line=$(tput el)
keypad_active=0
sixel_active=0

cleanup() {
    local status=$?
    trap - EXIT HUP INT TERM
    # End an interrupted SIXEL packet before restoring text modes.
    if (( sixel_active )); then printf '\033\\'; fi
    printf '%s%s%s%s' "$sync_off" "$link_end" "$reset" "$cursor_show"
    if (( keypad_active )); then tput rmkx; fi
    printf '\n'
    exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

section() { printf '\n%s%s%s\n' "$(tput bold)" "$1" "$reset"; }
sample() { printf '%s%-18s%s' "$(tput "$1")" "$2" "$reset"; }

printf 'Windows Terminal Preview terminfo demo: %s (%s colors)\n' "$TERM" "$(tput colors)"
printf 'Compare the visible results with the labels. Ctrl-C exits safely.\n'
section 'Text styles'
sample bold 'Bold'; sample sitm 'Italic'; sample rev 'Reverse'; printf '\n'
sample smul 'Single underline'; sample Smul2 'Double underline'; printf '\n'
sample Smulc 'Curly underline'; sample Smuld 'Dotted underline'; printf '\n'
sample Smule 'Dashed underline'; sample Smol 'Overline'; printf '\n'

section 'Indexed colors: 16 foregrounds, then 16 backgrounds'
for (( color=0; color<16; color++ )); do
    tput setaf "$color"; printf ' %02d ' "$color"; printf '%s' "$reset"
done
printf '\n'
for (( color=0; color<16; color++ )); do
    tput setab "$color"; tput setaf "$((color == 0 || color == 4 ? 15 : 0))"
    printf ' %02d ' "$color"; printf '%s' "$reset"
done
printf '\n'
section '216-color cube (six rows) and 24 gray levels'
for (( color=16; color<256; color++ )); do
    tput setab "$color"; printf '  '
    if (( (color < 232 && (color - 15) % 36 == 0) || color == 255 )); then
        printf '%s\n' "$reset"
    fi
done

section '24-bit RGB foreground and background ramps'
if [[ $TERM == wt-direct ]]; then
    for capability in setfrgb setbrgb; do
        for (( step=0; step<48; step++ )); do
            red=$((255 - step * 255 / 47))
            green=$((step * 255 / 47))
            distance=$((2 * step - 47)); if (( distance < 0 )); then distance=$((-distance)); fi
            blue=$((255 - distance * 255 / 47))
            tput "$capability" "$red" "$green" "$blue"
            if [[ $capability == setfrgb ]]; then printf '#'; else printf ' '; fi
        done
        printf '%s\n' "$reset"
    done
else
    printf 'Use TERM=wt-direct to exercise setfrgb and setbrgb.\n'
fi

section 'Hyperlink: the label should open the repository'
# tput cannot pass a string parameter to this custom Smulx capability on
# all ncurses versions. Substitute its one string placeholder without eval.
repository_url=https://github.com/CryptoDragonLady/WTPTerminfo
printf '%sOpen WTPTerminfo on GitHub%s\n' "${link_start//%p1%s/$repository_url}" "$link_end"

section 'Synchronized redraw and cursor visibility'
printf '%s' "$cursor_hide"
for (( frame=0; frame<=24; frame++ )); do
    printf -v filled '%*s' "$frame" ''
    printf -v empty '%*s' "$((24 - frame))" ''
    printf '%s%s%s [%s%s] %3d%%%s' "$sync_on" "$carriage_return" "$erase_line" \
        "${filled// /#}" "${empty// /.}" "$((frame * 100 / 24))" "$sync_off"
    sleep 0.04
done
printf '%s\n' "$cursor_show"

section 'SIXEL graphics: snake.six (600 x 450 pixels)'
printf 'SIXEL is sent directly; it is not a capability defined by this profile.\n'
sixel_active=1
cat -- "$demo_dir/snake.six"
sixel_active=0
printf '\n'

if (( test_keys )); then
    section 'Key sequences: arrows, Home/End, Insert/Delete, PgUp/PgDn, F1-F12'
    printf 'Press keys to compare their bytes with terminfo; q finishes.\n'
    key_caps=(kcuu1 kcud1 kcub1 kcuf1 khome kend kich1 kdch1 kpp knp
              kf1 kf2 kf3 kf4 kf5 kf6 kf7 kf8 kf9 kf10 kf11 kf12)
    key_sequences=()
    for capability in "${key_caps[@]}"; do key_sequences+=("$(tput "$capability")"); done
    keypad_active=1
    tput smkx
    while IFS= read -r -s -N 1 key; do
        if [[ $key == q ]]; then break; fi
        if [[ $key == $'\033' ]]; then
            while IFS= read -r -s -N 1 -t 0.1 next; do key+=$next; done
        fi
        matched=unmapped
        for (( index=0; index<${#key_caps[@]}; index++ )); do
            if [[ $key == "${key_sequences[index]}" ]]; then matched=${key_caps[index]}; break; fi
        done
        printf '  %-10s %q\n' "$matched" "$key"
    done
fi
printf '\nDemo finished. Rendering and key matching are visual checks, not automatic pass/fail tests.\n'

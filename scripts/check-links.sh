#!/bin/sh
# Check every external link on the site.
#
# Two kinds of rot matter here:
#   1. the link dies            -> a bad status code catches it
#   2. the domain is sold on    -> still answers 200, but the content is now
#                                  someone else's (this is how ergoplanet.de
#                                  ended up pointing at a gambling site)
#
# For the second kind the script records each page's <title> in a baseline file
# and reports when a title changes, which is the cheapest signal that a site is
# no longer what it was. A changed title is not automatically bad - sites get
# redesigned - so it asks for a human look rather than failing.
#
# Usage: scripts/check-links.sh [--update-baseline]
# Exits non-zero if a link is unreachable or a title changed.

set -u

DIR="$(dirname "$0")"
SRC="$DIR/../src"
BASELINE="$DIR/link-titles.txt"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"

update=0
[ $# -gt 0 ] && [ "$1" = "--update-baseline" ] && update=1

failed=0
changed=0
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# HEAD first; some hosts reject it, so fall back to asking for a single byte
# rather than pulling down whole installers.
probe() {
    code=$(curl -s -o /dev/null -L -m 25 -A "$UA" -H 'Accept: text/html' -I -w '%{http_code}' "$1")
    case "$code" in
        2*|3*) echo "$code"; return ;;
    esac
    curl -s -o /dev/null -L -m 25 -A "$UA" -H 'Accept: text/html' -r 0-0 -w '%{http_code}' "$1"
}

# Only the first 8 KB is fetched: <title> lives in the head, and the download
# links point at whole installers. Takes the FIRST <title>, since pages embed
# further ones inside inline SVG icons.
page_title() {
    curl -s -L -m 25 -A "$UA" -H 'Accept: text/html' -r 0-8191 "$1" \
        | tr '\n' ' ' \
        | grep -o '<[Tt][Ii][Tt][Ll][Ee][^>]*>[^<]*<' \
        | head -1 \
        | sed 's/^<[^>]*>//; s/<$//; s/^ *//; s/ *$//' \
        | cut -c1-120
}

links=$(grep -rho 'href="http[^"]*"' --include='*.html' "$SRC" \
        | sed 's/^href="//; s/"$//' \
        | grep -v '://\(www\.\)\?incyclist\.com' \
        | grep -v 'schema\.org\|gmpg\.org\|w3\.org' \
        | sort -u)

for url in $links; do
    code=$(probe "$url")

    # the app stores rate-limit repeated probes; that is not a broken link
    if [ "$code" = "429" ]; then
        sleep 5
        code=$(probe "$url")
    fi

    case "$code" in
        2*|3*) ;;
        429)   printf '  rate-limited  %s (could not verify)\n' "$url"; continue ;;
        *)     printf '  FAIL %s  %s\n' "$code" "$url"; failed=$((failed + 1)); continue ;;
    esac

    title=$(page_title "$url")
    printf '%s\t%s\n' "$url" "$title" >> "$tmp"

    if [ "$update" -eq 1 ] || [ ! -f "$BASELINE" ]; then
        printf '  ok   %s  %s\n' "$code" "$url"
        continue
    fi

    was=$(grep -F "$url	" "$BASELINE" | head -1 | cut -f2-)
    if [ -z "$was" ]; then
        printf '  new  %s  %s\n' "$code" "$url"
        printf '       (not in baseline yet: "%s")\n' "$title"
    elif [ "$was" = "$title" ]; then
        printf '  ok   %s  %s\n' "$code" "$url"
    else
        printf '  CHANGED   %s\n' "$url"
        printf '       was: "%s"\n' "$was"
        printf '       now: "%s"\n' "$title"
        printf '       open it by hand - the site may have changed owner\n'
        changed=$((changed + 1))
    fi
done

if [ "$update" -eq 1 ] || [ ! -f "$BASELINE" ]; then
    sort "$tmp" > "$BASELINE"
    printf '\nBaseline written to %s\n' "$BASELINE"
    exit 0
fi

if [ "$failed" -gt 0 ] || [ "$changed" -gt 0 ]; then
    printf '\n%s unreachable, %s changed title.\n' "$failed" "$changed"
    printf 'After reviewing, re-run with --update-baseline to accept the current state.\n'
    exit 1
fi

printf '\nAll external links reachable, no title changes.\n'

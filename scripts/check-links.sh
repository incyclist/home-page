#!/bin/sh
# Check every external link on the site, so a domain that gets sold on does not
# keep sitting in the pages unnoticed.
#
# Usage: scripts/check-links.sh
# Exits non-zero if any link fails, so it can be wired into CI later.

set -u

SRC="$(dirname "$0")/../src"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
failed=0

# HEAD first; some hosts reject it, so fall back to asking for a single byte
# rather than pulling down whole installers.
probe() {
    code=$(curl -s -o /dev/null -L -m 25 -A "$UA" -H 'Accept: text/html' -I -w '%{http_code}' "$1")
    case "$code" in
        2*|3*) echo "$code"; return ;;
    esac
    curl -s -o /dev/null -L -m 25 -A "$UA" -H 'Accept: text/html' -r 0-0 -w '%{http_code}' "$1"
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
        2*|3*) printf '  ok   %s  %s\n' "$code" "$url" ;;
        429)   printf '  rate-limited  %s (could not verify)\n' "$url" ;;
        *)     printf '  FAIL %s  %s\n' "$code" "$url"; failed=$((failed + 1)) ;;
    esac
done

if [ "$failed" -gt 0 ]; then
    printf '\n%s link(s) failed.\n' "$failed"
    exit 1
fi

printf '\nAll external links reachable.\n'
printf 'Note: a domain that was sold on still answers 200. This catches dead links,\n'
printf 'not hijacked ones -- those need a human to look at the page.\n'

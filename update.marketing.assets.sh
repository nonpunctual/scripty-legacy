#!/bin/bash
#shellcheck disable=SC2207


# variables & functions
branch='main'
owner='fleetdm'
path='articles'
repo='fleet'


# collect article data & create tables
filearr=($(/usr/bin/curl -LSs -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$owner/$repo/git/trees/$branch?recursive=1" | /usr/bin/jq -r '.tree[] | select(.path | contains("articles")) | .path' | /usr/bin/sed 's/^articles\///;/^website\//d;1d'))

IFS=$'\n\t'

for i in "${filearr[@]}"
do
    filename="$(echo "$i" | /usr/bin/sed 's/\.md//')"
    metadata="$(/usr/bin/curl -LSs "https://raw.githubusercontent.com/$owner/$repo/$branch/$path/$i" | /usr/bin/grep -A10 -E '^<meta')"
    mauth="$(echo "$metadata" | /usr/bin/xmllint --html --xpath 'string(//meta[@name="authorFullName"]/@value)' -)"
    mcatg="$(echo "$metadata" | /usr/bin/xmllint --html --xpath 'string(//meta[@name="category"]/@value)' -)"
    mdesc="$(echo "$metadata" | /usr/bin/xmllint --html --xpath 'string(//meta[@name="description"]/@value)' -)"
    mstmp="$(echo "$metadata" | /usr/bin/xmllint --html --xpath 'string(//meta[@name="publishedOn"]/@value)' -)"
    mtitl="$(echo "$metadata" | /usr/bin/xmllint --html --xpath 'string(//meta[@name="articleTitle"]/@value)' -)"

    printf "%s\n" "$i"

    case "$mcatg" in
            'articles' ) artclarr+=($(printf "| %s | [%s](https://fleetdm.com/articles/$filename) | %s | %s |" "$mstmp" "$mtitl" "$mdesc" "$mauth")) ;;
       'announcements' ) csstdarr+=($(printf "| %s | [%s](https://fleetdm.com/announcements/$filename) | %s | %s |" "$mstmp" "$mtitl" "$mdesc" "$mauth")) ;;
          'case study' ) csstdarr+=($(printf "| %s | [%s](https://fleetdm.com/case-study/$filename) | %s | %s |" "$mstmp" "$mtitl" "$mdesc" "$mauth")) ;;
          'comparison' ) cmpararr+=($(printf "| %s | [%s](https://fleetdm.com/compare/$filename) | %s |" "$mstmp" "$mtitl" "$mdesc")) ;;
              'guides' ) guidearr+=($(printf "| %s | [%s](https://fleetdm.com/guides/$filename) | %s | %s |" "$mstmp" "$mtitl" "$mdesc" "$mauth")) ;;
            'releases' ) rlesearr+=($(printf "| %s | [%s](https://fleetdm.com/releases/$filename) | %s |" "$mstmp" "$mtitl" "$mdesc")) ;;
    esac

    unset filename metadata mauth mcatg mdesc mstmp mtitl
done

printf "\n\n"

printf "Articles & Blog Posts\n| Date updated | Asset | Description | Author |\n| :--- | :--- | :--- | :--- |\n"
for j in "${artclarr[@]}"; do echo "$j"; done | /usr/bin/sort -r -k 1 -t '|'; printf "\n\n"

printf "Case Studies & Success Stories\n| Date updated | Asset | Description | Author |\n| :--- | :--- | :--- | :--- |\n"
for j in "${csstdarr[@]}"; do echo "$j"; done | /usr/bin/sort -r -k 1 -t '|'; printf "\n\n"

# printf "| Date updated | Asset | Description |\n| :--- | :--- | :--- |\n"
# for j in "${cmpararr[@]}"; do echo "$j"; done | /usr/bin/sort -r -k 1 -t '|'; printf "\n\n"

printf "Guides\n| Date updated | Asset | Description | Author |\n| :--- | :--- | :--- | :--- |\n"
for j in "${guidearr[@]}"; do echo "$j"; done | /usr/bin/sort -r -k 1 -t '|'; printf "\n\n"

# printf "Release Notes\n| Date updated | Asset | Description |\n| :--- | :--- | :--- |\n"
# for j in "${rlesearr[@]}"; do echo "$j"; done | /usr/bin/sort -r -k 1 -t '|'; printf "\n\n"



# category: announcements
# https://fleetdm.com/announcements

# category: articles
# https://fleetdm.com/articles

# category: case study
# https://fleetdm.com/case-study/fastly

# category: comparison
# https://fleetdm.com/compare/jamf

# category: engineering
# https://fleetdm.com/engineering/

# category: guides
# https://fleetdm.com/guides/

# category: podcasts
# https://fleetdm.com/podcasts/

# category: releases
# https://fleetdm.com/releases

# category: report
# https://fleetdm.com/report/

# category: security
# https://fleetdm.com/securing/

# category: success stories
# https://fleetdm.com/success-stories/

# <meta name="articleTitle" value="Windows & Linux setup experience">
# <meta name="articleTitle" value="eBPF & the future of osquery on Linux">
# <meta name="articleTitle" value="Fleet 4.37.0 | Remote script execution & Puppet
#           ="articleTitle" value="Fleet 4.53.0 | Better vuln matching, multi-issue hosts, &
# <meta name="articleTitle" value="Fleet & osquery: Unlocking the value of Axonius
#  meta name="description" value="Join Fleet engineers every two weeks for live Q&A
#  Â® framework via Splunk">
#  <meta name="articleTitle" value="Translating Jamf Pro terminology & capabilities
#  <meta name="articleTitle" value="Windows & Linux setup experience">

# -:2: HTML parser error : Document is empty

# -:5: HTML parser error : htmlParseEntityRef: no name




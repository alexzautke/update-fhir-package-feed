#! /bin/bash

exit_with_message () {
  echo $1 >&2
  exit 1
}

if [ $# -eq 0 ] || [ $# -ne 3 ];
  then
    exit_with_message "You need to provide following arguments: (1) the path of the package-feed.xml, (2) the path to a package file (.tar.tgz), and (3) the base url incl. subpath of the package location"
fi

for dependency in "jq" "tar" "basename" "xmllint" "xmlstarlet"
do
    if ! [ -x "$(command -v $dependency)" ]; then
        exit_with_message "$dependency is not installed."
    fi
done

echo "Path to package-feed.xml: $1"
echo "Path to package file: $2"
echo "Base url of package location: $3"

tar zxf $2

packageJson=$(cat package/package.json)
name=$(echo "$packageJson" | jq --raw-output .description) # Workaround: In Firely.Terminal v2.5.0-beta-7, fhir pack will not use the correct name for the generated package. The correct name must come from the description.
version=$(echo "$packageJson" | jq --raw-output .version)
description=$(echo "$packageJson" | jq --raw-output .description)
creator=$(echo "$packageJson" | jq --raw-output .author)
fhirVersion=$(echo "$packageJson" | jq --raw-output ".fhirVersions | .[0]")
pubDate=$(date '+%a, %d %b %Y %T %Z')

if ! [[ "$3" == */ ]];
then
  baseUrlWithSubpath="$3/"
else
  baseUrlWithSubpath="$3"
fi

xmlstarlet ed --inplace -u "//channel/lastBuildDate" -v "$pubDate" $1
xmlstarlet ed --inplace -u "//channel/pubDate" -v "$pubDate" $1

fileName=$(basename $2)
baseUrlWithSubpath="$baseUrlWithSubpath$name/$version/$fileName?raw=true"
item="<title>$name#$version</title><description>$description</description><link>$baseUrlWithSubpath</link><guid isPermaLink=\"true\">$baseUrlWithSubpath</guid><dc:creator>$creator</dc:creator><fhir:version>$fhirVersion</fhir:version><fhir:kind>IG</fhir:kind><pubDate>$pubDate</pubDate>"

patchedXml=$(xmlstarlet ed --subnode "//channel" --type "elem" -n "item" -v "$item" $1 | xmlstarlet unesc | xmllint --format - | xmlstarlet fo -o)
echo -e "$patchedXml" > $1
rm -rf package/

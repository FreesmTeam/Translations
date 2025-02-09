#!/usr/bin/env bash

set -e
set -x

ROOT=$PWD
OUTPUT=$ROOT/build

LCONVERT_BIN=${LCONVERT_BIN:-lconvert}
LRELEASE_BIN=${LRELEASE_BIN:-lrelease}
LUPDATE_BIN=${LUPDATE_BIN:-lupdate}


if [ ! -d $OUTPUT ]
then
    mkdir $OUTPUT
fi

echo "Cleaning old .qm files..."
rm -f $OUTPUT/*

grep_count()
{
    local PIECE=`echo "$1" | grep -o "$2"`
    if [ -n "$PIECE" ]; then
        RETVAL=`echo $PIECE | sed 's/[a-z ]//g'`
        echo $RETVAL
        return
    fi
    echo 0
}

echo "{" >> $OUTPUT/index_v2.json
echo "    \"file_type\" : \"MMC-TRANSLATION-INDEX\"," >> $OUTPUT/index_v2.json
echo "    \"version\" : 2," >> $OUTPUT/index_v2.json
echo "    \"languages\" : {" >> $OUTPUT/index_v2.json

echo "Creating .qm files..."

FIRST=true

for ts_file in $(ls *.ts)
do
    echo "Considering ${ts_file}"

    lang="${ts_file%.ts}"

    po_file="${lang}.po"
    $LCONVERT_BIN -locations absolute "$ts_file" -o "$po_file"

    if cat "${po_file}" | grep '\"X-Qt-Contexts: true\\n\"' > /dev/null ; then
        echo "Translation ${po_file} is OK"
    else
        echo "Translation ${po_file} is bad (missing X-Qt-Contexts)"
        exit 1
    fi

    if [ "$lang" = "pt" ]; then
        lang="pt_PT"
    fi

    echo "    Create $lang.qm"
    $LRELEASE_BIN $ts_file -qm $OUTPUT/$lang.qm

    SHA1=`sha1sum $OUTPUT/$lang.qm | awk '{ print $1 }'`
    FILENAME="${SHA1}.class"
    cp "$OUTPUT/$lang.qm" "$OUTPUT/$FILENAME"

    # Create an index file with info about the amount of strings translated and expected hashes of the files (for local caching purposes)
    PO_STATS=`msgfmt --statistics --output=/dev/null ${po_file} 2>&1`
    UNTRANSLATED=$(grep_count "$PO_STATS" '[0-9]\+ untranslated messages\?')
    FUZZY=$(grep_count "$PO_STATS" '[0-9]\+ fuzzy translations\?')
    TRANSLATED=$(grep_count "$PO_STATS" '[0-9]\+ translated messages\?')

    FILESIZE=$(stat -c%s "$OUTPUT/$lang.qm")

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        # close previous scope
        echo "        }," >> $OUTPUT/index_v2.json
    fi
    echo "        \"$lang\" : {" >> $OUTPUT/index_v2.json
    echo "            \"file\" : \"$FILENAME\"," >> $OUTPUT/index_v2.json
    echo "            \"sha1\" : \"$SHA1\"," >> $OUTPUT/index_v2.json
    echo "            \"size\" : $FILESIZE," >> $OUTPUT/index_v2.json
    echo "            \"translated\" : $TRANSLATED," >> $OUTPUT/index_v2.json
    echo "            \"fuzzy\" : $FUZZY," >> $OUTPUT/index_v2.json
    echo "            \"untranslated\" : $UNTRANSLATED" >> $OUTPUT/index_v2.json
    # Create an index file with just the files (legacy)
    echo "$lang.qm" >> $OUTPUT/index
    rm "$po_file"
done
echo "        }" >> $OUTPUT/index_v2.json
echo "    }" >> $OUTPUT/index_v2.json
echo "}" >> $OUTPUT/index_v2.json

echo "All done!"

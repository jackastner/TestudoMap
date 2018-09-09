#! /bin/bash

if [ ! -f testudo_data.json ]; then
    if [! -f testudo_data.db ]; then
        ./testudo_query.sh
    fi
    ./make_geojson.sh
fi

scp testudo_data.json testudo_icon.svg webpage/testudo_map.html webpage/testudo_map.js kastner@linux.grace.umd.edu:/users/kastner/pub/

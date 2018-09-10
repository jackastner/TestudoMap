var mymap = L.map('mapid').setView([38.991538, -76.946769], 15);
var geojson;

/* Used to keep track of which feature are highlighted
 * and what type of event caused the highlight. This makes
 * it possible to toggle highlight with mouseout/over events
 * and click events.*/
var highlightedFeature = null;
var featureClicked = false;

L.tileLayer('https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiamFja2FzdG5lciIsImEiOiJjamx2bzhmc2YweTAxM2xxcGtqcHJtN3pkIn0.YKUh0QLQT_GHHVMdAyS-Mg',{
    attribution: 'Map data &copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors, <a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="https://www.mapbox.com/">Mapbox</a>',
    maxZoom: 20,
    id: 'mapbox.streets',
}).addTo(mymap);

requestData();

function requestData(){
    var xhr = new XMLHttpRequest();
    xhr.open("GET", "/~kastner/testudo_data.json", true);
    xhr.onload = function (e) {
        if (xhr.readyState === 4) {
            if (xhr.status === 200) {
                var data = JSON.parse(xhr.responseText);
                addGeoJson(data);
            } else {
                console.error(xhr.statusText);
            }
        }
    };
    xhr.send(null)
}

function addGeoJson(data){
    var turtleIcon = L.icon({
        iconUrl: '/~kastner/testudo_icon.svg',
        iconSize: [25, 25]
    });

    L.geoJSON(data.testudos, {
        onEachFeature: function (feature, layer) {
            layer.bindPopup(feature.properties.name);
        },
        pointToLayer: function(feature, latlng) {
            return L.marker(latlng, {icon: turtleIcon});
        }
    }).addTo(mymap);

    var featureIndex = 0;
    geojson = L.geoJSON(data.voronoi, {
        style: function (feature) {
            var colorCode = getColor(featureIndex, data.voronoi.length);
            var options = {
                fillColor: colorCode,
                color: colorCode,
                fillOpacity: 0.5,
                opacity: 1,
                weight: 1
            };
            featureIndex++;
            return options;
        },
        onEachFeature: function(feature, layer) {
            layer.on({
                click: toggleHighlight,
                mouseover: function (e) {
                    if(!featureClicked){
                        highlightFeature(e.target);
                    }
                },
                mouseout: function (e) {
                    if(!featureClicked) {
                        resetHighlight(e.target);
                    }
               }
            });
        }
    }).addTo(mymap);
}

function toggleHighlight(e) {
    if(featureClicked){
        resetHighlight(highlightedFeature);
    }

    if(highlightedFeature === e.target){
        highlightedFeature = null;
        featureClicked = false;
    } else {
        highlightFeature(e.target);
        highlightedFeature = e.target;
        featureClicked = true;
    }
}

function highlightFeature(layer) {
    layer.setStyle({
        weight: 4,
        color: 'black'
    });
    layer.bringToFront();
}

function resetHighlight(layer) {
    layer.setStyle({
        weight: 1,
        color: layer.options.fillColor
    });
}

function getColor(idx, numFeatures){
    var hue = 360*(idx / numFeatures);
    var colorCode = '#'+hue2rgb(hue).toString(16).padStart(6, 0);
    return colorCode;
}

//Adapted from https://stackoverflow.com/a/6930407/3179747
function hue2rgb(hue) {
    var sextant = hue / 60;
    var channel0 = Math.floor(255 * (sextant - Math.floor(sextant)));
    var channel1 = 255 - channel0;

    switch (Math.floor(sextant)) {
        case 0:
            return rgb2Int(255, channel0, 0);
        case 1:
            return rgb2Int(channel1, 255, 0);
        case 2:
            return rgb2Int(0, 255, channel0);
        case 3:
            return rgb2Int(0, channel1, 255);
        case 4:
            return rgb2Int(channel0, 0, 255);
        case 5:
        case 6:
            return rgb2Int(255, 0 , channel1);
    }
}

function rgb2Int(r, g, b) {
    return (r<<16) + (g<<8) + b;
}

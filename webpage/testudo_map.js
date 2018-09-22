var mymap = L.map('mapid');
var geojson;

/* Used to keep track of which feature are highlighted
 * and what type of event caused the highlight. This makes
 * it possible to toggle highlight with mouseout/over events
 * and click events.*/
var highlightedFeature = null;
var highlightedName = null;
var featureClicked = false;

var attribution;
if (window.innerWidth <= 800) {
    //mobile or other devices with small screens get shorter attribution text.
    attribution = '&copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> | ' +
                  '&copy; <a href="https://www.mapbox.com/">Mapbox</a> | ' + 
                  '&copy; <a href="https://www.creativetail.com/40-free-flat-animal-icons/">Creative Tail</a>';
} else {
    attribution = 'Map data &copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors, ' +
                  '<a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a> | ' +
                  'Imagery &copy; <a href="https://www.mapbox.com/">Mapbox</a> | ' + 
                  'Turtle Icon &copy; <a href="https://www.creativetail.com/40-free-flat-animal-icons/">Creative Tail</a>, ' + 
                  '<a href="https://creativecommons.org/licenses/by/4.0/">CC-BY-4.0</a>';
}

L.tileLayer('https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiamFja2FzdG5lciIsImEiOiJjamx2bzhmc2YweTAxM2xxcGtqcHJtN3pkIn0.YKUh0QLQT_GHHVMdAyS-Mg',{
    attribution: attribution,
    maxZoom: 20,
    id: 'mapbox.streets',
}).addTo(mymap);

requestData();

function addLegend(entries){
    var legend = L.control({position: 'bottomright'});
    var htmlEntries = [];

    legend.onAdd = function (map) {
        var div = L.DomUtil.create('div', 'legend');

        entries.forEach(function(e) {
            htmlEntries.push('<span id="' + e.name + '"><i style="background:' + e.color + '"></i>' + e.name + '</span>');
        });

        div.innerHTML = htmlEntries.join('<br>');

        return div;
    }
    legend.addTo(mymap);
}

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

    var entries = [];

    var featureIndex = 0;
    geojson = L.geoJSON(data.voronoi, {
        style: function (feature) {
            var colorCode = getColor(featureIndex, data.voronoi.length);

            entries.push({name: feature.properties.name, color: colorCode});

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
                click: function (e) {
                    toggleHighlight(e.target, feature.properties.name);
                },
                mouseover: function (e) {
                    if(!featureClicked){
                        highlightFeature(e.target, feature.properties.name);
                    }
                },
                mouseout: function (e) {
                    if(!featureClicked) {
                        resetHighlight(e.target, feature.properties.name);
                    }
               }
            });
        }
    }).addTo(mymap);

    addLegend(entries);
    setMapBounds(data.voronoi);
}

function setMapBounds(multiPolygons) {
    var dataPoints = [];
    //for each multi pollygon
    multiPolygons.forEach(function (multi) {
        //for polygon
        multi.geometry.coordinates.forEach(function (poly) {
            //for each ring
            poly.forEach(function (ring) {
                ring.forEach(function (point) {
                    dataPoints.push(L.latLng(point[1], point[0]));
                });
            });
        });
    });

    var dataBounds = L.latLngBounds(dataPoints);
    mymap.fitBounds(dataBounds);

    mymap.on('locationfound', function(e) {
        if(dataBounds.contains(e.latlng)){
            mymap.panTo(e.latlng);
            L.marker(e.latlng).addTo(mymap);
        }
    });

    mymap.locate({setView: false, maxZoom: 16});
}

function getLegendEntry(name){
    return document.getElementById(name);
}

function toggleHighlight(e, name) {
    if(featureClicked){
        resetHighlight(highlightedFeature, highlightedName);
    }

    if(highlightedFeature === e){
        highlightedFeature = null;
        selectedName = null;
        featureClicked = false;
    } else {
        highlightFeature(e, name);
        highlightedFeature = e;
        highlightedName = name;
        featureClicked = true;
    }
}

function highlightFeature(layer, name) {
    getLegendEntry(name).className = 'selected';
    layer.setStyle({
        weight: 4,
        color: 'black'
    });
    layer.bringToFront();
}

function resetHighlight(layer, name) {
    getLegendEntry(name).className = '';
    layer.setStyle({
        weight: 1,
        color: layer.options.fillColor
    });
}

function getColor(idx, numFeatures){
    var hue = 360*(idx / numFeatures);
    var colorHex = hue2rgb(hue).toString(16);
    return '#' + ('0'.repeat(6-colorHex.length)) + colorHex;
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

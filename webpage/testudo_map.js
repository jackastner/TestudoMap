var mymap = L.map('mapid').setView([38.991538, -76.946769], 15);

L.tileLayer('https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiamFja2FzdG5lciIsImEiOiJjamx2bzhmc2YweTAxM2xxcGtqcHJtN3pkIn0.YKUh0QLQT_GHHVMdAyS-Mg',{
    attribution: 'Map data &copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors, <a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="https://www.mapbox.com/">Mapbox</a>',
    maxZoom: 20,
    id: 'mapbox.streets',
}).addTo(mymap);

var xhr = new XMLHttpRequest();
xhr.open("GET", "/~kastner/testudo_data.json", true);
xhr.onload = function (e) {
    if (xhr.readyState === 4) {
        if (xhr.status === 200) {
            var data = JSON.parse(xhr.responseText);
            console.log(data.testudos);
            console.log(data.voronoi);


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
            L.geoJSON(data.voronoi, {
                style: function (feature) {
                    var hue = 360*(featureIndex / data.voronoi.length);
                    var colorCode = '#'+hue2rgb(hue).toString(16).padStart(6, 0);
                    var options = {
                        color: colorCode,
                        weight: 3,
                        opacity: 1
                    };
                    featureIndex++;
                    return options;
                }
            }).addTo(mymap);
        } else {
            console.error(xhr.statusText);
        }
    }
};
xhr.send(null)

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

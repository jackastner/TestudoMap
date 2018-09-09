var mymap = L.map('mapid').setView([38.991538, -76.946769], 15);

L.tileLayer('https://a.tile.openstreetmap.org/{z}/{x}/{y}.png ', {
    attribution: 'Map data &copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors, <a href="https://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="https://www.mapbox.com/">Mapbox</a>',
    maxZoom: 20,
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

            L.geoJSON(data.voronoi, {
                style: function (feature) {
                    return {
                        color: '#'+Math.floor(Math.random() * 0xffffff).toString(16),
                        weight: 3,
                        opacity:1
                    };
                }
            }).addTo(mymap);
        } else {
            console.error(xhr.statusText);
        }
    }
};
xhr.send(null)

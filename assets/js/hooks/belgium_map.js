// Leaflet OpenStreetMap hook for Belgium network visualization
// CSS loaded via CDN in root.html.heex
import L from "leaflet";

// Fix Leaflet default icon paths when using bundlers
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

const BelgiumMap = {
  mounted() {
    // Belgium center coordinates
    const belgiumCenter = [50.5, 4.5];
    const defaultZoom = 8;

    // Initialize map
    this.map = L.map(this.el, {
      center: belgiumCenter,
      zoom: defaultZoom,
      zoomControl: true,
    });

    // Add dark-themed tile layer (CartoDB Dark Matter)
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
      subdomains: 'abcd',
      maxZoom: 19
    }).addTo(this.map);

    // Layer groups for different marker types
    this.srpLayer = L.layerGroup().addTo(this.map);
    this.homeLayer = L.layerGroup().addTo(this.map);

    // Region colors - use string keys to match Elixir data
    this.colors = {
      "flanders": { srp: '#22d3ee', home: '#67e8f9' },
      "brussels": { srp: '#fbbf24', home: '#fcd34d' },
      "wallonia": { srp: '#a855f7', home: '#c084fc' }
    };

    // Track update count for debugging
    this.updateCount = 0;

    // Load initial markers
    const initialData = this.el.dataset.initialMarkers;
    if (initialData) {
      try {
        const markers = JSON.parse(initialData);
        if (markers.length > 0) {
          this.updateMarkers(markers);
        }
      } catch (e) {
        console.error("Failed to parse initial markers:", e);
      }
    }

    // Listen for marker updates from LiveView
    this.handleEvent("update-markers", ({ markers }) => {
      this.updateCount++;
      this.updateMarkers(markers);
    });

    // Add Belgium region boundaries (approximate)
    this.addRegionBoundaries();
  },

  updateMarkers(markers) {
    if (!markers || markers.length === 0) return;

    // Clear existing markers
    this.srpLayer.clearLayers();
    this.homeLayer.clearLayers();

    // Add markers efficiently
    markers.forEach(m => {
      const color = this.colors[m.region] || { srp: '#94a3b8', home: '#e2e8f0' };

      if (m.type === 'srp') {
        const marker = L.circleMarker([m.lat, m.lng], {
          radius: 8,
          fillColor: color.srp,
          color: '#ffffff',
          weight: 2,
          opacity: 1,
          fillOpacity: 0.9
        });
        marker.bindPopup(`<b>SRP Node</b><br>Region: ${m.region}<br>Lat: ${m.lat}<br>Lng: ${m.lng}`);
        this.srpLayer.addLayer(marker);
      } else {
        const marker = L.circleMarker([m.lat, m.lng], {
          radius: 3,
          fillColor: color.home,
          color: color.home,
          weight: 0,
          opacity: 0.8,
          fillOpacity: 0.6
        });
        this.homeLayer.addLayer(marker);
      }
    });
  },

  addRegionBoundaries() {
    // Simplified region boundaries for Belgium
    const flandersCoords = [
      [51.09, 2.55], [51.37, 3.37], [51.41, 3.83], [51.38, 4.24],
      [51.43, 4.84], [51.48, 5.03], [51.30, 5.25], [51.06, 5.74],
      [50.76, 5.87], [50.76, 5.40], [50.75, 5.05], [50.77, 4.85],
      [50.78, 4.45], [50.78, 4.25], [50.77, 4.00], [50.73, 3.60],
      [50.73, 3.27], [50.77, 3.02], [50.73, 2.87], [50.85, 2.64],
      [51.09, 2.55]
    ];

    const brusselsCoords = [
      [50.80, 4.28], [50.82, 4.31], [50.85, 4.34], [50.87, 4.37],
      [50.89, 4.40], [50.91, 4.43], [50.91, 4.45], [50.90, 4.44],
      [50.88, 4.42], [50.86, 4.40], [50.84, 4.37], [50.82, 4.34],
      [50.80, 4.31], [50.80, 4.28]
    ];

    // Add subtle region outlines
    L.polyline(flandersCoords, {
      color: '#22d3ee',
      weight: 2,
      opacity: 0.4,
      dashArray: '5, 5'
    }).addTo(this.map);

    L.polyline(brusselsCoords, {
      color: '#fbbf24',
      weight: 2,
      opacity: 0.6
    }).addTo(this.map);
  },

  destroyed() {
    if (this.map) {
      this.map.remove();
    }
  }
};

export default BelgiumMap;

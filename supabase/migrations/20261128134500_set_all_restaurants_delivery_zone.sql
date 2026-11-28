-- Update delivery_zones for all restaurants with the official regional delivery zone GeoJSON polygon
UPDATE public.restaurants
SET delivery_zones = '{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {},
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [5.7078091, 34.8884997],
            [5.6777273, 34.8736562],
            [5.6612162, 34.8346793],
            [5.6431219, 34.8133269],
            [5.684965, 34.7834243],
            [5.7176067, 34.7288234],
            [5.6886011, 34.7125621],
            [5.6654382, 34.6838993],
            [5.7009411, 34.6596259],
            [5.7208995, 34.6845198],
            [5.7489672, 34.7085413],
            [5.7619327, 34.7585602],
            [5.8395217, 34.8465063],
            [5.8046542, 34.895061],
            [5.7464116, 34.9138794],
            [5.7078091, 34.8884997]
          ]
        ]
      }
    }
  ]
}'::jsonb
WHERE id IS NOT NULL;

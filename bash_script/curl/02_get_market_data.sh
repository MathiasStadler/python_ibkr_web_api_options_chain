# 2. Hole Market Data für eine spezifische Contract ID
# Ersetze 265598 mit der tatsächlichen conid aus Schritt 1
curl -k -X GET "https://localhost:5000/v1/api/iserver/marketdata/snapshot" \
  -H "accept: application/json" \
  -G \
  --data-urlencode "conids=265598" \
  --data-urlencode "fields=31,55,84,86,85,7294,7295,7296"

# Wichtig: Beachten Sie den Parameter conids (plural) im zweiten Befehl.
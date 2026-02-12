# 2. Hole Market Data für eine spezifische Contract ID
# Ersetze 265598 mit der tatsächlichen conid aus Schritt 1

# fields => https://www.interactivebrokers.com/campus/ibkr-api-page/cpapi-v1/#market-data-fields
curl -k -X GET "https://localhost:5000/v1/api/iserver/marketdata/snapshot" \
  -H "accept: application/json" \
  -G \
  -H "Cache-Control: no-cache, no-store" \
  --data-urlencode "conids=265598" \
  --data-urlencode "fields=7283,55,31,55,84,86,85,73,7294,7295,7085,7296,7293" | jq .

# Wichtig: Beachten Sie den Parameter conids (plural) im zweiten Befehl.
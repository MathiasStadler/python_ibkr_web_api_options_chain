# 1. Suche nach Optionen für ein Underlying (z.B. AAPL)
curl -k -s "https://localhost:5000/v1/api/iserver/secdef/search" \
  -H "accept: application/json" \
  -G \
  --data-urlencode "symbol=TREX" \
  --data-urlencode "secType=OPT" \
  --data-urlencode "exchange=SMART"
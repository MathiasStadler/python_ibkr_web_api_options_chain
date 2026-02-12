# Option Chain direkt abrufen (wenn verfügbar)
# Call C
curl -k -X GET "https://localhost:5000/v1/api/iserver/secdef/info" \
  -H "accept: application/json" \
  -G \
  --data-urlencode "conid=265598" \
  --data-urlencode "sectype=OPT" \
  --data-urlencode "month=JAN" \
  --data-urlencode "strike=200" \
  --data-urlencode "right=C"
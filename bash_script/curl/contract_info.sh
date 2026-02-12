#!/bin/bash

TICKER=${1:-AAPL}
PORT=${2:-5000}

echo "Getting contract info for $TICKER on port $PORT..."

# First get the stock CONID
echo -e "\n1. Getting stock CONID for $TICKER..."
CONID=$(curl -k -s "https://localhost:$PORT/v1/api/trsrv/stocks?symbols=$TICKER" | jq -r ".$TICKER[].conid" | head -1)

if [ -n "$CONID" ] && [ "$CONID" != "null" ]; then
    echo "Found CONID: $CONID"
    
    # Try to get option chain
    echo -e "\n2. Trying to get option chain..."
    curl -k -s "https://localhost:$PORT/v1/api/iserver/secdef/info?conid=$CONID&sectype=OPT" | jq .
else
    echo "Could not find CONID for $TICKER"
fi

# curl -k "https://localhost:5000/v1/api/tickle"
# 
# Try the trsrv endpoint (often works)
curl -k "https://localhost:5000/v1/api/trsrv/stocks?symbols=AAPL"



# curl -k -s "https://localhost:$PORT/v1/api/iserver/secdef/info?conid=$CONID&sectype=OPT" | jq .
#{
#  "error": "Bad Request: month required",
#  "statusCode": 400
#}
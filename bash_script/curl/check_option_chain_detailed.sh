#!/bin/bash

# IBKR Option Chain Tester
# Testet alle CONIDs bis mindestens 10 valide Optionen gefunden sind

set -e  # Beende bei Fehlern

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funktionen
print_header() {
    echo -e "\n${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  IBKR Option Chain Tester${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_debug() {
    echo -e "${CYAN}🔍 $1${NC}"
}

print_result() {
    echo -e "${PURPLE}📊 $1${NC}"
}

# Konfiguration
DEFAULT_TICKER="AAPL"
DEFAULT_PORT=5000
DEFAULT_EXCHANGE="SMART"
DEFAULT_CURRENCY="USD"
MIN_VALID_OPTIONS=10
MAX_TESTS=100  # Maximale Anzahl zu testender CONIDs
BATCH_SIZE=5   # Anzahl CONIDs pro Request

# Parameter verarbeiten
TICKER="${1:-$DEFAULT_TICKER}"
PORT="${2:-$DEFAULT_PORT}"
EXCHANGE="${3:-$DEFAULT_EXCHANGE}"
CURRENCY="${4:-$DEFAULT_CURRENCY}"

BASE_URL="https://localhost:${PORT}/v1/api"
SEARCH_URL="${BASE_URL}/iserver/secdef/search"
MARKET_DATA_URL="${BASE_URL}/iserver/marketdata/snapshot"

# Statistik Variablen
declare -i TOTAL_TESTS=0
declare -i VALID_OPTIONS=0
declare -i INVALID_OPTIONS=0
declare -i MARKET_DATA_SUCCESS=0
declare -i MARKET_DATA_FAILED=0
declare -a VALID_CONIDS=()
declare -a INVALID_CONIDS=()

print_header
echo -e "${CYAN}Konfiguration:${NC}"
echo -e "  Ticker:           ${GREEN}${TICKER}${NC}"
echo -e "  Port:             ${GREEN}${PORT}${NC}"
echo -e "  Exchange:         ${GREEN}${EXCHANGE}${NC}"
echo -e "  Currency:         ${GREEN}${CURRENCY}${NC}"
echo -e "  Min. valide Opt.: ${GREEN}${MIN_VALID_OPTIONS}${NC}"
echo -e "  Max. Tests:       ${GREEN}${MAX_TESTS}${NC}"
echo -e "  Batch Size:       ${GREEN}${BATCH_SIZE}${NC}"

# 1. Gateway-Verfügbarkeit prüfen
print_info "Prüfe Gateway-Verfügbarkeit..."
if ! curl -k -s -o /dev/null -w "%{http_code}" "${BASE_URL}/tickle" 2>/dev/null | grep -q "200"; then
    print_error "Gateway nicht erreichbar"
    exit 1
fi
print_success "Gateway erreichbar"

# 2. Optionskette abrufen
print_info "Rufe alle Optionen für ${TICKER} ab..."
RESPONSE=$(curl -k -s -w "\nHTTP_STATUS:%{http_code}" \
    -G "${SEARCH_URL}" \
    --data-urlencode "symbol=${TICKER}" \
    --data-urlencode "secType=OPT" \
    --data-urlencode "exchange=${EXCHANGE}" \
    --data-urlencode "currency=${CURRENCY}")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" != "200" ]; then
    print_error "Fehler beim Abrufen der Optionskette: HTTP $HTTP_STATUS"
    exit 1
fi

# 3. Alle CONIDs extrahieren
CONIDS=$(echo "$RESPONSE_BODY" | jq -r '.[].conid' 2>/dev/null)
TOTAL_CONIDS=$(echo "$CONIDS" | wc -w)

if [ "$TOTAL_CONIDS" -eq 0 ]; then
    print_error "Keine CONIDs gefunden"
    exit 1
fi

print_success "Gefundene CONIDs: $TOTAL_CONIDS"
print_info "Teste CONIDs auf Gültigkeit (bis $MIN_VALID_OPTIONS valide Optionen gefunden)...\n"

# 4. CONIDs in Batches testen
CONID_ARRAY=($CONIDS)
CONID_COUNT=${#CONID_ARRAY[@]}
TEST_LIMIT=$((CONID_COUNT < MAX_TESTS ? CONID_COUNT : MAX_TESTS))

echo -e "${YELLOW}Fortschritt:${NC}"
for ((i=0; i<TEST_LIMIT; i+=BATCH_SIZE)); do
    # Batch erstellen
    BATCH_CONIDS=""
    BATCH_COUNT=0
    
    for ((j=0; j<BATCH_SIZE && (i+j) < TEST_LIMIT; j++)); do
        CONID="${CONID_ARRAY[$((i+j))]}"
        if [ -n "$CONID" ] && [ "$CONID" != "null" ]; then
            BATCH_CONIDS="${BATCH_CONIDS}${CONID},"
            BATCH_COUNT=$((BATCH_COUNT + 1))
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
        fi
    done
    
    # Komma am Ende entfernen
    BATCH_CONIDS="${BATCH_CONIDS%,}"
    
    if [ -z "$BATCH_CONIDS" ]; then
        continue
    fi
    
    # Progress-Bar
    PERCENTAGE=$(( (i * 100) / TEST_LIMIT ))
    BAR_WIDTH=50
    FILLED=$(( (PERCENTAGE * BAR_WIDTH) / 100 ))
    EMPTY=$((BAR_WIDTH - FILLED))
    
    printf "\r["
    printf "%${FILLED}s" | tr ' ' '='
    printf "%${EMPTY}s" | tr ' ' ' '
    printf "] %3d%% (%d/%d CONIDs getestet)" $PERCENTAGE $TOTAL_TESTS $TEST_LIMIT
    
    # Market Data für Batch abrufen
    MARKET_RESPONSE=$(curl -k -s -w "\nHTTP_STATUS:%{http_code}" \
        "${MARKET_DATA_URL}?conids=${BATCH_CONIDS}&fields=31,55,84,86,85,7294,7295,7296")
    
    MARKET_HTTP_STATUS=$(echo "$MARKET_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
    MARKET_BODY=$(echo "$MARKET_RESPONSE" | sed '/HTTP_STATUS:/d')
    
    if [ "$MARKET_HTTP_STATUS" = "200" ]; then
        # Jede CONID im Batch auswerten
        IFS=',' read -ra BATCH_ARR <<< "$BATCH_CONIDS"
        for CONID in "${BATCH_ARR[@]}"; do
            # Extrahiere Daten für diese CONID
            CONID_DATA=$(echo "$MARKET_BODY" | jq -r ".[] | select(.conid == $CONID)" 2>/dev/null)
            
            if [ -n "$CONID_DATA" ] && [ "$CONID_DATA" != "null" ]; then
                # Prüfe ob valide Daten vorhanden sind
                BID=$(echo "$CONID_DATA" | jq -r '."31"' 2>/dev/null)
                ASK=$(echo "$CONID_DATA" | jq -r '."55"' 2>/dev/null)
                LAST=$(echo "$CONID_DATA" | jq -r '."84"' 2>/dev/null)
                VOLUME=$(echo "$CONID_DATA" | jq -r '."86"' 2>/dev/null)
                OI=$(echo "$CONID_DATA" | jq -r '."85"' 2>/dev/null)
                IV=$(echo "$CONID_DATA" | jq -r '."7294"' 2>/dev/null)
                
                # Validierungskriterien
                HAS_BID_ASK=false
                HAS_VOLUME=false
                HAS_OI=false
                
                if [[ "$BID" =~ ^[0-9.]+$ ]] && [[ "$ASK" =~ ^[0-9.]+$ ]]; then
                    HAS_BID_ASK=true
                fi
                
                if [[ "$VOLUME" =~ ^[0-9.]+$ ]] && [ "${VOLUME%.*}" -ge 0 ]; then
                    HAS_VOLUME=true
                fi
                
                if [[ "$OI" =~ ^[0-9.]+$ ]] && [ "${OI%.*}" -ge 0 ]; then
                    HAS_OI=true
                fi
                
                # Option als valide betrachten wenn mindestens Bid/Ask vorhanden
                if [ "$HAS_BID_ASK" = true ]; then
                    VALID_OPTIONS=$((VALID_OPTIONS + 1))
                    MARKET_DATA_SUCCESS=$((MARKET_DATA_SUCCESS + 1))
                    VALID_CONIDS+=("$CONID")
                    
                    # Speichere Details für spätere Ausgabe
                    DESCRIPTION=$(echo "$RESPONSE_BODY" | jq -r ".[] | select(.conid == $CONID) | .description" 2>/dev/null || echo "Unbekannt")
                    
                    # Ausgabe bei den ersten 5 validen Optionen
                    if [ ${#VALID_CONIDS[@]} -le 5 ]; then
                        echo -e "\n${GREEN}  ✓ Valide Option gefunden:${NC}"
                        echo -e "    CONID: $CONID"
                        echo -e "    Beschreibung: $DESCRIPTION"
                        echo -e "    Bid/Ask: $BID / $ASK"
                        if [ "$HAS_VOLUME" = true ]; then
                            echo -e "    Volume: $VOLUME"
                        fi
                        if [ "$HAS_OI" = true ]; then
                            echo -e "    Open Interest: $OI"
                        fi
                    fi
                else
                    INVALID_OPTIONS=$((INVALID_OPTIONS + 1))
                    MARKET_DATA_FAILED=$((MARKET_DATA_FAILED + 1))
                    INVALID_CONIDS+=("$CONID")
                fi
            else
                INVALID_OPTIONS=$((INVALID_OPTIONS + 1))
                INVALID_CONIDS+=("$CONID")
            fi
            
            # Abbruch wenn genug valide Optionen gefunden
            if [ $VALID_OPTIONS -ge $MIN_VALID_OPTIONS ]; then
                break 2
            fi
        done
    else
        # Markiere alle CONIDs in diesem Batch als ungültig
        for CONID in "${BATCH_ARR[@]}"; do
            INVALID_OPTIONS=$((INVALID_OPTIONS + 1))
            INVALID_CONIDS+=("$CONID")
        done
        MARKET_DATA_FAILED=$((MARKET_DATA_FAILED + BATCH_COUNT))
    fi
    
    # Kurze Pause um den Server nicht zu überlasten
    sleep 0.1
    
    # Abbruch wenn genug valide Optionen gefunden
    if [ $VALID_OPTIONS -ge $MIN_VALID_OPTIONS ]; then
        break
    fi
done

echo -e "\n\n${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}TEST ABGESCHLOSSEN${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"

# 5. Detaillierte Ergebnisse
print_result "ZUSAMMENFASSUNG"
echo -e "  Getestete CONIDs:        ${TOTAL_TESTS}"
echo -e "  Valide Optionen:         ${GREEN}${VALID_OPTIONS}${NC}"
echo -e "  Ungültige Optionen:      ${RED}${INVALID_OPTIONS}${NC}"
echo -e "  Erfolgsrate:             $(( (VALID_OPTIONS * 100) / TOTAL_TESTS ))%"

print_result "MARKET DATA STATISTIK"
echo -e "  Erfolgreiche Abrufe:     ${GREEN}${MARKET_DATA_SUCCESS}${NC}"
echo -e "  Fehlgeschlagene Abrufe:  ${RED}${MARKET_DATA_FAILED}${NC}"

if [ ${#VALID_CONIDS[@]} -gt 0 ]; then
    print_result "VALIDE CONIDs (${#VALID_CONIDS[@]})"
    echo -e "${CYAN}  ┌────────────────────────────────────────────────────────────┐${NC}"
    
    # Zeige Details für jede valide CONID
    for ((idx=0; idx<${#VALID_CONIDS[@]}; idx++)); do
        CONID="${VALID_CONIDS[$idx]}"
        
        # Hole Beschreibung
        DESCRIPTION=$(echo "$RESPONSE_BODY" | jq -r ".[] | select(.conid == $CONID) | .description" 2>/dev/null || echo "Keine Beschreibung")
        
        # Hole Market Data Details
        MARKET_DETAILS=$(curl -k -s "${MARKET_DATA_URL}?conids=${CONID}&fields=31,55,84,86,85,7294")
        BID=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"31\"" 2>/dev/null || echo "N/A")
        ASK=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"55\"" 2>/dev/null || echo "N/A")
        LAST=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"84\"" 2>/dev/null || echo "N/A")
        VOLUME=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"86\"" 2>/dev/null || echo "N/A")
        OI=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"85\"" 2>/dev/null || echo "N/A")
        IV=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"7294\"" 2>/dev/null || echo "N/A")
        
        # Berechne Spread
        if [[ "$BID" =~ ^[0-9.]+$ ]] && [[ "$ASK" =~ ^[0-9.]+$ ]]; then
            SPREAD=$(echo "$ASK - $BID" | bc 2>/dev/null || echo "N/A")
        else
            SPREAD="N/A"
        fi
        
        # Formatierte Ausgabe
        printf "${CYAN}  │ %-3d. %-10s │ %-25s │${NC}\n" $((idx+1)) "$CONID" "$DESCRIPTION"
        printf "${CYAN}  │     Bid: %-6s Ask: %-6s Spread: %-6s │${NC}\n" "$BID" "$ASK" "$SPREAD"
        
        if [ $idx -lt $((${#VALID_CONIDS[@]} - 1)) ]; then
            echo -e "${CYAN}  ├────────────────────────────────────────────────────────────┤${NC}"
        fi
    done
    
    echo -e "${CYAN}  └────────────────────────────────────────────────────────────┘${NC}"
fi

# 6. Optionstypen Analyse
if [ ${#VALID_CONIDS[@]} -gt 0 ]; then
    print_result "OPTIONSTYPEN ANALYSE"
    
    CALL_COUNT=0
    PUT_COUNT=0
    UNKNOWN_COUNT=0
    
    for CONID in "${VALID_CONIDS[@]}"; do
        DESCRIPTION=$(echo "$RESPONSE_BODY" | jq -r ".[] | select(.conid == $CONID) | .description" 2>/dev/null || echo "")
        
        if [[ "$DESCRIPTION" == *" C"* ]] || [[ "$DESCRIPTION" == *" CALL"* ]]; then
            CALL_COUNT=$((CALL_COUNT + 1))
        elif [[ "$DESCRIPTION" == *" P"* ]] || [[ "$DESCRIPTION" == *" PUT"* ]]; then
            PUT_COUNT=$((PUT_COUNT + 1))
        else
            UNKNOWN_COUNT=$((UNKNOWN_COUNT + 1))
        fi
    done
    
    echo -e "  Call Optionen:  ${GREEN}${CALL_COUNT}${NC}"
    echo -e "  Put Optionen:   ${RED}${PUT_COUNT}${NC}"
    echo -e "  Unbekannt:      ${YELLOW}${UNKNOWN_COUNT}${NC}"
    
    # Expiration Dates extrahieren
    EXPIRATIONS=$(echo "$RESPONSE_BODY" | jq -r ".[] | select(.conid | IN($(echo "${VALID_CONIDS[@]}" | tr ' ' ','))) | .description" 2>/dev/null | \
        grep -oE "[0-9]{2}[A-Z]{3}[0-9]{2}|[0-9]{4}-[0-9]{2}-[0-9]{2}" | sort | uniq | head -5)
    
    if [ -n "$EXPIRATIONS" ]; then
        echo -e "  Expirations (erste 5):"
        while read -r exp; do
            echo -e "    - $exp"
        done <<< "$EXPIRATIONS"
    fi
fi

# 7. Performance-Metriken
print_result "PERFORMANCE METRIKEN"
echo -e "  Getestete CONIDs/Minute: $(( (TOTAL_TESTS * 60) / (SECONDS + 1) ))"
echo -e "  Valide Optionen/Minute:  $(( (VALID_OPTIONS * 60) / (SECONDS + 1) ))"

# 8. Export der Ergebnisse
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="option_validation_report_${TICKER}_${TIMESTAMP}.txt"
JSON_FILE="valid_options_${TICKER}_${TIMESTAMP}.json"

# Text Report
{
    echo "IBKR Option Validation Report"
    echo "============================="
    echo "Ticker: $TICKER"
    echo "Datum: $(date)"
    echo "Testdauer: ${SECONDS} Sekunden"
    echo ""
    echo "Zusammenfassung:"
    echo "  Getestete CONIDs: $TOTAL_TESTS"
    echo "  Valide Optionen: $VALID_OPTIONS"
    echo "  Ungültige Optionen: $INVALID_OPTIONS"
    echo "  Erfolgsrate: $(( (VALID_OPTIONS * 100) / TOTAL_TESTS ))%"
    echo ""
    echo "Valide CONIDs:"
    for CONID in "${VALID_CONIDS[@]}"; do
        echo "  - $CONID"
    done
} > "$REPORT_FILE"

# JSON Export
{
    echo "["
    for ((idx=0; idx<${#VALID_CONIDS[@]}; idx++)); do
        CONID="${VALID_CONIDS[$idx]}"
        DESCRIPTION=$(echo "$RESPONSE_BODY" | jq -r ".[] | select(.conid == $CONID) | .description" 2>/dev/null || echo "Unknown")
        
        MARKET_DETAILS=$(curl -k -s "${MARKET_DATA_URL}?conids=${CONID}&fields=31,55,84,86,85,7294")
        BID=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"31\"" 2>/dev/null)
        ASK=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"55\"" 2>/dev/null)
        LAST=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"84\"" 2>/dev/null)
        VOLUME=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"86\"" 2>/dev/null)
        OI=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"85\"" 2>/dev/null)
        IV=$(echo "$MARKET_DETAILS" | jq -r ".[0].\"7294\"" 2>/dev/null)
        
        echo "  {"
        echo "    \"conid\": \"$CONID\","
        echo "    \"description\": \"$DESCRIPTION\","
        echo "    \"bid\": \"$BID\","
        echo "    \"ask\": \"$ASK\","
        echo "    \"last\": \"$LAST\","
        echo "    \"volume\": \"$VOLUME\","
        echo "    \"open_interest\": \"$OI\","
        echo "    \"implied_volatility\": \"$IV\""
        if [ $idx -lt $((${#VALID_CONIDS[@]} - 1)) ]; then
            echo "  },"
        else
            echo "  }"
        fi
    done
    echo "]"
} > "$JSON_FILE" 2>/dev/null

print_success "Report gespeichert in: $REPORT_FILE"
print_success "JSON Daten gespeichert in: $JSON_FILE"

# 9. Finale Bewertung
echo -e "\n${BLUE}══════════════════════════════════════════════════════════════${NC}"
if [ $VALID_OPTIONS -ge $MIN_VALID_OPTIONS ]; then
    echo -e "${GREEN}✅ ERFOLG: ${VALID_OPTIONS} valide Optionen gefunden (≥ ${MIN_VALID_OPTIONS})${NC}"
    echo -e "${GREEN}   Option Chain URL ist voll funktionsfähig!${NC}"
    exit 0
else
    echo -e "${RED}❌ NICHT ERREICHT: Nur ${VALID_OPTIONS} valide Optionen gefunden (Ziel: ${MIN_VALID_OPTIONS})${NC}"
    
    if [ $VALID_OPTIONS -gt 0 ]; then
        echo -e "${YELLOW}⚠  Teilweise funktionsfähig - mögliche Ursachen:${NC}"
        echo "   - Viele Optionen haben keine Market Data (außerhalb der Handelszeiten)"
        echo "   - Delayed Data für bestimmte Optionen"
        echo "   - API-Beschränkungen"
    else
        echo -e "${RED}⚠  Kritischer Fehler - mögliche Ursachen:${NC}"
        echo "   - Gateway nicht korrekt konfiguriert"
        echo "   - Keine Market Data Berechtigungen"
        echo "   - Falsche API Endpoints"
    fi
    exit 1
fi
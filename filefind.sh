#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DOMAIN="$1"
EXT="$2"
THREADS=20           # requisicoes paralelas na validacao
TIMEOUT=8            # timeout por requisicao (segundos)
WAYBACK_LIMIT=50000  # maximo de URLs do Wayback

if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Uso: $0 <dominio> [extensao]${NC}"
    echo -e "Exemplo: $0 vivo.com.br php"
    exit 1
fi

MISSING=()
for cmd in curl jq xargs; do
    command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo -e "${RED}[ERRO] Dependencias faltando: ${MISSING[*]}${NC}"
    echo -e "Instale com: sudo apt install ${MISSING[*]}  (ou brew install no Mac)"
    exit 1
fi

OUTPUT_DIR="./filefind_results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SAFE_DOMAIN="${DOMAIN//\//_}"
OUTPUT_FILE="${OUTPUT_DIR}/${SAFE_DOMAIN}_${TIMESTAMP}.txt"
TMP_RAW=$(mktemp /tmp/filefind_raw_XXXXXX.txt)
TMP_FILTERED=$(mktemp /tmp/filefind_filtered_XXXXXX.txt)
TMP_VALID=$(mktemp /tmp/filefind_valid_XXXXXX.txt)

mkdir -p "$OUTPUT_DIR"
trap 'rm -f "$TMP_RAW" "$TMP_FILTERED" "$TMP_VALID" "${TMP_FILTERED}.all"' EXIT

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║          filefind.sh  v2.0               ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Dominio :${NC} $DOMAIN"
echo -e "  ${BOLD}Extensao:${NC} ${EXT:-todas}"
echo -e "  ${BOLD}Threads :${NC} $THREADS"
echo -e "  ${BOLD}Saida   :${NC} $OUTPUT_FILE"
echo ""

echo -e "${BOLD}[1/3] Coletando URLs de fontes publicas...${NC}"

echo -ne "  ${CYAN}-> Wayback Machine...${NC}  "
WB_COUNT=0
WB_RESP=$(curl -sf --max-time 20 \
    "http://web.archive.org/cdx/search/cdx?url=${DOMAIN}/*&output=text&fl=original&collapse=urlkey&limit=${WAYBACK_LIMIT}" \
    2>/dev/null)
if [[ -n "$WB_RESP" ]]; then
    echo "$WB_RESP" >> "$TMP_RAW"
    WB_COUNT=$(echo "$WB_RESP" | wc -l | tr -d ' ')
fi
echo -e "${GREEN}${WB_COUNT} URLs${NC}"

echo -ne "  ${CYAN}-> AlienVault OTX...${NC}   "
OTX_COUNT=0
OTX_RESP=$(curl -sf --max-time 20 \
    "https://otx.alienvault.com/api/v1/indicators/domain/${DOMAIN}/url_list?limit=500&page=1" \
    2>/dev/null)
if [[ -n "$OTX_RESP" ]]; then
    OTX_URLS=$(echo "$OTX_RESP" | jq -r '.url_list[].url' 2>/dev/null)
    if [[ -n "$OTX_URLS" ]]; then
        echo "$OTX_URLS" >> "$TMP_RAW"
        OTX_COUNT=$(echo "$OTX_URLS" | wc -l | tr -d ' ')
    fi
fi
echo -e "${GREEN}${OTX_COUNT} URLs${NC}"

echo -ne "  ${CYAN}-> URLScan.io...${NC}       "
US_COUNT=0
US_RESP=$(curl -sf --max-time 20 \
    "https://urlscan.io/api/v1/search/?q=domain:${DOMAIN}&size=1000" \
    2>/dev/null)
if [[ -n "$US_RESP" ]]; then
    US_URLS=$(echo "$US_RESP" | jq -r '.results[].page.url' 2>/dev/null)
    if [[ -n "$US_URLS" ]]; then
        echo "$US_URLS" >> "$TMP_RAW"
        US_COUNT=$(echo "$US_URLS" | wc -l | tr -d ' ')
    fi
fi
echo -e "${GREEN}${US_COUNT} URLs${NC}"

echo ""
echo -e "${BOLD}[2/3] Filtrando e deduplicando...${NC}"

sort -u "$TMP_RAW" | grep -iE "^https?://" | grep -iF "$DOMAIN" > "${TMP_FILTERED}.all"

if [[ -n "$EXT" ]]; then
    grep -iP "\.${EXT}(\?[^\s]*)?$" "${TMP_FILTERED}.all" > "$TMP_FILTERED"
else
    grep -iP "/[^/?]+\.[a-zA-Z0-9]{1,6}(\?[^\s]*)?$" "${TMP_FILTERED}.all" > "$TMP_FILTERED"
fi

TOTAL_FOUND=$(wc -l < "$TMP_FILTERED" | tr -d ' ')
echo -e "  URLs para validar: ${BOLD}${TOTAL_FOUND}${NC}"

if [[ "$TOTAL_FOUND" -eq 0 ]]; then
    echo -e "\n${YELLOW}[!] Nenhuma URL encontrada para validar.${NC}"
    exit 0
fi

echo ""
echo -e "${BOLD}[3/3] Validando arquivos (${THREADS} threads)...${NC}"
echo ""

validate_url() {
    local url="$1"
    local timeout="$2"
    local out="$3"
    local GREEN='\033[0;32m'
    local NC='\033[0m'

    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
        --max-time "$timeout" \
        --connect-timeout 5 \
        -L \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        -X HEAD \
        "$url" 2>/dev/null)

    if [[ "$HTTP_CODE" == "000" || "$HTTP_CODE" == "405" ]]; then
        HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
            --max-time "$timeout" \
            --connect-timeout 5 \
            -L \
            -r 0-0 \
            -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
            "$url" 2>/dev/null)
    fi

    if [[ "$HTTP_CODE" =~ ^(200|206|301|302|307|308)$ ]]; then
        echo "$HTTP_CODE $url" >> "$out"
        echo -e "  ${GREEN}[${HTTP_CODE}]${NC} $url"
    fi
}
export -f validate_url

cat "$TMP_FILTERED" | xargs -P "$THREADS" -I{} bash -c \
    'validate_url "$@"' _ {} "$TIMEOUT" "$TMP_VALID"

VALID=$(wc -l < "$TMP_VALID" | tr -d ' ')

echo ""
echo -e "${CYAN}${BOLD}============================================${NC}"
echo -e "  Checados  : ${TOTAL_FOUND}"
echo -e "  ${GREEN}${BOLD}Validos   : ${VALID}${NC}"
echo -e "${CYAN}${BOLD}============================================${NC}"

{
    echo "# filefind.sh - Resultado"
    echo "# Dominio  : $DOMAIN"
    echo "# Extensao : ${EXT:-todas}"
    echo "# Data     : $(date)"
    echo "# Checados : $TOTAL_FOUND"
    echo "# Validos  : $VALID"
    echo ""
    echo "# STATUS | URL"
    sort "$TMP_VALID"
} > "$OUTPUT_FILE"

echo -e "\n  ${BOLD}Salvo em:${NC} $OUTPUT_FILE\n"

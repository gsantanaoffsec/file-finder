# filefind.sh

Script bash para reconhecimento **passivo** de arquivos em domínios web. Consulta fontes públicas de inteligência (Wayback Machine, AlienVault OTX, URLScan.io) para descobrir URLs que já existiram ou foram indexadas no domínio alvo — sem fazer nenhuma requisição direta ao site. Depois valida cada URL encontrada em paralelo para confirmar se ainda está acessível.

## Dependências

```bash
# Debian/Ubuntu/Kali
sudo apt install curl jq

# macOS
brew install curl jq
```

## Uso

```bash
chmod +x filefind.sh

./filefind.sh <dominio> [extensao]
```

> ⚠️ **Passe apenas o domínio, sem `http://`**

### Exemplos

```bash
# Buscar arquivos .php
./filefind.sh alvo.com.br php

# Buscar arquivos .pdf
./filefind.sh alvo.com.br pdf

# Buscar arquivos .js
./filefind.sh alvo.com.br js

# Buscar todos os arquivos (qualquer extensão)
./filefind.sh alvo.com.br
```

## Quando usar

O `filefind.sh` é mais eficaz em domínios **reais e públicos** que já estiveram ativos por algum tempo — sites corporativos, e-commerces, portais governamentais. Fontes como Wayback Machine e URLScan acumulam histórico ao longo dos anos.

Para alvos de CTF ou ambientes de lab que nunca foram indexados publicamente, use o [`webrecon.sh`](../webrecon/) com força bruta por wordlist.

## Saída

Os resultados são exibidos em tempo real e salvos automaticamente em:

```
./filefind_results/<dominio>_<timestamp>.txt
```

Formato do arquivo salvo:

```
# filefind.sh - Resultado
# Dominio  : alvo.com.br
# Extensao : php
# Data     : Sat Apr 04 12:00:00 2026
# Checados : 342
# Validos  : 27

# STATUS | URL
200 https://alvo.com.br/admin/config.php
200 https://alvo.com.br/assets/app.js
301 https://alvo.com.br/painel/login.php
```

## Como funciona

### Fase 1 — Coleta passiva

Consulta três fontes sem tocar no alvo:

| Fonte | Limite | O que traz |
|---|---|---|
| Wayback Machine | 50.000 URLs | Histórico completo de URLs arquivadas |
| AlienVault OTX | 500 URLs | Base de threat intelligence pública |
| URLScan.io | 1.000 URLs | Scans de segurança feitos por pesquisadores |

### Fase 2 — Filtragem

- Deduplica tudo com `sort -u`
- Garante que as URLs pertencem ao domínio alvo
- Filtra pela extensão informada (ou mantém qualquer URL com extensão no path)

### Fase 3 — Validação paralela

- Faz requisições `HEAD` em **20 threads simultâneas**
- Se o servidor não aceitar `HEAD`, cai automaticamente para `GET` pedindo só o primeiro byte (`Range: bytes=0-0`)
- Considera válido: `200`, `206`, `301`, `302`, `307`, `308`

## Parâmetros

| Parâmetro | Obrigatório | Descrição |
|---|---|---|
| `dominio` | Sim | Domínio alvo sem `http://` (ex: `alvo.com.br`) |
| `extensao` | Não | Extensão sem ponto (ex: `php`, `pdf`, `js`). Se omitida, retorna todos os arquivos encontrados |

---

> Este script foi desenvolvido para fins educacionais e de segurança ofensiva autorizada. Use apenas em sistemas que você tem permissão explícita para testar.

--------------------------------------------------------------------------------------------------------------------------------------------------------------

# filefind.sh

A bash script for **passive** file reconnaissance on web domains. It queries public intelligence sources (Wayback Machine, AlienVault OTX, URLScan.io) to discover URLs that have existed or been indexed on the target domain — without sending a single request directly to the site. It then validates each found URL in parallel to confirm whether it is still accessible.

## Dependencies

```bash
# Debian/Ubuntu/Kali
sudo apt install curl jq

# macOS
brew install curl jq
```

## Usage

```bash
chmod +x filefind.sh

./filefind.sh <domain> [extension]
```

> ⚠️ **Pass the domain only, without `http://`**

### Examples

```bash
# Search for .php files
./filefind.sh target.com php

# Search for .pdf files
./filefind.sh target.com pdf

# Search for .js files
./filefind.sh target.com js

# Search for all files (any extension)
./filefind.sh target.com
```

## When to use

`filefind.sh` works best against **real, public domains** that have been active for some time — corporate sites, e-commerce platforms, government portals. Sources like Wayback Machine and URLScan accumulate history over the years.

For CTF targets or lab environments that have never been publicly indexed, use [`webrecon.sh`](../webrecon/) with wordlist brute force instead.

## Output

Results are displayed in real time and automatically saved to:

```
./filefind_results/<domain>_<timestamp>.txt
```

Saved file format:

```
# filefind.sh - Results
# Domain    : target.com
# Extension : php
# Date      : Sat Apr 04 12:00:00 2026
# Checked   : 342
# Valid     : 27

# STATUS | URL
200 https://target.com/admin/config.php
200 https://target.com/assets/app.js
301 https://target.com/panel/login.php
```

## How it works

### Phase 1 — Passive collection

Queries three sources without touching the target:

| Source | Limit | What it returns |
|---|---|---|
| Wayback Machine | 50,000 URLs | Full history of archived URLs |
| AlienVault OTX | 500 URLs | Public threat intelligence database |
| URLScan.io | 1,000 URLs | Security scans submitted by researchers |

### Phase 2 — Filtering

- Deduplicates everything with `sort -u`
- Ensures all URLs belong to the target domain
- Filters by the provided extension (or keeps any URL with an extension in the path)

### Phase 3 — Parallel validation

- Sends `HEAD` requests across **20 simultaneous threads**
- If the server does not support `HEAD`, automatically falls back to a `GET` requesting only the first byte (`Range: bytes=0-0`)
- Considers valid: `200`, `206`, `301`, `302`, `307`, `308`

## Parameters

| Parameter | Required | Description |
|---|---|---|
| `domain` | Yes | Target domain without `http://` (e.g. `target.com`) |
| `extension` | No | Extension without dot (e.g. `php`, `pdf`, `js`). If omitted, returns all files found |

---

> This script was developed for educational purposes and authorized offensive security only. Use it exclusively on systems you have explicit permission to test.

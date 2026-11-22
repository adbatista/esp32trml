# TRMNL BYOD — ESP32 + Waveshare 7.5" V2

E-paper TRMNL caseiro com servidor próprio (Terminus) no Mac.

## Hardware

- ESP32 DevKit V1 (ESP-WROOM-32)
- Waveshare e-Paper Driver HAT Rev2.3 + tela 7.5" V2 800x480 P&B

| HAT  | ESP32 GPIO |
|------|------------|
| DIN  | 14 |
| CLK  | 13 |
| CS   | 15 |
| DC   | 27 |
| RST  | 26 |
| BUSY | 25 |
| PWR  | 19 |
| VCC/GND | 3V3/GND |

Botão: **BOOT** (GPIO0). Segure 5–15 s com o dispositivo acordado para abrir o portal Wi-Fi.

## Pastas

- `trmnl-firmware/` — firmware oficial [usetrmnl/trmnl-firmware](https://github.com/usetrmnl/trmnl-firmware), env `waveshare-esp32-driver`, com mudanças locais (`git diff`):
  - `src/display.cpp`: liga o PWR (GPIO19) e inicia o SPI com MISO no GPIO35, para o core não tomar o GPIO19.
  - `src/board_config.cpp` / `include/config.h`: botão no GPIO0 (BOOT), `epd_en` = 19, servidor padrão `http://192.168.1.132:2300`.
  - `src/wake_init.cpp`: log na serial sempre ligado.
- `terminus/` — servidor BYOS [usetrmnl/terminus](https://github.com/usetrmnl/terminus) via Docker (imagem `ghcr.io/usetrmnl/terminus:latest`).
  - `.env`: IP, portas e senhas (gerado por `bin/setup docker`). Não compartilhe.
  - `compose.override.yml`: não expõe Postgres/Valkey no Mac (o Mac já tem Postgres na 5432).
- `terminus-customizations/` — ajustes feitos no Terminus:
  - `fix_daycast.rb`: corrige o plugin Daycast importado do TRMNL, configura Guarapuava em pt-BR, liga ao dispositivo e gera a tela.
  - `daycast.*`: backup do template, URL e configurações da Daycast como estão no banco.
  - `weather-canvas.pt-BR.template.liquid`: template da Weather Canvas traduzido (não está em uso; o serviço dela é instável).

## Comandos

Gravar o firmware (ESP32 na USB):

```bash
cd trmnl-firmware
python3 -m platformio run -e waveshare-esp32-driver -t upload --upload-port /dev/cu.usbserial-0001
```

Terminus:

```bash
cd terminus
docker compose up -d        # subir
docker compose logs -f web  # logs
docker compose down         # parar
```

Painel: http://192.168.1.132:2300

Reaplicar as correções da Daycast (depois de reimportar o plugin):

```bash
cd terminus
docker compose cp ../terminus-customizations/fix_daycast.rb web:/app/tmp_fix_daycast.rb
docker compose exec web bundle exec hanami run tmp_fix_daycast.rb
docker compose exec web rm /app/tmp_fix_daycast.rb
```

## Se o IP do Mac mudar

1. `terminus/.env`: atualize `API_URI` e rode `docker compose up -d`.
2. `trmnl-firmware/include/config.h`: atualize `API_BASE_URL` e grave o firmware de novo.

Melhor: reserve o IP do Mac no roteador (rede Nick).

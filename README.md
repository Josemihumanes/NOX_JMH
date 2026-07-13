# NOX

Un compañero personal, sin conexión, para tu pulsera WHOOP en iPhone — un fork independiente del proyecto de código abierto **NOOP**, rebautizado y mantenido para uso personal.

> **No oficial e independiente.** No está afiliado con, respaldado por, ni patrocinado por WHOOP, Inc. "WHOOP" se usa únicamente para identificar el hardware de terceros con el que esta app interopera. Consulta [`DISCLAIMER.md`](DISCLAIMER.md) para el aviso legal completo.

## ¿Qué es esto?

NOX se conecta directamente a una pulsera WHOOP 4.0 o 5.0/MG por Bluetooth — sin app oficial, sin cuenta, sin nube. Lee los datos sin procesar de los sensores de la pulsera y calcula sus propias puntuaciones de recuperación, esfuerzo y sueño **completamente en el dispositivo**, usando métodos de ciencia del deporte publicados y revisados por pares. Nada se sube a ningún lado a menos que tú lo elijas explícitamente (por ejemplo, la integración opcional con Home Assistant, que solo se comunica con la instancia de Home Assistant que tú mismo configures).

Este es un **proyecto personal**: solo apunta a iOS, se distribuye sin firmar para instalarse vía sideload con [SideStore](https://sidestore.io)/AltStore, y no está publicado en la App Store.

## Funciones

- **Conexión BLE directa** a pulseras WHOOP 4.0 y 5.0/MG — sin necesitar la app oficial
- **Puntuación de Carga, Esfuerzo y Descanso calculada en el dispositivo** (el Recovery/Strain/Sleep de WHOOP, calculado de forma independiente, en la misma escala de 0 a 100)
- **Apple Watch como sensor** — funciona sin pulsera, usando los propios datos de HealthKit del reloj
- **Soporte para anillo Oura**, bandas de frecuencia cardíaca estándar/Garmin/Huami, y máquinas de fitness Bluetooth genéricas (FTMS)
- **Copia de seguridad y restauración completas sin conexión**, a la carpeta que elijas (iCloud Drive, Dropbox, Google Drive, etc.)
- **Integración con Home Assistant** — envía opcionalmente tus puntuaciones como sensores a tu propia instancia de Home Assistant para automatizaciones y paneles
- **AI Coach** — un asistente de chat opcional, con tu propia clave de API (Anthropic, OpenAI, Gemini, o cualquier servidor local compatible con OpenAI)
- **Atajos de Siri y App Intents**, Sesiones en vivo, clasificación de fases del sueño, un cuaderno de laboratorio personal, seguimiento de correlaciones entre ánimo y comportamiento, y más
- Disponible en **español e inglés**

## Instalación

NOX no está en la App Store. Instálalo vía [SideStore](https://sidestore.io) o AltStore usando esta URL de fuente:

```
https://raw.githubusercontent.com/Josemihumanes/NOX_JMH/main/altstore-source.json
```

Los builds son `.ipa`s sin firmar, generados por GitHub Actions en cada release etiquetado; SideStore/AltStore los firman localmente con tu propio Apple ID (gratuito) al instalarlos.

## Compilar desde el código fuente

El proyecto usa [XcodeGen](https://github.com/yonaskolb/XcodeGen) — el `.xcodeproj` se genera a partir de [`project.yml`](project.yml), no está comiteado:

```bash
brew install xcodegen
xcodegen generate
xcodebuild -scheme NOOPiOS -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  clean build
```

Consulta [`.github/workflows/ios-release.yml`](.github/workflows/ios-release.yml) para ver el proceso exacto de release.

## No es un dispositivo médico

Carga, Esfuerzo, Descanso, y cualquier otra métrica que calcula NOX son aproximaciones para uso informativo y curiosidad personal — no están clínicamente validadas, no son consejo médico, y no sustituyen la atención de un profesional. Consulta [`DISCLAIMER.md`](DISCLAIMER.md) §5 para el aviso completo.

## Licencia y atribución

El trabajo original está licenciado bajo la **PolyForm Noncommercial License 1.0.0** — consulta [`LICENSE`](LICENSE). Las dependencias de terceros mantienen sus propias licencias; consulta [`NOTICE`](NOTICE) y [`ATTRIBUTION.md`](ATTRIBUTION.md).

# Forge — instalación del CLI en macOS

Instalador robusto del Forge CLI (`forge`) para macOS con zsh, alineado con la
**Guía del Forjador V5.3.1** (§02 Instalación, §10 Buenas prácticas, §11 Troubleshooting).

## Uso

En tu Mac, desde una terminal:

```zsh
zsh setup-forge-macos.zsh ~/.forge
```

Si no pasas la ruta, el script te la pregunta antes de asumir una
(`~/.forge` es la convención oficial de la guía).

## Qué hace

1. Elimina alias `forge` legados (estilo V4, `cp -r …`) de `~/.zshrc`, con backup previo.
2. Clona `https://github.com/getforja/forge-pro` en la ruta indicada. Si el clon ya
   existe, lo sincroniza con `git fetch` + `reset --hard` — **nunca `git pull`**, porque
   el repo es un mirror force-pusheado (§2.4 de la guía). Si detecta modificaciones
   locales en archivos rastreados, se detiene antes de descartarlas.
3. En `tools/forge-cli` ejecuta `npm install`, `npm run build` y `npm link` — los tres
   siempre juntos (sin build, el link queda roto: «Cannot find module '../dist/index.js'»).
4. Blindaje del PATH: garantiza que `$(npm prefix -g)/bin` esté en el PATH de la sesión
   y en `~/.zshrc` (idempotente, sin duplicar la línea), y corre `hash -r`.
5. Detecta colisiones de binarios: si otro `forge` (típicamente Foundry,
   `~/.foundry/bin/forge`) gana en el PATH, lo lista y explica cómo resolverlo.
6. Verifica `forge --version` contra la versión real del clon (leída de
   `tools/forge-cli/package.json` — V5.3.1 al momento de escribir esto) y ejecuta
   `forge doctor`.
7. Imprime los siguientes pasos del Escenario A de la guía
   (`forge init --target=claude` → `/forge-check` → `/plan`).

Siguiendo la guía, el script **no crea alias `forge` de respaldo**: un alias tapa el
binario real y es la causa nº1 de reportes de soporte. Si `forge` no aparece tras el
link, el script diagnostica (symlink en el bin global de npm, PATH, colisiones) y se
detiene con instrucciones concretas.

Para actualizaciones futuras de Forge: `forge self-update`.

Variables opcionales: `FORGE_REPO_URL` permite instalar desde otra URL (p. ej. un fork).

# Forge — instalación del CLI en macOS

Instalador robusto del Forge CLI (`forge`) para macOS con zsh: `setup-forge-macos.zsh`.

## Uso

En tu Mac, desde una terminal:

```zsh
zsh setup-forge-macos.zsh ~/Proyectos/forge-pro
```

Si no pasas la ruta, el script te la pregunta antes de asumir una.

## Qué hace

1. Elimina cualquier alias `forge` viejo de `~/.zshrc` (con backup previo) para que no tape el CLI real.
2. Clona `https://github.com/getforja/forge-pro` en la ruta indicada (o actualiza el clon si ya existe).
3. En `tools/forge-cli` ejecuta `npm install`, `npm run build` y `npm link`.
4. Blindaje del PATH: comprueba que `$(npm prefix -g)/bin` esté en el PATH; si no, lo agrega a `~/.zshrc` de forma idempotente, lo exporta en la sesión actual y corre `hash -r`.
5. Verifica `forge --version` (debe imprimir `5.2.1`) y ejecuta `forge doctor`.
6. Si `forge` sigue sin encontrarse, diagnostica (symlink en el bin global de npm, PATH) y como último recurso crea el alias `forge="node …/tools/forge-cli/dist/index.js"`.
7. Al terminar imprime el siguiente paso para crear un proyecto nuevo (`forge init --target=claude`).

El script no da la instalación por terminada hasta que `forge --version` responde `5.2.1`; si algo falla, se detiene con un mensaje que indica la causa y cómo resolverla.

Variables opcionales: `FORGE_REPO_URL` permite instalar desde otra URL de repositorio (por ejemplo, un fork propio).

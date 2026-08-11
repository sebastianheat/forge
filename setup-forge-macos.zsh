#!/bin/zsh
# setup-forge-macos.zsh — Instalador completo del Forge CLI para macOS (zsh).
#
# Uso:
#   zsh setup-forge-macos.zsh [ruta-destino-del-clon]
#
# Si no pasas ruta, el script te la pregunta (Enter = ~/Proyectos/forge-pro).
# Al terminar, `forge --version` debe imprimir 5.2.1. Ejecuta después:
#   source ~/.zshrc
# en las terminales que ya tuvieras abiertas.

set -u

REPO_URL="${FORGE_REPO_URL:-https://github.com/getforja/forge-pro}"
ZSHRC="$HOME/.zshrc"
EXPECTED_VERSION="5.2.1"

ok()   { print -P "%F{green}✔%f $1"; }
warn() { print -P "%F{yellow}⚠%f $1"; }
die()  { print -P "%F{red}✘%f $1"; exit 1; }

# ---------------------------------------------------------------- requisitos
command -v git  >/dev/null || die "git no está instalado. Instálalo con: xcode-select --install"
command -v npm  >/dev/null || die "npm no está instalado. Instálalo con: brew install node"
command -v node >/dev/null || die "node no está instalado. Instálalo con: brew install node"
[[ -f "$ZSHRC" ]] || touch "$ZSHRC"

# ------------------------------------------------- ruta destino del clon (paso 2)
DEST="${1:-}"
if [[ -z "$DEST" ]]; then
  read "DEST?Ruta donde clonar forge-pro [Enter = ~/Proyectos/forge-pro]: "
  DEST="${DEST:-$HOME/Proyectos/forge-pro}"
fi
DEST="${DEST/#\~/$HOME}"

# ------------------------------------ paso 1: eliminar alias `forge` viejos
if grep -qE '^[[:space:]]*alias[[:space:]]+forge=' "$ZSHRC"; then
  BACKUP="$ZSHRC.backup.$(date +%Y%m%d%H%M%S)"
  cp "$ZSHRC" "$BACKUP"
  if sed --version >/dev/null 2>&1; then
    sed -i -E '/^[[:space:]]*alias[[:space:]]+forge=/d' "$ZSHRC"        # GNU sed
  else
    sed -i '' -E '/^[[:space:]]*alias[[:space:]]+forge=/d' "$ZSHRC"     # sed de BSD (macOS)
  fi
  ok "Alias 'forge' viejo eliminado de ~/.zshrc (backup en $BACKUP)"
fi
unalias forge 2>/dev/null && ok "Alias 'forge' de la sesión actual descartado"
unfunction forge 2>/dev/null

# --------------------------------------------------- paso 2: clonar/actualizar
if [[ -d "$DEST/.git" ]]; then
  warn "Ya existe un clon en $DEST — actualizando en vez de clonar"
  git -C "$DEST" pull --ff-only || die "No pude actualizar el clon existente en $DEST. Revisa su estado con: git -C \"$DEST\" status"
else
  [[ -e "$DEST" ]] && die "$DEST existe pero no es un repositorio git. Elige otra ruta o elimínalo."
  mkdir -p "${DEST:h}"
  git clone "$REPO_URL" "$DEST" || die "Falló el clon de $REPO_URL. ¿Tienes acceso al repo y sesión de GitHub activa (gh auth login / credenciales git)?"
  ok "Repositorio clonado en $DEST"
fi

CLI_DIR="$DEST/tools/forge-cli"
[[ -d "$CLI_DIR" ]] || die "No existe $CLI_DIR — la estructura del repo no es la esperada."

# ------------------------------------------- paso 3: install + build + link
cd "$CLI_DIR" || die "No pude entrar a $CLI_DIR"

npm install       || die "Falló 'npm install' en $CLI_DIR. Revisa el error de arriba."
npm run build     || die "Falló 'npm run build'. Revisa el error de arriba."
if ! npm link; then
  warn "'npm link' falló — probablemente por permisos en la carpeta global de npm."
  warn "Opción A (recomendada): mover el prefix global a tu HOME y reintentar:"
  warn "  npm config set prefix ~/.npm-global && zsh $0 \"$DEST\""
  warn "Opción B: sudo npm link   (dentro de $CLI_DIR)"
  die  "Resuelve el link global y vuelve a ejecutar este script."
fi
ok "CLI instalado, compilado y linkeado globalmente"

# ------------------------------------------------ paso 4: blindaje del PATH
NPM_BIN="$(npm prefix -g)/bin"
if [[ ":$PATH:" != *":$NPM_BIN:"* ]]; then
  export PATH="$NPM_BIN:$PATH"
  warn "$NPM_BIN no estaba en el PATH — agregado a la sesión actual"
fi
# Idempotente: solo añade la línea a ~/.zshrc si esa carpeta no está ya exportada
if ! grep -qF "$NPM_BIN" "$ZSHRC"; then
  {
    print ""
    print "# Forge CLI: carpeta global de binarios de npm (añadido por setup-forge-macos.zsh)"
    print -r -- "export PATH=\"$NPM_BIN:\$PATH\""
  } >> "$ZSHRC"
  ok "PATH blindado en ~/.zshrc ($NPM_BIN)"
else
  ok "El PATH ya incluía $NPM_BIN en ~/.zshrc — no se duplicó nada"
fi
hash -r

# ----------------------------------------- pasos 5 y 6: verificar/diagnosticar
if ! command -v forge >/dev/null; then
  warn "'forge' sigue sin encontrarse. Diagnosticando…"
  if [[ -L "$NPM_BIN/forge" || -x "$NPM_BIN/forge" ]]; then
    warn "El binario SÍ existe en $NPM_BIN/forge; el problema es el PATH de esta sesión."
  else
    warn "No existe $NPM_BIN/forge — 'npm link' no dejó el symlink esperado."
  fi
  ENTRY="$CLI_DIR/dist/index.js"
  [[ -f "$ENTRY" ]] || die "Tampoco existe $ENTRY. La build no produjo el CLI; revisa 'npm run build'."
  warn "Último recurso: creando alias directo al CLI compilado."
  ALIAS_LINE="alias forge=\"node $ENTRY\""
  grep -qxF "$ALIAS_LINE" "$ZSHRC" || print -r -- "$ALIAS_LINE" >> "$ZSHRC"
  alias forge="node $ENTRY"
  ok "Alias de respaldo creado (sesión actual y ~/.zshrc)"
fi

VERSION="$(forge --version 2>/dev/null || true)"
if [[ "$VERSION" != *"$EXPECTED_VERSION"* ]]; then
  die "forge respondió '${VERSION:-nada}' en vez de $EXPECTED_VERSION. Revisa que el repo esté en la versión correcta (git -C \"$DEST\" log -1) y repite la build."
fi
ok "forge --version → $VERSION"

print ""
print "── forge doctor ──────────────────────────────────────────────"
forge doctor || warn "'forge doctor' reportó problemas — revisa su salida arriba."
print "──────────────────────────────────────────────────────────────"

# --------------------------------------------------------------- paso 7: OK
print ""
ok "Instalación completa: forge $EXPECTED_VERSION operativo."
print ""
print "Siguiente paso — crear un proyecto nuevo:"
print "  mkdir mi-proyecto && cd mi-proyecto"
print "  forge init --target=claude"
print ""
print "Nota: en terminales que ya estaban abiertas, ejecuta antes:  source ~/.zshrc"

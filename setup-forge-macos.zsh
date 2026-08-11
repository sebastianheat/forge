#!/bin/zsh
# setup-forge-macos.zsh — Instalador completo del Forge CLI para macOS (zsh).
# Alineado con la Guía del Forjador V5.3.1 (§02 Instalación, §11 Troubleshooting).
#
# Uso:
#   zsh setup-forge-macos.zsh [ruta-destino-del-clon]
#
# Si no pasas ruta, el script te la pregunta (Enter = ~/.forge, la convención
# oficial de la guía). Al terminar, `forge --version` debe responder la versión
# del CLI clonado (V5.3.1 al momento de escribir esto) y corre `forge doctor`.
#
# En terminales que ya estuvieran abiertas, ejecuta después:  source ~/.zshrc

set -u

REPO_URL="${FORGE_REPO_URL:-https://github.com/getforja/forge-pro}"
ZSHRC="$HOME/.zshrc"

ok()   { print -P "%F{green}✔%f $1"; }
warn() { print -P "%F{yellow}⚠%f $1"; }
die()  { print -P "%F{red}✘%f $1"; exit 1; }

# ---------------------------------------------------------------- requisitos
command -v git  >/dev/null || die "git no está instalado. Instálalo con: xcode-select --install"
command -v node >/dev/null || die "node no está instalado (se requiere Node 18+): brew install node"
command -v npm  >/dev/null || die "npm no está instalado: brew install node"
NODE_MAJOR="${$(node --version)#v}"; NODE_MAJOR="${NODE_MAJOR%%.*}"
(( NODE_MAJOR >= 18 )) || die "Forge requiere Node 18 o superior; tienes $(node --version). Actualiza con: brew upgrade node"
[[ -f "$ZSHRC" ]] || touch "$ZSHRC"

# ------------------------------------------------- ruta destino del clon
DEST="${1:-}"
if [[ -z "$DEST" ]]; then
  read "DEST?Ruta donde clonar forge-pro [Enter = ~/.forge (convención oficial)]: "
  DEST="${DEST:-$HOME/.forge}"
fi
DEST="${DEST/#\~/$HOME}"

# ------------------------------------------- eliminar alias `forge` legado
# La guía (§10, regla 1) prohíbe cualquier alias o función `forge`: tapa el
# binario real. Aquí solo LIMPIAMOS los legados (estilo V4: cp -r …).
if grep -qE '^[[:space:]]*alias[[:space:]]+forge=' "$ZSHRC"; then
  BACKUP="$ZSHRC.forge-bak.$(date +%Y%m%d%H%M%S)"
  cp "$ZSHRC" "$BACKUP"
  if sed --version >/dev/null 2>&1; then
    sed -i -E '/^[[:space:]]*alias[[:space:]]+forge=/d' "$ZSHRC"        # GNU sed
  else
    sed -i '' -E '/^[[:space:]]*alias[[:space:]]+forge=/d' "$ZSHRC"     # sed de BSD (macOS)
  fi
  ok "Alias 'forge' legado eliminado de ~/.zshrc (backup en $BACKUP)"
fi
unalias forge 2>/dev/null && ok "Alias 'forge' de la sesión actual descartado"
unfunction forge 2>/dev/null

# --------------------------------------------------- clonar / sincronizar
# OJO: forge-pro es un mirror force-pusheado. La guía (§2.4) prohíbe `git pull`
# en el clon: para actualizar se usa `forge self-update` o, aquí, fetch + reset
# duro contra origin — el mismo mecanismo que usa self-update.
if [[ -d "$DEST/.git" ]]; then
  warn "Ya existe un clon en $DEST — sincronizando contra origin (sin git pull)"
  if [[ -n "$(git -C "$DEST" status --porcelain -uno)" ]]; then
    die "Hay cambios locales en $DEST. El clon de Forge no se edita a mano (los cambios se perderían en cada actualización). Respáldalos y reintenta, o usa 'forge self-update' si el CLI ya funciona."
  fi
  git -C "$DEST" fetch origin || die "Falló 'git fetch' en $DEST."
  if git -C "$DEST" rev-parse --verify -q origin/main >/dev/null; then
    git -C "$DEST" reset --hard origin/main || die "Falló la sincronización contra origin/main."
  else
    git -C "$DEST" reset --hard origin/HEAD || die "Falló la sincronización contra origin/HEAD."
  fi
  ok "Clon sincronizado con origin"
else
  [[ -e "$DEST" ]] && die "$DEST existe pero no es un repositorio git. Elige otra ruta o elimínalo."
  mkdir -p "${DEST:h}"
  if ! git clone "$REPO_URL" "$DEST"; then
    print ""
    warn "Falló el clon de $REPO_URL. Casi siempre es autenticación:"
    warn "  1) Verifica en el navegador que tu cuenta ve el repo (¿invitación aceptada?)"
    warn "  2) gh auth login && gh auth setup-git   (vía recomendada)"
    warn "  3) O borra la credencial vieja del llavero y usa un token (PAT):"
    warn "     printf 'protocol=https\\nhost=github.com\\n' | git credential-osxkeychain erase"
    die  "Resuelve el acceso y vuelve a ejecutar este script."
  fi
  ok "Repositorio clonado en $DEST"
fi

CLI_DIR="$DEST/tools/forge-cli"
[[ -d "$CLI_DIR" ]] || die "No existe $CLI_DIR — la estructura del repo no es la esperada."

# ------------------------------------------- install + build + link
# La guía (§2.2) es explícita: los tres pasos van SIEMPRE juntos. El paquete no
# tiene script 'prepare'; sin 'npm run build', el link queda apuntando a un
# dist/ inexistente («Cannot find module '../dist/index.js'»).
cd "$CLI_DIR" || die "No pude entrar a $CLI_DIR"

npm install   || die "Falló 'npm install' en $CLI_DIR. Revisa el error de arriba."
npm run build || die "Falló 'npm run build'. Revisa el error de arriba."
if ! npm link; then
  warn "'npm link' falló — probablemente permisos en la carpeta global de npm."
  warn "Opción A (recomendada): npm config set prefix ~/.npm-global && zsh $0 \"$DEST\""
  warn "Opción B: sudo npm link   (dentro de $CLI_DIR)"
  die  "Resuelve el link global y vuelve a ejecutar este script."
fi
ok "CLI instalado, compilado y linkeado globalmente"

# ------------------------------------------------ blindaje del PATH
NPM_BIN="$(npm prefix -g)/bin"
if [[ ":$PATH:" != *":$NPM_BIN:"* ]]; then
  export PATH="$NPM_BIN:$PATH"
  warn "$NPM_BIN no estaba en el PATH — agregado a la sesión actual"
fi
# Idempotente: solo añade la línea a ~/.zshrc si esa carpeta no aparece ya
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

# ----------------------------------------- verificación y diagnóstico
if ! command -v forge >/dev/null; then
  warn "'forge' sigue sin encontrarse. Diagnóstico:"
  if [[ -L "$NPM_BIN/forge" || -x "$NPM_BIN/forge" ]]; then
    warn "El binario SÍ existe en $NPM_BIN/forge; el problema es el PATH de esta sesión."
    warn "Abre una terminal nueva o corre: source ~/.zshrc && hash -r"
  else
    warn "No existe $NPM_BIN/forge — 'npm link' no dejó el symlink esperado."
    warn "Comprueba el prefix global (npm prefix -g / npm root -g) y repite: npm install && npm run build && npm link"
  fi
  # NO creamos un alias de respaldo: la guía lo prohíbe expresamente — un
  # alias tapa el binario y rompe forge doctor/self-update.
  die "Instalación incompleta. Corrige lo de arriba y vuelve a ejecutar el script."
fi

# Colisiones: ¿el `forge` que gana en el PATH es el nuestro? (típico: Foundry)
WINNER="$(command -v forge)"
if [[ "$WINNER" != "$NPM_BIN/forge" ]]; then
  warn "Hay OTRO binario 'forge' ganando en el PATH: $WINNER"
  print -l -- "Todos los 'forge' visibles:" ${(f)"$(whence -pa forge 2>/dev/null)"}
  die "Típico con Foundry (~/.foundry/bin/forge). Reordena tu PATH (la línea de npm debe ir DESPUÉS en ~/.zshrc para quedar delante) o renombra el otro binario, y reintenta."
fi

EXPECTED_VERSION="$(node -p "require('$CLI_DIR/package.json').version" 2>/dev/null)"
[[ -n "$EXPECTED_VERSION" ]] || die "No pude leer la versión esperada de $CLI_DIR/package.json"
VERSION="$(forge --version 2>/dev/null || true)"
if [[ "$VERSION" != *"$EXPECTED_VERSION"* ]]; then
  die "forge respondió '${VERSION:-nada}' pero el clon es v$EXPECTED_VERSION. Hay una instalación vieja tapando la nueva: revisa 'whence -pa forge' y repite install → build → link."
fi
ok "forge --version → $VERSION (coincide con el clon, v$EXPECTED_VERSION)"

print ""
print "── forge doctor ──────────────────────────────────────────────"
forge doctor || warn "'forge doctor' reportó problemas — revisa su salida arriba."
print "──────────────────────────────────────────────────────────────"

# --------------------------------------------------------------- listo
print ""
ok "Instalación completa: forge v$EXPECTED_VERSION operativo."
print ""
print "Siguiente paso — proyecto nuevo (Escenario A de la guía):"
print "  mkdir mi-app && cd mi-app"
print "  forge init --target=claude"
print "  npm install"
print "  claude .        # y dentro del agente: /forge-check → /plan"
print ""
print "Para actualizar Forge en el futuro:  forge self-update"
print "(nunca 'git pull' dentro de $DEST — es un mirror force-pusheado)"
print ""
print "Verificación end-to-end opcional:  bash $DEST/docs/smoke-test-e2e.sh"
print "Nota: en terminales ya abiertas, corre antes:  source ~/.zshrc"

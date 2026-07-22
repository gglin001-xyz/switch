scripts/build-clt.sh

mkdir -p "$HOME/Applications"
ditto build/clt/Switch.app "$HOME/Applications/Switch Local.app"
open "$HOME/Applications/Switch Local.app"

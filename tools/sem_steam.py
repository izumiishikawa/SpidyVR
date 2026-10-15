"""Reaplica o "abrir sem Steam" num Spidy oficial, depois de cada update do launcher.

O update troca tools/vr_launcher.py inteiro. Este script anexa ao fim dele um bloco que, quando
game-path.txt (na pasta do Spidy) aponta pro Spider-Man.exe, troca a abertura pela Steam (ou Epic)
pela abertura direta do exe: cedo o bastante pra memória de render maior, e sem o "Executar como
administrador" que trancaria o Spidy fora do jogo. Rodar de novo só atualiza o bloco.

    python\\python.exe -I -B sem_steam.py [pasta do Spidy]
"""
import pathlib
import re
import sys

BEGIN = '# >>> sem Steam (game-path.txt) >>>'
END = '# <<< sem Steam <<<'
BLOCK = BEGIN + r'''
# Anexado por sem_steam.py: some com o próximo update do Spidy; rode "Reaplicar sem Steam.cmd" de novo.
def _sem_steam_exe():
    try: value=(ROOT/'game-path.txt').read_text(encoding='utf-8-sig').strip().strip('"')
    except OSError: return None
    if not value: return None
    path=pathlib.Path(value)
    if path.is_dir(): path=path/'Spider-Man.exe'
    return path if path.is_file() else None


class _SemSteamSubprocess:
    """subprocess, com a abertura do jogo pela Steam trocada pela do exe."""
    def __getattr__(self,name): return getattr(_sem_steam_subprocess,name)

    def Popen(self,args,*rest,**options):
        exe=_sem_steam_exe()
        if exe and isinstance(args,(list,tuple)) and '-applaunch' in [str(arg) for arg in args]:
            print(f'Starting Spider-Man from {exe} (without Steam).',flush=True)
            # RunAsInvoker: um "Executar como administrador" no exe deixaria o Spidy fora do jogo.
            return _sem_steam_subprocess.Popen([str(exe),'-nolauncher'],cwd=str(exe.parent),
                                               env=dict(os.environ,__COMPAT_LAYER='RunAsInvoker'))
        return _sem_steam_subprocess.Popen(args,*rest,**options)


if _sem_steam_exe():
    import subprocess as _sem_steam_subprocess
    subprocess=_SemSteamSubprocess()
    # A "Steam" que abre o jogo é o próprio exe, e ela sempre o tem: nada de Epic.
    steam_executable=lambda *args,**options: _sem_steam_exe()
    if 'steam_has_game' in globals(): steam_has_game=lambda *args,**options: True
    if 'epic_launch' in globals(): epic_launch=lambda *args,**options: None
''' + END + '\n'


def apply(spidy):
    launcher = spidy / 'tools' / 'vr_launcher.py'
    if not launcher.is_file():
        raise SystemExit(f'Não achei {launcher}. Passe a pasta do Spidy (a do "Spidy Launcher.exe").')
    text = launcher.read_text(encoding='utf-8')
    if BEGIN in text and END in text:
        text = text[:text.index(BEGIN)].rstrip('\n') + '\n' + text[text.index(END) + len(END):].lstrip('\n')
    for needed in ('def steam_executable', "'-applaunch'"):
        if needed not in text:
            raise SystemExit(f'Esta versão do Spidy não abre o jogo como o bloco espera (falta {needed}). '
                             'Nada foi mudado.')
    # Antes do main() do script, que rodado direto abriria o jogo antes de ler o bloco.
    guard = re.search(r"^if __name__ *== *['\"]__main__['\"]:", text, re.M)
    at = guard.start() if guard else len(text)
    text = text[:at].rstrip('\n') + '\n\n\n' + BLOCK + ('\n\n' + text[at:] if guard else '')
    launcher.write_text(text, encoding='utf-8', newline='\n')
    game = spidy / 'game-path.txt'
    if not game.is_file():
        print(f'Falta {game}: crie com o caminho do Spider-Man.exe numa linha.')
    print(f'Abrir sem Steam aplicado em {launcher}.')


if __name__ == '__main__':
    apply(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent))

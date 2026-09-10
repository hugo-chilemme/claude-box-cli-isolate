# claude-box

Lance Claude Code dans un conteneur Docker en ne montant que les fichiers et
dossiers que tu choisis. Chaque élément est monté dans `/workspace` en
conservant son chemin relatif et synchronisé en direct avec ta machine. Claude
ne voit jamais que ce que tu montes.

- `claude-box up <éléments...>` — monte chaque élément dans `/workspace` et lance Claude
- `claude-box down` — nettoie les conteneurs et les fichiers résiduels

L'authentification est conservée dans un volume Docker (`claude-auth`), donc tu
te connectes une seule fois.

---

## Pourquoi

Sur les gros projets, on veut souvent que Claude travaille sur une partie
précise sans lui donner tout le code. Pointer Claude Code sur la racine du
projet expose tout : services non liés, secrets, configuration, code d'autres
équipes.

`claude-box` inverse la logique. Au lieu d'ouvrir le projet en espérant que
Claude reste dans son couloir, tu listes explicitement les fichiers et dossiers
qu'il peut toucher. Tout le reste n'est tout simplement pas présent dans le
conteneur : il n'y a donc rien où s'égarer, rien à lire par accident, rien à
modifier. L'isolation est structurelle, pas déclarative : elle vient de ce qui
est monté, pas de consignes que Claude est censé suivre.

Résultat : une exposition stricte, tâche par tâche, sur des dépôts volumineux ou
sensibles, tout en gardant les modifications appliquées en direct sur tes vrais
fichiers.

---

## Prérequis

| Requis | Pourquoi | Lien |
|--------|----------|------|
| Docker Desktop (ou moteur) | fait tourner le conteneur | https://www.docker.com/products/docker-desktop |
| Git | déjà installé en général | https://git-scm.com/downloads |
| Un compte Anthropic | pour le `/login` dans Claude | https://claude.ai |

Docker doit être **démarré** avant de lancer le setup (`docker ps` doit
répondre).

### Note macOS
Télécharge et installe Docker Desktop depuis le site officiel, puis lance-le et
attends qu'il soit démarré avant de continuer :
https://www.docker.com/products/docker-desktop

### Note Windows
Docker Desktop nécessite la virtualisation matérielle. Si Windows tourne
lui-même dans une VM (ex. Parallels/VMware sur un Mac), il faut activer la
**virtualisation imbriquée** sur l'hôte, VM éteinte. Ce n'est possible que sur
un hôte Intel ; sur Apple Silicon, ce n'est généralement pas supporté.

---

## Installation — Linux / macOS

Lance `./bin/setup.sh` depuis le même dossier que ce README.

```bash
chmod +x /bin/setup.sh
./bin/setup.sh
```

---

## Installation — Windows

Lance `.\bin\setup.ps1` depuis le même dossier que ce README, dans PowerShell.

```powershell
powershell -ExecutionPolicy Bypass -File .\bin\setup.ps1
```

---

## Utilisation

```bash
cd ~/projet
claude-box up config.json app/routes
claude-box down
```

Monter plusieurs éléments conserve leurs chemins relatifs dans `/workspace` :

```
claude-box up apps/portal services/api config.json

/workspace/
  apps/portal/       -> synchro live avec ./apps/portal
  services/api/      -> synchro live avec ./services/api
  config.json        -> synchro live avec ./config.json
```

Les éléments doivent exister par rapport au dossier depuis lequel tu lances la
commande. Pour monter quelque chose ailleurs, utilise un chemin relatif (ex.
`claude-box up ../autre/api`).

---

## Fonctionnement

- Chaque élément est un **bind mount** Docker vers `/workspace/<chemin-relatif>`,
  donc les modifications de Claude s'appliquent directement à tes vrais fichiers
  (en direct, bidirectionnel).
- L'isolation vient du conteneur : Claude ne peut atteindre que les chemins que
  tu montes.
- `claude-auth` est le seul volume nommé, il conserve ton login entre les runs.
- À la sortie, les fichiers `.claude/` et `CLAUDE.md` injectés dans le dossier de
  travail sont supprimés automatiquement.

---

## Premier run

Au premier `claude-box up`, lance `/login` dans Claude. Le token est stocké dans
le volume `claude-auth` et réutilisé aux runs suivants.

---

## Notes

- `up` lance le conteneur avec `--rm` ; il s'autodétruit quand tu quittes Claude
  (`/exit` ou Ctrl+C). `down` est un filet de secours qui supprime aussi les
  conteneurs restants.
- L'étape de nettoyage supprime `.claude/` et `CLAUDE.md` du dossier depuis
  lequel tu as lancé la commande. Si ton projet a déjà son propre `.claude/` ou
  `CLAUDE.md`, sauvegarde-les d'abord.

# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## What's included

- `.gitconfig` - Git configuration with aliases and LFS setup
- `.ideavimrc` - IdeaVim plugin configuration for IntelliJ IDEA
- `.bashrc` - Bash shell configuration
- `bash/` - Modular bash configuration:
  - `.aliases.sh` - Shell aliases (exa, clipboard, tool launchers)
  - `.exports.sh` - Environment variables, PATH, and 1Password secrets integration
  - `.functions.sh` - Loader for modular function files
  - `.bash_functions/` - Function modules (Datadog, process tools, search)
  - `.claude/` - Claude Code project settings
  - `CLAUDE.md` - Claude Code context for the bash config

## Install

```bash
chezmoi init git@github.com:erickZatlas/dotfiles.git
chezmoi diff    # review changes
chezmoi apply   # apply to home directory
```

## Update

```bash
chezmoi update
```

## Add new files

```bash
chezmoi add ~/.some-config
cd $(chezmoi source-path) && git add -A && git commit -m "feat: add some-config" && git push
```

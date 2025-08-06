# saur.sh
A **s**imple and "secure" **AUR** helper written purely in bash

I had two goals with this project:

1 - it must be written in bash as most Arch users should be familiar with bash and can easily understand what the script is doing

2 - it must enforce security practices, as such it forces the viewing of the PKGBUILD and displays a "safety card" showing the maintainer, package name, date submitted, date last updated, votes, and popularity, it also shows id the maintainer has changes since last time

## usage
currently supports 2 arguments:

|Command | effect |
| ------ | ------ |
|`-Syu` | updates all AUR packages|
| `-S <package name>` | Installs a package |

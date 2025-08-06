# saur
A **S**imple and "secure" **AUR** helper written purely in bash

I had two goals with this project:

1 - it must be written in bash as most Arch users should be familiar with bash and can easily understand what the script is doing

2 - it must enforce security practices, as such it forces the viewing of the PKGBUILD and displays a "safety card" showing the maintainer, package name, date submitted, date last updated, votes, and popularity, it also shows id the maintainer has changes since last time

## AUR only dependenices
The way saur handles AUR only dependencies is in the following order:
```
1. Show "safety card" + any maintainer changes since last time (if package was previously installed)
2. Show PKGBUILDs individually and ask for confirmation after each
3. Build dependencies one by one
4. Then build the actual package
```

## Usage
currently supports 2 arguments:

|Command | effect |
| ------ | ------ |
|`-Syu` | updates all AUR packages|
| `-S <package name>` | Installs a package |

# EightyOne EmulatorJS core

The fixed source and controller regression are declared in `retrom-fork.json` and the build scripts.

Formal publication uses `build-release.py --output <absolute-empty-directory> --tag <tag>`.
The workflow runs the same native regression and pinned Web build for PRs and tags.
Only annotated tags reachable from the declared maintenance branch may publish;
release assets include the complete core source archive, license and integrity report.

# Hardware Dependencies

All hardware dependencies in this folder are git repositories themselves that are flattened into this repository. They are managed by [Bender](https://github.com/fabianschuiki/bender) instead of git submodules or subtrees. This allows us to have a flat repository where all changes are visible in a single repository. The downside is that changes to the dependencies need to be pulled/pushed to the upstream repository manually. The flow to do so is described here.

## Add new dependency

1. To add a new dependency, simply add it to the `Bender.yml` file and execute `bender update`. This will check the new dependencies and create a new `Bender.lock` entry. You can double check the lock file to make sure the correct commit will be checked out.
2. Execute a bender command, like `bender script vsim`, which will trigger Bender to actually check out the repository.
3. Remove the `.git` folder in the new dependency, which will flatten it into the main repository.
4. Add all the files from the submodule to git and create a commit. Make sure the main repository's `.gitignore` file is not excluding important files from the new dependency.

## Push changes to upstream

If you modify a dependency to implement some fixes or upgrades you want to contribute back to the upstream repository use the following flow. We use the `axi` dependency as an example.

1. Make sure the main repository is in a clean state and everything is checked in.
2. Delete the folder containing your dependency: `rm -rf deps/axi`
3. Check out the folder with Bender. This will restore the folder from the last point you synchronized it with the upstream repository. `make build`
4. Reset the changes in the dependency folder that you just introduced by checking out the last synchronization point. `git checkout deps/axi`
5. Now you restored the `.git` folder linked with the correct commit. However, the remote will be in the `.bender` folder. Add the upstream remote you want to push to. `cd deps/axi; git remote add upstream https://github.com/pulp-platform/axi`
6. Create/Checkout a branch and add the changes, push them to the upstream repository.
7. Remote the `.git` folder in the repo to reflatten the repository and add a commit updating the `Bender.lock` file to indicate the synchronization point.

## Pull changes from upstream

1. Make sure the main repository is in a clean state and everything is checked in.
2. Make sure your dependency has no changes compared to the last synchronization point that are not yet merged with the upstream repository.
3. Delete the folder containing your dependency: `rm -rf deps/axi`
4. Change the `Bender.yml`/`Bender.lock` to the version you want to upgrade to.
5. Pull the dependency through Bender. `make build`
6. Remove the dependency's `.git` folder.
7. Commit the changes to the dependency and the changes to the `Bender.*` files to the main repository.

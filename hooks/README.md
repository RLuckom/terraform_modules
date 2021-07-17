After the millionth time that my demo code didn't update because I made a commit to this
repo without running the snapshot command first, I made this pre-commit hook to do it automatically.

To use this hook, make sure you have a recent version of node installed and you have run `npm install` in the repo root.
Then copy the `pre-commit` file in this directory to the `.git/hooks` directory and make sure it's executable.

Before each commit, this will run the snapshot command and automatically add any changes from the `snapshots` directory
to the commit.

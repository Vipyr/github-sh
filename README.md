# Installation

Clone this repository somewhere on your file system.

Source the appropriate shell file in your `$HOME/.<shell>rc` file

Ensure `hub` is in your `$PATH` variable before running

## Getting Started with the Plugin:

Clone `github-sh`.

### Installing with `oh-my-zsh`:

```sh
mkdir $HOME/.oh-my-zsh/custom/plugin/github-sh
cd $HOME/.oh-my-zsh/custom/plugin/github-sh
ln -s /path/to/github-sh/clone/github-sh.plugin.zsh .
ln -s /path/to/github-sh/clone/_hub .
```
Add `github-sh` to the `plugins` array in your `.zshrc`.

### Installing with `zsh`:

Add the following to your `.zshrc`:
```
fpath=(/path/to/github-sh/clone $fpath)
compdef _hub hub
source /path/to/github-sh/clone/github-sh.plugin.zsh
```

### Installing with `bash`:

Add the following to your `.bashrc`:
```
source /path/to/github-sh/clone/github-sh.plugin.bash
```

### Installing with `ksh`:

Add the following to your `.kshrc`:
```
source /path/to/github-sh/clone/github-sh.plugin.ksh
```

### Setting up your hub wrappers:

Go to `github.com`

Click your picture in the top right and select "Settings"

Click "Developer Settings" near the bottom on the right

Click "Personal access tokens"

Click the "Generate new token" button in the top right

Confirm your password

Enter a token description (something like "hub in AFS")

Check the following:
```
       [x] repo
           [x] repo:status
           [x] repo_deployment
           [x] public_repo
           [x] repo:invite
       [x] notifications
       [x] user
           [x] read:user
           [x] user:email
           [x] user:follow
       [x] write:discussion
           [x] read:discussion
```


Copy the token value
 *****IMPORTANT***** This is the only time you will see this token value!

Run `set-gh-token <your-token> [github-hostname]`
    If `github-hostname` is not provided, `$GITHUB_HOST` is used.
    If `$GITHUB_HOST` is not set, then `github.com` is used.

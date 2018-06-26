# github
#
# Setup For GitHub:
#   Go to `github.com`
#   Click your picture in the top right and select "Settings"
#   Click "Developer Settings" near the bottom on the right
#   Click "Personal access tokens"
#   Click the "Generate new token" button in the top right
#   Confirm your password
#   Enter a token description (something like "hub in AFS")
#   Check the following:
#       [x] repo
#           [x] repo:status
#           [x] repo_deployment
#           [x] public_repo
#           [x] repo:invite
#       [x] notifications
#       [x] user
#           [x] read:user
#           [x] user:email
#           [x] user:follow
#       [x] write:discussion
#           [x] read:discussion
#   Co  py the token value
#     *****IMPORTANT***** This is the only time you will see this token value!
#   Run `set-gh-token <your-token> [github-hostname]`
#       If `github-hostname` is not provided, `$GITHUB_HOST` is used.
#       If `$GITHUB_HOST` is not set, then `github.com` is used.
#   User 
# 
# Setup For GitHub Enterprise:
#   Same as GitHub

# GitHub Token Functions
tokenfile() {
  if [ "$1" = "" ] ; then
    if [ "$GITHUB_HOST" = "" ] ; then
      TOKENFILE="$HOME/.github.com.token"
    else
      TOKENFILE="$HOME/.$GITHUB_HOST.token"
    fi
  else
    TOKENFILE="$HOME/.$1.token"
  fi
}

set-gh-token() {
  tokenfile "$2"
  echo "$1" | openssl rsautl -encrypt -inkey $HOME/.ssh/id_rsa > $TOKENFILE
}

get-gh-token() {
  tokenfile "$2"
  openssl rsautl -decrypt -inkey $HOME/.ssh/id_rsa -in $TOKENFILE
}

# Add a `gh` command that wraps `hub`, directs it to github.com and gets your token.
gh() {
  local -a args
  local nargs
  args=("$@")
  nargs=$#args
  for i in {1..$nargs} ; do
    if [ "${args[$i]}" = "pr" ] && [ "${args[$i+1]}" = "create" ] ; then
      args[$i]="pull-request"
      args[$i+1]=""
    fi
  done
  # Set github.com as the GitHub host and retrieve your token.
  #GITHUB_HOST=github.com 
  GITHUB_TOKEN=$(get-gh-token) hub $args
}


# Add the path to this directory to `fpath`
fpath=(${(%):-%N} $fpath)

compdef _hub gh=hub

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
      echo "$HOME/.github.com.token"
    else
      echo "$HOME/.$GITHUB_HOST.token"
    fi
  else
    echo "$HOME/.$1.token"
  fi
}

set-gh-token() {
  echo "$1" | openssl rsautl -encrypt -inkey $HOME/.ssh/id_rsa > $(tokenfile "$2")
}

get-gh-token() {
  openssl rsautl -decrypt -inkey $HOME/.ssh/id_rsa -in $(tokenfile "$1")
}

# Add a `_gh` command that wraps `hub`
_gh() {
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
  hub $args
}

add-gh-host() {
  if [ "$1" = "" ] || [ "$2" = "" ] ; then
    echo "\
usage: add-gh-host <hostname> <alias>
  <hostname>  The github hostname to add a hub function for i.e. github.com
  <alias>     The generated function name i.e. gh-pub.  $ gh-pub clone my-repo"
    # ?=1
  else
    (>/dev/null 2>&1 ping -c 1 "$1")
    _host_found=$?
    if [ "$_host_found" = 0 ] ; then
      # echo "Host '$1' found!"
      read "?token: " _token
      set-gh-token $_token $1
      echo "\
$2() {
  GITHUB_HOST=$1 GITHUB_TOKEN=\$(get-gh-token $1) _gh \$@
}
compdef _hub $2=hub" > $HOME/.gh-func-$2
      source $HOME/.gh-func-$2
    else
      echo "Host '$1' not found!"
    fi
  fi
}

# Add the path to this directory to `fpath`
fpath=(${(%):-%N} $fpath)

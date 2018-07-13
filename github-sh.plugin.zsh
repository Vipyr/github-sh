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
#   Run `add-gh-host <github-hostname> <alias>`

# GITHUB_SH_DIR=$(dirname ${(%):-%N})
GITHUB_SH_DIR=$HOME/.github-sh
if ! [ -e $GITHUB_SH_DIR ] ; then
  mkdir $GITHUB_SH_DIR
elif ! [ -d $GITHUB_SH_DIR ] ; then
  echo "$GITHUB_SH_DIR exists and is not a directory, aborting 'source github-sh'"
  return 1
fi

# GitHub Token Functions
tokenfile() {
  echo "$GITHUB_SH_DIR/$1.token"
}

gh-key-file() {
  echo "$GITHUB_SH_DIR/$1.key"
}

gh-ssh-key() {
  if ! [ -e "$(gh-key-file $1)" ] ; then
    echo -n "$HOME/.ssh/id_rsa" > "$(gh-key-file $1)"
  fi
  cat "$(gh-key-file $1)"
}

set-gh-token() {
  if [ "$1" = "" ] || [ "$2" = "" ] ; then
    echo "\
usage: set-gh-token <token> <hostname>
  <token>     Your Personal Access Token for <hostname>
  <hostname>  The github hostname to set the token for i.e. github.com"
    return 1
  else
    echo "$1" | openssl rsautl -encrypt -inkey $(gh-ssh-key "$2") > $(tokenfile "$2")
  fi
}

get-gh-token() {
  if [ "$1" = "" ] ; then
    echo "\
usage: get-gh-token <hostname>
  <hostname>  The github hostname to get the token for i.e. github.com"
    return 1
  else
    openssl rsautl -decrypt -inkey $(gh-ssh-key "$1") -in $(tokenfile "$1")
  fi
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

check-function-file() {
  if [ -e "$_function_file" ] ; then
    # Get user input about what to do if the file already exists
    _duplicate_file_action=""
    while [ "$_duplicate_file_action" = "" ] ; do
      read -k 1 "?$_function_file exists! abort, move, replace? [amR]: " _in
      echo
      if   [ "$_in" = "a" ] || [ "$_in" = "A" ] ; then
        _duplicate_file_action="a"
      elif [ "$_in" = "m" ] || [ "$_in" = "M" ] ; then
        _duplicate_file_action="m"
      elif [ "$_in" = "r" ] || [ "$_in" = "R" ] ; then
        _duplicate_file_action="r"
      else
        echo "Invalid input: options are [a, A, m, M, r, R]"
      fi
    done
    # Do something based on the input:
    #   a/A: Abort   -> quit
    #   m/M: Move    -> Change the name of the existing function
    #   r/R: Replace -> Replace the existing function
    if   [ "$_duplicate_file_action" = "a" ] ; then
      _function_file=""
    elif [ "$_duplicate_file_action" = "m" ] ; then
      read "?Change name to: " _move_name
      _move_function_file=$GITHUB_SH_DIR/gh-func-$_move_name
      echo "$_move_name() {" > $_move_function_file
      tail -n +2 $_function_file >> $_move_function_file
      source $_move_function_file
    elif [ "$_duplicate_file_action" = "r" ] ; then
      # No change, the function will be overwritten naturally.
    fi
  fi
}

add-gh-host() {
  if [ "$1" = "" ] || [ "$2" = "" ] ; then
    echo "\
usage: add-gh-host <hostname> <alias>
  <hostname>  The github hostname to add a hub function for i.e. github.com
  <alias>     The generated function name i.e. gh-pub.  $ gh-pub clone my-repo"
    return 1
  else
    (>/dev/null 2>&1 ping -c 1 "$1")
    _host_found=$?
    if [ "$_host_found" = 0 ] ; then
      _function_file="$GITHUB_SH_DIR/gh-func-$2"
      # Alert and abort for colliding function names
      check-function-file
      # _function_file is set to "" if the user decides to abort
      if [ "$_function_file" != "" ] ; then
        _ssh_key="$HOME/.ssh/id_rsa"
        read "?Ssh Key (\$HOME/.ssh/id_rsa): " _ssh_key_input
        if [ "$_ssh_key_input" != "" ] ; then
          _ssh_key=$_ssh_key_input
        fi
        echo -n "$_ssh_key" > "$(gh-key-file $1)"
        # Query for the PAT, if needed
        if ! [ -e $(tokenfile $1) ] ; then
          read "?Personal Access Token ($1): " _token
          # Save the PAT, encrypted with an ssh key
          set-gh-token $_token $1
        fi
        # Write and source the new shell function file
        echo "\
$2() {
  GITHUB_HOST=$1 GITHUB_TOKEN=\$(get-gh-token $1) _gh \$@
}
compdef $2=hub" > $_function_file
        source $_function_file
      fi
    else
      echo "Host '$1' not found!"
    fi
  fi
}

# Add the path to this directory to `fpath`
fpath=($GITHUB_SH_DIR $fpath)

# Source any gh function wrappers (generated by `add-gh-host`)
for _file in $(ls -a $GITHUB_SH_DIR) ; do
  if [ "$(echo $_file | cut -c 1-8)" = "gh-func-" ] ; then
    source $GITHUB_SH_DIR/$_file
  fi
done

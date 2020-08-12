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

GITHUB_SH_INSTALL_DIR=$(dirname ${(%):-%N})
GITHUB_SH_DIR=$HOME/.github-sh


gh-init-dir() {
  if ! [ -e $GITHUB_SH_DIR ] ; then
    mkdir $GITHUB_SH_DIR
  elif ! [ -d $GITHUB_SH_DIR ] ; then
    echo "$GITHUB_SH_DIR exists and is not a directory, aborting 'source github-sh'"
    return 1
  fi
}


# GitHub Token Functions
tokenfile() {
  echo "$GITHUB_SH_DIR/$1.token"
}


gh-init-gpg-agent() {
  local _rc
  gpg-agent --quiet >& /dev/null
  _rc=$?
  if [ "$_rc" != "0" ] ; then
    # Kill and clean up orphaned `gpg-agent`s
    for _line in "${(@f)$(ps -u $USER | grep gpg-agent)}" ; do
      kill ${${(ps: :)_line}[1]}
    done
    ls /tmp | grep gpg- >& /dev/null
    _rc=$?
    if [ "$_rc" = "0" ] ; then
      find /tmp/gpg-* -maxdepth 0 -user $USER -exec rm -rf {} \;
    fi
    # Then start up a new one
    eval $(gpg-agent --daemon)
  fi
}


gh-init-gpg-key() {
  gh-init-gpg-agent
  local _key_exists
  gpg --quiet --list-keys | grep GithubShell >& /dev/null
  _key_exists=$?
  if [ "$_key_exists" != "0" ] ; then
    echo "No GPG Key for github-sh detected, generating key \"GithubShell\" - this will take a while..."
    gpg --batch --gen-key "$GITHUB_SH_INSTALL_DIR/gpg-gen-key"
    echo "Key generated!"
  fi
}

set-gh-token() {
  local _token
  gh-init-dir
  if [ "$1" = "" ] ; then
    echo "\
usage: set-gh-token [<token>] <hostname>
  <token>     Your Personal Access Token for <hostname>. If not provided, the user will be prompted.
  <hostname>  The github hostname to set the token for i.e. github.com"
    return 1
  elif [ "$2" = "" ] ; then
    read "?Personal Access Token ($1): " _token
    # Save the PAT, encrypted with a gpg key
    set-gh-token $_token $1
  else
    echo "$1" | gpg --quiet -o $(tokenfile "$2") --encrypt --recipient GithubShell
    echo "$2 token added!"
  fi
}

get-gh-token() {
  gh-init-dir
  if [ "$1" = "" ] ; then
    echo "\
usage: get-gh-token <hostname>
  <hostname>  The github hostname to get the token for i.e. github.com"
    return 1
  else
    gpg --quiet --no-tty --decrypt $(tokenfile "$1") 2> /dev/null
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


check-gh-host() {
  gh-init-dir
  gh-init-gpg-key
  if [ "$1" = "" ] ; then
    echo "\
usage: remove-gh-host <hostname>  Check that your token works on the host"
    return 1
  else
    local response
    response=$(GITHUB_TOKEN=$(get-gh-token $1) curl https://api.$1/user -H "Authorization: token $GITHUB_TOKEN") >& /dev/null
    echo $response | grep "Bad credentials" >& /dev/null
    if [ $? -ne 0 ] ; then
      return 1
    fi
  fi
}


add-gh-host() {
  gh-init-dir
  gh-init-gpg-key
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
        # Query for the PAT, if needed
        if ! [ -e $(tokenfile $1) ] ; then
          # Get and save the PAT, encrypted with a gpg key
          set-gh-token $1
        fi
        # Write and source the new shell function file
        echo "\
$2() {
  gh-init-dir
  gh-init-gpg-key
  GITHUB_HOST=$1 GITHUB_TOKEN=\$(get-gh-token $1) _gh \$@
}
compdef $2=hub" > $_function_file
        source $_function_file
        echo "github-sh: Created alias '$2' for hub with token!"
      fi
    else
      echo "Host '$1' not found!"
    fi
  fi
}


remove-gh-host() {
  gh-init-dir
  gh-init-gpg-key
  if [ "$1" = "" ] ; then
    echo"\
usage: remove-gh-host <hostname>  Removes a specific host from your configuration
       remove-gh-host --all       Removes all hosts and configurations for github-sh"
    return 1
  else
    if [ "$1" = "--all" ] ; then
      # Go through all the files in the sh dir, find the func names and unset them
      for _file in $GITHUB_SH_DIR/gh-func-* ; do
        local func_name="$(basename $_file | cut -d\- -f3)"
        unfunction $func_name
      done
      # Then just blow everything away
      rm -rf $GITHUB_SH_DIR/*
    else
      # Find the func-file based on the hostname, then find the func name, delete and unset
      local func_files="$(grep -l "$1" $GITHUB_SH_DIR/gh-func-*)"
      local func_file
      for func_file in "${(@f)func_files}" ; do
        local func_name="$(basename $func_file | cut -d\- -f3)"
        rm -f $GITHUB_SH_DIR/$1*
        rm -f $func_file
        unfunction $func_name
      done
    fi

  fi
}


# Initialize the github shell directory
gh-init-dir

# Add the path to this directory to `fpath`
fpath=($GITHUB_SH_DIR $fpath)

# Source any gh function wrappers (generated by `add-gh-host`)
for _file in $GITHUB_SH_DIR/gh-func-* ; do
  source $_file
done

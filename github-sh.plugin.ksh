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

GITHUB_SH_INSTALL_DIR=$(dirname "$BASH_SOURCE")
GITHUB_SH_DIR=$HOME/.github-sh

gh_init_dir() {
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

gh_init_gpg_agent() {
  local __gpg_agent_rc
  gpg-agent --quiet 2>/dev/null
  __gpg_agent_rc=$?
  if [ "$__gpg_agent_rc" != "0" ] ; then
    eval $(gpg-agent --daemon)
  fi
}

gh_init_gpg_key() {
  gh_init_gpg_agent
  local _key_exists
  gpg --quiet --list-keys | grep GithubShell >/dev/null
  _key_exists=$?
  if [ "$_key_exists" != "0" ] ; then
    echo "No GPG Key for github-sh detected, generating key \"GithubShell\" - this will take a while..."
    gpg --batch --gen-key "$GITHUB_SH_INSTALL_DIR/gpg-gen-key"
    echo "Key generated!"
  fi
}

set_gh_token() {
  gh_init_dir
  gh_init_gpg_key
  if [ "$1" = "" ] || [ "$2" = "" ] ; then
    echo "\
usage: set_gh_token <token> <hostname>
  <token>     Your Personal Access Token for <hostname>
  <hostname>  The github hostname to set the token for i.e. github.com"
    return 1
  else
    echo "$1" | gpg --quiet -o $(tokenfile "$2") --encrypt --recipient GithubShell
    echo "$2 token added!"
  fi
}

get_gh_token() {
  gh_init_dir
  gh_init_gpg_key
  if [ "$1" = "" ] ; then
    echo "\
usage: get_gh_token <hostname>
  <hostname>  The github hostname to get the token for i.e. github.com"
    return 1
  else
    gpg --quiet --no-tty --decrypt $(tokenfile "$1") 2>/dev/null
  fi
}

# Add a `_gh` command that wraps `hub`
_gh() {
  args=("$@")
  for i in "${!args[@]}" ; do
    if [ "${args[$i]}" = "pr" ] && [ "${args[$i+1]}" = "create" ] ; then
      args[$i]="pull-request"
      args[$i+1]=""
    fi
  done
  # Set github.com as the GitHub host and retrieve your token.
  hub "${args[@]}"
}

check_function_file() {
  if [ -e "$_function_file" ] ; then
    # Get user input about what to do if the file already exists
    _duplicate_file_action=""
    while [ "$_duplicate_file_action" = "" ] ; do
      read _in?"$_function_file exists! abort, move, replace? [amR]: "
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
      read _move_name?"?Change name to: " 
      _move_function_file=$GITHUB_SH_DIR/gh-func-$_move_name
      echo "$_move_name() {" > $_move_function_file
      tail -n +2 $_function_file >> $_move_function_file
      source $_move_function_file
    elif [ "$_duplicate_file_action" = "r" ] ; then
      # No change, the function will be overwritten naturally.
      rm $_function_file 
    fi
  fi
}

add_gh_host() {
  gh_init_dir
  if [ "$1" = "" ] || [ "$2" = "" ] ; then
    echo "\
usage: add_gh_host <hostname> <alias>
  <hostname>  The github hostname to add a hub function for i.e. github.com
  <alias>     The generated function name i.e. gh-pub.  $ gh-pub clone my-repo"
    return 1
  else
    (>/dev/null 2>&1 ping -c 1 "$1")
    _host_found=$?
    if [ "$_host_found" = 0 ] ; then
      _function_file="$GITHUB_SH_DIR/gh-func-$2"
      # Alert and abort for colliding function names
      check_function_file
      # _function_file is set to "" if the user decides to abort
      if [ "$_function_file" != "" ] ; then
        # Query for the PAT, if needed
        if ! [ -e $(tokenfile $1) ] ; then
          # In KSH, read is backwards
          read _token?"Personal Access Token ($1): "
          # Save the PAT, encrypted with an ssh key
          set_gh_token $_token $1
        fi
        # Write and source the new shell function file
        echo "\
$2() {
  GITHUB_HOST=$1 GITHUB_TOKEN=\$(get_gh_token $1) _gh \"\$@\"
}
source $GITHUB_SH_DIR/hub.bash_completion.sh $2=hub" > $_function_file

        source $_function_file
        echo "github-sh: Created $2 alias for hub with token!" 
      fi
    else
      echo "Host '$1' not found!"
    fi
  fi
}

remove_gh_host() {
  if [ "$1" = "" ] ; then 
    echo"\
usage: remove_gh_host <hostname>  Removes a specific host from your configuration
       remove_gh_host --all       Removes all hosts and configurations for github-sh"
    return 1
  else
    if [ "$1" = "--all" ] ; then
      # Go through all the files in the sh dir, find the func names and unset them
      for _file in $(ls -a $GITHUB_SH_DIR) ; do
        if [ "$(echo $_file | cut -c 1-8)" = "gh-func-" ] ; then
          func_name="$(echo $_file | awk -F\- '{print $3}')"
          unset -f $func_name
        fi
      done
      # Then just blow everything away 
      rm -rf $GITHUB_SH_DIR/*
    else
      # Find the func-file based on the hostname, then find the func name, delete and unset
      func_file="$(grep -l "$1" $GITHUB_SH_DIR/*)"
      func_name="$(echo $func_file | awk -F\- '{print $3}')"
      rm -f $GITHUB_SH_DIR/$1*
      rm -f $GITHUB_SH_DIR/$func_file
      unset -f $func_name
    fi

  fi
}

# Initialize the github shell directory
gh_init_dir

# Add the path to this directory to `fpath`
fpath=($GITHUB_SH_DIR $fpath)

# Source any gh function wrappers (generated by `add-gh-host`)
for _file in $(ls -a $GITHUB_SH_DIR) ; do
  if [ "$(echo $_file | cut -c 1-8)" = "gh-func-" ] ; then
    source $GITHUB_SH_DIR/$_file
  fi
done

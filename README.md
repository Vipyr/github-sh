
# Installation

Clone this repository somewhere on your file system. 

Source the appropriate shell file in your `$HOME/.<shell>rc` file

Ensure `hub` is in your `$PATH` variable before running


# Getting Started with the Plugin:

   Go to `github.com`
   Click your picture in the top right and select "Settings"
   Click "Developer Settings" near the bottom on the right
   Click "Personal access tokens"
   Click the "Generate new token" button in the top right
   Confirm your password
   Enter a token description (something like "hub in AFS")
   Check the following:
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
   Co  py the token value
     *****IMPORTANT***** This is the only time you will see this token value!
   Run `set-gh-token <your-token> [github-hostname]`
       If `github-hostname` is not provided, `$GITHUB_HOST` is used.
       If `$GITHUB_HOST` is not set, then `github.com` is used.
   User 
 

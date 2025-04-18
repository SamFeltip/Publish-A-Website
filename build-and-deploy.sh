#!/bin/bash

VARS_FILE="deploy-vars.env"
declare -A VARS

# Load existing variables
if [ -f "$VARS_FILE" ]; then
  while IFS='=' read -r key val; do
    VARS["$key"]="${val%\"}"
    VARS["$key"]="${VARS["$key"]#\"}"
  done < "$VARS_FILE"
fi

# Prompt for any missing variables
prompt_if_missing() {
  local varname=$1
  local prompt=$2
  local silent=$3

  if [ -z "${VARS[$varname]}" ]; then
    if [ "$silent" = "true" ]; then
      read -s -p "$prompt" value && echo
    else
      read -p "$prompt" value
    fi
    VARS["$varname"]="$value"
  fi
}

echo ""
echo "✨ Let's get started!"
echo "We'll host your Astro site's code on github, and use Cloudflare to run the site itsself."
sleep 2
echo "If you want to stop the process at any time, just hit Ctrl+C."
sleep 1

prompt_if_missing "REPO_NAME" "🚀 What shall we name your repo (e.g. astro-cloudflare-demo)? "
prompt_if_missing "GITHUB_USER" "🐙 Your GitHub username (so we can find your starry home): "
prompt_if_missing "CLOUDFLARE_API_TOKEN" "🔐 Paste your Cloudflare API token (input hidden): " true
prompt_if_missing "ACCOUNT_ID" "🌩️  Your Cloudflare Account ID (found via 'wrangler whoami'): "

# Save all variables back to the file
cat > "$VARS_FILE" <<EOF
REPO_NAME="${VARS[REPO_NAME]}"
GITHUB_USER="${VARS[GITHUB_USER]}"
CLOUDFLARE_API_TOKEN="${VARS[CLOUDFLARE_API_TOKEN]}"
ACCOUNT_ID="${VARS[ACCOUNT_ID]}"
EOF

REPO_NAME="${VARS[REPO_NAME]}"
GITHUB_USER="${VARS[GITHUB_USER]}"
CLOUDFLARE_API_TOKEN="${VARS[CLOUDFLARE_API_TOKEN]}"
ACCOUNT_ID="${VARS[ACCOUNT_ID]}"

echo ""
echo "🛠️  Preparing your project... hang tight!"

npm create astro@latest "$REPO_NAME" -- --template minimal --typescript strict --install --yes
cd "$REPO_NAME"
npm install

echo "🌱 Growing a git repo..."
git init
git add .
git commit -m "Initial Astro commit"

echo "☁️  Beaming your project to GitHub..."
gh repo create "$GITHUB_USER/$REPO_NAME" --public --source=. --push

echo "⚡ Connecting to the Cloudflare Pages constellation..."
curl -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/pages/projects" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "'"$REPO_NAME"'",
    "production_branch": "main",
    "source": {
      "type": "github",
      "config": {
        "owner": "'"$GITHUB_USER"'",
        "repo_name": "'"$REPO_NAME"'",
        "production_branch": "main"
      }
    }
  }'

echo ""
echo "✅ All done!"
echo "Your Astro site '$REPO_NAME' now lives on GitHub *and* is linked to Cloudflare Pages."
echo "Deployments will trigger automatically whenever you push to main!"
echo "🪐 Happy site-building, space traveler."

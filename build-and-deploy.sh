#!/bin/bash

VARS_FILE="deploy-vars.env"

# Load existing variables from file
if [ -f "$VARS_FILE" ]; then
  source "$VARS_FILE"
fi

# Prompt for any missing variable
prompt_if_missing() {
  local var_name="$1"
  local label="$2"
  local secret="$3"
  
  # Check if variable is empty using indirect reference
  if [ -z "${!var_name}" ]; then
    if [ "$secret" == "true" ]; then
      read -s -p "$label" value
      echo
    else
      read -p "$label" value
    fi
    # Use eval to set the variable by name
    eval "$var_name=\"$value\""
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

# Write updated values back to the file
cat > "$VARS_FILE" << EOF
REPO_NAME="$REPO_NAME"
GITHUB_USER="$GITHUB_USER"
CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN"
ACCOUNT_ID="$ACCOUNT_ID"
EOF

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
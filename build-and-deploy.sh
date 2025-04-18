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
echo "We'll host your Astro site's code on GitHub, and use Cloudflare Pages for deployment."
sleep 2
echo "If you want to stop the process at any time, just hit Ctrl+C."
sleep 1

prompt_if_missing "REPO_NAME" "🚀 What shall we name your repo (e.g. astro-cloudflare-demo)? "
prompt_if_missing "GITHUB_USER" "🐙 Your GitHub username (so we can find your starry home): "

# Cloudflare API Token Instructions
echo ""
echo "📋 To get your Cloudflare API token:"
echo "  1. Log in to your Cloudflare dashboard (https://dash.cloudflare.com)"
echo "  2. Click on 'My Profile' in the top right corner"
echo "  3. Select 'API Tokens' from the left sidebar"
echo "  4. Click 'Create Token'"
echo "  5. Either use the 'Edit Cloudflare Workers' template or create a custom token with:"
echo "     - Account / Cloudflare Pages: Edit permission"
echo "     - Account / Account Settings: Read permission"
echo "  6. Complete the token creation process and copy the token provided"
echo ""

prompt_if_missing "CLOUDFLARE_API_TOKEN" "🔐 Paste your Cloudflare API token (input hidden): " true

# Get Account ID using wrangler
echo ""
echo "🔍 Checking for Cloudflare Account ID using wrangler..."
echo "If you haven't installed wrangler, run: npm install -g wrangler"
echo "If you haven't logged in to wrangler, run: wrangler login"
echo ""

if [ -z "$ACCOUNT_ID" ]; then
  if command -v wrangler &> /dev/null; then
    echo "Running wrangler whoami to get your account information..."
    WHOAMI_OUTPUT=$(wrangler whoami 2>&1)
    
    # Look for the line containing the Account ID in the table
    # The sample output shows it's in the second column of the account table row
    if echo "$WHOAMI_OUTPUT" | grep -q "Account ID"; then
      # Extract just the account ID (the actual ID value, not the header)
      EXTRACTED_ID=$(echo "$WHOAMI_OUTPUT" | grep -A 2 "Account ID" | tail -n 1 | awk -F '│' '{print $3}' | xargs)
      
      # Make sure we got something that looks like an ID (non-empty, not a header)
      if [[ -n "$EXTRACTED_ID" && "$EXTRACTED_ID" != *"Account ID"* ]]; then
        ACCOUNT_ID="$EXTRACTED_ID"
        echo "✅ Found Account ID: $ACCOUNT_ID"
      else
        echo "❌ Could not automatically extract Account ID."
        echo "Please look in the output below for your Account ID (a string of letters and numbers):"
        echo "$WHOAMI_OUTPUT"
        prompt_if_missing "ACCOUNT_ID" "🌩️  Your Cloudflare Account ID: "
      fi
    else
      echo "❌ Could not find Account ID in wrangler output."
      echo "Please look in the output below for your Account ID (a string of letters and numbers):"
      echo "$WHOAMI_OUTPUT"
      prompt_if_missing "ACCOUNT_ID" "🌩️  Your Cloudflare Account ID: "
    fi
  else
    echo "❌ wrangler command not found. Please install it with: npm install -g wrangler"
    echo "Then run wrangler login and wrangler whoami to find your Account ID."
    prompt_if_missing "ACCOUNT_ID" "🌩️  Your Cloudflare Account ID: "
  fi
else
  echo "✅ Using saved Account ID: $ACCOUNT_ID"
fi

# Write updated values back to the file
cat > "$VARS_FILE" << EOF
REPO_NAME="$REPO_NAME"
GITHUB_USER="$GITHUB_USER"
CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN"
ACCOUNT_ID="$ACCOUNT_ID"
EOF

echo ""
echo "🛠️  Preparing your project... hang tight!"

npm create astro@latest "$REPO_NAME" -- --typescript strict --install --yes
cd "$REPO_NAME"
npm install

echo "📦 Adding Cloudflare adapter to Astro..."
npm install @astrojs/cloudflare

# Create Cloudflare build configuration
echo "🔧 Configuring Astro for Cloudflare Pages..."
cat > astro.config.mjs << EOF
import { defineConfig } from 'astro/config';
import cloudflare from '@astrojs/cloudflare';

export default defineConfig({
  output: 'server',
  adapter: cloudflare(),
});
EOF

echo "🌱 Initializing git repo..."
git init
git add .
git commit -m "Initial commit with Cloudflare Pages configuration"

echo "☁️  Creating GitHub repository..."
gh repo create "$GITHUB_USER/$REPO_NAME" --public --source=. --push

echo "⚡ Connecting to Cloudflare Pages..."
curl -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/pages/projects" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "'"$REPO_NAME"'",
    "production_branch": "main",
    "build_config": {
      "build_command": "npm run build",
      "destination_dir": "dist",
      "root_dir": ""
    },
    "source": {
      "type": "github",
      "config": {
        "owner": "'"$GITHUB_USER"'",
        "repo_name": "'"$REPO_NAME"'",
        "production_branch": "main",
        "pr_comments_enabled": true,
        "deployments_enabled": true
      }
    }
  }'

echo "🚀 Triggering the first deployment..."

curl -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/pages/projects/$REPO_NAME/deployments" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json"

echo ""
echo "📡 Deployment triggered! You can monitor progress in your Cloudflare dashboard."
echo ""

echo ""
echo "✅ All done!"
echo "Your Astro site '$REPO_NAME' is now on GitHub and linked to Cloudflare Pages."
echo "The first deployment will begin automatically now that your code is pushed to GitHub."
echo "It may take a few minutes for Cloudflare to complete the initial build."
echo ""
echo "📋 To check deployment status and get your site URL:"
echo "  1. Go to https://dash.cloudflare.com"
echo "  2. Navigate to 'Pages'"
echo "  3. Find your project '$REPO_NAME'"
echo ""
echo "🪐 Happy site-building, space traveler!"
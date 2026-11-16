
#!/bin/sh
set -eu

# Install Mise
curl https://mise.run | sh

export PATH="$HOME/.local/bin:$PATH"

# Move to repository root
cd ..

# Install pinned Tuist version
mise install

# Resolve dependencies
mise exec -- tuist install

# Generate Xcode workspace without opening Xcode
mise exec -- tuist generate --no-open
chmod +x ci_scripts/ci_post_clone.sh
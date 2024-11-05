#!/bin/bash

set -e

#!/bin/bash

# Check if the GPG key ID was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <GPG Key ID>"
    exit 1
fi

KEY_ID=$1

# Print message
echo "Renewing GPG key expiration for key ID: $KEY_ID"

# Extend expiration for both primary key and subkey
gpg --command-fd 0 --status-fd 1 --edit-key "$KEY_ID" <<EOF
expire
1y
key 1
expire
1y
save
EOF

echo "The expiration dates for both the primary key and the first subkey with ID $KEY_ID have been successfully extended by 1 year."

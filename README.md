# Install Puppet Server using official chart
Our goal is to install puppet using official chart and provide adidtional customizations without modifying it.

## External Postgres
We will use our existing postgress instance and since official chart does not allow this directly we need to override a few things.

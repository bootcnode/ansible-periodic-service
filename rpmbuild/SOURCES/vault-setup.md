# Ansible Vault Setup for ansible-periodic-service

## Overview

The ansible-periodic-service supports Ansible Vault for encrypting sensitive variables in your `vars.yml` files. This allows you to store passwords, API keys, and other secrets securely in your git repository.

## Setting Up Vault Password

### 1. Create Vault Password File

Create a vault password file that the service can access:

```bash
# Create the vault password file
sudo mkdir -p /var/lib/ansible-periodic
echo "your_vault_password_here" | sudo tee /var/lib/ansible-periodic/.vault_password

# Secure the file (readable only by root)
sudo chmod 600 /var/lib/ansible-periodic/.vault_password
sudo chown root:root /var/lib/ansible-periodic/.vault_password
```

### 2. Encrypt Variables in Your Repository

In your git repository, encrypt sensitive variables using ansible-vault:

```bash
# Encrypt an entire vars.yml file
ansible-vault encrypt vars.yml

# Encrypt specific variables inline
ansible-vault encrypt_string 'secret_password' --name 'database_password'
```

### 3. Example Repository Structure

```
your-ansible-configs/
├── vars.yml                    # Can be encrypted
├── app1/
│   ├── task.yml
│   ├── vars.yml               # Can be encrypted
│   └── system-quadlets/
│       ├── myapp.container.j2
│       └── vars.yml           # Can be encrypted
└── app2/
    └── user-quadlets/
        └── username/
            ├── userapp.container.j2
            └── vars.yml       # Can be encrypted
```

### 4. Example Encrypted vars.yml

```yaml
# This file is encrypted with ansible-vault
database_host: "localhost"
database_user: "myapp"
database_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386439653762386631383336663966363262393061396464636439346436333636333865623534
          3834623531386166363963663936306437323534333763610a626163343634363965313462393330
          37323134636365653134626434303265316664643763353938316464643665323534373632363835
          3535326463623764650a373364396562623233343838363365363333623332643932663933643332
          3238
api_key: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          33363138613733313934613133653164313137336635613366653461346462323161656539626665
          6439643835333834343834323364346530383461383864610a316635373934393330363536363835
          31613734653036383834316331663937313462383565326432653264656464396464373833356665
          3431656432356533650a643034653166353761346132366465636566316633323931613836353538
          6438
```

### 5. Verify Setup

Test that the vault password is working:

```bash
# Run the service manually to test
sudo /usr/libexec/ansible-periodic/run-ansible-periodic.sh full

# Check the logs for vault-related messages
sudo journalctl -u ansible-periodic@full.service -f
```

## Troubleshooting

### Error: "Attempting to decrypt but no vault secrets found"

This error means:
1. Your `vars.yml` files are encrypted but no vault password file exists
2. The vault password file is in the wrong location
3. The vault password file has incorrect permissions

**Solution:**
- Ensure `/var/lib/ansible-periodic/.vault_password` exists
- Ensure it contains the correct password
- Ensure it has correct permissions (600, owned by root)

### Error: "Decryption failed"

This means the password in the vault file doesn't match the password used to encrypt the files.

**Solution:**
- Verify the password in `/var/lib/ansible-periodic/.vault_password`
- Re-encrypt your vars.yml files with the correct password

## Security Notes

- The vault password file is stored on the local system and readable only by root
- The ansible-periodic service runs as root, so it can access the vault password file
- Keep your vault password secure and don't store it in your git repository
- Consider using different vault passwords for different environments
- Regularly rotate your vault passwords and re-encrypt files 
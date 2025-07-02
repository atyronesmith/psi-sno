# OpenStack Secrets Directory

This directory contains sensitive configuration files that are **not checked into git** for security purposes.

## Setup Instructions

1. **Copy the example passwords file:**
   ```bash
   cp secrets/passwords.yaml.example secrets/passwords.yaml
   ```

2. **Edit the passwords file with your actual values:**
   ```bash
   vim secrets/passwords.yaml
   # or
   nano secrets/passwords.yaml
   ```

3. **Update passwords as needed:**
   - Use strong, unique passwords for production deployments
   - Consider using a password manager to generate secure passwords
   - Ensure passwords meet your organization's security requirements

## File Structure

- `passwords.yaml.example` - Sample configuration (safe to commit)
- `passwords.yaml` - Your actual passwords (never committed)
- `README.md` - This documentation (safe to commit)

## Security Notes

- ✅ The entire `secrets/` directory is excluded from git via `.gitignore`
- ✅ Only `.example` files are allowed to be committed
- ❌ Never commit actual password files to version control
- 🔒 Use appropriate file permissions: `chmod 600 secrets/passwords.yaml`

## Usage

The deployment scripts will automatically read from `secrets/passwords.yaml` if it exists, otherwise fall back to default passwords.

For production deployments, **always** use the secrets file approach rather than default passwords.
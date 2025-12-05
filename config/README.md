# Configuration Security

## Encrypted Password Setup

To protect your API credentials, passwords are stored encrypted using Windows Data Protection API (DPAPI).

### Initial Setup

1. Run the password setup script:
   ```powershell
   .\config\Setup-SecurePassword.ps1
   ```

2. Enter your password when prompted (input will be hidden)

3. The script creates `config\secure-password.txt` containing the encrypted password

### Security Features

- **Encrypted at rest**: Password is encrypted using Windows DPAPI
- **User-specific**: Can only be decrypted by the same Windows user account
- **Machine-specific**: Can only be decrypted on the same machine
- **Git-ignored**: The `secure-password.txt` file is automatically excluded from version control

### Changing the Password

To update the password, simply run the setup script again:
```powershell
.\config\Setup-SecurePassword.ps1
```

### Configuration Reference

The `api-config.psd1` file references the encrypted password file:

```powershell
Credentials = @{
    Username = "your-username"
    SecurePasswordFile = "secure-password.txt"
}
```

### Important Notes

⚠️ **Backup**: The encrypted password file cannot be transferred to another user or machine. Each user/machine needs to run `Setup-SecurePassword.ps1` independently.

⚠️ **Legacy Support**: Plain text `Password` field is still supported but deprecated and will show a warning in logs.

### Troubleshooting

**Error: "Secure password file not found"**
- Run `.\config\Setup-SecurePassword.ps1` to create the encrypted password file

**Error: "Failed to decrypt password"**
- The file was created by a different user or on a different machine
- Run `.\config\Setup-SecurePassword.ps1` again to recreate it with your credentials

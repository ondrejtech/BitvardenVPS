
# Kompletní dokumentace: Vaultwarden + Windows 11 + 2FA Google Authenticator

## Shrnutí

**Projekt:** Vaultwarden (self-hosted Bitwarden)  
**Doména:** `https://bitwarden.ozelina.eu`  
**Provoz přes:** Apache reverzní proxy, HTTPS (Let's Encrypt)  
**Porty:** pouze 443  
**Zálohování:** lokálně + NAS `/mnt/NAS/export/vulgarden`  
**Další:** 2FA přihlašování přes Google Authenticator

---

## 1. Instalace a příprava serveru

### Instalace Podman
```bash
sudo dnf install -y podman
```

### Instalace Apache, Certbot a další
```bash
sudo dnf install -y httpd epel-release
sudo dnf install -y certbot python3-certbot-apache
```

### Instalace Argon2 nástroje
```bash
sudo dnf install -y argon2
```

---

## 2. Příprava adresářů

```bash
sudo mkdir -p /opt/vaultwarden/data
sudo mkdir -p /opt/vaultwarden/backup
sudo chown -R $USER:$USER /opt/vaultwarden
```

---

## 3. Konfigurace Vaultwarden

### `.env` soubor

V `/opt/vaultwarden/.env`:

```dotenv
ADMIN_TOKEN=$argon2id$v=19$m=65536,t=2,p=1$c29tZXNhbHQ$2T2iaRgIGBpIzcV174KosLmjD4ww/ZAk0q58IYa68Jc
SIGNUPS_ALLOWED=false
```

_(hash generován pomocí příkazu níže)_

### Generování hash pro ADMIN_TOKEN

```bash
echo -n "TvojeTajneHeslo" | argon2 somesalt -id -t 2 -m 16 -p 1
```
Použij výstup z "Encoded:" části.

### `podman-compose.yml`

V `/opt/vaultwarden/podman-compose.yml`:

```yaml
version: "3.8"

services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: always
    env_file:
      - .env
    ports:
      - 127.0.0.1:8080:80
    volumes:
      - ./data:/data
```

---

## 4. Nastavení HTTPS certifikátu

Zastavení Apache:
```bash
sudo systemctl stop httpd
```

Získání certifikátu:
```bash
sudo certbot certonly --standalone -d bitwarden.ozelina.eu --preferred-challenges http
```

Zapnutí Apache:
```bash
sudo systemctl start httpd
```

---

## 5. Apache reverzní proxy

Vytvoř `/etc/httpd/conf.d/bitwarden.ozelina.eu.conf`:

```apache
<VirtualHost *:443>
    ServerName bitwarden.ozelina.eu

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/bitwarden.ozelina.eu/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/bitwarden.ozelina.eu/privkey.pem

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/

    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"

    ErrorLog /var/log/httpd/bitwarden_error.log
    CustomLog /var/log/httpd/bitwarden_access.log combined
</VirtualHost>
```

Restart Apache:
```bash
sudo systemctl restart httpd
```

---

## 6. Spuštění Vaultwarden

```bash
cd /opt/vaultwarden
podman-compose up -d
```

---

## 7. Automatické zálohování Vaultwarden

### Skript `/opt/vaultwarden/backup.sh`

```bash
#!/bin/bash

DATE=$(date +'%Y-%m-%d_%H-%M-%S')

# Záloha dat
tar czf /opt/vaultwarden/backup/vaultwarden_backup_$DATE.tar.gz -C /opt/vaultwarden/data .

# Kopírování na NAS
cp /opt/vaultwarden/backup/vaultwarden_backup_$DATE.tar.gz /mnt/NAS/export/vulgarden/

# Čištění starých záloh
find /opt/vaultwarden/backup/ -type f -mtime +7 -name "*.tar.gz" -exec rm {} \;
```

Nastavení spustitelnosti:
```bash
chmod +x /opt/vaultwarden/backup.sh
```

### Cronjob

```bash
sudo crontab -e
```

Přidej:
```cron
0 6 * * * /opt/vaultwarden/backup.sh
0 0 * * * /opt/vaultwarden/backup.sh
```

---

## 8. Propojení s Windows 11

### Aplikace

- Stáhni Bitwarden z Microsoft Store.
- V nastavení aplikace změň **Server URL** na:
  ```
  https://bitwarden.ozelina.eu
  ```
- Přihlas se svým účtem.

### Rozšíření pro prohlížeče

- Instaluj rozšíření Bitwarden pro Chrome, Firefox nebo Edge.
- Nastav také vlastní Server URL na `https://bitwarden.ozelina.eu`.

---

## 9. Aktivace 2FA pomocí Google Authenticator

1. Přihlas se na `https://bitwarden.ozelina.eu`.
2. Jdi do "Account Settings" -> "Two-step Login".
3. Vyber "Authenticator App".
4. Naskenuj QR kód v aplikaci Google Authenticator.
5. Zadej vygenerovaný 6místný kód.
6. Ulož zálohovací kódy!

---

# Hotovo!

Vaultwarden je nasazen, zabezpečen SSL certifikátem, propojen s Windows 11 a chráněn 2FA ověřením.

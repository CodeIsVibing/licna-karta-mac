# Lična karta na Mac-u

Podešavanje srpske lične karte sa čipom za prijavu na eUpravu, eFakturu (SEF) i druge državne portale na macOS-u. Jedna komanda u Terminalu, bez ručnog podešavanja.

## Instalacija

1. Priključi čitač kartica i ubaci ličnu kartu.
2. Otvori **Terminal** i nalepi:

```bash
curl -fsSL https://raw.githubusercontent.com/CodeIsVibing/licna-karta-mac/main/install.sh | bash
```

3. Unesi lozinku Mac-a kada je skripta zatraži.
4. Zatvori Firefox potpuno (Cmd + Q) i otvori ga ponovo.

Prijava: otvori https://efaktura.mfin.gov.rs/login u Firefox-u, izaberi prijavu kvalifikovanim elektronskim sertifikatom, izaberi sertifikat za autentifikaciju i unesi PIN lične karte.

## Šta skripta radi

1. Instalira Firefox sa mozilla.org, ako već nije instaliran, i proverava Mozilla potpis.
2. Preuzima open-source modul [srb-id-pkcs11](https://github.com/ubavic/srb-id-pkcs11) (verzija v0.6.0) za tvoj procesor (Apple Silicon ili Intel) i proverava njegov SHA-256 otisak. Ako se otisak ne poklapa, ništa se ne instalira.
3. Postavlja modul u `/Library/Application Support/srb-id-pkcs11/`.
4. Upisuje Firefox sistemsku politiku (`/Library/Preferences/org.mozilla.firefox`) koja modul dodaje pod imenom "Licna karta" u svaki Firefox profil. Postojeće Firefox politike ostaju sačuvane.

## Zašto Firefox

MUP ne izdaje softver za lične karte za macOS. Brave, Chrome i Safari na macOS-u uzimaju sertifikate samo od sistema, a sistem ne ume da pročita sertifikate sa srpske lične karte. Firefox može direktno da učita modul za karticu.

## Provera

U Firefox-u otvori `chrome://pippki/content/device_manager.xhtml`. U levoj listi treba da piše "Licna karta", a ispod nje čitač i token "NetSeT's CardEdge Token".

## Uklanjanje

1. U Terminalu ukloni politiku i modul:

```bash
sudo defaults delete /Library/Preferences/org.mozilla.firefox SecurityDevices
sudo rm -r "/Library/Application Support/srb-id-pkcs11"
```

2. U Firefox-u otvori `chrome://pippki/content/device_manager.xhtml`, izaberi "Licna karta" i klikni **Unload**.

## Napomena o bezbednosti

Modul srb-id-pkcs11 nije zvaničan softver MUP-a. To je open-source projekat koji je napisao Nikola Ubavić i koji se distribuira bez garancije. Modul ima pristup kartici i PIN-u. Ova skripta preuzima tačno određenu verziju modula sa GitHub stranice projekta i odbija svaki fajl čiji se otisak razlikuje od proverenog.

Testirano na macOS 26 (Apple Silicon) sa novom ličnom kartom (ATR "SCE 8.0-C2V0") i čitačem Hama.

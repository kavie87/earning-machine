# Earning machine

Docker setup for bandwidth-sharing apps on one Debian or Ubuntu computer, plus EarnApp's official Linux installer.

Each app shares this computer's internet connection and pays according to its own rules. Read the terms for an app before you enable it. Run one instance of each app on this computer's own connection. These services check the network and limit how many devices they pay on one address.

## Apps

| App | How it runs |
| --- | --- |
| Honeygain | Official Docker image `honeygain/honeygain` |
| Pawns | Official Docker image `iproyal/pawns-cli` |
| PacketStream | Official Docker image `packetstream/psclient` |
| TraffMonetizer | Official Docker image `traffmonetizer/cli_v2` |
| Repocket | Official Docker image `repocket/repocket` |
| Mysterium | Official Docker image `mysteriumnetwork/myst`, host networking |
| Bitping | Official Docker image `bitping/bitpingd` |
| AntGain | Official Docker image `pinors/antgain-cli` |
| EarnApp | Official Linux installer, then a browser link to your account |
| Watchtower | Optional. Updates only containers in this project, every 12 hours |

EarnApp is installed on the host with the installer published by EarnApp. The setup script downloads that installer, then you accept EarnApp's terms in the installer and open the link it prints.

Mysterium uses the host network and the `NET_ADMIN` capability, which is the official Docker run method for a node. Its identity is kept in the `mysterium-data` volume.

## Set up

On the Linux computer:

```bash
git clone https://github.com/kavie87/earning-machine.git
cd earning-machine
bash setup.sh
```

The script asks which apps to enable, then writes `.env` so only your user can read it. `.env` is gitignored.

Start or stop a single app later:

```bash
docker compose --profile honeygain up -d
docker compose stop honeygain
```

EarnApp, after it is installed:

```bash
sudo earnapp register
sudo earnapp status
sudo earnapp stop
```

Bitping accounts with two-factor authentication need `BITPING_MFA` added to `.env` and to the `bitping` service environment. The node stores its login in the `bitping-data` volume. Run one Bitping node per credentials directory.

## Secrets

Keep `.env` on the Linux computer. Honeygain's password and the TraffMonetizer token are passed as container arguments, because that is how those official images accept them. Anyone who can run `docker inspect` on this machine can read those two values.

## Signup links

Replace the empty cells with your own referral links before you point people at this repo.

| App | Link |
| --- | --- |
| Honeygain | https://join.honeygain.com/SPARE2A1D9 |
| EarnApp | |
| Pawns | |
| PacketStream | https://packetstream.io/?psr=5wim |
| TraffMonetizer | |
| Repocket | |
| Mysterium | |
| Bitping | |
| AntGain | |

## Useful logs

```bash
docker compose logs -f honeygain
docker logs -f mysterium
```

AntGain can take up to two minutes to become healthy. Check it with:

```bash
docker exec antgain antgain health
```

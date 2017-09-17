# DEPLOYMENT

Vimflowy supports deployment to docker, checkout the
[`Dockerfile`](/Dockerfile) for technical details, or head over to [Docker
hub](https://hub.docker.com/r/vimflowy/vimflowy/) for ops details.

## Example deployment

Tested on an Ubuntu 16.04 server running docker `17.05.0-ce`.

First we create a volume called `vimflowy-db` to hold the
[SQLite](storage/SQLite.md) databases. Then we run vimflowy container mounting
in the `vimflowy-db` volume

```
$ docker volume create vimflowy-db
$ docker run -d \
             -e VIMFLOWY_PASSWORD=supersecretpassword \
             --name vimflowy \
             --mount source=vimflowy-db,target=/app/db \
             -p 3000:3000 \
             --restart unless-stopped \
             vimflowy/vimflowy
```

Alternatively you can make use of [Docker Compose](https://docs.docker.com/compose/). Create the file below

```yaml
# docker-compose.yml
version: "3"
services:
  vimflowy:
    image: vimflowy/vimflowy
    ports:
      - "3000:3000"
```

Launch vimflowy with `docker-compose up`


## Environment variables

You can override certain aspects of the container through environment variables that (specified in `-e` options in the `docker run` command).

* `VIMFLOWY_PASSWORD`: The server password, specified by the user in *Settings
> Data Storage > Vimflowy Server*

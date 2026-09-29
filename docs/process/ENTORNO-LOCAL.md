# Montar el entorno local desde cero

Cómo dejar Samay corriendo en una máquina nueva (portátil de clase, equipo
prestado) con datos suficientes para enseñar la app: cuentas, amigos,
partidas, eventos, grupos y chats.

Todo lo que sigue se ha ejecutado tal cual en Windows (Git Bash) y está
escrito pensando en Linux, que es donde suele terminar.

## Qué hace falta

| Herramienta | Para qué | Comprobar |
|---|---|---|
| Docker + Docker Compose | el stack de Supabase | `docker compose version` |
| Python 3 | firma los JWT del stack local | `python3 -c "print(1)"` |
| curl | sube las imágenes de prueba | `curl --version` |
| Flutter | compila la app | `flutter doctor` |

No hace falta `psql` ni `jq`: todo lo de base de datos pasa por
`docker exec`.

## Los dos comandos

```bash
git clone https://github.com/DaereanLegrand/Vive.git
cd Vive
bash tools/setup_dev.sh
```

Tarda unos minutos (la última parte descarga ~70 fotos de prueba). Al
terminar imprime las cuentas y cómo arrancar la app.

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54386 \
  --dart-define=SUPABASE_ANON_KEY=$(cat .anon_key)
```

Para jugar con dos cuentas a la vez hacen falta dos ventanas con perfiles
separados de Chrome:

```bash
google-chrome --user-data-dir=/tmp/vive-A --new-window http://127.0.0.1:8765 &
google-chrome --user-data-dir=/tmp/vive-B --new-window http://127.0.0.1:8765 &
```

## Cuentas que deja preparadas

| Cuenta | Clave | Para qué |
|---|---|---|
| `diag@test.com` | `Diagnostico123` | anfitrión de las 4 partidas |
| `jugador2@test.com` … `jugador6@test.com` | `Diagnostico123` | el resto de la mesa |
| `tester@tester.com` | `tester123` | el universo grande: 8 grupos, 15 eventos, chats |
| `tester2@tester.com` … `tester40@tester.com` | `tester123` | relleno con foto real |

Las seis cuentas `demo` son amigas entre sí, llevan 2500 shards y 400
preshards, y tienen cuatro partidas montadas con **todos marcados como
Listo**, así que se puede pulsar Empezar de inmediato.

`botella-trio` queda **privada a propósito**: sirve para comprobar en dos
ventanas que, al encender «Partida abierta», la partida aparece al instante
en el lobby de la otra cuenta.

## Lo que el stack self-hosted no trae resuelto

Esto es lo que cuesta descubrir la primera vez. El script ya lo hace, pero
conviene saber qué está pasando cuando algo falle.

**El tenant de Realtime.** Kong reescribe la cabecera `Host` al proxear, así
que Realtime busca un tenant que se llame como el contenedor
(`samay-realtime`) y el stack solo trae `realtime-dev`. Sin esa fila, todo el
tiempo real responde 403 y nada se actualiza en vivo. El `jwt_secret` hay que
**copiarlo** de la fila que ya existe: está cifrado con AES-128-ECB y la clave
`DB_ENC_KEY`, así que meterlo en claro revienta con
`non-alphabet character found`.

**Las claves de Kong duran 24 horas.** Cuando caducan, absolutamente todo
responde `Unauthorized`. Se arregla con:

```bash
bash tools/setup_dev.sh --keep-db
```

y **recompilando la app**, porque la clave va incrustada en el build.

**Reiniciar Kong borra sus credenciales.** Su entrypoint regenera la
configuración desde el archivo montado, y las credenciales se añaden encima
en caliente. Si reinicias ese contenedor a mano, vuelve a pasar por
`--keep-db`.

**CRLF en Windows.** `git` con `core.autocrlf=true` reescribe los scripts
montados en cada checkout y el bash del contenedor de Kong no los puede leer:
entra en bucle de reinicio con `set: pipefail: invalid option name` y nada
responde. El paso 0 del script lo normaliza.

**El `python3` de pega de Windows.** La Microsoft Store instala un alias
`python3` que existe pero no ejecuta nada. El script comprueba que Python
*corre*, no solo que el comando esté.

**Las claves de cifrado del chat se generan en el cliente.** Una cuenta que
nunca ha iniciado sesión no tiene paquete de claves publicado, y la consola se
llena de `e2ee session initiate FAILED`. No es un fallo: se arregla entrando
una vez con esa cuenta.

## Si algo va mal

| Síntoma | Causa casi segura |
|---|---|
| Todo responde `Unauthorized` / 401 | la clave caducó → `--keep-db` + recompilar |
| Nada se actualiza en vivo | falta el tenant `samay-realtime` → paso 3 |
| Kong reiniciándose en bucle | CRLF en los scripts montados → paso 0 |
| Avatares y portadas rotos | falta la ruta pública de storage en `kong.yml` |
| Login del seed: `Database error querying schema` | columnas de token en NULL en `auth.users` → paso 7 |
| `e2ee session initiate FAILED` | esa cuenta nunca inició sesión; es inofensivo |

## Volver a empezar

```bash
bash tools/setup_dev.sh              # borra la base y la rehace entera
bash tools/setup_dev.sh --sin-datos  # igual, pero sin el seed grande
```

# ACL - WIP

Para configurar la ACL del broker, se usa una `aclfile`:

Esto determina que acciones puede tomar cada dispositivo

```aclfile
# Dispositivos. %u se reemplaza por el usuario, que es tambien el device-id.

pattern write  fak/v1/devices/%u/meta/availability
pattern write  fak/v1/devices/%u/meta/identity
pattern write  fak/v1/devices/%u/meta/capabilities
pattern write  fak/v1/devices/%u/meta/health
pattern write  fak/v1/devices/%u/readings/+
pattern write  fak/v1/devices/%u/actionables/+/result
pattern write  fak/v1/devices/%u/actionables/+/state
pattern write  fak/v1/devices/%u/config/reported

pattern read   fak/v1/devices/%u/actionables/+/command
pattern read   fak/v1/devices/%u/config/desired

# Lo que sea que funcioune de backend, debería de poder leer todo, y escribir en `/actionables/+/command` y `/config/desired`

user backend
topic read   fak/v1/#
topic write  fak/v1/devices/+/actionables/+/command
topic write  fak/v1/devices/+/config/desired
```

Esta ACL no tiene contemplado que haya dispositivos que envien peticiones a otros dispositivos sin pasar antes por un eventual backend. Eso hay que verlo

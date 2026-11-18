# bspwn

## Manual

### Antialiasing de fuentes

El suavizado (antialiasing) de las fuentes lo controla **fontconfig**, no la
terminal. El archivo es:

```
dot/.config/fontconfig/fonts.conf   ->   ~/.config/fontconfig/fonts.conf
```

Tiene dos bloques de render:

1. **Global** (`<match target="font">` sin `<test>`): antialias activado,
   `hintslight`, subpíxel `rgb`. Aplica a todas las apps.
2. **Solo Alacritty** (filtrado por `prgname = alacritty`): fuerza
   `antialias = false` + `hintfull` para texto "pixelado"/nítido.
   **Viene desactivado** (comentado).

#### Activar/desactivar el antialias en Alacritty

- **Con antialias (por defecto):** el bloque de Alacritty debe estar comentado,
  es decir, envuelto entre las dos líneas marcadas `NO-AA-ALACRITTY`.
- **Sin antialias (texto nítido):** borra las dos líneas marcadas
  `NO-AA-ALACRITTY` para que el bloque quede activo.

Después de cualquier cambio:

```sh
fc-cache -f          # refresca la caché de fontconfig
# cierra y vuelve a abrir Alacritty (no basta con recargar su config)
```

#### Aplicarlo a otras apps

Dentro del `<test name="prgname">` puedes añadir más programas, uno por línea:

```xml
<test name="prgname" compare="eq">
  <string>alacritty</string>
  <string>polybar</string>
  <string>conky</string>
</test>
```

Para cambiar el antialias de **todo** el sistema edita el bloque global
(`<bool>true</bool>` → `<bool>false</bool>` en `antialias`).

#### Comprobar qué se está aplicando

```sh
fc-match -v 'BlexMono Nerd Font Mono:prgname=alacritty' | grep -E 'antialias|hintstyle'
```

`antialias: True` = suavizado activo; `False` = desactivado.
`xmllint --noout ~/.config/fontconfig/fonts.conf` valida que el XML no esté roto.

### Tema de arranque (GRUB + Plymouth)

Tema GRUB monocromo estilo terminal ASCII con el sigilo 四, en
`system/boot/grub/themes/bspwn/` (generado por `scripts/grub/gen_theme.py`;
edita el script, no los archivos generados).

```sh
python3 scripts/grub/gen_theme.py   # regenerar el tema
./install.sh -boot                  # instalar + activar el enforcer
```

**Sobrevive a las actualizaciones:** `/etc/default/grub.d/zz-bspwn.cfg` se lee
después de `kali-themes.cfg`, y el hook de apt
`/etc/apt/apt.conf.d/99-enforce-boot-theme` ejecuta
`/usr/local/sbin/enforce-boot-theme` tras cada `apt`: si `grub.cfg` ya no usa el
tema bspwn ejecuta `update-grub`, y si Plymouth cambió de tema (o un initramfs
nuevo no lo incluye) lo reaplica.

```sh
sudo enforce-boot-theme status            # qué está fijado / activo
sudo enforce-boot-theme plymouth <tema>   # fijar otro tema de Plymouth
```

Los temas de Plymouth se copian a `/usr/share/plymouth/themes/<tema>/` antes de
fijarlos (p. ej. de github.com/adi1090x/plymouth-themes).

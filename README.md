# DRUPAL 8 - INSTALACIÓN Y PASO ENTRE ENTORNOS

## INSTALACIÓN

### DRUPAL
####Requerimientos
* [Node 0.10 o superior](http://nodejs.org)
* [Ruby 2.1.5](https://www.ruby-lang.org/)
* [Composer](https://getcomposer.org/)
* [Capistrano 3.2](http://capistranorb.com/)

#### Preparación del entorno (si ya se tiene instalado omitir)

Nos bajamos el repositorio y creamos el archivo web/sites/default/settings.local.php (podemos copiar web/sites/default/example.settings.local.php) y añadimos nuestra configuración de base de datos.

* Instalar Node (https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-an-ubuntu-14-04-server)
* Instalar Ruby (recomendado con `rvm`)
(
```sh
 $ gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
 $ \curl -sSL https://get.rvm.io | bash -s stable --ruby
```
)
* Instalar Composer (si ya se tiene instalado omitir)
```sh
$ curl -sS https://getcomposer.org/installer | php
$ sudo mv composer.phar /usr/local/bin/composer
```

* Instalar las dependencias de node, ruby y bower (bundler necesario:  sudo gem install bundler)

```sh
$ cd web/
$ composer install
$ cd ..
$ bundle install
$ npm install
```

Nos bajamos la base de datos del entorno dev, y la importamos en local (tenemos que tener creada la base de datos):
```sh
$ cap dev drupal:dump_dl
```

#### Gestión de la configuración
Siempre que se exporte la configuración para subirla al repositorio (Ejemplo en la rama dev):
```sh
$ cap local drupal:config:export
$ git commit -a -m "MENSAJE"
$ git pull dev
```
Arreglamos posibles conflictos
```sh
$ cap local drupal:config:import
$ git push origin dev
```

#### Paso entre ENTORNOS
##### Primera vez (ejemplo en stage dev):
Previamente copiamos la base de datos en el servidor
y
```sh
$ cap dev deploy
```
Nos dará error, creamos el web/sites/default/example.settings.local.php

```sh
$ cap dev composer:install_executable
$ cap dev deploy
```
##### Posteriores:
Subir a dev (sube la rama dev):
```sh
$ cap dev deploy
```
Subir a test (sube la rama test):
```sh
$ cap test deploy
```

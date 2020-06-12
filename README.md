# Libelula
Libélula es una herramienta de línea de comandos de GNU/Linux que automatiza la compilación, empaquetado, tagueo en SVN, entrega de RPMs resultantes y envío de correos de notificación a interesados, a partir de fuentes de softwares que usan RPM como tecnología de empaquetado de software.

## Contexto
En mi antigua empresa en la que trabajaba, una conocida multinacional española, formaba parte del equipo de Gestión de Configuración y Entorno Linux, que entre otras cosas se encargaba de recibir solicitudes de equipos de desarrollo para la construcción y empaquetado de su software.

Este proceso llevaba unos 30 minutos de trabajo rutinario en el que había que ejecutar una serie de pasos manuales como si de una receta de cocina se tratase. Esto provocaba que nuestro grupo fuera un cuello de botella para todos los grupos de desarrollo, que tenían que esperar a que nosotros les enviáramos de vuelta el software empaquetado, y una productividad bajísima por nuestra parte.

Después de varios meses, propuse a mi responsable la posibilidad de desarrollar una herramienta capaz de realizar este trabajo de manera automática, y que los integrantes del equipo se dedicaran a innovar y evolucionar los sistemas y plataformas los cuales estaban bastante anticuados (para eso es para lo que están los ingenieros ¿no?). Este responsable no apoyó la propuesta y en su lugar ejerció más presión sobre nosotros para tratar de minimizar el tiempo de generación, intentando que el trabajo manual se hiciera más rápido y sin errores.

Algunos meses después, para evitar este trabajo tedioso y repetitivo, decidí dedicar las tardes al llegar a casa a desarrollar aquella herramienta que propuse a mi responsable el cual no estuvo a favor de desarrollarla en la empresa.

La idea era usarla a nivel privado para ser más productivo en la empresa, pero rápidamente otros integrantes del grupo la vieron y empezaron a usarla también. Llegué a presentarla a los equipos de desarrollo, los cuales empezaron a utilizarla también.

Tras abandonar la empresa, propiciado por la falta de innovación tecnológica y por responsables que en mi opinión tomaban decisiones desafortunadas, esperaba que esta herramienta dejara de usarse (al fin y al cabo no pertenecía a la empresa), pero me consta que tras casi dos años después aún se sigue utilizando. Es por ello por lo que he decidido publicar el código fuente con licencia GPLv3. De esta manera, los equipos que aún la usan podrán seguirla manteniendo y adaptando a sus necesidades, siempre que se cumplan las restricciones de la licencia.

## Uso
En el directorio `doc` se distribuyen unas diapositivas que explican el modo de uso de la herramienta.

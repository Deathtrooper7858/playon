import os
import yt_dlp


# ============================================================
# CONFIGURACIÓN
# ============================================================

# URL DE TU PLAYLIST
PLAYLIST_URL = (
    "https://music.youtube.com/playlist"
    "?list=PLaBNnr4Zq668"
    "&si=xqSN0kdf3t5bUJHG"
)


# ============================================================
# CARPETA DESCARGAS
# ============================================================

# Detectar automáticamente la carpeta de descargas en Arch Linux / Linux
try:
    import subprocess
    carpeta_descargas = subprocess.check_output(
        ['xdg-user-dir', 'DOWNLOAD'],
        text=True
    ).strip()
except Exception:
    carpeta_descargas = os.path.join(
        os.path.expanduser("~"),
        "Downloads"
    )


# ============================================================
# OBTENER INFORMACIÓN DE LA PLAYLIST
# ============================================================

print()
print("=" * 60)
print("     DESCARGADOR DE PLAYLIST")
print("=" * 60)
print()

print("Obteniendo información de la playlist...")
print()


opciones_info = {
    "quiet": True,
    "extract_flat": True,

    # No detener el proceso por elementos no disponibles
    "ignoreerrors": True,
}


try:

    with yt_dlp.YoutubeDL(opciones_info) as ydl:
        info = ydl.extract_info(
            PLAYLIST_URL,
            download=False
        )

except Exception as error:

    print()
    print("ERROR AL OBTENER LA PLAYLIST")
    print()
    print(error)

    input("\nPresiona ENTER para cerrar...")
    exit()


# ============================================================
# NOMBRE DE LA PLAYLIST
# ============================================================

nombre_playlist = info.get(
    "title",
    "Playlist"
)


# Limpiar caracteres que Windows no permite
caracteres_invalidos = '<>:"/\\|?*'

for caracter in caracteres_invalidos:
    nombre_playlist = nombre_playlist.replace(
        caracter,
        "_"
    )


# ============================================================
# CREAR CARPETA DE LA PLAYLIST
# ============================================================

carpeta_playlist = os.path.join(
    carpeta_descargas,
    nombre_playlist
)


os.makedirs(
    carpeta_playlist,
    exist_ok=True
)


print(f"Playlist: {nombre_playlist}")
print()
print(f"Carpeta de destino:")
print(carpeta_playlist)
print()


# ============================================================
# ARCHIVO DE REGISTRO
# ============================================================

# Este archivo permite recordar qué elementos
# ya fueron procesados.

archivo_registro = os.path.join(
    carpeta_playlist,
    "descargas.txt"
)


# ============================================================
# OPCIONES DE DESCARGA
# ============================================================

opciones = {

    # Obtener el mejor audio disponible
    "format": "bestaudio/best",


    # Nombre de los archivos
    #
    # Ejemplo:
    #
    # 001 - Nombre de la canción.mp3
    #
    "outtmpl": os.path.join(
        carpeta_playlist,
        "%(playlist_index)03d - %(title)s.%(ext)s"
    ),


    # Convertir audio a MP3
    "postprocessors": [

        {
            "key": "FFmpegExtractAudio",

            "preferredcodec": "mp3",

            "preferredquality": "320",
        }

    ],


    # No detener toda la playlist
    # si una canción no está disponible
    "ignoreerrors": True,


    # No sobrescribir archivos existentes
    "nooverwrites": True,


    # Continuar descargas incompletas
    "continuedl": True,


    # Número de reintentos
    "retries": 10,


    # Reintentos de fragmentos
    "fragment_retries": 10,


    # Archivo de registro
    #
    # yt-dlp utilizará este archivo para
    # recordar elementos procesados.
    "download_archive": archivo_registro,


    # Mostrar progreso de descarga
    "progress": True,


    # Mostrar mensajes normales
    "quiet": False,


    # No mostrar información innecesaria
    "no_warnings": False,
}


# ============================================================
# INICIAR DESCARGA
# ============================================================

print("=" * 60)
print("INICIANDO DESCARGA")
print("=" * 60)
print()

print("Los elementos no disponibles serán ignorados.")
print()

try:

    with yt_dlp.YoutubeDL(opciones) as ydl:

        ydl.download(
            [PLAYLIST_URL]
        )


except KeyboardInterrupt:

    print()
    print()
    print("Descarga detenida por el usuario.")
    print()

    print(
        "Puedes ejecutar nuevamente el programa "
        "para continuar."
    )


except Exception as error:

    print()
    print("=" * 60)
    print("SE PRODUJO UN ERROR")
    print("=" * 60)
    print()

    print(error)


# ============================================================
# FINAL
# ============================================================

print()
print()
print("=" * 60)
print("          PROCESO TERMINADO")
print("=" * 60)
print()

print("Playlist:")
print(nombre_playlist)

print()

print("Ubicación:")
print(carpeta_playlist)

print()

print(
    "Los elementos procesados se registran en:"
)

print(archivo_registro)

print()

print(
    "Si algunos elementos no estaban disponibles, "
    "yt-dlp los habrá omitido."
)

print()

print(
    "Puedes ejecutar nuevamente este programa "
    "para intentar procesar los elementos pendientes."
)

print()

input("Presiona ENTER para cerrar...")  
import os
import json
import re
import traceback
import urllib.request
import yt_dlp
from mutagen import File as MutagenFile
from mutagen.mp4 import MP4, MP4Cover
from mutagen.easyid3 import EasyID3
from mutagen.id3 import ID3, ID3NoHeaderError

def clean_title(title):
    """Limpia sufijos típicos de YouTube / YouTube Music en títulos de canciones."""
    if not title:
        return ""
    cleaned = re.sub(
        r'[\(\[\{]\s*(?:official\s*video|official\s*audio|official\s*music\s*video|video\s*oficial|audio\s*oficial|letra|lyrics|video\s*con\s*letra|videoclip|hd|4k|remastered|visualizer|audio|lyric\s*video)\s*[\)\]\}]',
        '',
        title,
        flags=re.IGNORECASE
    )
    return re.sub(r'\s+', ' ', cleaned).strip()

def parse_artist_title(raw_title, uploader=""):
    """Intenta separar 'Artista - Canción' y limpiar el nombre de artista."""
    cleaned = clean_title(raw_title)
    artist = uploader or ""
    title = cleaned

    # Limpiar sufijos típicos del uploader como ' - Topic' o 'VEVO'
    if artist.endswith(" - Topic"):
        artist = artist[:-8].strip()
    elif artist.lower().endswith("vevo"):
        artist = artist[:-4].strip()

    # Si el título contiene ' - ' o ' – '
    if " - " in cleaned:
        parts = cleaned.split(" - ", 1)
        artist = parts[0].strip()
        title = parts[1].strip()
    elif " – " in cleaned:
        parts = cleaned.split(" – ", 1)
        artist = parts[0].strip()
        title = parts[1].strip()

    return artist, title

def _build_ydl_opts(extra_headers=None, cookies_str=""):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    }
    if cookies_str:
        headers['Cookie'] = cookies_str

    if extra_headers:
        headers.update(extra_headers)

    return {
        'quiet': True,
        'no_warnings': True,
        'http_headers': headers,
    }

def get_audio_url(url, cookies_str=""):
    ydl_opts = _build_ydl_opts(cookies_str=cookies_str)
    ydl_opts['format'] = 'bestaudio/best'
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            return info.get('url', '')
    except Exception as e:
        return "ERROR:" + str(e) + "\n" + traceback.format_exc()

def get_playlist_info(url, cookies_str=""):
    """Extrae información completa de una playlist o video individual de YouTube/YT Music."""
    ydl_opts = _build_ydl_opts(cookies_str=cookies_str)
    ydl_opts['extract_flat'] = 'in_playlist'
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if not info:
                return json.dumps({"error": "No se pudo obtener información del enlace"})

            playlist_title = info.get('title', 'Descarga')
            tracks = []

            if 'entries' in info and info['entries']:
                for entry in info['entries']:
                    if not entry:
                        continue
                    vid_id = entry.get('id', '')
                    raw_title = entry.get('title', '')
                    uploader = entry.get('uploader') or entry.get('channel') or ''
                    duration = entry.get('duration') or 0
                    thumbnail = entry.get('thumbnail') or ''

                    artist, title = parse_artist_title(raw_title, uploader)

                    tracks.append({
                        "id": vid_id,
                        "title": title or raw_title,
                        "artist": artist or "Artista desconocido",
                        "duration": int(duration) if duration else 0,
                        "thumbnail": thumbnail,
                        "url": f"https://www.youtube.com/watch?v={vid_id}" if vid_id else url,
                    })
            else:
                # Video individual
                vid_id = info.get('id', '')
                raw_title = info.get('title', '')
                uploader = info.get('uploader') or info.get('channel') or ''
                duration = info.get('duration') or 0
                thumbnail = info.get('thumbnail') or ''

                artist, title = parse_artist_title(raw_title, uploader)

                tracks.append({
                    "id": vid_id,
                    "title": title or raw_title,
                    "artist": artist or "Artista desconocido",
                    "duration": int(duration) if duration else 0,
                    "thumbnail": thumbnail,
                    "url": f"https://www.youtube.com/watch?v={vid_id}" if vid_id else url,
                })

            return json.dumps({
                "title": playlist_title,
                "tracks": tracks,
            })
    except Exception as e:
        return json.dumps({"error": str(e)})

def download_audio(url, out_path, title="", artist="", album="", thumbnail_url="", cookies_str=""):
    if out_path.endswith('.m4a'):
        base_path = out_path[:-4]
    else:
        base_path = out_path

    ydl_opts = _build_ydl_opts(cookies_str=cookies_str)
    ydl_opts.update({
        'format': 'bestaudio[ext=m4a]/bestaudio[ext=mp4]/bestaudio',
        'outtmpl': base_path + '.%(ext)s',
        'noplaylist': True,
    })

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            if not title and info:
                title = info.get('title', '')
            if not artist and info:
                artist = info.get('uploader', '')
            if not thumbnail_url and info:
                thumbnail_url = info.get('thumbnail', '')

        # Asegurar archivo .m4a
        final_file = None
        if os.path.exists(out_path):
            final_file = out_path
        else:
            for ext in ('m4a', 'webm', 'opus', 'mp4', 'ogg'):
                candidate = base_path + '.' + ext
                if os.path.exists(candidate):
                    if candidate != out_path:
                        os.replace(candidate, out_path)
                    final_file = out_path
                    break

        if not final_file or not os.path.exists(final_file):
            return "ERROR: archivo descargado no encontrado en " + base_path

        # ── Incrustar etiquetas ID3 / MP4 y carátula de álbum ─────────────
        try:
            mp4 = MP4(final_file)
            if mp4.tags is None:
                mp4.add_tags()

            parsed_artist, parsed_title = parse_artist_title(title, artist)
            mp4.tags['\xa9nam'] = [parsed_title or title]
            mp4.tags['\xa9ART'] = [parsed_artist or artist]
            if album:
                mp4.tags['\xa9alb'] = [album]

            # Descargar e incrustar carátula si existe thumbnail_url
            if thumbnail_url and thumbnail_url.startswith(('http://', 'https://')):
                try:
                    req = urllib.request.Request(
                        thumbnail_url,
                        headers={'User-Agent': 'Mozilla/5.0'}
                    )
                    with urllib.request.urlopen(req, timeout=10) as resp:
                        img_data = resp.read()
                        if img_data:
                            covr_format = MP4Cover.FORMAT_PNG if thumbnail_url.endswith('.png') else MP4Cover.FORMAT_JPEG
                            mp4.tags['covr'] = [MP4Cover(img_data, imageformat=covr_format)]
                except Exception as cover_err:
                    print(f"Warning: could not embed cover art: {cover_err}")

            mp4.save()
        except Exception as tag_err:
            print(f"Warning: could not save mp4 tags: {tag_err}")

        return "SUCCESS"
    except Exception as e:
        return "ERROR:" + str(e) + "\n" + traceback.format_exc()

def get_audio_tags(file_path):
    try:
        if not file_path:
            return json.dumps({"error": "Ruta inválida"})

        audio = MutagenFile(file_path)
        if audio is None:
            return json.dumps({"title": "", "artist": "", "album": ""})

        title = ""
        artist = ""
        album = ""

        if isinstance(audio, MP4) or file_path.lower().endswith(('.m4a', '.mp4')):
            tags = audio.tags or {}
            title = str(tags.get('\xa9nam', [''])[0]) if tags.get('\xa9nam') else ""
            artist = str(tags.get('\xa9ART', [''])[0]) if tags.get('\xa9ART') else ""
            album = str(tags.get('\xa9alb', [''])[0]) if tags.get('\xa9alb') else ""
        else:
            if hasattr(audio, 'tags') and audio.tags:
                title = str(audio.tags.get('title', [''])[0]) if audio.tags.get('title') else ""
                artist = str(audio.tags.get('artist', [''])[0]) if audio.tags.get('artist') else ""
                album = str(audio.tags.get('album', [''])[0]) if audio.tags.get('album') else ""

        return json.dumps({"title": title, "artist": artist, "album": album})
    except Exception as e:
        return json.dumps({"error": str(e)})

def set_audio_tags(file_path, title, artist, album):
    try:
        if not file_path:
            return "ERROR: Ruta inválida"

        if file_path.lower().endswith(('.m4a', '.mp4')):
            mp4 = MP4(file_path)
            if mp4.tags is None:
                mp4.add_tags()
            if title: mp4.tags['\xa9nam'] = [title]
            if artist: mp4.tags['\xa9ART'] = [artist]
            if album: mp4.tags['\xa9alb'] = [album]
            mp4.save()
            return "SUCCESS"
        elif file_path.lower().endswith('.mp3'):
            try:
                audio = EasyID3(file_path)
            except ID3NoHeaderError:
                id3 = ID3()
                id3.save(file_path)
                audio = EasyID3(file_path)
            if title: audio['title'] = [title]
            if artist: audio['artist'] = [artist]
            if album: audio['album'] = [album]
            audio.save()
            return "SUCCESS"
        else:
            audio = MutagenFile(file_path, easy=True)
            if audio is not None and hasattr(audio, 'tags') and audio.tags is not None:
                if title: audio['title'] = [title]
                if artist: audio['artist'] = [artist]
                if album: audio['album'] = [album]
                audio.save()
                return "SUCCESS"
            return "ERROR: Formato no soportado para edición de tags"
    except Exception as e:
        return "ERROR: " + str(e) + "\n" + traceback.format_exc()
